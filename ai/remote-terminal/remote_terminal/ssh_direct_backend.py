from __future__ import annotations

import subprocess
from collections.abc import Callable

from remote_terminal.backends import TerminalBackend
from remote_terminal.models import (
    BackendCommandError,
    CommandTimeoutError,
    ExecResult,
    MissingDependencyError,
    SessionRef,
    ValidationError,
)

CommandRunner = Callable[[list[str]], subprocess.CompletedProcess[str]]


class SshDirectBackend(TerminalBackend):
    """Fallback backend that runs commands via ``ssh <host> <command>`` directly.

    Used when the remote host does not have tmux installed.  Only ``exec``
    has real semantics — it runs the command and returns stdout + exit code.
    ``write``, ``read``, ``interrupt``, and ``close`` are no-ops because
    there is no persistent pane.  SSH connection reuse still works via
    OpenSSH ControlMaster if the user has configured it.
    """

    def __init__(self, command_runner: CommandRunner | None = None) -> None:
        self._command_runner = command_runner or self._default_command_runner

    def create_session(self, host: str, name: str) -> SessionRef:
        session = SessionRef(host=host, name=name, backend="ssh")
        self._validate_session(session)

        # Probe connectivity — a failed SSH connection surfaces here so the
        # caller gets a clear error instead of a delayed failure on exec.
        self._run_ssh("create_session", session, "true")
        return session

    def write(self, session: SessionRef, data: str) -> None:
        # No persistent pane — nothing to write to.
        pass

    def read(self, session: SessionRef, lines: int = 200) -> str:
        # No persistent pane — nothing to read.
        return ""

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

        result = self._run_ssh("exec", session, command, timeout=timeout)
        # Merge stderr into output so error messages are not silently lost.
        output = result.stdout
        if result.stderr:
            output = f"{output}{result.stderr}" if output else result.stderr
        return ExecResult(
            command=command,
            exit_code=result.returncode,
            output=output,
            marker="",
        )

    def interrupt(self, session: SessionRef) -> None:
        # No persistent process to interrupt.
        pass

    def close(self, session: SessionRef) -> None:
        # No persistent session to close.
        pass

    @staticmethod
    def _default_command_runner(
        args: list[str], timeout: float | None = None
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(args, text=True, capture_output=True, check=False, timeout=timeout)

    def _run_ssh(
        self,
        operation: str,
        session: SessionRef,
        remote_command: str,
        timeout: float | None = None,
    ) -> subprocess.CompletedProcess[str]:
        ssh_args = ["ssh", session.host, remote_command]
        try:
            result = self._command_runner(ssh_args, timeout=timeout)
        except FileNotFoundError as exc:
            raise MissingDependencyError(
                "local OpenSSH client executable 'ssh' was not found"
            ) from exc
        except subprocess.TimeoutExpired as exc:
            raise CommandTimeoutError(
                f"{operation} timed out for {session.host}/{session.name} "
                f"after {timeout}s"
            ) from exc

        if operation == "create_session" and result.returncode != 0:
            raise BackendCommandError(
                f"{operation} failed for {session.host}/{session.name} "
                f"with exit code {result.returncode}: {result.stderr.strip()}"
            )
        return result