# Hammerspoon 配置

本目录为 Hammerspoon 配置与文档。实际运行目录通过符号链接挂到用户家目录：

```text
~/.hammerspoon → hammerspoon/.hammerspoon
```

## 结构

| 路径 | 说明 |
|------|------|
| `.hammerspoon/init.lua` | 入口：快捷键、App 切换、加载 Spoon |
| `.hammerspoon/config.json` | AutoIme 应用/输入法映射与 TUI 标题规则 |
| `.hammerspoon/Spoons/AutoIme.spoon/` | 按 App / 终端标题自动切换输入法 |
| `.hammerspoon/keyboard_remap.lua` | 键盘相关（可选） |
| `docs/auto-ime.md` | **AutoIme 方案调研与设计结论**（现状、标题边界、上报方案、路线图） |

## AutoIme（自动输入法）

- **L1**：按 `bundleId` 切换（终端默认英文，聊天/笔记等中文）。  
- **L2**：kitty / Warp 下按窗口标题识别 qwen-code、Grok Build，在 TUI 内切中文。  

细节、误伤分析（如路径含 `grok`）、以及 **zsh 主动上报** 等后续方案见：

→ [docs/auto-ime.md](./docs/auto-ime.md)

## 生效

菜单栏 **Hammerspoon → Reload Config**。

说明：`hs.ipc` 用于从终端执行 `hs -c '…'` 遥控 Hammerspoon，与标题检测无关；当前入口默认未加载 ipc。
