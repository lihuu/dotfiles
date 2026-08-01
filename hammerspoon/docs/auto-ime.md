# AutoIme：终端内 TUI 自动切换输入法 — 方案调研

> 状态：调研结论文档（可长期维护）  
> 范围：Hammerspoon `AutoIme` spoon + 终端（kitty / Warp）+ TUI（qwen-code / Grok Build / Claude Code / opencode）  
> 约束：若采用 shell 上报，**仅考虑 zsh**（bash/fish 不在范围内）  
> 相关代码：
>
> - `hammerspoon/.hammerspoon/Spoons/AutoIme.spoon/init.lua`
> - `hammerspoon/.hammerspoon/config.json`
> - 入口：`hammerspoon/.hammerspoon/init.lua`（`spoon.AutoIme:init(true)` / `start()`）

---

## 1. 目标

| 场景 | 期望输入法 |
|------|------------|
| 普通 App（微信、Obsidian 等） | 中文（豆包等，见 `config.json`） |
| 编码类 App / 终端默认（shell、CLI） | 英文（ABC） |
| 终端内运行需要中文输入的 TUI（qwen-code、Grok Build、Claude Code、opencode） | 中文（豆包） |
| 离开 TUI 回到 shell，或离开终端 | 回到合理状态（终端默认英文；其它 App 按各自规则） |

核心难点不是「前台是不是 Warp」，而是：

> **这个终端会话里，当前交互焦点是不是某个指定 TUI？**

macOS / Hammerspoon 只认 GUI App 进程；Warp 是一个 App，内部 shell/TUI 是子进程。任何方案都是间接推断，差别在准确度、侵入性和可维护性。

---

## 2. 当前实现（已落地）

### 2.1 两级模型

```text
第 1 级：App（bundleId）
  微信 / Obsidian / … → 豆包（shouldSwitchBack）
  kitty / Warp / VSCode / … → 默认 ABC

第 2 级：终端窗口标题（仅 tuiTitleDetection.apps）
  标题命中 TUI 规则 → 豆包
  标题未命中       → 终端默认 ABC
```

配置入口：`config.json` 中的 `tuiTitleDetection`。

```json
"tuiTitleDetection": {
  "apps": ["net.kovidgoyal.kitty", "dev.warp.Warp-Stable"],
  "rules": [
    { "name": "qwen-code",  "patterns": ["^[Qq]wen%s*%-"], "contains": ["qwen -"], ... },
    { "name": "grok-build", "patterns": ["[Gg]rok%s*[Bb]uild", "^[Gg]rok%s"], "contains": ["grok"], ... },
    { "name": "claude-code", "patterns": ["^[Cc]laude", "[Cc]laude%s*[Cc]ode", "^[Cc]laudex"], "contains": ["claude", "claudex"], ... },
    { "name": "opencode", "patterns": ["^OC%s*|"], ... }
  ]
}
```

### 2.2 运行时事件

| 事件 | 行为 |
|------|------|
| `windowFocused` | 按 App +（若是终端）标题解析目标输入法 |
| `windowTitleChanged` | 仅 tui-aware 终端：同窗口内启动/退出 TUI 时重判 |
| `windowUnfocused` | 终端 tui-aware：**不**记 `lastUsed`；其它 App 走原 `shouldSwitchBack` / `lastUsed` |

### 2.3 两级「切回来」的含义不同

| 级别 | 机制 | 含义 |
|------|------|------|
| L1 App（如微信） | `shouldSwitchBack` | 进入前记住 IME，离开时**还原** |
| L2 终端标题 | 状态重算 | 有 TUI 标题 → 中文；没有 → **固定回 ABC**（不是还原进 TUI 前的任意 IME） |

L2 不用 `lastUsed`，是为了避免：在 qwen 里用了豆包 → 退出到 shell 仍带着中文。

### 2.4 已验证

- qwen-code：标题形态 `Qwen - <folder>` 可稳定触发（默认未关 `hideWindowTitle`）。
- Grok Build：默认 `ui.notifications.title.enabled = true`，`title.items` 含 `grok`，标题方案可用。
- Claude Code：进程/默认标题多为 `claude`；alias `claudex` 也可能出现在标题中。
- opencode：标题形态 `OC|xxx`（`OC` + `|` + 项目名/路径），规则为**大小写敏感**的 `^OC%s*|`。
- 手动 Reload Config 即可生效；**不依赖** `hs.ipc`（ipc 仅用于从终端遥控 HS，与标题检测无关）。

---

## 3. 标题方案：能力与边界

### 3.1 qwen-code

| 项 | 说明 |
|----|------|
| 机制 | OSC 0/2 写终端标题（`writeTerminalTitle`） |
| 默认标题 | `Qwen - <folderName>` 或 `Qwen - qwen` |
| 风险 | `/rename` 后标题可能变为纯会话名，**不再含 `Qwen`**，会漏检 |
| 关闭方式 | `ui.hideWindowTitle = true` |

### 3.2 Grok Build（`grok`）

| 项 | 说明 |
|----|------|
| 机制 | crossterm `SetTitle`；配置 `[ui.notifications.title]` |
| 默认 | `enabled = true`，`items` 含 `action-required` / `spinner` / `activity` / `session-name` / **`grok`** |
| 风险 | 见下节误伤；用户关掉 `title.enabled` 则失效 |

### 3.3 Claude Code（`claude` / `claudex`）

| 项 | 说明 |
|----|------|
| 进程名 | 二进制一般为 `claude`；`claudex` 是 alias（如 `claude --dangerously-skip-permissions`），进程仍是 `claude` |
| 常见标题 | 终端显示运行进程名时多为 `claude`；Oh My Zsh 自动标题可能短暂/持续显示命令名 `claudex` |
| 其它形态 | 社区/后续版本可能写 `Claude Code - …` 或会话摘要标题 |
| 规则 | `patterns` 覆盖 `^Claude…` / `Claude Code` / `claudex`；`contains` 含 `claude`、`claudex` |
| 风险 | 与 grok 类似：路径含 `claude` 时 `contains` 可能误伤 |

### 3.4 opencode（`OC` 前缀）

| 项 | 说明 |
|----|------|
| 机制 | opencode 默认写终端标题 `OC|xxx`（`OC` + `|` + 项目名/路径） |
| 规则 | `patterns: ["^OC%s*|"]`；Lua pattern **大小写敏感**，仅匹配大写 `OC` + `|` |
| 为什么不加 `contains` | `contains` 实现是**大小写不敏感**（两侧转小写后 `find`），写 `oc` 会误伤路径/其它含 oc 的标题 |
| 风险 | 若 opencode 改标题格式（去掉 `OC|` 前缀）会漏检；可用 `^OC%s*|` 与 `^OC` 组合兜底，但 `^OC` 会命中 `OCaml…` 等大写 OC 开头标题 |
| 验证范围 | **目前仅在 Warp 中实测过**（标题形态 `OC|xxx`）；kitty 等其它终端下 opencode 是否写标题、写法是否一致**未验证**，存在漏检/误检可能，需实测后确认 |

### 3.5 已知误伤：`contains: ["grok"]`

**结论：真实问题，不是纯理论。**

`"contains": ["grok"]` 会匹配标题里任意子串 `grok`，包括路径：

| 标题示例 | 是否命中 | 是否在跑 Grok TUI |
|----------|----------|-------------------|
| `lihu@host:~/git/grok-proxy` | 是 | 否 |
| Warp tab 显示工作目录 `grok-proxy` | 是 | 否 |
| `… · Grok` / `Grok Build` | 是 | 是 |

本机放大因素：

1. **Oh My Zsh 自动标题**（`DISABLE_AUTO_TITLE` 未开启）  
   - 空闲窗口标题类似 `%n@%m:%~` → 路径进标题  
2. **Warp** `primary_info = "working_directory"`  
   - tab/标题侧暴露 cwd  

更严的 `patterns`（如 `Grok Build`、`^Grok `）对路径通常不命中；**误伤主要来自过宽的 `contains: ["grok"]`**。

**后续若改标题规则（未实施）：** 去掉裸 `contains: ["grok"]`，改为独立词 / `Grok Build` / 状态类强特征。

---

## 4. 备选方案总览

| 方案 | 准确度 | 实现成本 | 多 tab | 说明 |
|------|--------|----------|--------|------|
| A. 窗口标题（现状） | 中 | 低 | 依赖当前 title | 已落地；有路径误伤 |
| B. 进程树 / 前台进程 | 中高 | 中 | 难对齐当前 tab | 贴「是否在跑」，易跨 tab 误判 |
| C. hooks / shell 主动上报 | 高 | 中～高 | 取决于 session 对齐 | 语义最干净；见第 5 节 |
| D. 手动热键强制中/英 | 最高（人工） | 低 | N/A | 兜底，不自动 |
| E. 读屏幕 / OCR | 不推荐 | 高 | — | 脆、慢 |

准确度粗序：

```text
主动上报 (hooks/shell)  ≥  进程(当前会话)  >  标题  >  全局「有 grok 进程」
```

**没有** Hammerspoon / Warp 官方 API 直接给出「当前 block 在跑 grok」。要么猜（标题/进程），要么让程序/shell 自己说（上报）。

### 4.1 进程树方案要点（**已放弃作主方案**）

- 想法：focus 时查 Warp/kitty 子孙是否存在 `grok` / `qwen`。  
- 优点：不依赖 title，路径名不误伤；切走再切回时 focus 重算即可。  
- **放弃原因（架构）**：  
  - macOS 上 Warp / kitty / Terminal.app 等通常是 **一个主进程 + 多个 Window**，不是「一窗一进程」。  
  - 子 shell / grok 虽是独立子进程，但都挂在**同一 App pid** 下。  
  - `frontmostApplication():pid()` 在两个终端窗口之间**相同**；「该 App 下有没有 grok」无法区分：  
    - 窗口 A 跑 grok → 应豆包  
    - 窗口 B 纯 shell → 应英文  
  - 多 tab 同一窗口时更粗。  
- 精确到窗需要 **窗口级** 信号（title、或 window↔TTY 映射），不是 App 级进程树。  
- 决策：**不采用进程树作为主检测**；保留标题方案。

### 4.2 务实组合（标题为主时的可选增强）

1. 收紧 grok 标题规则（去裸 `contains`）— 已识别，暂不改。  
2. 热键强制中/英 — 可选兜底。  
3. 不上 App 级 pgrep 作主路径。

### 4.3 多窗口 vs 多进程（结论备忘）

| 对象 | 是否独立进程 | 对 IME 检测的含义 |
|------|--------------|-------------------|
| 多个 Terminal **窗口** | 通常 **否**（同一 App） | 不能靠 App pid 区分 |
| 窗口内 **tab** | 通常 **否** | 更不能靠 App pid |
| 内部 **zsh / grok** | **是** 子进程 | 能发现「有人在跑 grok」，对不齐「当前是哪扇窗」 |
| **窗口标题** | 每窗可不同 | 适合多窗口切换 |

用户期望「切到 grok 窗 → 豆包，切到另一 Terminal 窗 → 英文」：用 **当前 focused 窗口的 title** 可行；用 **整 App 进程树** 不可行。

---

## 5. 方案 C：hooks / shell 主动上报（调研重点）

### 5.1 一句话

**不要猜标题，让「进入 / 离开 TUI」的那一刻主动登记状态；Hammerspoon 只读状态并切输入法。**

约束：**仅 zsh**（`preexec` / `precmd`）。

### 5.2 三层架构

```text
Layer A  信号源
         A1. zsh preexec / precmd（通用，覆盖 grok/qwen/白名单命令）
         A2. 程序 hooks（如 Grok session 生命周期，增强项）

Layer B  状态通道
         B1. 状态文件（推荐作真相源）
         B2. hs.ipc 推送（可选加速；需 require("hs.ipc")）

Layer C  AutoIme
         前台是终端？→ 解析 session → 读 tui=none|qwen-code|grok-build → 切 IME
```

### 5.3 Layer A：zsh 逻辑

| 钩子 | 时机 | 动作 |
|------|------|------|
| `preexec` | 命令即将执行 | 命令在 TUI 白名单 → 写 `tui=<name>` |
| `precmd` | 命令结束、下一 prompt 前 | 写 `tui=none` 或删状态 |

白名单示例（basename）：

| 命令 | 映射 |
|------|------|
| `grok`, `agent` | `grok-build` |
| `qwen`, `qwen-dev` | `qwen-code` |

zsh 方案边界：

| 情况 | preexec |
|------|---------|
| 直接 `grok` / `qwen` | 可靠 |
| 带路径或前缀的启动 | 可解析 argv，需实现 |
| SSH 远端再跑 TUI | 本机钩子看不到 |
| tmux 内 | 能上报，session 要对 pane |
| 非交互 attach 已有进程 | 无 preexec |

适合：**本机交互式启动的 TUI**。

状态文件示例：

```json
{
  "tui": "grok-build",
  "cmd": "grok",
  "cwd": "/Users/lihu/git/dotfiles",
  "updated_at": 1730000000,
  "shell_pid": 12345
}
```

路径约定（建议）：

```text
~/.cache/autoime/sessions/<session_key>.json
```

`session_key` 候选：`shell_pid`、`tty` 变换、或启动 shell 时生成的 UUID。

### 5.4 关键难点：窗口 ↔ 会话对齐

若全局只写一个文件：

```text
Tab A 跑 grok，Tab B 是 shell
切到 Tab B 仍读到 grok → 误切中文
```

必须**按会话隔离**。HS 在「前台是 Warp」时要回答：当前窗口对应哪个 `session_key`？

| 对齐策略 | 说明 | 多 tab |
|----------|------|--------|
| S1 简单 | 任意子会话 `tui≠none` 即当真 | 易误伤 |
| S2 中等 | 仅一个活跃 TUI 时采用；多个则启发式（最近 `updated_at` / 标题） | 可接受 |
| S3 较准 | 进程树 + TTY 找前台相关 shell | 实现难一些 |
| S4 推送 | 信「最近一次 push」；切 tab 需再推送 | 依赖环境 |

**调研结论：上报逻辑本身简单；成败在多 tab 对齐。** 单 tab 重度场景 S1/S2 即可；多 tab 并行 TUI 需 S3 或更好 ID。

### 5.5 Layer B：文件 + 可选 ipc

推荐：

```text
写文件     = source of truth
hs.ipc     = 可选加速（已 focus 时立刻应用）
HS focus   = 以文件 reconcile
pid 不存在 = 状态作废（防 kill -9 残留）
```

`hs.ipc` 与标题方案无关；仅当需要 `hs -c '…'` 从 shell 调 HS 时才开启。

### 5.6 Layer C：AutoIme 概念逻辑

```text
resolve(win):
  if not terminal_app(win):
      return L1 app 规则
  state = lookup_session_state(win)
  if state.tui in {grok-build, qwen-code}:
      return 豆包
  return ABC
```

与标题关系（迁移可选）：

- 完全替换标题；或  
- **上报优先，标题 fallback**；或  
- 双信号（如 title AND/OR process，与上报正交）

### 5.7 分工原则：zsh 通用 vs 工具自有 hooks

**原则（与直觉一致）：**

| 层 | 放哪里 | 职责 |
|----|--------|------|
| 通用入口 | **zsh** `preexec` / `precmd` | 覆盖「本机交互式启动的 TUI 命令」白名单（qwen、grok、其它） |
| 工具增强 | **仅当该工具自己实现了 lifecycle hooks** | 用会话级语义补齐 zsh 猜不到的边界（resume、异常退出、子 agent 等） |

不能把「上报」默认塞进 grok 源码或假设所有 TUI 都有 hook。  
**Grok Build 已支持官方 hooks**（见下节），因此对 grok 可以做成「zsh 兜底 + Grok hooks 精报」；qwen 等需单独查是否有等价能力。

### 5.8 Grok Build 原生 Hooks 调研（已支持）

官方文档：`~/.grok/docs/user-guide/10-hooks.md`（TUI 内 `/hooks` 或 Ctrl+L → Hooks 页）。

#### 5.8.1 它是什么

Grok 在**会话生命周期关键时刻**调用你配置的 **shell 命令**或 **HTTP 请求**：

- 可 **拦截** 工具调用（仅 `PreToolUse` 可 deny）  
- 可 **被动响应**（日志、通知、写状态文件——适合 AutoIme 上报）  
- 可与 Claude / Cursor hooks 配置兼容合并加载  

发现路径（合并加载）：

| 范围 | 路径 | 信任 |
|------|------|------|
| 全局 | `~/.grok/hooks/*.json` | 始终可信 |
| 全局 | `~/.claude/settings.json`、`~/.cursor/hooks.json` | 默认可扫（可在 config 关掉） |
| 项目 | `<project>/.grok/hooks/*.json` 等 | 需 folder trust |
| 插件 | 插件内置 hooks | 随插件 |

#### 5.8.2 支持的 Hook 事件

| Event | 何时触发 | 可阻断？ | 对 AutoIme 的意义 |
|-------|----------|----------|-------------------|
| **`SessionStart`** | 会话开始 | 否 | **进入 grok → 上报 tui=grok-build** |
| **`SessionEnd`** | 会话结束 | 否 | **离开 grok → 上报 tui=none** |
| `UserPromptSubmit` | 用户提交 prompt | 否 | 一般不需要（输入法不跟每条 prompt 变） |
| `PreToolUse` | 工具即将执行 | **是**（可 deny） | 权限/安全，**不是** IME 主路径 |
| `PostToolUse` | 工具成功结束 | 否 | 审计/格式化；IME 过重 |
| `PostToolUseFailure` | 工具失败 | 否 | 同上 |
| `PermissionDenied` | 权限系统拒绝工具 | 否 | 安全向 |
| `Stop` | agent turn 结束（完成/取消/错） | 否 | 可通知「一轮结束」，非进出 TUI |
| `StopFailure` | turn 因 API 错误结束 | 否 | 同上 |
| `Notification` | agent 发通知 | 否 | 与 UI 通知相关 |
| `SubagentStart` / `SubagentStop` | 子 agent 起停 | 否 | IME 通常不变 |
| `PreCompact` / `PostCompact` | 会话压缩前后 | 否 | 无关 IME |

说明：`SubagentEnd` 是 `SubagentStop` 的别名。  
**只有 `PreToolUse` 可阻断**；其余均为 passive（stdout 忽略，exit 0 即可）。

Cursor 驼峰名会映射到上表（如 `sessionStart` → `SessionStart`）。

#### 5.8.3 配置形态（概念）

`~/.grok/hooks/autoime-session.json` 一类：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.cache/autoime/bin/grok-session-hook.sh start",
            "timeout": 5
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.cache/autoime/bin/grok-session-hook.sh end",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

- `type`：`command` 或 `http`  
- 工具类事件可加 `matcher`（正则匹配工具名）；**`SessionStart` / `SessionEnd` / `Stop` / `UserPromptSubmit` 不接受 matcher**  
- 失败默认 **fail-open**（超时/崩溃不阻断工具；对 IME 上报只需尽力写文件）

#### 5.8.4 Hook 进程环境变量（节选）

| 变量 | 含义 |
|------|------|
| `GROK_HOOK_EVENT` | 事件名（如 `session_start`、`session_end`） |
| `GROK_HOOK_NAME` | 该 hook 配置名 |
| `GROK_SESSION_ID` | 当前会话 ID |
| `GROK_WORKSPACE_ROOT` | 工作区根路径 |
| `CLAUDE_PROJECT_DIR` | 与 workspace 同义的兼容别名 |

stdin 还会喂 JSON 事件体（含 `sessionId`、`cwd`、`workspaceRoot`、工具类则有 `toolName` / `toolInput` 等）。

写 AutoIme 状态时可用：`session_id` + `cwd` + `shell` 侧已有的 `tty`/`ppid`（若 hook 环境能拿到）拼进状态文件。

#### 5.8.5 另一套：UI Notification Hooks（别混）

`~/.grok/config.toml` 里还有 **`[[ui.notifications.hooks]]`**（见 `05-configuration.md`）：

| | Lifecycle hooks（`10-hooks.md`） | Notification hooks（`ui.notifications.hooks`） |
|--|----------------------------------|-----------------------------------------------|
| 用途 | 会话/工具生命周期 | 桌面通知类（turn 完成、要审批等） |
| 典型事件 | SessionStart/End、PreToolUse… | `turn_complete`、`approval_required`… |
| 环境变量 | `GROK_HOOK_*`、`GROK_SESSION_ID`… | `$GROK_EVENT`、`$GROK_MESSAGE`、`$GROK_SESSION_ID` |
| 与 IME | **SessionStart/End 合适** | 偏「未聚焦时提醒」，且常 `only_unfocused=true`，**不适合**进出 TUI 登记 |

**AutoIme 应优先用 lifecycle `SessionStart` / `SessionEnd`，不要用 notification hooks 当进出信号。**

#### 5.8.6 zsh 上报 vs Grok hooks（对照）

| 维度 | zsh preexec/precmd | Grok `SessionStart`/`SessionEnd` |
|------|--------------------|----------------------------------|
| 触发点 | 命令行启动/退回 prompt | **Grok 会话真正开始/结束** |
| 覆盖面 | 任意白名单 CLI | **仅 Grok** |
| resume / `-c` continue | 仍是一条 `grok` 命令，一般能 preexec | SessionStart 语义更贴会话 |
| 异常 kill | precmd 可能不跑 | SessionEnd 是否总能跑取决于进程退出路径（与 zsh 类似，需 pid 兜底） |
| 路径误伤 | 无（看命令不看路径标题） | 无 |
| 维护 | 一份 zsh，管所有 TUI | 每种带 hooks 的 TUI 各配一套 |

**对 AutoIme 的建议：**

1. **通用基线仍放 zsh**（qwen 等未必有 hooks；逻辑统一）。  
2. **Grok 可叠加** `SessionStart`/`SessionEnd` 写同一套状态文件（`tui=grok-build`），比纯 preexec 更贴「会话在线」。  
3. 两者写同一 schema 时注意幂等与 `updated_at`，避免互相踩。  
4. 不要用 `PreToolUse`/`Stop` 来回切输入法（过于频繁且语义不对）。

### 5.9 端到端时序

**先 focus 终端再启动 grok：**

```text
focus Warp (tui=none) → ABC
# zsh 路径：
preexec grok → 写状态 → [ipc/timer] → 豆包
# 或 Grok hooks 路径（更贴会话）：
SessionStart → 写状态 tui=grok-build → 豆包
exit / SessionEnd → tui=none → ABC
```

**grok 已在跑，从其它 App 切回：**

```text
focus Warp → 读状态已是 grok → 豆包
```

### 5.10 工作量粗估

| 模块 | 量级 |
|------|------|
| zsh 片段 + 白名单 + 写 JSON | 小 |
| Grok `SessionStart`/`SessionEnd` 写同一状态 | 小（仅 grok） |
| 状态目录 / schema / pid 清理 | 小 |
| AutoIme 读状态 | 小 |
| hs.ipc 即时推送 | 中 |
| 多 tab 窗口↔shell 对齐 | **中～大（关键）** |

---

## 6. 推荐路线图

| 阶段 | 内容 | 状态 |
|------|------|------|
| 0 | L1 App 映射 + L2 标题（qwen + grok + claude + opencode） | **已落地** |
| 0.1 | 收紧 grok 标题（去掉裸 `contains: ["grok"]`） | 已识别，**暂不改**（用户确认） |
| 1 | zsh 写状态文件 + HS focus 读取（MVP，单会话/启发式对齐） | 未做 |
| 1b | Grok 原生 `SessionStart`/`SessionEnd` 写入同一状态（可选增强） | 未做；能力已调研 |
| 2 | 可选 hs.ipc 推送 + pid 存活校验 | 未做 |
| 3 | 多 tab 对齐；标题降为 fallback | 未做 |
| — | 热键强制中/英 | 可选兜底 |

当前产品决策：

- 以**标题方案（L2）为线上行为**，继续维护；多窗口场景下标题是窗口级信号，可用。  
- **放弃「App 级进程树」作为主方案**：macOS 上终端多为**单进程多窗口**，`app:pid()` 无法区分「哪一扇窗在跑 grok」；多窗一 grok 一 shell 时会误判。详见 §4.3。  
- **主动上报（zsh / Grok SessionStart）**仍作可选增强方向（本文第 5 节），非当前优先级。  
- grok 路径误伤（`contains: ["grok"]`）已知，**暂不改规则**；若改按第 3.3 节收紧。

---

## 7. 待拍板事项（实施前）

1. **多 tab 准确度目标**  
   - 单 TUI 够用 → S1/S2  
   - 多 tab 常并行 → 必须做窗口↔shell 对齐  

2. **上报范围**  
   - 仅 `grok` / `qwen` 白名单，还是扩展其它 TUI  

3. **与标题的关系**  
   - 替换 / 上报优先 / 仅 fallback  

4. **是否开启 `hs.ipc`**  
   - 仅即时推送需要；文件真相源可不依赖 ipc  

---

## 8. 相关路径速查

| 路径 | 说明 |
|------|------|
| `hammerspoon/.hammerspoon/init.lua` | 加载 AutoIme |
| `hammerspoon/.hammerspoon/config.json` | App 映射 + `tuiTitleDetection` |
| `hammerspoon/.hammerspoon/Spoons/AutoIme.spoon/init.lua` | 焦点/标题/切 IME |
| `~/.grok/config.toml` | Grok title / notifications |
| `~/.qwen/settings.json` | Qwen `hideWindowTitle` 等 |
| `~/.oh-my-zsh/lib/termsupport.zsh` | zsh 自动标题（误伤相关） |
| `~/.warp/settings.toml` | Warp tab 显示 working_directory |
| `~/.grok/docs/user-guide/10-hooks.md` | Grok lifecycle hooks 官方说明 |
| `~/.grok/hooks/*.json` | 用户全局 Grok hooks 配置目录 |

---

## 9. 变更记录

| 日期 | 说明 |
|------|------|
| 2026-07-19 | AutoIme 标题检测：qwen-code |
| 2026-07-21 | 增加 grok-build 标题规则；确认 `contains: ["grok"]` 路径误伤；完成 hooks/shell 上报调研 |
| 2026-07-21 | 本文档落盘：现状、边界、备选方案、zsh 上报设计、路线图 |
| 2026-07-21 | 补充 Grok Build 原生 lifecycle hooks 调研（事件表、与 notification hooks 区分、与 zsh 分工） |
| 2026-07-29 | 增加 claude-code 标题规则（`claude` / `claudex` / `Claude Code`） |
| 2026-08-01 | 增加 opencode 标题规则（大小写敏感的 `^OC%s*|`；无 `contains`） |
| 2026-07-21 | 明确放弃 App 级进程树主方案（单进程多窗口）；继续以标题检测为线上方案 |
