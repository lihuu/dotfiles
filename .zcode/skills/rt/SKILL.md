---
name: rt
description: 远程终端交互工具。通过 SSH + tmux 操作持久远程终端会话。当用户说"连接服务器"、"连到 macmini"、"在服务器上执行命令"、"看服务器状态"、"远程跑个命令"时使用。
---

# rt — 远程终端交互

## 概述

`rt` 是 `remote-terminal` CLI 的 skill 封装。它通过本地 `ssh` 命令驱动远端 tmux 会话，让 agent 像一个 SSH 登录后在 tmux 里持续操作的用户一样工作——cwd、环境变量、历史记录跨命令持久化。

这不是 SSH 替代品，也不管理 SSH 配置或密钥。它只操作用户已有 SSH 配置可达的主机上的 tmux 会话。

## 何时使用

当用户的请求涉及与远程服务器的**持续交互**时使用本 skill：

| 用户说 | 映射到 | 说明 |
|--------|--------|------|
| "连接/连到 macmini" / "连到我的服务器" | `rt create <host> main` | 创建或接入持久会话 |
| "在 macmini 上跑个 pwd" / "在服务器上执行 xxx" | `rt exec <host>/main "命令"` | 在持久会话中执行命令，返回 exit code + output |
| "看看服务器现在什么状态" / "读一下终端" | `rt read <host>/main` | 读取 tmux pane 当前内容 |
| "输入 cd /tmp" / "写入命令" | `rt write <host>/main "cd /tmp\n"` | 向终端发送文本（含换行符触发 Enter） |
| "中断" / "停掉正在跑的进程" | `rt interrupt <host>/main` | 发送 Ctrl-C |
| "关闭会话" / "清理" | `rt close <host>/main` | 杀掉 tmux 会话 |

### 何时**不**使用

- 单次 `ssh host command` 一把梭的场景——直接用 ssh 即可，不需要持久会话
- 需要结构化 stdout/stderr 分离的场景——`rt` 返回的是终端 pane 文本，不是管道输出
- Windows 远程主机——当前版本仅支持 Unix-like 远端

## 命令速查

CLI 路径：`/Users/lihu/git/dotfiles/ai/remote-terminal/.venv/bin/rt`
（如果已 `pip install -e` 到全局环境，可直接用 `rt`）

```bash
RT="/Users/lihu/git/dotfiles/ai/remote-terminal/.venv/bin/rt"
```

### create — 创建或接入持久会话

```bash
$RT create <host> <name>
# 输出: <host>/<name>
# 退出码: 0 成功；1 远端缺少 tmux 或连接失败
```

attach-or-create 语义：如果 tmux 会话已存在则直接复用，不存在则创建。

### exec — 在持久会话中执行命令

```bash
$RT exec <host>/<name> "<command>" [--timeout 30]
# 输出: 命令的终端 pane 输出
# 退出码: 命令本身的 exit code（0=成功，非零=命令失败）；1=运行时错误
```

exec 发送命令 + 唯一完成 marker，轮询 pane 直到 marker 出现或超时。返回的是 pane 文本（含命令回显、prompt），不是纯 stdout。

### read — 读取终端 pane 内容

```bash
$RT read <host>/<name> [--lines 200]
# 输出: pane 文本
# 退出码: 0
```

### write — 向终端输入文本

```bash
$RT write <host>/<name> "<text>"
# 文本中的 \n 被转换为 Enter 键事件，不是字面字符
```

用于输入需要交互的命令（如 `python3 -q\n` 启动 REPL）。

### interrupt — 发送 Ctrl-C

```bash
$RT interrupt <host>/<name>
```

### close — 关闭会话

```bash
$RT close <host>/<name>
# 破坏性操作：杀掉指定 tmux 会话，不影响其他会话
```

## 工作流

### 默认 session 名称

除非用户指定，默认使用 `main` 作为 session 名。

### 典型流程

1. **连接**：`$RT create <host> main` — 如果远端报缺少 tmux，提示用户安装
2. **执行命令**：`$RT exec <host>/main "pwd"` — 验证 cwd 持久化
3. **持续操作**：write / exec / read / interrupt 按需组合
4. **清理**：`$RT close <host>/main` — 确认后再执行

### session 复用

session 创建后持久存在，跨多次调用复用。不需要每次都 create——如果不确定是否存在，先 `read` 探测，失败再 `create`。

## 安全注意事项

- **不修改** `~/.ssh/config`、不安装 SSH 密钥、不管理凭据
- `close` 是破坏性操作，执行前向用户确认
- `exec` 的 `--timeout` 默认 30 秒，长命令需显式设置
- 远端 tmux 会话在 close 之前一直存在；如果远端重启，session 丢失，需重新 create

## 详细用法

完整示例、常见场景和故障排查见 [references/usage.md](references/usage.md)。