# CodexIABGuard

[English](README.md) | [简体中文](README.zh-CN.md)

A safety-first, Windows-focused containment and recovery aid for one Codex Desktop failure chain:

- restored or active in-app Browser state followed by a Chromium GPU crash and relaunch failure, optionally with Code Integrity Event 3033 for `vk_swiftshader.dll`;
- AppX/MSIX package state then becoming `Modified` or `NeedsRemediation`, returning `0x3CFC` / `0x80073CFC`, or leaving Codex unable to launch.

CodexIABGuard diagnoses first and asks before changing persisted browser state. It is an independent community mitigation, not an official OpenAI fix, and it cannot guarantee permanent recovery.

## Quick start

Clone the skill into your Codex skills directory:

```powershell
git clone https://github.com/onovich/codex-iab-guard.skill.git `
  "$env:USERPROFILE\.codex\skills\codex-iab-guard"
```

Restart Codex, then run:

```text
$codex-iab-guard Diagnose this incident. Ask before changing any persisted browser state.
```

## What it does

1. Takes one bounded, read-only snapshot of current package health and recent relevant Windows events.
2. Requires evidence from both the in-app-browser/GPU side and the AppX/MSIX side; a generic crash or firewall prompt alone is rejected.
3. Identifies one suspect task without reopening its browser UI or reproducing the dangerous page.
4. With explicit approval and Codex fully closed, backs up local state and quarantines only that task's `thread-browser-tabs-v1:<task-id>` key.
5. Preserves task history and recommends one outcome: continue under a no-browser guardrail, make a clean handoff, or repair the Codex package first.

A successful quarantine may stop the affected task from automatically restoring the dangerous tab. It does not prove that the underlying Codex defect is fixed or that another task cannot encounter it.

## Safety

- Never live-reproduces a suspect URL, Cloudflare challenge, screenshot, canvas, WebGL, WebCodecs, Browser Use, Chrome-control, or computer-use action.
- Never deletes a task, task history, the whole `.codex` directory, or the whole global-state file.
- Never edits `WindowsApps`, AppX ACLs, package registry state, firewall rules, Code Integrity policy, or GPU security policy.
- Requires explicit approval before browser-state quarantine or official Store repair/reinstall.
- Backs up and validates state before replacement, supports rollback, and redacts task IDs, paths, project names, prompts, and private URLs from public reports.

## Time and version scope

Last reviewed: 2026-07-25

The local Windows reproduction affected Codex Desktop `26.721.3404.0`; Store reinstall restored launchability with `26.721.3996.0` on Windows 11 build `10.0.26200`. Related public reports cover other environments and include the same failure family on `26.721.3996.0`. This is an observed range, not a compatibility guarantee.

Check the latest upstream status before using the skill:

- GPU crash, relaunch failure, and Code Integrity Event 3033: [openai/codex#34133](https://github.com/openai/codex/issues/34133);
- Cloudflare Turnstile in-app-browser crash followed by an unlaunchable app: [openai/codex#27828](https://github.com/openai/codex/issues/27828);
- related GPU/AppX-container failure chain: [openai/codex#32094](https://github.com/openai/codex/issues/32094);
- sidebar browser use followed by `Modified` / `NeedsRemediation`: [openai/codex#34311](https://github.com/openai/codex/issues/34311);
- later-build report closed as a duplicate of #34133: [openai/codex#35132](https://github.com/openai/codex/issues/35132).

On newer builds, diagnose before taking action. Stop using the quarantine workaround when the linked issues are fixed and the same symptoms no longer occur.

## Not covered

CodexIABGuard is not a general Codex or Windows crash fixer. A generic silent exit, browser timeout, unrelated launch failure, or firewall-consent dialog without matching GPU and AppX/MSIX evidence is outside its scope.

The skill cannot patch the closed-source Codex Desktop application, prove an unobserved root cause, or guarantee a permanent repair. When its two-sided signature is absent, it refuses browser-state quarantine and routes the incident to normal crash diagnosis.
