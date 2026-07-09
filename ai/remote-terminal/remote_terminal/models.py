from dataclasses import dataclass


@dataclass(frozen=True)
class SessionRef:
    host: str
    name: str
    backend: str = "tmux"

    @property
    def session_id(self) -> str:
        return f"{self.host}/{self.name}"


@dataclass(frozen=True)
class ExecResult:
    command: str
    exit_code: int
    output: str
    marker: str


class RemoteTerminalError(Exception):
    """Base exception for remote-terminal failures."""


class ValidationError(RemoteTerminalError):
    """Raised when user-provided session data is invalid."""


class BackendCommandError(RemoteTerminalError):
    """Raised when a backend command fails."""


class MissingDependencyError(BackendCommandError):
    """Raised when a local or remote dependency is missing."""


class CommandTimeoutError(RemoteTerminalError):
    """Raised when a terminal command does not finish before the timeout."""


class MarkerParseError(RemoteTerminalError):
    """Raised when an exec completion marker cannot be parsed."""