# WeChat 表情面板定位问题：根因分析与 watcher 方案

## 问题现象

在 Apple container + xpra 方案下运行 Linux 微信，拖动主窗口到屏幕其他位置后，
打开表情面板等 utility 子窗口时，子窗口出现在屏幕左上角启动坐标 `+0+124` 附近，
而不是跟随主窗口当前位置。VM 方案下也存在类似问题，但更轻微。

## 根因

### 技术栈

Linux 版微信基于 **CEF (Chromium Embedded Framework)**，运行时进程为
`/opt/wechat/RadiumWMPF/runtime/WeChatAppEx`，带有 `crashpad_handler`、
`Chromium clipboard` 等 Chromium 特征窗口。

### 定位机制（实验验证）

通过 X11 层探测确认了以下行为链：

1. 微信启动时创建一个 **1x1 像素、永远隐藏、钉在 `(0,0)` 的占位窗口**
   `0x400008`，它没有 WM_CLASS、没有 WM_STATE、永远是 `IsUnMapped`。
2. 表情面板 popup（如 `0x40002d`）的 `WM_TRANSIENT_FOR` 指向这个隐藏窗口。
3. **每次 popup 从 `IsUnMapped` -> `IsViewable`（即每次打开）时，CEF 把 popup
   定位到固定坐标 `+0+124`**。这个坐标不依赖任何 X11 窗口的实际位置。
4. popup 变为可见后，**CEF 不再主动维护其位置**——纯净环境下（无 watcher），
   popup 在 `+0+124` 稳定停留数十秒，坐标完全不变。

### 关键实验与结论

| 实验 | 操作 | 结果 | 结论 |
|------|------|------|------|
| 移动隐藏父窗口 | X11 层把 `0x400008` 从 `(0,0)` 移到 `(674,168)` | popup 仍在 `+0+124` | CEF 不读 X11 父窗口坐标 |
| 改写 transient | 把 popup 的 `WM_TRANSIENT_FOR` 指向可见主窗口 | popup 仍不受影响 | CEF 不读 transient 属性定位 |
| 纯净观察 | 无 watcher，popup 保持打开 25 秒 | 全程稳定 `+0+124` | CEF map 后不主动 reposition |
| 单次移动 | popup 可见时 `windowmove` 一次 | CEF 仅做一次 y 微调，之后稳定 | 单次移动不会触发持续对抗 |
| 持续轮询移动 | watcher 每轮 `windowmove` | `+0`/`+674` 交替横跳 | 重复移动触发 CEF 反馈循环 |

**核心结论：CEF 在 popup map 瞬间定位一次，之后不再维护。任何在 X11 层移动 popup
的操作都会被 CEF 接受，但若 watcher 持续重复移动，会触发 CEF 的位置变化反馈，
形成横跳。**

### 为什么 VM 方案更轻微

VM 方案下 X server 是完整的 Xorg，窗口管理器（openbox 等）和微信在同一 X 环境中。
seamless xpra 方案下，每个顶层窗口被单独转发到 macOS 桌面，CEF 内部的隐藏父窗口
`0x400008` 不被转发也不被 WM 管理，但其坐标本来就是固定的 `(0,0)`，所以两种方案
都有这个定位问题——只是 VM 下可能因为其他因素（如窗口叠放、WM 行为）表现略不同。

## 方案：popup watcher（状态机版）

### 设计原理

基于上述实验结论，正确的 watcher 策略是：

1. **只在 popup 从 `IsUnMapped` -> `IsViewable` 跳变时移动一次**
2. popup 保持可见期间，**绝不重复移动**（这是防横跳的关键）
3. popup 隐藏后清除状态记录，下次打开重新触发移动

### 实现要点

脚本：`wechat-remote/docker/image/wechat-popup-watcher.sh`

- **状态文件** `wechat-popup-watcher.state`：记录当前已移动且仍可见的 popup id
- **`was_moved_visible`**：检查 popup 是否已标记为「移动过且可见」
- **主循环**：检测到 popup 可见且未标记时，**先写 state 再移动**（避免轮询间隙重复进入）
- **`move_once`**：`sleep 0.4` 等 CEF 初始定位稳定，再 `windowmove` 一次

### 已踩的坑

1. **`find_main_window` 的窗口筛选**：xpra 转发的可见主窗口可能没有 WM_CLASS，
   `xdotool search --class wechat` 搜不到。改用 `xdotool search --name "微信"` +
   `WM_STATE=Normal` 筛选。

2. **state 文件换行符 bug**（最关键）：在 `#!/bin/sh` 下用 `$'\n'` 拼接字符串，
   换行符没被解释成真换行，变成字面 `\n` 写入文件。导致 `grep -qx` 永远匹配失败，
   `was_moved_visible` 恒为 false，每轮重复移动 popup，触发 CEF 反馈横跳。
   修复：用 `NL=' '`（真换行变量）替代 `$'\n'`。

3. **持续轮询 vs 单次移动**：早期版本在 popup 可见期间每轮检查坐标偏离并重复
   `windowmove`，这直接触发 CEF 的位置反馈循环，造成 `+0`/`+674` 交替横跳。
   正确做法是状态机：跳变触发，单次移动，可见期间不动。

### 已知局限

- popup 打开瞬间会在 CEF 默认位置（左侧 `+0+124`）闪现约 0.4-0.7 秒，
  然后 watcher 移动到主窗口旁。这个初始闪烁无法消除（CEF 的 map 定位在前）。
- 如果主窗口被拖动时 popup 正好打开，popup 会移到移动前的主窗口位置（因为
  watcher 在 map 瞬间读取主窗口坐标）。

## 验证记录

2026-07-08 实测（修正 state 换行符 bug 后）：

```
19:41:28 popup IsViewable +674+184   <- 第一轮,移到主窗口旁,稳定
19:42:11 popup IsUnMapped +0+0       <- 43秒后关闭,期间零横跳
19:42:12 popup IsViewable +0+124     <- 重新打开,CEF 先放默认位置
19:42:13 popup IsViewable +674+184   <- 0.7s 后 watcher 移到位,稳定
```

多轮开关均稳定，无横跳。

## 相关文件

- `wechat-remote/docker/image/wechat-popup-watcher.sh`：watcher 脚本
- `wechat-remote/docker/image/entrypoint.sh`：通过 xpra `--start` 拉起 watcher
- `wechat-remote/docker/image/Dockerfile`：构建时 COPY watcher 到 `/usr/local/bin/`
- `wechat-remote/docs/troubleshooting.md`：其他故障排查
