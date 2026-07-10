# Remote Terminal Runtime

Remote Terminal Runtime is a small Python library and CLI for operating a persistent remote terminal session through OpenSSH and tmux.

It is not an SSH replacement. It uses the local `ssh` command and the user's existing SSH configuration.

## Model

There are two separate persistence layers:

- OpenSSH ControlMaster, when configured by the user, reuses SSH transport setup: TCP connection, SSH handshake, authentication, and encrypted transport.
- tmux preserves the remote terminal session: shell process, cwd, environment variables, virtual environment activation, terminal history, and long-running processes.

ControlMaster does not preserve shell state. The tmux session does.

```text
RemoteTerminalRuntime
  -> TmuxBackend
    -> ssh <host> <tmux command>
      -> remote tmux session
        -> remote shell
```

## Requirements

Local machine:

- Python 3.11+
- OpenSSH client available as `ssh`

Remote host:

- Unix-like shell environment
- `tmux`

## Install for Development

```bash
cd ai/remote-terminal
python3 -m pip install -e ".[test]"
```

The package installs two equivalent commands:

```bash
rt --help                    # recommended — short, Unix-style
remote-terminal --help        # same thing, longer name
```

All examples below use `rt`. The longer `remote-terminal` works identically.

## Usage

Create or attach to a persistent session:

```bash
rt create macmini main
```

Type into the terminal:

```bash
rt write macmini/main "cd ~/project
"
```

Run a helper command and wait for its completion marker:

```bash
rt exec macmini/main "pwd"
```

Read the latest pane content:

```bash
rt read macmini/main --lines 200
```

Interrupt the foreground process:

```bash
rt interrupt macmini/main
```

Close the tmux session:

```bash
rt close macmini/main
```

## macOS Remote Hosts

macOS remotes (e.g. a Mac mini with Homebrew) need two extra flags:

```bash
rt --tmux /opt/homebrew/bin/tmux --shell "/bin/zsh -f" create macmini main
rt --tmux /opt/homebrew/bin/tmux --shell "/bin/zsh -f" exec macmini/main "pwd"
```

**Why:**

- `--tmux /opt/homebrew/bin/tmux`: non-interactive SSH on macOS does not include `/opt/homebrew/bin` in PATH, so `tmux` is not found. This flag specifies the full path and automatically prepends it to the remote PATH.
- `--shell "/bin/zsh -f"`: the default zsh loads `~/.zshrc`, which may register fzf zle widgets (`eval "$(fzf --zsh)"`) that prevent tmux `send-keys` input from being consumed. `-f` skips all user config. `/bin/sh` also works and is the default for non-macOS hosts.

**Troubleshooting:**

- If `create` reports `command not found: tmux`, specify `--tmux` with the full path.
- If `create` succeeds but `exec` times out with no output, the remote shell config is blocking input — try `--shell "/bin/sh"` or `--shell "/bin/zsh -f"`.

Linux remotes typically need no extra flags.

## Human Takeover

The runtime uses ordinary named tmux sessions. A human can attach to the same terminal:

```bash
ssh macmini
tmux attach -t main
```

## API Example

```python
from remote_terminal import RemoteTerminalRuntime

# Linux remote — defaults work
runtime = RemoteTerminalRuntime()
session = runtime.create_session("vm-ubuntu", "main")
runtime.write(session, "cd ~/project\n")
result = runtime.exec(session, "pwd")
print(result.exit_code)
print(result.output)
```

```python
from remote_terminal import RemoteTerminalRuntime

# macOS remote — specify tmux path and clean shell
runtime = RemoteTerminalRuntime(
    remote_tmux="/opt/homebrew/bin/tmux",
    remote_shell="/bin/zsh -f",
)
session = runtime.create_session("macmini", "main")
result = runtime.exec(session, "uname -a")
print(result.exit_code)
print(result.output)
```

## Exec Semantics

`exec()` is a helper over terminal input. It sends the command, injects a unique marker, polls `tmux capture-pane`, and parses the marker exit code.

The returned output is terminal pane text observed around the marker. It is not a structured stdout/stderr pipe transcript.

In ssh-direct fallback mode, `exec()` runs `ssh <host> <command>` directly and returns stdout + exit code — no marker, no polling.

## SSH-Direct Fallback (No tmux Required)

If the remote host does not have tmux installed, the runtime automatically falls back to **ssh-direct mode**: commands are executed via `ssh <host> <command>` directly.

- **Automatic**: `create` tries tmux first; if the remote reports `command not found: tmux`, it switches to ssh-direct.
- **exec only**: In ssh-direct mode, only `exec` has real semantics. `write`, `read`, `interrupt`, and `close` are no-ops.
- **No persistent session**: Without tmux there is no session persistence — each `exec` is an independent SSH call. SSH connection reuse still works if ControlMaster is configured.
- **Stateless fallback**: `exec <host>/<name> "command"` works even without a prior `create` — the fallback triggers automatically.

```bash
# Host without tmux — falls back automatically
rt create banwagong main
rt exec banwagong/main "uname -a"
# Works: returns stdout + exit code via direct SSH
```

## First-Version Limitations

- Unix-like remotes only.
- Requires remote `tmux` for persistent sessions; falls back to ssh-direct (exec-only) when tmux is absent.
- Does not implement SSH or manage SSH credentials.
- Does not edit `~/.ssh/config`.
- Does not implement tmux control mode.
- Does not parse full terminal escape streams.
- Does not provide multi-window or multi-pane orchestration.
- Does not claim structured stdout/stderr separation.

## Manual Smoke Path

Use a host alias that already works with `ssh <host>`.

```bash
rt create <host> main
rt write <host>/main "cd /tmp
"
rt exec <host>/main "pwd"
rt write <host>/main "python3 -q
"
rt read <host>/main
rt interrupt <host>/main
ssh <host>
tmux attach -t main
```

Expected observations:

- `pwd` reports `/tmp`, showing cwd state persisted.
- `python3 -q` remains attached to the same tmux terminal until interrupted.
- `tmux attach -t main` shows the same session the runtime operated.

## Agent Skill

A ZCode agent skill is provided at `.zcode/skills/rt/` so ZCode can automatically use this tool when the user says things like "connect to my server" or "run a command on macmini". The skill handles:

- Natural language triggers → `rt` command mapping
- macOS vs Linux remote detection (automatic `--tmux` / `--shell` flags)
- ControlMaster first-use reminder
- Session lifecycle management

See `.zcode/skills/rt/SKILL.md` for the skill definition.

## Tests

The automated tests use fake command runners. They do not require a real SSH server or real tmux.

```bash
cd ai/remote-terminal
python3 -m pytest -v
```
