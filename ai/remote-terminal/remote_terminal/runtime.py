from remote_terminal.backends import TerminalBackend
from remote_terminal.models import ExecResult, SessionRef
from remote_terminal.tmux_backend import TmuxBackend


class RemoteTerminalRuntime:
    def __init__(
        self,
        backend: TerminalBackend | None = None,
        remote_tmux: str = "tmux",
        remote_shell: str = "/bin/sh",
    ) -> None:
        self._backend = backend or TmuxBackend(
            remote_tmux=remote_tmux,
            remote_shell=remote_shell,
        )

    def create_session(self, host: str, name: str) -> SessionRef:
        return self._backend.create_session(host, name)

    def write(self, session: SessionRef, data: str) -> None:
        self._backend.write(session, data)

    def read(self, session: SessionRef, lines: int = 200) -> str:
        return self._backend.read(session, lines=lines)

    def exec(
        self,
        session: SessionRef,
        command: str,
        timeout: float = 30.0,
        poll_interval: float = 0.25,
    ) -> ExecResult:
        return self._backend.exec(
            session,
            command,
            timeout=timeout,
            poll_interval=poll_interval,
        )

    def interrupt(self, session: SessionRef) -> None:
        self._backend.interrupt(session)

    def close(self, session: SessionRef) -> None:
        self._backend.close(session)