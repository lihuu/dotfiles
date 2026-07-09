import pytest

from remote_terminal import (
    BackendCommandError,
    CommandTimeoutError,
    ExecResult,
    MarkerParseError,
    MissingDependencyError,
    RemoteTerminalError,
    SessionRef,
    ValidationError,
)


def test_session_ref_formats_session_id():
    session = SessionRef(host="macmini", name="main")

    assert session.session_id == "macmini/main"
    assert session.backend == "tmux"


def test_exec_result_stores_command_result_fields():
    result = ExecResult(
        command="pwd",
        exit_code=0,
        output="/tmp\n",
        marker="__REMOTE_TERMINAL_DONE:abc:0",
    )

    assert result.command == "pwd"
    assert result.exit_code == 0
    assert result.output == "/tmp\n"
    assert result.marker == "__REMOTE_TERMINAL_DONE:abc:0"


@pytest.mark.parametrize(
    "error_type",
    [
        ValidationError,
        BackendCommandError,
        MissingDependencyError,
        CommandTimeoutError,
        MarkerParseError,
    ],
)
def test_specific_errors_share_base_type(error_type):
    assert issubclass(error_type, RemoteTerminalError)