import pytest

from remote_terminal.cli import main, parse_session_id
from remote_terminal.models import BackendCommandError, ExecResult, SessionRef, ValidationError


class FakeRuntime:
    def __init__(self, exec_result=None, error=None):
        self.calls = []
        self.exec_result = exec_result or ExecResult("pwd", 0, "/tmp\n", "marker")
        self.error = error

    def _maybe_raise(self):
        if self.error:
            raise self.error

    def create_session(self, host, name):
        self._maybe_raise()
        self.calls.append(("create_session", host, name))
        return SessionRef(host, name)

    def write(self, session, data):
        self._maybe_raise()
        self.calls.append(("write", session, data))

    def read(self, session, lines=200):
        self._maybe_raise()
        self.calls.append(("read", session, lines))
        return "pane output\n"

    def exec(self, session, command, timeout=30.0, poll_interval=0.25):
        self._maybe_raise()
        self.calls.append(("exec", session, command, timeout, poll_interval))
        return self.exec_result

    def interrupt(self, session):
        self._maybe_raise()
        self.calls.append(("interrupt", session))

    def close(self, session):
        self._maybe_raise()
        self.calls.append(("close", session))


def test_parse_session_id_splits_host_and_name():
    assert parse_session_id("macmini/main") == SessionRef("macmini", "main")


@pytest.mark.parametrize("value", ["macmini", "macmini/", "/main", "a/b/c"])
def test_parse_session_id_rejects_invalid_values(value):
    with pytest.raises(ValidationError):
        parse_session_id(value)


def test_create_command_delegates_to_runtime(capsys):
    runtime = FakeRuntime()

    code = main(["create", "macmini", "main"], runtime=runtime)

    assert code == 0
    assert runtime.calls == [("create_session", "macmini", "main")]
    assert "macmini/main" in capsys.readouterr().out


def test_write_command_delegates_to_runtime():
    runtime = FakeRuntime()

    code = main(["write", "macmini/main", "cd /tmp\n"], runtime=runtime)

    assert code == 0
    assert runtime.calls == [("write", SessionRef("macmini", "main"), "cd /tmp\n")]


def test_read_command_prints_output(capsys):
    runtime = FakeRuntime()

    code = main(["read", "macmini/main", "--lines", "50"], runtime=runtime)

    assert code == 0
    assert runtime.calls == [("read", SessionRef("macmini", "main"), 50)]
    assert capsys.readouterr().out == "pane output\n"


def test_exec_command_prints_output_and_returns_zero_for_success(capsys):
    runtime = FakeRuntime(exec_result=ExecResult("pwd", 0, "/tmp\n", "marker"))

    code = main(["exec", "macmini/main", "pwd", "--timeout", "5"], runtime=runtime)

    assert code == 0
    assert runtime.calls == [("exec", SessionRef("macmini", "main"), "pwd", 5.0, 0.25)]
    assert capsys.readouterr().out == "/tmp\n"


def test_exec_command_returns_process_exit_code_for_command_failure(capsys):
    runtime = FakeRuntime(exec_result=ExecResult("false", 7, "failed\n", "marker"))

    code = main(["exec", "macmini/main", "false"], runtime=runtime)

    assert code == 7
    assert capsys.readouterr().out == "failed\n"


def test_interrupt_command_delegates_to_runtime():
    runtime = FakeRuntime()

    code = main(["interrupt", "macmini/main"], runtime=runtime)

    assert code == 0
    assert runtime.calls == [("interrupt", SessionRef("macmini", "main"))]


def test_close_command_delegates_to_runtime():
    runtime = FakeRuntime()

    code = main(["close", "macmini/main"], runtime=runtime)

    assert code == 0
    assert runtime.calls == [("close", SessionRef("macmini", "main"))]


def test_runtime_errors_print_to_stderr(capsys):
    runtime = FakeRuntime(error=BackendCommandError("connection failed"))

    code = main(["read", "macmini/main"], runtime=runtime)

    assert code == 1
    assert "connection failed" in capsys.readouterr().err