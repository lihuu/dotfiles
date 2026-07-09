# rt 详细用法

## 路径设置

```bash
RT="/Users/lihu/git/dotfiles/ai/remote-terminal/.venv/bin/rt"
```

如果已全局安装（`pip install -e .`），可直接用 `rt`。

## 场景 1：首次连接并验证

```bash
# 创建持久会话
$RT create vm-ubuntu main

# 切换目录
$RT write vm-ubuntu/main "cd /tmp
"

# 验证 cwd 持久化
$RT exec vm-ubuntu/main "pwd"
# 输出包含 /tmp，exit code 0 → cwd 跨命令持久化成功
```

## 场景 2：执行单条命令

```bash
# 确保 session 存在（已存在则复用，不会报错）
$RT create vm-ubuntu main

# 执行命令，获取 exit code
$RT exec vm-ubuntu/main "systemctl status nginx" --timeout 10
# exit code 0 = 服务正常；非零 = 服务异常或命令失败

# 长时间运行的命令
$RT exec vm-ubuntu/main "apt update" --timeout 120
```

## 场景 3：交互式进程

```bash
# 启动 Python REPL
$RT write vm-ubuntu/main "python3 -q
"

# 读取 pane 确认 REPL 已启动（看到 >>> 提示符）
$RT read vm-ubuntu/main

# 向 REPL 输入代码
$RT write vm-ubuntu/main "import os; print(os.getcwd())
"

# 读取输出
$RT read vm-ubuntu/main

# 中断 REPL
$RT interrupt vm-ubuntu/main
```

## 场景 4：查看服务器状态

```bash
# 读取最近 50 行 pane 内容
$RT read vm-ubuntu/main --lines 50

# 如果 session 不存在会报错，先 create
$RT create vm-ubuntu main
$RT read vm-ubuntu/main
```

## 场景 5：多步骤运维任务

```bash
HOST="vm-ubuntu"
SESSION="$HOST/main"

# 1. 连接
$RT create $HOST main

# 2. 检查磁盘
$RT exec $SESSION "df -h /" --timeout 10

# 3. 检查内存
$RT exec $SESSION "free -h" --timeout 10

# 4. 查看日志
$RT exec $SESSION "journalctl -u nginx --no-pager -n 20" --timeout 10

# 5. 清理
$RT close $SESSION
```

## 场景 6：人类接管

rt 创建的是普通 tmux 会话，用户可以手动 attach：

```bash
ssh vm-ubuntu
tmux attach -t main
# 看到的就是 rt 操作的同一个终端
# detach: Ctrl-b d
```

## exec 输出说明

`exec` 返回的是 **tmux pane 文本**，不是纯 stdout。典型输出包含：

```
# prompt 行
$ pwd
/tmp                  ← 命令实际输出
$ printf '\n__REMOTE_TERMINAL_DONE:<nonce>:%s\n' "$?"  ← marker 注入行
```

- 命令回显、prompt、marker 行都会出现在 output 中
- exit code 是从 marker 行解析的，准确反映命令真实退出码
- 如果需要干净的 stdout，应在命令内部处理（如重定向）

## 故障排查

### 远端缺少 tmux

```
$RT create macmini main
# 输出: remote host 'macmini' needs tmux installed: command not found
# 退出码: 1
```

解决：在远端安装 tmux（`apt install tmux` / `brew install tmux`）。

### session 不存在

如果远端重启或 session 被 close，后续操作会报错：

```
$RT exec vm-ubuntu/main "pwd"
# 输出: ... failed ... can't find session
```

解决：重新 `create`。

### exec 超时

```
$RT exec vm-ubuntu/main "sleep 100" --timeout 5
# 输出: timed out waiting for marker ...; latest pane output: ...
# 退出码: 1
```

解决：增大 `--timeout`，或用 `interrupt` 停掉卡住的进程。

### host 不可达

```
$RT create unknown-host main
# 输出: ... failed with exit code 255: ... connection refused / timed out
```

解决：确认 `~/.ssh/config` 中有该 host 别名，且网络可达。

### write 不生效

`write` 发送文本到终端，但不等待执行完成。如果需要确认执行结果，用 `exec` 而不是 `write`。

## session 生命周期

```
create ──→ 持久存在（跨命令、跨调用）
  │
  ├── exec / read / write / interrupt（复用同一 session）
  │
  └── close ──→ session 消失
```

- session 在 close 之前一直存在于远端 tmux server
- 远端重启后 session 丢失
- 可用 `ssh <host> 'tmux ls'` 查看所有 session