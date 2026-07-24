# CodexIABGuard

CodexIABGuard is a signature-specific containment skill for a Codex Desktop for Windows failure chain: restored in-app browser state triggers a Chromium GPU failure, followed by AppX/MSIX package remediation symptoms that can leave Codex unable to launch.
<br/>**CodexIABGuard 是一个针对特定故障链的阻断 Skill：Codex Desktop for Windows 恢复内置浏览器状态后触发 Chromium GPU 故障，继而出现 AppX/MSIX 软件包修复异常，严重时会导致 Codex 无法启动。**

It is a cautious mitigation and handoff aid, not a universal crash fixer or a guaranteed permanent repair.
<br/>**它是一套谨慎的临时阻断与任务交接方案，并不是通用闪退修复器，也不保证永久修好问题。**

## Scope

The skill requires evidence from both sides of the known chain before treating an incident as a match:
<br/>**只有同时找到这条已知故障链两端的证据，Skill 才会把事件判定为匹配：**

- An in-app-browser/GPU signal, such as a restored browser task, `reason=crashed` followed by `reason=launch-failed`, or Code Integrity Event 3033 involving `vk_swiftshader.dll`.
  <br/>**内置浏览器/GPU 信号，例如恢复了带浏览器状态的任务、先出现 `reason=crashed` 再出现 `reason=launch-failed`，或代码完整性事件 3033 指向 `vk_swiftshader.dll`。**
- An AppX/MSIX signal, such as `Modified`, `NeedsRemediation`, `appxState=2`, `0x3CFC`, `0x80073CFC`, container destruction, or Codex becoming unlaunchable.
  <br/>**AppX/MSIX 信号，例如 `Modified`、`NeedsRemediation`、`appxState=2`、`0x3CFC`、`0x80073CFC`、应用容器被销毁，或 Codex 变得无法启动。**

A firewall permission dialog by itself, or an unrelated generic Codex crash, is not enough to match this skill.
<br/>**只出现防火墙授权弹窗，或只发生一次无关的普通 Codex 闪退，都不足以匹配这个 Skill。**

## What It Does

- Collects read-only package-health and event evidence without intentionally reproducing the dangerous browser action.
  <br/>**以只读方式收集软件包健康状态和系统事件证据，不主动复现危险的浏览器动作。**
- Preserves the task history and, only with explicit approval while Codex is fully closed, backs up and quarantines the exact task's persisted in-app-browser tab state.
  <br/>**保留任务历史；仅在用户明确同意且 Codex 已完全退出时，备份并隔离指定任务所保存的内置浏览器标签状态。**
- Helps decide whether to resume the original task, make a clean handoff to a new task, or repair/reinstall the Codex package first.
  <br/>**帮助判断应该恢复原任务、交接到新任务，还是先修复或重装 Codex 软件包。**
- Instructs the resumed task not to repeat the risky browser action and to return URLs for the user to open manually.
  <br/>**要求恢复后的任务不要重复危险的浏览器动作，只提供网址，由用户手动打开。**

## Install

Clone the repository into the Codex skills directory from PowerShell:
<br/>**在 PowerShell 中把仓库克隆到 Codex 的 Skills 目录：**

```powershell
git clone https://github.com/onovich/codex-iab-guard.skill.git "$env:USERPROFILE\.codex\skills\codex-iab-guard"
```

Restart Codex, then invoke `$codex-iab-guard` or select `CodexIABGuard` from the skill picker.
<br/>**重启 Codex，然后调用 `$codex-iab-guard`，或从 Skill 选择器中选择 `CodexIABGuard`。**

## Safety Boundaries

The workflow does not modify `WindowsApps`, the registry, firewall rules, security policy, or Code Integrity settings. It does not delete task history and does not silently mutate browser state.
<br/>**这套流程不会修改 `WindowsApps`、注册表、防火墙规则、安全策略或代码完整性设置；不会删除任务历史，也不会静默修改浏览器状态。**

If the signature does not match, the skill stops and routes the incident to normal crash diagnosis instead of applying its quarantine procedure.
<br/>**如果故障特征不匹配，Skill 会停止专用隔离流程，并把问题转交给普通闪退诊断。**

## Related Reports

- [#34133 — GPU process crash / launch failure and Code Integrity 3033](https://github.com/openai/codex/issues/34133)
  <br/>**[#34133——GPU 进程崩溃/启动失败与代码完整性事件 3033](https://github.com/openai/codex/issues/34133)**
- [#27828 — Cloudflare Turnstile in-app-browser crash and reinstall recovery](https://github.com/openai/codex/issues/27828)
  <br/>**[#27828——Cloudflare Turnstile 触发内置浏览器崩溃，重装后恢复](https://github.com/openai/codex/issues/27828)**
- [#32094 — Related GPU/AppX container failure chain](https://github.com/openai/codex/issues/32094)
  <br/>**[#32094——相关的 GPU/AppX 应用容器故障链](https://github.com/openai/codex/issues/32094)**
- [#35132 — Same family reported on a later Codex build; closed as a duplicate of #34133](https://github.com/openai/codex/issues/35132)
  <br/>**[#35132——较新 Codex 版本上的同类报告；已作为 #34133 的重复问题关闭](https://github.com/openai/codex/issues/35132)**

## Repository Contents

- `SKILL.md` — routing, evidence gate, containment workflow, and safety rules.
  <br/>**`SKILL.md`——路由条件、证据门槛、阻断流程和安全规则。**
- `scripts/codex-iab-gpu-msix-health-check.ps1` — read-only Windows health and incident checker.
  <br/>**`scripts/codex-iab-gpu-msix-health-check.ps1`——只读的 Windows 健康状态与事故检查脚本。**
- `scripts/quarantine-thread-browser-state.ps1` — targeted backup, quarantine, verification, and rollback helper.
  <br/>**`scripts/quarantine-thread-browser-state.ps1`——针对指定任务的备份、隔离、验证与回滚工具。**
- `references/` — incident signatures and a redacted reporting template.
  <br/>**`references/`——故障特征说明和已脱敏的报告模板。**
