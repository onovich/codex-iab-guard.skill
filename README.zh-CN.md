# CodexIABGuard

[English](README.md) | [简体中文](README.zh-CN.md)

一个安全优先、面向 Windows、只针对一条特定 Codex Desktop 故障链的临时阻断与恢复方案：

- 恢复或使用内置浏览器状态后，Chromium GPU 进程崩溃且重新拉起失败；部分事件还会出现 `vk_swiftshader.dll` 对应的代码完整性事件 3033；
- 随后 AppX/MSIX 软件包变成 `Modified` 或 `NeedsRemediation`，返回 `0x3CFC` / `0x80073CFC`，严重时 Codex 无法启动。

CodexIABGuard 会先诊断、再询问，未经确认不会修改持久化的浏览器状态。它是独立的社区临时缓解方案，不是 OpenAI 官方修复，也不保证永久恢复。

## 快速开始

将 Skill 克隆到 Codex 技能目录：

```powershell
git clone https://github.com/onovich/codex-iab-guard.skill.git `
  "$env:USERPROFILE\.codex\skills\codex-iab-guard"
```

重启 Codex，然后运行：

```text
$codex-iab-guard 诊断这次故障。修改任何持久化浏览器状态前先询问我。
```

## 它会做什么

1. 对当前软件包健康状态和近期相关 Windows 事件执行一次有界、只读的诊断。
2. 要求同时找到内置浏览器/GPU 侧和 AppX/MSIX 侧证据；只有普通闪退或防火墙弹窗时会拒绝匹配。
3. 在不重新打开浏览器界面、不复现危险网页的前提下，只识别一个有充分证据的可疑任务。
4. 取得明确同意并确认 Codex 完全退出后，先备份本地状态，再仅隔离该任务的 `thread-browser-tabs-v1:<task-id>` 状态键。
5. 保留任务历史，并给出一种建议：在禁用自动浏览器动作的约束下继续、干净交接到新任务，或先修复 Codex 软件包。

成功隔离可能阻止受影响任务自动恢复危险标签页，但不能证明 Codex 本身已经修好，也不能保证其他任务以后不会遇到同类问题。

## 安全边界

- 不主动复现可疑网址、Cloudflare 验证、网页截图、Canvas、WebGL、WebCodecs、Browser Use、Chrome 控制或 computer-use 动作。
- 不删除任务、任务历史、整个 `.codex` 目录或整个全局状态文件。
- 不修改 `WindowsApps`、AppX ACL、软件包注册表状态、防火墙规则、代码完整性策略或 GPU 安全策略。
- 隔离浏览器状态或执行官方商店修复/重装前，必须取得明确同意。
- 替换状态前会备份并验证，支持回滚；公开报告默认脱敏任务 ID、本地路径、项目名、提示词和私有网址。

## 适用版本与时间

最后核对：2026-07-25

本机 Windows 复现时受影响的 Codex Desktop 版本为 `26.721.3404.0`；通过 Microsoft Store 重装后，`26.721.3996.0` 在 Windows 11 build `10.0.26200` 上恢复启动。公开报告涉及其他环境，也包括 `26.721.3996.0` 上的同类故障。这些只是已观察范围，不是兼容性保证。

使用前请检查上游问题的最新状态：

- GPU 崩溃、重新拉起失败及代码完整性事件 3033：[openai/codex#34133](https://github.com/openai/codex/issues/34133)；
- Cloudflare Turnstile 内置浏览器崩溃并导致应用无法启动：[openai/codex#27828](https://github.com/openai/codex/issues/27828)；
- 相关 GPU/AppX 应用容器故障链：[openai/codex#32094](https://github.com/openai/codex/issues/32094)；
- 使用侧边栏浏览器后出现 `Modified` / `NeedsRemediation`：[openai/codex#34311](https://github.com/openai/codex/issues/34311)；
- 较新版本上的报告，已作为 #34133 的重复问题关闭：[openai/codex#35132](https://github.com/openai/codex/issues/35132)。

在更新的 Codex 版本上，应先诊断再决定是否处理。如果关联 Issue 已经修复，且相同症状不再出现，请停用这项隔离方案。

## 当前不覆盖

CodexIABGuard 不是通用的 Codex 或 Windows 闪退修复器。普通静默退出、浏览器超时、无关启动失败，或没有同时出现 GPU 与 AppX/MSIX 证据的防火墙授权弹窗，都不属于它的处理范围。

这个 Skill 无法修补闭源的 Codex Desktop、证明没有被观测到的根因，也不能保证永久修复。缺少这条双侧故障特征时，它会拒绝隔离浏览器状态，并把问题交给普通闪退诊断流程。
