import subprocess

import pytest

from remote_terminal.models import (
    BackendCommandError,
    CommandTimeoutError,
    ExecResult,
    MissingDependencyError,
    SessionRef,
    ValidationError,
)
from remote_terminal.ssh_direct_backend import SshDirectBackend


class FakeRunner:
    def __init__(self, responses=None):
        self.calls = []
        self.responses = list(responses or [])

    def __call__(self, args):
        self.calls.append(args)
        if self.responses:
            response = self.responses.pop(0)
            if isinstance(response, BaseException):
                raise response
            return response
        return subprocess.CompletedProcess(args, 0, "", "")


def completed(args=None, returncode=0, stdout="", stderr=""):
    return subprocess.CompletedProcess(args or [], returncode, stdout, stderr)


@pytest.mark.parametrize("host", ["-bad", "bad\nhost", "\x01host", ""])
def test_create_session_rejects_invalid_host(host):
    runner = FakeRunner()
    backend = SshDirectBackend(command_runner=runner)

    with pytest.raises(ValidationError):
        backend.create_session(host, "main")

    assert runner.calls == []


@pytest.mark.parametrize("name", ["bad/name", "bad name", "bad:name", ""])
def test_create_session_rejects_invalid_name(name):
    runner = FakeRunner()
    backend = SshDirectBackend(command_runner=runner)

    with pytest.raises(ValidationError):
        backend.create_session("macmini", name)

    assert runner.calls == []


def test_create_session_probes_connectivity_and_returns_ssh_backend():
    runner = FakeRunner([completed(stdout="")])
    backend = SshDirectBackend(command_runner=runner)

    session = backend.create_session("vm-ubuntu", "main")

    assert session == SessionRef(host="vm-ubuntu", name="main", backend="ssh")
    assert runner.calls == [["ssh", "vm-ubuntu", "true"]]


def test_create_session_reports_connection_failure():
    runner = FakeRunner([completed(returncode=255, stderr="connection refused")])
    backend = SshDirectBackend(command_runner=runner)

    with pytest.raises(BackendCommandError) as excinfo:
        backend.create_session("vm-ubuntu", "main")

    message = str(excinfo.value)
    assert "create_session" in message
    assert "vm-ubuntu" in message


def test_exec_runs_command_and_returns_result():
    runner = FakeRunner([completed(stdout="/tmp\n", returncode=0)])
    backend = SshDirectBackend(command_runner=runner)

    result = backend.exec(SessionRef("vm-ubuntu", "main", "ssh"), "pwd")

    assert result.command == "pwd"
    assert result.exit_code == 0
    assert result.output == "/tmp\n"
    assert result.marker == ""
    assert runner.calls == [["ssh", "vm-ubuntu", "pwd"]]


def test_exec_returns_nonzero_exit_code():
    runner = FakeRunner([completed(stdout="err\n", returncode=2)])
    backend = SshDirectBackend(command_runner=runner)

    result = backend.exec(SessionRef("vm-ubuntu", "main", "ssh"), "ls /nonexistent")

    assert result.exit_code == 2
    assert result.output == "err\n"


def test_exec_reports_missing_ssh():
    runner = FakeRunner([FileNotFoundError("ssh")])
    backend = SshDirectBackend(command_runner=runner)

    with pytest.raises(MissingDependencyError, match="ssh"):
        backend.exec(SessionRef("vm-ubuntu", "main", "ssh"), "pwd")


def test_exec_rejects_non_positive_timeout():
    runner = FakeRunner()
    backend = SshDirectBackend(command_runner=runner)

    with pytest.raises(ValidationError):
        backend.exec(SessionRef("vm-ubuntu", "main", "ssh"), "pwd", timeout=0)

    assert runner.calls == []


def test_write_is_noop():
    runner = FakeRunner()
    backend = SshDirectBackend(command_runner=runner)

    backend.write(SessionRef("vm-ubuntu", "main", "ssh"), "cd /tmp\n")

    assert runner.calls == []


def test_read_returns_empty_string():
    runner = FakeRunner()
    backend = SshDirectBackend(command_runner=runner)

    output = backend.read(SessionRef("vm-ubuntu", "main", "ssh"))

    assert output == ""
    assert runner.calls == []


def test_interrupt_is_noop():
    runner = FakeRunner()
    backend = SshDirectBackend(command_runner=runner)

    backend.interrupt(SessionRef("vm-ubuntu", "main", "ssh"))

    assert runner.calls == []


def test_close_is_noop():
    runner = FakeRunner()
    backend = SshDirectBackend(command_runner=runner)

    backend.close(SessionRef("vm-ubuntu", "main", "ssh"))

    assert runner.calls == []