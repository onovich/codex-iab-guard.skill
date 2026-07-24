# Redacted upstream reporting template

Prefer a comment on the closest existing issue. Use a new issue only when the trigger, error signature, or affected subsystem is materially different.

## Independent reproduction comment

```markdown
Independent reproduction on Windows; this appears to be the same failure family.

Environment
- Codex Desktop package: `<version>`
- Windows: `<edition/build/architecture>`
- GPU/driver: `<model/version, if relevant>`

Observed sequence
1. A resumed task restored its persisted in-app-browser tab and attempted to load `<public site class; omit private URL>`.
2. Windows displayed a network/firewall consent prompt.
3. Codex had already logged the first failure `<N>` milliseconds before the user clicked Allow, so the click itself was not the initiating event.
4. Codex logged:
   - `Recoverable Chromium child process gone ... processType=GPU reason=crashed ...`
   - `Recoverable Chromium child process gone ... processType=GPU reason=launch-failed ...`
5. Codex exited and would no longer launch.
6. Windows later reported `<Modified / NeedsRemediation / appxState=2 / 0x80073CFC>`.
7. Official Store reinstall/restage restored launchability. Resuming the same task reproduced the failure until only that task's persisted browser state was quarantined.

Control observations
- The project contained no code that modifies WindowsApps, AppX package state, firewall rules, or package registry state.
- The triggering task's tool-call history contained no such mutation.
- Task history remained intact; only `thread-browser-tabs-v1:<redacted-task-id>` was removed from local persisted UI state.
- The safe replacement task continues normally when it outputs URLs for manual opening and does not invoke Browser Use.

Expected
A browser GPU/WebGL failure should be isolated to the tab. It must not corrupt/mark the MSIX package, terminate the whole app, or poison the next launch through persisted browser restoration.

Containment helper
I published `CodexIABGuard` (`$codex-iab-guard`), a project-agnostic, redacted Codex skill specifically for the IAB GPU-to-MSIX failure signature. It performs read-only diagnosis, backs up state, quarantines only the affected task's persisted browser tab state, and recommends whether to continue or hand off. It is not a general crash fixer and may restore usability, but it remains mitigation rather than a guaranteed product fix: `<public skill URL>`.

I can provide sanitized event XML and desktop-log excerpts privately if useful.
```

## Redaction checklist

Remove or replace:

- Windows username and profile path;
- project/repository name and workspace path;
- task/conversation IDs;
- private or signed URLs;
- Cloudflare tokens and query strings;
- cookies, headers, account IDs, and email addresses;
- prompt contents unrelated to reproduction;
- full global-state files and full logs.

Keep:

- public Codex version and Windows build;
- GPU model and driver version;
- event IDs, error codes, and relative timing;
- public test URL only if it contains no token or account context;
- exact sanitized error strings;
- whether recovery preserved history;
- observed facts separated from hypotheses.
