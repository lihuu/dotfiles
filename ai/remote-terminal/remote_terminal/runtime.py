import sys

from remote_terminal.backends import TerminalBackend
from remote_terminal.models import (
    BackendCommandError,
    ExecResult,
    MissingDependencyError,
    SessionRef,
)
from remote_terminal.ssh_direct_backend import SshDirectBackend
from remote_terminal.tmux_backend import TmuxBackend


class RemoteTerminalRuntime:
    def __init__(
        self,
        backend: TerminalBackend | None = None,
        remote_tmux: str = "tmux",
        remote_shell: str = "/bin/sh",
    ) -> None:
        self._explicit_backend = backend
        self._tmux_backend = TmuxBackend(
            remote_tmux=remote_tmux,
            remote_shell=remote_shell,
        )
        self._ssh_backend = SshDirectBackend()
        # session_id -> "tmux" or "ssh"
        self._backend_map: dict[str, str] = {}

    def _select_backend(self, session: SessionRef) -> TerminalBackend:
        """Return the backend for a session, falling back to ssh-direct.

        The CLI is stateless (each invocation is a new process), so
        _backend_map only helps within a single process.  When a session
        is unknown, try tmux first and fall back to ssh-direct on
        MissingDependencyError — the same logic as create_session.
        """
        if self._explicit_backend:
            return self._explicit_backend

        kind = self._backend_map.get(session.session_id)
        if kind == "ssh":
            return self._ssh_backend
        if kind == "tmux":
            return self._tmux_backend

        # Unknown session — default to tmux, let the caller's try/except
        # handle the fallback.
        return self._tmux_backend

    def create_session(self, host: str, name: str) -> SessionRef:
        if self._explicit_backend:
            session = self._explicit_backend.create_session(host, name)
            return session

        try:
            session = self._tmux_backend.create_session(host, name)
            self._backend_map[session.session_id] = "tmux"
            return session
        except MissingDependencyError:
            print(
                f"warning: tmux not available on {host!r}, falling back to "
                f"ssh-direct mode (no session persistence; "
                f"write/read/interrupt disabled)",
                file=sys.stderr,
            )
            session = self._ssh_backend.create_session(host, name)
            self._backend_map[session.session_id] = "ssh"
            return session

    def write(self, session: SessionRef, data: str) -> None:
        self._dispatch("write", session, data)

    def read(self, session: SessionRef, lines: int = 200) -> str:
        return self._dispatch("read", session, lines=lines)

    def exec(
        self,
        session: SessionRef,
        command: str,
        timeout: float = 30.0,
        poll_interval: float = 0.25,
    ) -> ExecResult:
        return self._dispatch(
            "exec", session, command, timeout=timeout, poll_interval=poll_interval
        )

    def interrupt(self, session: SessionRef) -> None:
        self._dispatch("interrupt", session)

    def close(self, session: SessionRef) -> None:
        self._dispatch("close", session)

    def _dispatch(self, method: str, session: SessionRef, *args, **kwargs):
        """Route to the correct backend, with automatic ssh-direct fallback."""
        if self._explicit_backend:
            return getattr(self._explicit_backend, method)(session, *args, **kwargs)

        kind = self._backend_map.get(session.session_id)
        if kind == "ssh":
            return getattr(self._ssh_backend, method)(session, *args, **kwargs)

        # Try tmux first (covers both "known tmux" and "unknown session").
        try:
            return getattr(self._tmux_backend, method)(session, *args, **kwargs)
        except MissingDependencyError:
            # Remote has no tmux — fall back to ssh-direct.
            print(
                f"warning: tmux not available on {session.host!r}, falling back to "
                f"ssh-direct mode (no session persistence; "
                f"write/read/interrupt disabled)",
                file=sys.stderr,
            )
            self._backend_map[session.session_id] = "ssh"
            return getattr(self._ssh_backend, method)(session, *args, **kwargs)