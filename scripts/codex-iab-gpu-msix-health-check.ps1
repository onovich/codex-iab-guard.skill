[CmdletBinding()]
param(
    [ValidateSet('Current', 'IncidentEvidence')]
    [string]$Mode = 'Current',

    [ValidateRange(1, 720)]
    [int]$LookbackHours = 48
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageName = 'OpenAI.Codex'
$packageFamilyName = 'OpenAI.Codex_2p2nqsd0c76g0'
$lookbackStart = (Get-Date).AddHours(-$LookbackHours)

function Get-EventsSafely {
    param(
        [Parameter(Mandatory)]
        [string]$LogName,

        [Parameter(Mandatory)]
        [datetime]$StartTime,

        [int[]]$Ids
    )

    try {
        $filter = @{
            LogName = $LogName
            StartTime = $StartTime
        }
        if ($Ids -and $Ids.Count -gt 0) {
            $filter.Id = $Ids
        }
        return @(Get-WinEvent -FilterHashtable $filter -ErrorAction Stop)
    }
    catch {
        return @()
    }
}

function Get-StateChangeEntries {
    $stateRoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModel\StateChange\PackageList'
    if (-not (Test-Path -LiteralPath $stateRoot)) {
        return @()
    }

    return @(
        Get-ChildItem -LiteralPath $stateRoot -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'OpenAI\.Codex|2p2nqsd0c76g0' } |
            ForEach-Object {
                $properties = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
                [pscustomobject]@{
                    RegistryLeaf = Split-Path -Leaf $_.Name
                    PackageStatus = $properties.PackageStatus
                }
            }
    )
}

function Get-CodexProcesses {
    return @(
        Get-Process -Name @('ChatGPT', 'Codex') -ErrorAction SilentlyContinue |
            ForEach-Object {
                [pscustomobject]@{
                    Name = $_.ProcessName
                    Id = $_.Id
                    Responding = $_.Responding
                }
            }
    )
}

if ($Mode -eq 'IncidentEvidence') {
    $appModelEvents = Get-EventsSafely `
        -LogName 'Microsoft-Windows-AppModel-Runtime/Admin' `
        -StartTime $lookbackStart `
        -Ids @(6, 202, 217)

    $activationFailures = @(
        $appModelEvents |
            Where-Object {
                $_.Message -match '0x(?:8007)?3CFC|machine-level package status' -or
                $_.Message -match 'OpenAI\.Codex.*GetPackageToken'
            }
    )

    $containerDestruction = @(
        $appModelEvents |
            Where-Object {
                $_.Id -eq 217 -and $_.Message -match 'OpenAI\.Codex'
            }
    )

    $storeEvents = Get-EventsSafely `
        -LogName 'Microsoft-Windows-Store/Operational' `
        -StartTime $lookbackStart

    $modifiedState = @(
        $storeEvents |
            Where-Object {
                $_.Message -match $packageFamilyName -and
                $_.Message -match 'appxState=2'
            }
    )

    $firewallEvents = Get-EventsSafely `
        -LogName 'Microsoft-Windows-Windows Firewall With Advanced Security/Firewall' `
        -StartTime $lookbackStart `
        -Ids @(2097, 2099)

    $firewallConsent = @(
        $firewallEvents |
            Where-Object {
                $_.Message -match 'OpenAI\.Codex_.+\\app\\(?:ChatGPT|Codex)\.exe'
            }
    )

    $codeIntegrityEvents = Get-EventsSafely `
        -LogName 'Microsoft-Windows-CodeIntegrity/Operational' `
        -StartTime $lookbackStart `
        -Ids @(3033)

    $gpuCodeIntegrity = @(
        $codeIntegrityEvents |
            Where-Object {
                $_.Message -match '(?:ChatGPT|Codex)\.exe' -and
                $_.Message -match 'vk_swiftshader\.dll|GPU'
            }
    )

    $packageFailureFound = $activationFailures.Count -gt 0 -and $modifiedState.Count -gt 0
    $gpuFailureFound = $gpuCodeIntegrity.Count -gt 0
    $appxSideFound = $packageFailureFound -or $containerDestruction.Count -gt 0
    $chainEvidenceFound = $gpuFailureFound -and $appxSideFound
    $partialEvidenceFound = $gpuFailureFound -or $appxSideFound

    [pscustomobject]@{
        Mode = $Mode
        Safety = 'Read-only; Codex, AppX, registry, firewall, and browser state were not modified.'
        Verdict = if ($chainEvidenceFound) {
            'IAB_GPU_MSIX_CHAIN_EVIDENCE_FOUND'
        } elseif ($gpuFailureFound) {
            'GPU_SIDE_ONLY_NEEDS_CORRELATION'
        } elseif ($packageFailureFound) {
            'MSIX_SIDE_ONLY_NEEDS_CORRELATION'
        } elseif ($containerDestruction.Count -gt 0) {
            'APPX_SIDE_ONLY_NEEDS_CORRELATION'
        } else {
            'NO_MATCHING_EVIDENCE_IN_LOOKBACK'
        }
        LookbackStart = $lookbackStart.ToString('o')
        ActivationFailureCount = $activationFailures.Count
        PackageModifiedStateCount = $modifiedState.Count
        AppxContainerDestructionCount = $containerDestruction.Count
        GpuCodeIntegrityEventCount = $gpuCodeIntegrity.Count
        FirewallConsentEventCount = $firewallConsent.Count
        FirstActivationFailureTime = if ($activationFailures.Count -gt 0) {
            ($activationFailures | Sort-Object TimeCreated | Select-Object -First 1).TimeCreated.ToString('o')
        } else {
            $null
        }
        FirstFirewallConsentTime = if ($firewallConsent.Count -gt 0) {
            ($firewallConsent | Sort-Object TimeCreated | Select-Object -First 1).TimeCreated.ToString('o')
        } else {
            $null
        }
        CausationNote = 'Event ordering can disprove that a button click caused the crash, but temporal proximity alone cannot prove a root cause.'
    } | ConvertTo-Json -Depth 5

    if ($partialEvidenceFound) {
        exit 2
    }
    exit 0
}

$packages = @(
    Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending
)
$package = if ($packages.Count -gt 0) { $packages[0] } else { $null }
$stateChangeEntries = @(Get-StateChangeEntries)
$nonzeroStateEntries = @(
    $stateChangeEntries |
        Where-Object {
            $null -ne $_.PackageStatus -and
            [int64]$_.PackageStatus -ne 0
        }
)

$installLocation = if ($null -ne $package) { [string]$package.InstallLocation } else { '' }
$packageStatus = if ($null -ne $package) { $package.Status.ToString() } else { 'Missing' }
$healthy = (
    $null -ne $package -and
    $packageStatus -eq 'Ok' -and
    (Test-Path -LiteralPath $installLocation) -and
    $nonzeroStateEntries.Count -eq 0
)

[pscustomobject]@{
    Mode = $Mode
    Safety = 'Read-only; Codex, AppX, registry, firewall, and browser state were not modified.'
    Verdict = if ($healthy) { 'HEALTHY' } else { 'UNHEALTHY' }
    Package = if ($null -ne $package) {
        [pscustomobject]@{
            FullName = $package.PackageFullName
            FamilyName = $package.PackageFamilyName
            Version = $package.Version.ToString()
            Status = $packageStatus
            InstallLocationExists = Test-Path -LiteralPath $installLocation
        }
    } else {
        $null
    }
    NonzeroPackageStateEntries = $nonzeroStateEntries
    RunningProcesses = @(Get-CodexProcesses)
} | ConvertTo-Json -Depth 7

if ($healthy) {
    exit 0
}
exit 2
