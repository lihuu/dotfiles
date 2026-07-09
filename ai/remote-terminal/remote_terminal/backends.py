from abc import ABC, abstractmethod

from remote_terminal.models import ExecResult, SessionRef


class TerminalBackend(ABC):
    @abstractmethod
    def create_session(self, host: str, name: str) -> SessionRef:
        raise NotImplementedError

    @abstractmethod
    def write(self, session: SessionRef, data: str) -> None:
        raise NotImplementedError

    @abstractmethod
    def read(self, session: SessionRef, lines: int = 200) -> str:
        raise NotImplementedError

    @abstractmethod
    def exec(
        self,
        session: SessionRef,
        command: str,
        timeout: float = 30.0,
        poll_interval: float = 0.25,
    ) -> ExecResult:
        raise NotImplementedError

    @abstractmethod
    def interrupt(self, session: SessionRef) -> None:
        raise NotImplementedError

    @abstractmethod
    def close(self, session: SessionRef) -> None:
        raise NotImplementedError