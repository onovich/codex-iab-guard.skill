[CmdletBinding()]
param(
    [ValidateSet('Inspect', 'Quarantine')]
    [string]$Mode = 'Inspect',

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ThreadId,

    [ValidatePattern('^$|^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ConfirmThreadId = '',

    [string]$StatePath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBomStrict = New-Object System.Text.UTF8Encoding($false, $true)

if ([string]::IsNullOrWhiteSpace($StatePath)) {
    $StatePath = Join-Path $env:USERPROFILE '.codex\.codex-global-state.json'
}

$StatePath = [System.IO.Path]::GetFullPath($StatePath)
$defaultStatePath = [System.IO.Path]::GetFullPath(
    (Join-Path $env:USERPROFILE '.codex\.codex-global-state.json')
)
$isDefaultStatePath = [string]::Equals(
    $StatePath,
    $defaultStatePath,
    [System.StringComparison]::OrdinalIgnoreCase
)
$targetKey = "thread-browser-tabs-v1:$ThreadId"
$candidatePaths = @($StatePath)
$stateBackupPath = "$StatePath.bak"

if (Test-Path -LiteralPath $stateBackupPath -PathType Leaf) {
    $candidatePaths += $stateBackupPath
}

function Read-CodexState {
    param([Parameter(Mandatory)][string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path, $script:utf8NoBomStrict)
    try {
        $state = $raw | ConvertFrom-Json
    }
    catch {
        throw "Refusing to touch invalid JSON at '$Path': $($_.Exception.Message)"
    }

    $atomsProperty = $state.PSObject.Properties['electron-persisted-atom-state']
    if ($null -eq $atomsProperty -or $null -eq $atomsProperty.Value) {
        throw "Refusing to touch '$Path': electron-persisted-atom-state is missing."
    }

    [pscustomobject]@{
        Path = $Path
        State = $state
        Atoms = $atomsProperty.Value
    }
}

function Test-TargetKey {
    param(
        [Parameter(Mandatory)]$Atoms,
        [Parameter(Mandatory)][string]$Key
    )

    return $null -ne $Atoms.PSObject.Properties[$Key]
}

if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
    throw "Codex state file not found: $StatePath"
}

$documents = @()
foreach ($path in $candidatePaths) {
    $document = Read-CodexState -Path $path
    $keyExists = Test-TargetKey -Atoms $document.Atoms -Key $targetKey
    $tabCount = 0
    if ($keyExists) {
        $entry = $document.Atoms.PSObject.Properties[$targetKey].Value
        $tabCount = @($entry.tabs).Count
    }

    Write-Output ("{0}: KeyExists={1}; TabCount={2}" -f $path, $keyExists, $tabCount)
    $documents += [pscustomobject]@{
        Path = $document.Path
        State = $document.State
        Atoms = $document.Atoms
        KeyExists = $keyExists
    }
}

if ($Mode -eq 'Inspect') {
    Write-Output 'READ_ONLY_INSPECTION_COMPLETE'
    exit 0
}

if (-not [string]::Equals(
    $ThreadId,
    $ConfirmThreadId,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    Write-Output 'REFUSED: -ConfirmThreadId must exactly match -ThreadId. No file was changed.'
    exit 3
}

if ($isDefaultStatePath) {
    $runningCodex = @(Get-Process -Name @('ChatGPT', 'Codex') -ErrorAction SilentlyContinue)
    if ($runningCodex.Count -gt 0) {
        Write-Output (
            'REFUSED: Codex Desktop is running. Close every Codex window, wait for ' +
            'ChatGPT.exe/Codex.exe to exit, and run this command again. No file was changed.'
        )
        exit 3
    }
}

$documentsToChange = @($documents | Where-Object { $_.KeyExists })
if ($documentsToChange.Count -eq 0) {
    Write-Output "ALREADY_QUARANTINED: $targetKey"
    exit 0
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$prepared = @()

try {
    foreach ($document in $documentsToChange) {
        $originalTopLevelCount = @($document.State.PSObject.Properties).Count
        $originalAtomCount = @($document.Atoms.PSObject.Properties).Count
        $document.Atoms.PSObject.Properties.Remove($targetKey)

        if (Test-TargetKey -Atoms $document.Atoms -Key $targetKey) {
            throw "Failed to remove the target key in memory for '$($document.Path)'."
        }

        $newJson = $document.State | ConvertTo-Json -Depth 100 -Compress
        $tempPath = "$($document.Path).browser-quarantine-$([guid]::NewGuid().ToString('N')).tmp"
        [System.IO.File]::WriteAllText($tempPath, $newJson, $utf8NoBomStrict)

        $validated = Read-CodexState -Path $tempPath
        $validatedTopLevelCount = @($validated.State.PSObject.Properties).Count
        $validatedAtomCount = @($validated.Atoms.PSObject.Properties).Count

        if (Test-TargetKey -Atoms $validated.Atoms -Key $targetKey) {
            throw "Validation failed: target key remains in '$tempPath'."
        }
        if ($validatedTopLevelCount -ne $originalTopLevelCount) {
            throw "Validation failed: top-level property count changed for '$($document.Path)'."
        }
        if ($validatedAtomCount -ne ($originalAtomCount - 1)) {
            throw "Validation failed: more than the target atom changed for '$($document.Path)'."
        }

        $prepared += [pscustomobject]@{
            Path = $document.Path
            TempPath = $tempPath
            BackupPath = "$($document.Path).pre-browser-quarantine-$timestamp.backup"
            Replaced = $false
        }
    }

    foreach ($item in $prepared) {
        [System.IO.File]::Replace($item.TempPath, $item.Path, $item.BackupPath, $true)
        $item.Replaced = $true
    }

    foreach ($item in $prepared) {
        $verified = Read-CodexState -Path $item.Path
        if (Test-TargetKey -Atoms $verified.Atoms -Key $targetKey) {
            throw "Post-write verification failed for '$($item.Path)'."
        }
    }
}
catch {
    foreach ($item in $prepared) {
        if ($item.Replaced -and (Test-Path -LiteralPath $item.BackupPath -PathType Leaf)) {
            [System.IO.File]::Copy($item.BackupPath, $item.Path, $true)
        }
        if (Test-Path -LiteralPath $item.TempPath -PathType Leaf) {
            Remove-Item -LiteralPath $item.TempPath -Force
        }
    }
    throw "Quarantine failed; changed files were rolled back where possible. $($_.Exception.Message)"
}

Write-Output "QUARANTINED: $targetKey"
foreach ($item in $prepared) {
    Write-Output "Backup: $($item.BackupPath)"
}
Write-Output 'Task history was not deleted. Only the selected task persisted in-app browser state was removed.'
exit 0
