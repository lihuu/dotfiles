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
remote-terminal --help
rt --help
```

## Usage

Create or attach to a persistent session:

```bash
remote-terminal create macmini main
```

Type into the terminal:

```bash
remote-terminal write macmini/main "cd ~/project
"
```

Run a helper command and wait for its completion marker:

```bash
remote-terminal exec macmini/main "pwd"
```

Read the latest pane content:

```bash
remote-terminal read macmini/main --lines 200
```

Interrupt the foreground process:

```bash
remote-terminal interrupt macmini/main
```

Close the tmux session:

```bash
remote-terminal close macmini/main
```

## macOS Remote Hosts

macOS remotes (e.g. a Mac mini with Homebrew) need two extra flags:

```bash
remote-terminal --tmux /opt/homebrew/bin/tmux --shell "/bin/zsh -f" create macmini main
remote-terminal --tmux /opt/homebrew/bin/tmux --shell "/bin/zsh -f" exec macmini/main "pwd"
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

## First-Version Limitations

- Unix-like remotes only.
- Requires remote `tmux`.
- Does not implement SSH or manage SSH credentials.
- Does not edit `~/.ssh/config`.
- Does not implement tmux control mode.
- Does not parse full terminal escape streams.
- Does not provide multi-window or multi-pane orchestration.
- Does not claim structured stdout/stderr separation.

## Manual Smoke Path

Use a host alias that already works with `ssh <host>`.

```bash
remote-terminal create <host> main
remote-terminal write <host>/main "cd /tmp
"
remote-terminal exec <host>/main "pwd"
remote-terminal write <host>/main "python3 -q
"
remote-terminal read <host>/main
remote-terminal interrupt <host>/main
ssh <host>
tmux attach -t main
```

Expected observations:

- `pwd` reports `/tmp`, showing cwd state persisted.
- `python3 -q` remains attached to the same tmux terminal until interrupted.
- `tmux attach -t main` shows the same session the runtime operated.

## Agent Skill

An agent skill is provided at `.zcode/skills/rt/` so that ZCode can automatically use this tool when the user says things like "connect to my server" or "run a command on macmini". The skill handles:

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