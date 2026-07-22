from __future__ import annotations

import shlex
import subprocess
import time
import uuid
from collections.abc import Callable

from remote_terminal.backends import TerminalBackend
from remote_terminal.models import (
    BackendCommandError,
    CommandTimeoutError,
    ExecResult,
    MarkerParseError,
    MissingDependencyError,
    SessionRef,
    ValidationError,
)

CommandRunner = Callable[[list[str]], subprocess.CompletedProcess[str]]

MARKER_PREFIX = "__REMOTE_TERMINAL_DONE"
MARKER_START_PREFIX = "__REMOTE_TERMINAL_START"


class TmuxBackend(TerminalBackend):
    def __init__(
        self,
        command_runner: CommandRunner | None = None,
        nonce_factory: Callable[[], str] | None = None,
        sleeper: Callable[[float], None] | None = None,
        clock: Callable[[], float] | None = None,
        remote_tmux: str = "tmux",
        remote_shell: str = "/bin/sh",
        ssh_timeout: float = 30.0,
    ) -> None:
        self._command_runner = command_runner or self._default_command_runner
        self._nonce_factory = nonce_factory or (lambda: uuid.uuid4().hex)
        self._sleeper = sleeper or time.sleep
        self._clock = clock or time.monotonic
        self._remote_tmux = remote_tmux
        self._remote_shell = remote_shell
        self._ssh_timeout = ssh_timeout

    def create_session(self, host: str, name: str) -> SessionRef:
        session = SessionRef(host=host, name=name)
        self._validate_session(session)

        result = self._run_tmux("create_session", session, ["has-session", "-t", name], check=False)
        if result.returncode == 0:
            return session
        if self._looks_like_missing_tmux(result):
            raise MissingDependencyError(
                f"remote host {host!r} needs tmux installed: {result.stderr.strip()}"
            )

        self._run_tmux(
            "create_session", session, ["new-session", "-d", "-s", name, self._remote_shell]
        )
        return session

    def write(self, session: SessionRef, data: str) -> None:
        self._validate_session(session)
        parts = data.split("\n")
        for index, part in enumerate(parts):
            if part:
                self._run_tmux("write", session, ["send-keys", "-t", session.name, "-l", "--", part])
            if index < len(parts) - 1:
                self._run_tmux("write", session, ["send-keys", "-t", session.name, "Enter"])

    def read(self, session: SessionRef, lines: int = 200) -> str:
        self._validate_session(session)
        if lines <= 0:
            raise ValidationError("lines must be greater than zero")
        result = self._run_tmux(
            "read",
            session,
            ["capture-pane", "-t", session.name, "-p", "-S", f"-{lines}"],
        )
        return result.stdout

    def exec(
        self,
        session: SessionRef,
        command: str,
        timeout: float = 30.0,
        poll_interval: float = 0.25,
    ) -> ExecResult:
        self._validate_session(session)
        if timeout <= 0:
            raise ValidationError("timeout must be greater than zero")
        if poll_interval <= 0:
            raise ValidationError("poll_interval must be greater than zero")

        nonce = self._nonce_factory()
        start_marker = f"{MARKER_START_PREFIX}:{nonce}"
        end_marker = f"{MARKER_PREFIX}:{nonce}:"
        marker_command = (
            f"printf '{start_marker}\\n'\n"
            f"{command}\n"
            f"printf '\\n{end_marker}%s\\n' \"$?\""
        )
        self.write(session, marker_command + "\n")

        deadline = self._clock() + timeout
        latest_output = ""
        while self._clock() <= deadline:
            latest_output = self.read(session)
            parsed = self._parse_marker(latest_output, end_marker, start_marker)
            if parsed is not None:
                exit_code, output = parsed
                return ExecResult(
                    command=command,
                    exit_code=exit_code,
                    output=output,
                    marker=end_marker,
                )
            self._sleeper(poll_interval)

        latest_output = self.read(session)
        raise CommandTimeoutError(
            f"timed out waiting for marker {end_marker!r}; latest pane output:\n{latest_output}"
        )

    def interrupt(self, session: SessionRef) -> None:
        self._validate_session(session)
        self._run_tmux("interrupt", session, ["send-keys", "-t", session.name, "C-c"])

    def close(self, session: SessionRef) -> None:
        self._validate_session(session)
        self._run_tmux("close", session, ["kill-session", "-t", session.name])

    @staticmethod
    def _default_command_runner(
        args: list[str], timeout: float | None = None
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(args, text=True, capture_output=True, check=False, timeout=timeout)

    def _run_tmux(
        self,
        operation: str,
        session: SessionRef,
        tmux_args: list[str],
        check: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        remote_command = self._remote_tmux_command(tmux_args)
        ssh_args = ["ssh", session.host, remote_command]
        try:
            result = self._command_runner(ssh_args, timeout=self._ssh_timeout)
        except FileNotFoundError as exc:
            raise MissingDependencyError("local OpenSSH client executable 'ssh' was not found") from exc
        except subprocess.TimeoutExpired as exc:
            raise CommandTimeoutError(
                f"{operation} timed out for {session.host}/{session.name} "
                f"after {self._ssh_timeout}s"
            ) from exc

        if check and result.returncode != 0:
            if self._looks_like_missing_tmux(result):
                raise MissingDependencyError(
                    f"remote host {session.host!r} needs tmux installed: {result.stderr.strip()}"
                )
            raise BackendCommandError(
                f"{operation} failed for {session.host}/{session.name} "
                f"with exit code {result.returncode}: {result.stderr.strip()}"
            )
        return result

    def _remote_tmux_command(self, tmux_args: list[str]) -> str:
        tmux_bin = self._remote_tmux
        quoted_args = " ".join(shlex.quote(arg) for arg in tmux_args)
        command = f"{shlex.quote(tmux_bin)} {quoted_args}"
        # When using a non-standard tmux path (e.g. /opt/homebrew/bin/tmux on
        # macOS), the remote non-interactive SSH PATH may not include that
        # directory. Wrap the command in a shell that prepends common Homebrew
        # paths so tmux is found.
        if tmux_bin != "tmux" and "/" in tmux_bin:
            tmux_dir = tmux_bin.rsplit("/", 1)[0]
            # Quote tmux_dir in case it contains spaces; don't quote $PATH —
            # it must expand on the remote shell.
            prefix = f"PATH={shlex.quote(tmux_dir)}:$PATH"
            command = f"{prefix} {command}"
        return command

    @staticmethod
    def _looks_like_missing_tmux(result: subprocess.CompletedProcess[str]) -> bool:
        stderr = (result.stderr or "").lower()
        return result.returncode == 127 or "tmux: not found" in stderr or "command not found" in stderr

    @staticmethod
    def _parse_marker(output: str, end_marker: str, start_marker: str) -> tuple[int, str] | None:
        # Search from the end for an end-marker line whose exit code is a
        # plain integer. The literal marker command text (sent via send-keys
        # -l) also contains the end-marker prefix followed by
        # "%s\n' \"$?\"", so a naive rfind can match the echoed command line
        # instead of the real marker output. We distinguish the two by
        # checking whether the remainder after the marker prefix looks like
        # the echoed printf command (contains %s or quote/$ characters).
        search_from = len(output)
        end_index = -1
        exit_code = -1
        while True:
            idx = output.rfind(end_marker, 0, search_from)
            if idx < 0:
                return None

            line_end = output.find("\n", idx)
            marker_line = output[idx:] if line_end < 0 else output[idx:line_end]
            exit_text = marker_line[len(end_marker) :].strip()
            try:
                exit_code = int(exit_text)
            except ValueError:
                if "%" in exit_text or "'" in exit_text or '"' in exit_text or "$" in exit_text:
                    search_from = idx
                    continue
                raise MarkerParseError(
                    f"could not parse exec marker exit code from {marker_line!r}"
                )

            end_index = idx
            break

        # Find the start marker before the end marker.  The actual start
        # marker output is a standalone line: \n<marker>\n.  The echoed
        # printf command contains the marker inside quotes with other text
        # around it, so the standalone pattern won't match the echo.
        start_pattern = f"\n{start_marker}\n"
        start_idx = output.rfind(start_pattern, 0, end_index)
        if start_idx >= 0:
            command_output = output[start_idx + len(start_pattern) : end_index]
        elif output.startswith(f"{start_marker}\n"):
            # Start marker is at the very beginning of the captured pane.
            command_output = output[len(start_marker) + 1 : end_index]
        else:
            # Fallback: no start marker found (e.g. pane scrolled past it).
            # Return everything before the end marker — same as the old
            # behavior, so we never lose output.
            command_output = output[:end_index]

        return exit_code, command_output