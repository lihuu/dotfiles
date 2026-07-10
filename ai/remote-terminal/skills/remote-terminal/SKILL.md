---
name: remote-terminal
description: Use when Codex needs to operate a remote Unix, Linux, or macOS host through an existing SSH alias, especially for persistent tmux shells, cwd or environment continuity, long-running process control, terminal capture, or SSH-only fallback.
---

# Remote Terminal

## Overview

Use the repository's `remote-terminal` CLI to control an ordinary remote tmux session over OpenSSH. Reuse the user's SSH configuration and leave credentials and `~/.ssh/config` untouched.

## Start

Resolve this skill's directory, then use its launcher for every operation:

```bash
RT="<skill-directory>/scripts/run-rt"
"$RT" --help
```

Use a stable, descriptive session name and the exact SSH host alias supplied by the user. Session IDs always use `<host>/<name>`.

For Linux and other standard Unix hosts:

```bash
"$RT" create my-host codex
"$RT" exec my-host/codex 'uname -a'
```

For a Homebrew-based macOS host, include these options on every invocation:

```bash
"$RT" --tmux /opt/homebrew/bin/tmux --shell '/bin/zsh -f' create macmini codex
"$RT" --tmux /opt/homebrew/bin/tmux --shell '/bin/zsh -f' exec macmini/codex 'pwd'
```

The clean shell avoids interactive `.zshrc` hooks that can block tmux input. If the remote has no tmux, the runtime automatically falls back to direct SSH; only `exec` then has meaningful behavior.

## Choose the Operation

| Need | Command |
| --- | --- |
| Create or reuse a persistent shell | `create <host> <name>` |
| Run a bounded command and get its exit code | `exec <host>/<name> '<command>'` |
| Send literal terminal input | `write <host>/<name> $'text\n'` |
| Inspect recent pane content | `read <host>/<name> --lines 200` |
| Send Ctrl-C to the foreground process | `interrupt <host>/<name>` |
| Terminate the tmux session | `close <host>/<name>` |

Pass the remote command or input as one local shell argument. Preserve the trailing newline with `write` when Enter is intended.

## Operate Safely

1. Verify the target host and begin with read-only inspection when the request does not already authorize a change.
2. Use `exec` for bounded commands. Treat its output as captured terminal-pane text, not cleanly separated stdout and stderr.
3. Use `write` followed by periodic `read` for interactive programs or commands likely to outlive the timeout. An `exec` timeout does not guarantee the remote process stopped.
4. Use `interrupt` only when the foreground process should receive Ctrl-C.
5. Use `close` only when terminating the persistent shell is intended; it kills the remote tmux session.
6. Do not send passwords, tokens, private keys, or other secrets in command arguments or report them in output.
7. Ask before destructive commands, privilege changes, service disruption, or other system-wide mutations unless the user explicitly requested them.

## Troubleshoot

- `tmux: command not found` on macOS: use `/opt/homebrew/bin/tmux`.
- `exec` times out with no input consumed: use `/bin/zsh -f` or `/bin/sh` as the remote shell.
- SSH fails: verify `ssh <host>` independently; this tool does not manage authentication or SSH configuration.
- No tmux: continue with `exec`; persistence, `write`, `read`, `interrupt`, and `close` are unavailable in SSH-direct mode.
