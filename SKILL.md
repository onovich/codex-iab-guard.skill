---
name: codex-iab-guard
description: Contain and assess the specific Codex Desktop for Windows failure chain in which restored or active in-app Browser (IAB) state is followed by a Chromium GPU child crash and relaunch failure, optional Code Integrity Event 3033 for vk_swiftshader.dll, then AppX/MSIX Modified or NeedsRemediation state, appxState=2, 0x3CFC or 0x80073CFC, and an app that may become unlaunchable. Preserve task history, quarantine only the affected task's persisted browser state, and decide whether to continue, hand off, or wait for package repair. Use only for this signature or a strong subset; do not use for generic Codex crashes. Recovery may succeed, but this skill cannot guarantee a product-level fix.
---

# Codex IAB Guard

Use a read-only-first workflow for the IAB GPU-to-MSIX failure chain on Windows. This skill may restore a usable state, but it does not guarantee that Codex is fixed. Its minimum useful outcome is to block an affected task from automatically re-triggering the chain, preserve its history, and make a defensible continue-versus-handoff decision. It cannot patch the closed-source desktop application.

## Signature gate

Use this skill only when evidence spans both sides of the chain:

1. IAB/GPU side: restored per-task IAB state, Browser/Cloudflare/WebGL activity, GPU `reason=crashed` then `reason=launch-failed`, or Code Integrity Event 3033 for `vk_swiftshader.dll`.
2. AppX/MSIX side: `Modified`, `NeedsRemediation`, `appxState=2`, `0x3CFC`, `0x80073CFC`, AppX-container destruction, or an app that becomes unlaunchable until Store recovery.

A firewall prompt alone, a generic silent exit, or an unrelated launch crash does not pass this gate. With evidence from only one side, return `INSUFFICIENT_EVIDENCE` and do not quarantine task browser state.

## Possible outcomes

- `CONTAINED_HANDOFF_RECOMMENDED`: the suspect browser state was isolated; preserve/archive the original and continue in a clean task.
- `CONTAINED_ORIGINAL_MAY_CONTINUE`: the browser state was isolated and evidence supports continuing the original task under a strict no-browser guardrail.
- `PACKAGE_REPAIR_REQUIRED`: Windows package state is unhealthy; do not continue any affected task until the user completes official repair/restage/reinstall.
- `INSUFFICIENT_EVIDENCE`: the suspect task or exact state key cannot be identified safely; do not mutate state and ask the user for direction.
- `OUT_OF_SCOPE_GENERIC_CRASH`: no browser/GPU/AppX/MSIX signature exists; do not quarantine browser state and use a general crash-diagnosis workflow instead.
- `NOT_CONTAINED`: quarantine or verification failed; keep the suspect task stopped and report the rollback/result.

Outcome precedence:

1. An unhealthy package takes precedence: return `PACKAGE_REPAIR_REQUIRED`, record any unresolved task identification as pending, and stop.
2. After official package recovery, rerun read-only diagnosis and task identification.
3. If the package is healthy but the suspect task remains unknown, return `INSUFFICIENT_EVIDENCE`.
4. If the defining browser/GPU/AppX/MSIX signature is absent, return `OUT_OF_SCOPE_GENERIC_CRASH`.

## Safety invariants

- Do not live-reproduce a suspect URL, Cloudflare challenge, screenshot, canvas, WebCodecs, Browser Use, Chrome, or computer-use action.
- Do not reopen or resume a suspect task before its persisted browser state is inspected.
- Never delete the task, the whole `.codex` directory, or the whole global-state file.
- Never edit `WindowsApps`, AppX ACLs, package-state registry keys, Code Integrity policy, GPU security policy, or Windows Firewall rules.
- Do not run package removal, reset, repair, or reinstall without explicit user authorization and a data-preservation check.
- Treat a firewall-consent dialog as a timeline marker unless evidence proves causation. A crash can precede the user's click.
- Redact usernames, local paths, task IDs, project names, prompts, private URLs, cookies, challenge tokens, and account identifiers from public reports.

## Workflow

### 1. Stabilize

1. Tell the user not to restart the dangerous task or invoke browser tools.
2. If Codex still opens, keep Browser Use, Chrome, and computer use unused.
3. If the suspect task has an active goal, do not wake it merely to stop it. First quarantine browser state. Afterward, obtain explicit user approval before archiving it or sending a stop instruction with task-management tools.
4. Preserve the task history. Prefer a safe fork or handoff after quarantine.

### 2. Diagnose without launching the trigger

Run the bundled checker:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\codex-iab-gpu-msix-health-check.ps1" -Mode Current
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\codex-iab-gpu-msix-health-check.ps1" -Mode IncidentEvidence -LookbackHours 48
```

The checker is read-only. Exit code `0` means no current package failure or matching captured incident was found. Exit code `2` means the current package is unhealthy or at least one side of the signature exists. Only `IAB_GPU_MSIX_CHAIN_EVIDENCE_FOUND` spans both sides locally; a `*_SIDE_ONLY_NEEDS_CORRELATION` verdict requires independent IAB/task evidence before quarantine.

If there is no browser/GPU/AppX/MSIX evidence, return `OUT_OF_SCOPE_GENERIC_CRASH`. Do not inspect or quarantine per-task browser state merely because Codex crashed.

Correlate, but do not overclaim:

- Browser/sidebar lifecycle immediately precedes a GPU child crash.
- `Recoverable Chromium child process gone` reports `processType=GPU`, then `reason=launch-failed`.
- Windows later reports package state `Modified`, `NeedsRemediation`, `appxState=2`, `0x3CFC`, or `0x80073CFC`.
- The app becomes unlaunchable until Store repair/restage/reinstall.

Read [references/incident-signatures.md](references/incident-signatures.md) when classifying the incident or linking related upstream reports.

### 3. Identify the suspect task

Use task-management tools when available:

1. List/read candidate tasks without opening their browser UI.
2. Compare timestamps and captured tool history.
3. Select a task only when evidence ties it to the browser action.
4. Record the task ID privately; never include it in public output.

If no task can be identified confidently, stop and ask the user. Do not quarantine multiple tasks speculatively. When the package is also unhealthy, handle `PACKAGE_REPAIR_REQUIRED` first, then repeat this identification step after recovery.

### 4. Inspect and quarantine only persisted browser state

Inspection is safe while Codex is open:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\quarantine-thread-browser-state.ps1" -Mode Inspect -ThreadId "<task-id>"
```

Before mutation:

1. Show whether `thread-browser-tabs-v1:<task-id>` exists and its tab count.
2. Obtain explicit user approval.
3. Ask the user to fully exit Codex and verify `ChatGPT.exe`/`Codex.exe` has stopped.

Then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\quarantine-thread-browser-state.ps1" -Mode Quarantine -ThreadId "<task-id>" -ConfirmThreadId "<task-id>"
```

The script:

- refuses the live default state file while Codex is running;
- validates JSON before touching it;
- backs up both the main state file and its `.bak` when applicable;
- removes exactly one per-task browser-state key;
- atomically replaces and revalidates each file;
- rolls back completed replacements if any later step fails;
- leaves task history intact.

### 5. Repair only when package evidence requires it

- If package status is `Ok` and the app launches, do not reinstall.
- If status is `Modified`/`NeedsRemediation`, or AppModel activation returns `0x3CFC`/`0x80073CFC`, use the official Microsoft Store repair/restage/reinstall path after the user approves.
- Back up relevant app data before package removal or reset.
- Do not present re-registering manifests, changing ACLs, disabling Code Integrity, or weakening GPU policy as fixes.
- Reinstalling can restore launchability but does not remove recurrence risk in the same affected build.

### 6. Restore work safely

After quarantine and a healthy package check:

1. Decide whether to continue or hand off:
   - Prefer a clean fork/handoff after a repeated fatal crash, active auto-continuation goal, uncertain residual state, or any case that previously made the package unlaunchable.
   - Consider the original task only after one-key quarantine succeeded, package health is `Ok`, no active goal can re-run the browser step, and the user explicitly prefers it.
   - If evidence is incomplete, keep the original stopped and recommend a clean handoff.
2. Present the recommendation and obtain explicit user approval before archiving/stopping the original, forking/creating a replacement, or sending any message to either task.
3. When the user approves a handoff, keep the original task archived as evidence and fork or create a replacement task from preserved history.
4. Send this guardrail to the replacement task:

   `Do not invoke Browser Use, Chrome control, computer use, screenshots, or any automatic URL opening for the previously failing step. Output the exact URL only; the user will open it manually.`

5. Send the same guardrail to the original task before continuing it, if that route is selected and the user approved the message.
6. If the project maintains a role-routing file, update it only through the project's designated routing skill and only when the user requests it.
7. Verify the selected task can continue without browser-state restoration.

### 7. Report upstream

Prefer an independent reproduction comment on the closest existing issue over opening a duplicate. Read [references/reporting-template.md](references/reporting-template.md), separate observed facts from hypotheses, and include:

- Codex package/app version and Windows build;
- sanitized reproduction sequence;
- exact GPU and AppModel error strings;
- the fact that the crash timing may precede the firewall-button click;
- recovery outcome and recurrence risk;
- links to this containment skill, if publicly published.

Never publish, tweet, comment, or create an issue without explicit user authorization.
