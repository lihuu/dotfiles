from __future__ import annotations

import re
from abc import ABC, abstractmethod

from remote_terminal.models import ExecResult, SessionRef, ValidationError

SESSION_NAME_RE = re.compile(r"^[A-Za-z0-9_.-]+$")


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

    @staticmethod
    def _validate_session(session: SessionRef) -> None:
        if not session.host or session.host.startswith("-") or any(
            ord(ch) < 0x20 or ord(ch) == 0x7f for ch in session.host
        ):
            raise ValidationError(f"invalid host: {session.host!r}")
        if not SESSION_NAME_RE.fullmatch(session.name):
            raise ValidationError(f"invalid session name: {session.name!r}")