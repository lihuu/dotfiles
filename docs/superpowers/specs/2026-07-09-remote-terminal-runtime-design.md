<!-- IMPLEMENTATION-SPEC-BEGIN -->

# Goal

Build a first-version Remote Persistent Terminal Runtime under `ai/remote-terminal/` as a Python library plus a small CLI. The runtime lets an agent operate a persistent remote terminal session that behaves like a user who has SSHed into a host, attached to a tmux session, and kept typing in the same shell.

The first version must combine two separate persistence layers:

- SSH transport reuse is delegated to OpenSSH and the user's existing SSH configuration, including ControlMaster when the user has enabled it.
- Remote shell/session persistence is provided by a remote tmux session.

# Non-Goals

- Do not replace SSH or implement the SSH protocol.
- Do not edit `~/.ssh/config`, install SSH keys, manage credentials, or write host-specific secrets into the repository.
- Do not support Windows remotes in the first version.
- Do not implement tmux control mode in the first version.
- Do not implement a full terminal stream parser or structured stdout/stderr separation.
- Do not implement multi-window or multi-pane tmux orchestration.
- Do not make this a general command runner that hides terminal state. Normal one-shot `ssh host command` remains a separate useful path.

# Architecture

The implementation lives in a new self-contained project directory:

```text
ai/remote-terminal/
  README.md
  pyproject.toml
  remote_terminal/
    __init__.py
    backends.py
    cli.py
    models.py
    runtime.py
    tmux_backend.py
  tests/
```

The public boundary is `RemoteTerminalRuntime`. It delegates all terminal operations to a `TerminalBackend` interface. The first implemented backend is `TmuxBackend`.

```text
RemoteTerminalRuntime
  -> TerminalBackend
    -> TmuxBackend
      -> local OpenSSH command
        -> remote tmux session
          -> remote shell
```

OpenSSH ControlMaster is treated as a transport optimization only. It may reduce repeated connection setup cost for the runtime's SSH calls, but it must not be described or implemented as shell state persistence.

# Detailed Design

## Data Model

Define `SessionRef` in `remote_terminal/models.py`:

```python
from dataclasses import dataclass


@dataclass(frozen=True)
class SessionRef:
    host: str
    name: str
    backend: str = "tmux"

    @property
    def session_id(self) -> str:
        return f"{self.host}/{self.name}"
```

Define `ExecResult`:

```python
from dataclasses import dataclass


@dataclass(frozen=True)
class ExecResult:
    command: str
    exit_code: int
    output: str
    marker: str
```

Define `RemoteTerminalError` as the base exception and specific subclasses for validation, backend command failures, missing remote dependencies, timeout, and marker parsing failure.

## Backend Interface

Define `TerminalBackend` in `remote_terminal/backends.py` as an abstract base class with these methods:

```python
class TerminalBackend(ABC):
    @abstractmethod
    def create_session(self, host: str, name: str) -> SessionRef: ...

    @abstractmethod
    def write(self, session: SessionRef, data: str) -> None: ...

    @abstractmethod
    def read(self, session: SessionRef, lines: int = 200) -> str: ...

    @abstractmethod
    def exec(
        self,
        session: SessionRef,
        command: str,
        timeout: float = 30.0,
        poll_interval: float = 0.25,
    ) -> ExecResult: ...

    @abstractmethod
    def interrupt(self, session: SessionRef) -> None: ...

    @abstractmethod
    def close(self, session: SessionRef) -> None: ...
```

The interface is terminal-oriented. `write()` types into the terminal. `read()` returns terminal pane text. `exec()` is a helper layered on top of terminal input and pane capture.

## Runtime API

Define `RemoteTerminalRuntime` in `remote_terminal/runtime.py`. It validates and routes calls to the selected backend. The first version exposes:

```python
runtime = RemoteTerminalRuntime()
session = runtime.create_session("macmini", "main")
runtime.write(session, "cd ~/project\n")
output = runtime.read(session)
result = runtime.exec(session, "pwd")
runtime.interrupt(session)
runtime.close(session)
```

`RemoteTerminalRuntime` accepts an optional backend instance for tests and future implementations.

## Tmux Backend

`TmuxBackend` uses local `subprocess.run()` with argument lists for local process execution. It invokes remote commands through OpenSSH:

```text
ssh <host> <remote-command>
```

Remote command arguments are shell-quoted with `shlex.quote()` before being combined into the remote command string. Host and tmux session names are validated before use. Host values must not begin with `-` and must not contain control characters. Tmux session names must match:

```text
^[A-Za-z0-9_.-]+$
```

The backend uses these remote tmux operations:

- `tmux has-session -t <name>` to check whether the session exists.
- `tmux new-session -d -s <name>` to create it when missing.
- `tmux send-keys -t <name> -l -- <text>` to send literal text.
- `tmux send-keys -t <name> Enter` for newline events.
- `tmux capture-pane -t <name> -p -S -<lines>` to read terminal output.
- `tmux send-keys -t <name> C-c` to interrupt.
- `tmux kill-session -t <name>` to close.

`create_session()` must be attach-or-create. If the tmux session already exists, the method returns the existing session instead of replacing it.

`write()` must preserve user intent for newline input. Literal text is sent with `send-keys -l`. Newline characters are translated into tmux `Enter` key events. This preserves the distinction between typing text and pressing Enter.

`read()` returns pane text, not structured command output. The first version may include visible prompts, previously captured output, and long-running process output.

## Exec Completion Detection

`exec()` sends the requested command followed by a unique completion marker:

```sh
<command>
printf '\n__REMOTE_TERMINAL_DONE:<nonce>:%s\n' "$?"
```

The nonce is generated for each exec call. `exec()` polls `read()` until it sees the marker or the timeout expires. It parses the exit code from the marker line and returns an `ExecResult`.

The implementation must avoid claiming that `exec()` captures perfect stdout/stderr. It returns the relevant pane text observed while waiting for the marker, best-effort trimmed around the marker. The API contract is terminal output plus exit status, not a process-level pipe transcript.

## CLI

Provide console scripts named `remote-terminal` and `rt`. Both entry points call the same CLI implementation. The CLI supports:

```bash
remote-terminal create <host> <name>
remote-terminal write <host>/<name> <text>
remote-terminal read <host>/<name> [--lines 200]
remote-terminal exec <host>/<name> <command> [--timeout 30]
remote-terminal interrupt <host>/<name>
remote-terminal close <host>/<name>
```

The CLI parses `<host>/<name>` into `SessionRef`. It exits non-zero on validation errors, backend errors, timeouts, and non-zero `exec()` exit codes. For `exec()`, terminal output is printed to stdout and backend/runtime errors are printed to stderr.

## Documentation

`README.md` must explain:

- The difference between SSH ControlMaster transport reuse and tmux shell/session persistence.
- Required remote dependency: `tmux`.
- Required local dependency: OpenSSH client available as `ssh`.
- Human takeover with `ssh <host>` then `tmux attach -t <name>`.
- First-version limitations and non-goals.
- Example workflow that proves state preservation:

```bash
remote-terminal create macmini main
remote-terminal write macmini/main "cd ~/project\n"
remote-terminal exec macmini/main "pwd"
```

# Error Handling

- If local `ssh` is missing, raise a backend command error with a message that names the missing executable.
- If remote `tmux` is missing, `create_session()` must fail with a clear message that the remote host needs tmux installed.
- If host or session name validation fails, reject before invoking SSH.
- If an SSH command exits non-zero, include the operation name, host, session name, exit code, and stderr in the exception message.
- If `exec()` times out before seeing its marker, raise a timeout error and include the marker and the latest captured pane output.
- If a marker is present but the exit code cannot be parsed, raise a marker parsing error.
- `close()` should be explicit and destructive for that tmux session only. It must not kill other sessions.

# Testing Strategy

Use `pytest`.

Unit tests must cover:

- `SessionRef` session id formatting.
- `<host>/<name>` CLI/session parsing.
- Host and session-name validation.
- SSH command construction uses local subprocess argument lists and quoted remote tmux commands.
- `create_session()` creates a missing tmux session and attaches to an existing one without replacing it.
- `write()` converts newlines into `Enter` events while sending literal text through `send-keys -l`.
- `read()` calls `capture-pane` with the requested line count.
- `exec()` sends a command with a unique marker, polls until marker detection, parses the exit code, and returns an `ExecResult`.
- `exec()` timeout behavior includes the latest captured pane output.
- `interrupt()` sends `C-c`.
- `close()` kills only the named session.

Tests must not require a real SSH server or real tmux. Use a fake command runner injected into `TmuxBackend` to assert requested commands and simulate outputs.

Manual validation should be documented, not required for unit test success:

```bash
remote-terminal create <host> main
remote-terminal write <host>/main "cd /tmp\n"
remote-terminal exec <host>/main "pwd"
remote-terminal write <host>/main "python3 -q\n"
remote-terminal read <host>/main
remote-terminal interrupt <host>/main
ssh <host>
tmux attach -t main
```

<!-- IMPLEMENTATION-SPEC-END -->

<!-- ACCEPTANCE-BEGIN -->

# Completion Contract

The task is complete only when the Python library, CLI, tests, and README implement the first-version Remote Persistent Terminal Runtime exactly within the Implementation Spec boundaries.

# Verification Protocol

- Verify each Acceptance Criterion independently; do not approve from aggregate test results alone.
- When a criterion references another spec definition, read and compare the complete definition.
- Report PASS, FAIL, or NOT VERIFIED for every criterion.
- A PASS must include all Required Evidence named by the criterion.
- Missing required evidence means the criterion is NOT VERIFIED, not PASS.
- Test success does not replace required source, boundary, or runtime semantic checks.
- Execute Rollout Acceptance checks with the same evidence rules.
- Only when every criterion and every Rollout Acceptance check is PASS may the task and automated loop stop.

# Acceptance Criteria

### AC-01: Project Structure

**Requirement:** The implementation creates a self-contained Python project under `ai/remote-terminal/` with README, packaging metadata, library modules, and tests matching the structure in the Architecture section.

**Verification Steps:**
1. Inspect `ai/remote-terminal/`.
2. Compare the files against the Architecture section.

**Pass Conditions:** The directory contains `README.md`, `pyproject.toml`, `remote_terminal/`, and `tests/`, and the library modules named in the Architecture section exist.

**Fail Conditions:** Runtime code is placed in `.ai/`, mixed into unrelated script directories, or required files/modules are missing.

**Required Evidence:** File listing for `ai/remote-terminal/` and line references for package metadata.

### AC-02: Backend Abstraction

**Requirement:** Public runtime logic depends on a `TerminalBackend` interface, and tmux-specific behavior is contained in `TmuxBackend`.

**Verification Steps:**
1. Inspect `remote_terminal/backends.py`.
2. Inspect `remote_terminal/runtime.py`.
3. Inspect `remote_terminal/tmux_backend.py`.

**Pass Conditions:** `TerminalBackend` defines the required methods, `RemoteTerminalRuntime` delegates through that interface, and tmux command details are implemented in `TmuxBackend`.

**Fail Conditions:** Runtime public methods directly construct tmux commands, or tmux-specific behavior is spread into CLI or model code.

**Required Evidence:** File and line references for the interface, runtime delegation, and tmux backend implementation.

### AC-03: ControlMaster Boundary

**Requirement:** The implementation delegates SSH transport reuse to OpenSSH and does not edit SSH configuration or represent ControlMaster as shell/session persistence.

**Verification Steps:**
1. Inspect runtime and backend source for writes to SSH config paths.
2. Inspect README explanation of ControlMaster and tmux responsibilities.

**Pass Conditions:** No implementation code modifies `~/.ssh/config` or key material, and README clearly states that ControlMaster is transport reuse while tmux preserves shell/session state.

**Fail Conditions:** Code writes SSH config, stores credentials, or documents ControlMaster as preserving cwd/env/shell state.

**Required Evidence:** Source search result plus README line references.

### AC-04: Session State Preservation Semantics

**Requirement:** Commands typed through `write()` and `exec()` target the same remote tmux session so cwd, environment variables, virtual environment activation, and long-running processes can persist across calls.

**Verification Steps:**
1. Inspect `TmuxBackend.create_session()`, `write()`, `read()`, and `exec()`.
2. Verify they all use the same validated tmux target name from `SessionRef`.

**Pass Conditions:** The backend creates or attaches to a named tmux session and every terminal operation targets that session name.

**Fail Conditions:** Each command starts an independent remote shell outside tmux, or `exec()` bypasses the persistent tmux session.

**Required Evidence:** File and line references for create/attach and each operation targeting the same session.

### AC-05: Terminal-Oriented IO

**Requirement:** `write()` behaves like typing into a terminal by sending literal text through `tmux send-keys -l` and translating newline characters into `Enter` key events.

**Verification Steps:**
1. Inspect `TmuxBackend.write()`.
2. Run the unit test that covers newline conversion.

**Pass Conditions:** Literal text and newline key events are handled separately, and the test demonstrates input containing a newline produces an `Enter` event.

**Fail Conditions:** Newline input is passed only as literal text, or all input is executed as one quoted shell command instead of terminal input.

**Required Evidence:** Source line references and specific pytest test name/output.

### AC-06: Exec Marker Completion

**Requirement:** `exec()` sends the command to the persistent terminal, injects a unique completion marker, polls pane output, parses marker exit status, and returns terminal output plus exit code.

**Verification Steps:**
1. Inspect `TmuxBackend.exec()`.
2. Run the unit test for successful marker parsing.
3. Run the unit test for timeout behavior.

**Pass Conditions:** The marker includes a per-call nonce, exit code parsing is tested, timeout raises a timeout error with latest pane output, and `ExecResult` includes command, exit code, output, and marker.

**Fail Conditions:** Completion is detected from a shell prompt, marker is static across calls, timeout loses captured output, or `exec()` runs a separate `ssh host command` outside tmux.

**Required Evidence:** Source line references and pytest test names/output.

### AC-07: Human Takeover

**Requirement:** The tmux session created by the runtime can be attached by a human using ordinary SSH and `tmux attach -t <name>`.

**Verification Steps:**
1. Inspect `create_session()` for ordinary named tmux session creation.
2. Inspect README human takeover instructions.

**Pass Conditions:** The backend uses normal named tmux sessions, and README documents the exact attach command.

**Fail Conditions:** The backend uses hidden/private terminal state that cannot be attached with normal tmux, or README omits takeover instructions.

**Required Evidence:** Source and README line references.

### AC-08: Validation and Command Safety

**Requirement:** Host and session names are validated before invoking SSH, local subprocess calls use argument lists, and remote tmux command arguments are shell-quoted.

**Verification Steps:**
1. Inspect validation code.
2. Inspect command runner construction.
3. Run unit tests for invalid host/session inputs and command construction.

**Pass Conditions:** Invalid values are rejected before SSH invocation, subprocess calls are list-based, and remote command arguments are quoted.

**Fail Conditions:** Raw host/session values are interpolated into shell commands without validation, local subprocess execution uses `shell=True`, or tests do not cover invalid values.

**Required Evidence:** Source line references and pytest test names/output.

### AC-09: CLI Contract

**Requirement:** The CLI provides `remote-terminal` and `rt` entry points, each supporting create, write, read, exec, interrupt, and close commands using `<host>/<name>` session identifiers where specified.

**Verification Steps:**
1. Inspect `remote_terminal/cli.py`.
2. Run CLI parser/unit tests for each command.

**Pass Conditions:** Both entry points are declared in package metadata, each required command exists, parses arguments as specified, and delegates to `RemoteTerminalRuntime`.

**Fail Conditions:** Either entry point is missing, required commands are missing, session id parsing is inconsistent, or CLI commands bypass runtime abstractions.

**Required Evidence:** CLI source line references and pytest test names/output.

### AC-10: Documentation Boundaries

**Requirement:** README documents dependencies, usage examples, ControlMaster versus tmux responsibilities, human takeover, first-version limitations, and manual validation commands.

**Verification Steps:**
1. Inspect `ai/remote-terminal/README.md`.
2. Compare README content against the Documentation section of the Implementation Spec.

**Pass Conditions:** README covers every listed documentation topic without adding unsupported first-version features.

**Fail Conditions:** README omits required topics or claims support for Windows remotes, tmux control mode, SSH implementation, or structured stdout/stderr.

**Required Evidence:** README line references.

# Rollout Acceptance

### RA-01: Automated Test Suite

**Requirement:** The project test suite runs locally without requiring a real SSH server or real tmux.

**Verification Steps:**
1. Run the documented pytest command from `ai/remote-terminal/`.

**Pass Conditions:** Tests pass using fake command runners or equivalent local fakes.

**Fail Conditions:** Tests require network SSH access, require a live tmux server, or fail.

**Required Evidence:** Test command and output summary.

### RA-02: Manual Remote Smoke Path

**Requirement:** README provides a manual smoke path for a real host that demonstrates create, state preservation, long-running/interactive behavior, interrupt, and human attach.

**Verification Steps:**
1. Inspect README manual validation section.

**Pass Conditions:** The manual path contains concrete commands for create, write `cd`, exec `pwd`, start an interactive/long-running process, read, interrupt, and attach with tmux.

**Fail Conditions:** Manual validation is missing, vague, or relies on repository-specific private hostnames/secrets.

**Required Evidence:** README line references.

<!-- ACCEPTANCE-END -->
