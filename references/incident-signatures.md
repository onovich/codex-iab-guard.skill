# Incident signatures and public evidence

Use this reference to classify evidence, not to claim a root cause that has not been proven.

## Closest public reports

- [openai/codex#27828](https://github.com/openai/codex/issues/27828): Cloudflare Turnstile in the in-app browser, GPU crash, GPU relaunch failure, then an unlaunchable Windows app requiring repair/reinstall. This is the closest trigger-and-impact match.
- [openai/codex#32094](https://github.com/openai/codex/issues/32094): embedded-browser media/canvas pages reproduce the same GPU exit codes and AppX-container termination. The issue states that the browser team tracks it as `BRWPL-293`.
- [openai/codex#34133](https://github.com/openai/codex/issues/34133): browser screenshot causes Windows Code Integrity Event 3033 for bundled `vk_swiftshader.dll`, followed by GPU crash and launch failure. This is a plausible mechanism for some incidents, not proof for every GPU crash.
- [openai/codex#35132](https://github.com/openai/codex/issues/35132): the same Code Integrity, `Modified`/`NeedsRemediation`, and `0x3CFC` chain was reported on `26.721.3996.0`; GitHub marks it as a duplicate of #34133. A healthy reinstall of this build is therefore recovery evidence, not proof of a permanent product fix.
- [openai/codex#34311](https://github.com/openai/codex/issues/34311): sidebar browser use followed by package state `Modified, NeedsRemediation` and an app that will not launch until reinstall.
- [openai/codex#21912](https://github.com/openai/codex/issues/21912): Windows-specific in-app-browser bootstrap failure. It is adjacent, but does not include the fatal package-state chain.
- [openai/codex#23814](https://github.com/openai/codex/issues/23814): silent Windows app restarts with heavy in-app-browser/sidebar lifecycle churn. It is adjacent, not an exact match.

## Evidence classes

### Exact or near-exact

The incident is in the same public bug family when these appear together:

1. A Codex in-app-browser/sidebar action loads a Cloudflare, canvas, media, WebGL, WebCodecs, or screenshot-capable page.
2. Codex logs:

   ```text
   Recoverable Chromium child process gone ... processType=GPU reason=crashed
   Recoverable Chromium child process gone ... processType=GPU reason=launch-failed
   ```

3. Codex exits, the AppX container is destroyed, or the next launch fails.
4. Windows reports `Modified`, `NeedsRemediation`, `appxState=2`, `0x3CFC`, or `0x80073CFC`; Store repair/restage/reinstall restores launchability.

### Strongly related

- In-app Browser cannot bootstrap or disappears on Windows.
- Browser activity immediately precedes a silent Codex restart.
- A packaged GPU DLL is rejected by Windows Code Integrity.
- The package becomes unhealthy after sidebar browser use, but GPU logs are missing.

### Adjacent only

- Generic Windows launch crash with no browser involvement.
- Generic Browser Use timeout with a healthy package.
- A firewall prompt without GPU, AppX, or package-state evidence.

## Interpretation rules

- A Windows firewall prompt is normal when a newly installed/versioned executable first requests inbound network capability. Its appearance does not prove it caused the crash.
- If the first GPU/AppModel failure precedes the user's click, explicitly say the click was not the initiating event.
- `Modified`/`NeedsRemediation` is an observed package state. Do not infer which component changed package files unless file-level or Store deployment evidence proves it.
- `vk_swiftshader.dll` Code Integrity rejection is a strong candidate mechanism only when Event 3033 exists in the same timeline.
- A project page can provide the trigger content while the product defect remains in Codex Desktop's embedded Chromium/MSIX integration.

## Authoritative Windows references

- [PackageStatus class](https://learn.microsoft.com/en-us/uwp/api/windows.management.deployment.packagestatus)
- [Troubleshooting packaging, deployment, and query of Windows apps](https://learn.microsoft.com/en-us/windows/win32/appxpkg/troubleshooting)
- [Windows Firewall rules](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/rules)
- [PROCESS_MITIGATION_BINARY_SIGNATURE_POLICY](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-process_mitigation_binary_signature_policy)
