# macOS 输入法接入 xpra 方案：分析与设计

## 目标

在 Apple container + xpra 方案下，用 macOS 本地输入法（而非容器内 fcitx5）
实现微信中文输入。

## 背景：当前输入链路

```
macOS 按键 -> xpra 客户端(GTK窗口) -> key-action 包(keyname/keyval/keycode)
  -> xpra 服务端 -> XTest 注入 X11 keycode -> 容器内 fcitx5 -> 提交中文给微信
```

中文输入完全在容器内完成：fcitx5 跑在容器里，通过 `QT_IM_MODULE=fcitx` 接管微信输入。
macOS 客户端只负责转发原始按键。

## 为什么 xpra 默认不支持"客户端 IME"

对 xpra 源码（`/Users/lihu/git/xpra`）的完整分析结论：

1. **协议层没有文本包**：`net/packet_type.py` 只有 4 个键盘包
   (`key-action`/`keyboard-event`/`keyboard-config`/`keyboard-sync`)，
   没有 `text-commit`/`preedit` 包类型。每个按键包只携带 keyname/keyval/keycode/string(单字符)。

2. **客户端没挂 IMContext**：macOS 上激活中文输入法时，IME 拦截按键后走
   `NSTextInputClient` 协议回调 `insertText:`/`setMarkedText:`。但 xpra 的 GTK 窗口
   没有实现 NSTextInputClient，也没挂 `Gtk.IMContext`，组合期间的 preedit 和 commit
   text 直接丢失。

3. **服务端只认 keycode**：`_handle_key()` -> `XTestFakeKeyEvent(keycode)`，
   只注入 keycode，没有"把字符串注入为 X11 输入"的代码路径。

4. **唯一的 NSTextInputContext 使用**（`platform/darwin/keyboard.py:162-191`）
   只用于查询当前键盘布局名，不接收任何 IME 文本回调。

源码里 `docs/Features/Keyboard.md:31` 直接写了：
`Input methods don't work by default: #634`

## 选定方案：剪贴板通道

### 核心思路

```
macOS IME commit 文本 -> 写入 macOS 剪贴板 -> xpra 自动同步到容器 X11 clipboard
  -> 容器内 xdotool 模拟 Ctrl+V -> 微信输入框收到中文
```

### 已验证可行的部分（无需开发）

| 环节 | 验证方式 | 结果 |
|------|----------|------|
| xpra 剪贴板同步 | macOS `pbcopy "测试"` -> 容器 Ctrl+V | ✅ 微信输入框收到中文 |
| 容器内 Ctrl+V 注入 | `xdotool key ctrl+v` | ✅ 微信收到剪贴板内容 |
| xdotool type 中文 | `xdotool type "你"` | ✅ 单字注入成功，3ms |
| xdotool type 多字 | `xdotool type "你好世界"` | ⚠️ 部分成功，fcitx5 会拦截字母键 |

注意：`xdotool type` 对纯中文有效但会被 fcitx5 干扰（英文模式下字母触发候选词），
因此选剪贴板+Ctrl+V 方案，完全绕过 fcitx5 和 keysym 注入问题。

### 不需要改的部分

- **xpra 协议**：剪贴板走 xpra 现有的 clipboard 同步，无需新增包类型
- **xpra 服务端**：Ctrl+V 走现有 key-action 转发，无需改服务端
- **容器内 fcitx5**：可保留（方案不依赖它，但也不冲突）

### 需要开发的部分

唯一核心难点：**在 macOS 侧拿到 IME 的 commit 文本**。

| 组件 | 需要做什么 | 代码量(估) |
|------|-----------|-----------|
| macOS IME 文本捕获 | 给 xpra GTK 窗口挂 IMContext，或 pyobjc swizzle NSView | 30-80 行 |
| commit 回调处理 | 写剪贴板 + 通知容器执行 Ctrl+V | ~20 行 |
| 容器侧脚本 | 接收通知，执行 `xdotool key ctrl+v` | ~15 行 |
| **总计** | | **65-115 行** |

### macOS IME 文本捕获的两个实现选项

**选项 A：GTK IMMulticontext（已验证不可行）**
- 给 xpra 的 GTK 窗口挂 `Gtk.IMMulticontext`，连接 `commit` 信号
- 验证结果（2026-07-08）：挂载成功，commit 信号会触发，但 macOS IME **不会激活中文组合**。
  打 `nihao` 被原样逐字 commit（n/i/h/a/o），没有变成「你好」。
  日志出现 `error messaging the mach port for IMKCFRunLoopWakeUpReliable`。
- 原因：macOS IME 需要窗口实现 `NSTextInputClient` 协议才会激活中文组合。
  GTK Quartz 后端的默认 IMContext 不调用 NSTextInputClient。
- **结论：选项 A 不可行，必须走选项 B。**

**选项 B：pyobjc swizzle NSView 实现 NSTextInputClient（选定方案）**

验证发现（2026-07-08）：GTK Quartz 后端的 `GdkQuartzView` **已经实现了** NSTextInputClient 协议
（`insertText:replacementRange:` = YES，`setMarkedText:` = YES，`interpretKeyEvents:` = YES）。
父类链：`GdkQuartzView -> NSView -> NSResponder -> NSObject`。

但 macOS IME 仍然不工作。原因：GdkQuartzView 的 `insertText:` 实现把文本转成 GDK key 事件，
但 xpra 的 `KeyboardWindow` 只处理 `key-press-event`，且 `parse_key_event` 从 `event.keyval`
取值--IME 合成文本没有正常的 keyval，`Gdk.keyval_to_unicode(keyval)` 返回 0，`string` 为空。

因此方案是 **swizzle（替换）GdkQuartzView 的 `insertText:replacementRange:` 方法**：
- 用 pyobjc 的 `objc.classAddMethod` / method swizzle 替换原实现
- 在新实现里：拿到 insertText 的 NSString，通过 `VIEW_TO_WINDOW` 反查 ClientWindow
- 把文本写入 macOS 剪贴板，然后通知容器执行 Ctrl+V
- 或直接构造 KeyEvent 走 xpra 的 key-action 包（但 string 字段服务端会忽略，见分析）

xpra 已有全部前置技术：
- `objc.objc_object(c_void_p=nsview_ptr)` 把指针包成 pyobjc 对象（`gl_context.py:186`）
- `add_window_hooks` 是装 hook 的正确时机（窗口 realize 后，`base.py:587`）
- `VIEW_TO_WINDOW` 字典可反查 ClientWindow（`gui.py:465`，需去掉 `if WHEEL` 条件）
- pyobjc NSObject 子类化范例：`events.py:42` AppDelegate、`webcam.py:141` _DeviceObserver

代码量估：~80 行 pyobjc + ~20 行回调逻辑 + ~15 行容器脚本 = ~115 行

### 关键文件参考（xpra 源码）

- `xpra/client/gtk3/window/keyboard.py:25-27`：窗口连接 key-press/release-event
- `xpra/client/gui/keyboard_helper.py:250-262`：`send_key_action` 打包 key-action 包
- `xpra/platform/darwin/gdk3_bindings.pyx:39-41`：`get_nsview_ptr` 获取窗口 NSView
- `xpra/platform/darwin/gui.py:479-490`：`add_window_hooks`/`remove_window_hooks`
- `xpra/platform/darwin/keyboard.py:162-191`：NSTextInputContext 查布局名（现有用法）
- `xpra/server/subsystem/keyboard.py:465-478`：包处理器注册
- `xpra/net/packet_type.py:34-37`：键盘包类型定义

## 排除的方案

### 方案 B（keysym 序列走 key-action）

把中文字符转成 X11 keysym（`0x01000000 | codepoint`），用现有 key-action 包发送。

**致命缺陷**：XTest 只能注入 keycode，不能注入 keysym。中文字符有 keysym，但 "us" 键表里
没有 keycode 映射到它。必须动态 `XChangeKeyboardMapping`，这是全 server 同步操作，
每个字符几百 ms 延迟 + 风暴式重算。**不可行。**

### 方案 A（新协议 text-commit + 服务端注入）

最"正确"的方案，但服务端注入是空白领域：
- XIM 注入：xpra 不作为 XIM 客户端运行，无绑定
- ibus commit_text：需要创建 IBus.InputContext，脆弱且无文档
- XSendEvent：被多数 toolkit 忽略
- 动态 keycode 重映射：同方案 B 的缺陷

**结论**：服务端注入路径不可靠，工作量远大于剪贴板方案。

## 实施结论：方案不可行，放弃

### 验证过程

1. **GTK IMMulticontext 测试**：挂载成功，commit 信号触发，但 macOS IME 没有激活中文组合。打 `nihao` 被原样逐字 commit，没有变成「你好」。日志出现 `error messaging the mach port for IMKCFRunLoopWakeUpReliable`。

2. **GdkQuartzView NSTextInputClient 检查**：发现 GdkQuartzView **已经实现**了完整的 NSTextInputClient 协议（`insertText:` / `setMarkedText:` / `interpretKeyEvents:` 全部 YES）。但 IME 仍不工作。

3. **swizzle `insertText:` 测试**：swizzle 成功，但回调从未被触发--因为 IME 组合流程根本没启动，`insertText:` 不会被调用。

4. **swizzle `keyDown:` 测试**：尝试让 `keyDown:` 调用 `interpretKeyEvents:` 激活 IME，但 pyobjc + ctypes 的 swizzle 不稳定（crash / 无效果）。

5. **原生 NSTextView 对照测试**：用 pyobjc 创建原生 NSWindow + NSTextView，**豆包输入法完全正常**，中文输入无问题。

### 根因

GdkQuartzView 实现了 NSTextInputClient 协议方法，但它的 `keyDown:` 实现没有调用 `interpretKeyEvents:` 来启动 IME 组合流程。macOS IME（包括豆包输入法）需要 `interpretKeyEvents:` 才会激活。

原生 NSTextView 能用，因为它的 `keyDown:` 正确调用了 `interpretKeyEvents:`。

要让 GTK 窗口支持 IME，必须 swizzle `keyDown:` 让它调 `interpretKeyEvents:`。但这条路在 pyobjc + ctypes 层面不稳定（crash），投入产出比极低。

### 最终结论

**macOS 本地输入法接入 xpra 方案不可行，放弃。继续使用容器内 fcitx5。**
