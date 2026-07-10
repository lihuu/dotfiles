from remote_terminal.models import ExecResult, MissingDependencyError, SessionRef
from remote_terminal.runtime import RemoteTerminalRuntime


class FakeBackend:
    def __init__(self):
        self.calls = []

    def create_session(self, host, name):
        self.calls.append(("create_session", host, name))
        return SessionRef(host, name)

    def write(self, session, data):
        self.calls.append(("write", session, data))

    def read(self, session, lines=200):
        self.calls.append(("read", session, lines))
        return "pane output"

    def exec(self, session, command, timeout=30.0, poll_interval=0.25):
        self.calls.append(("exec", session, command, timeout, poll_interval))
        return ExecResult(command, 0, "output", "__REMOTE_TERMINAL_DONE:test:")

    def interrupt(self, session):
        self.calls.append(("interrupt", session))

    def close(self, session):
        self.calls.append(("close", session))


class FakeTmuxBackend(FakeBackend):
    """Tmux backend that always reports missing tmux."""

    def create_session(self, host, name):
        raise MissingDependencyError(f"remote host {host!r} needs tmux installed")


class FakeSshBackend(FakeBackend):
    """Ssh-direct backend that succeeds on create."""

    def create_session(self, host, name):
        self.calls.append(("create_session", host, name))
        return SessionRef(host, name, backend="ssh")


def test_runtime_delegates_all_operations_to_backend():
    backend = FakeBackend()
    runtime = RemoteTerminalRuntime(backend=backend)

    session = runtime.create_session("macmini", "main")
    runtime.write(session, "pwd\n")
    assert runtime.read(session, lines=20) == "pane output"
    result = runtime.exec(session, "pwd", timeout=1.0, poll_interval=0.1)
    runtime.interrupt(session)
    runtime.close(session)

    assert result.exit_code == 0
    assert backend.calls == [
        ("create_session", "macmini", "main"),
        ("write", session, "pwd\n"),
        ("read", session, 20),
        ("exec", session, "pwd", 1.0, 0.1),
        ("interrupt", session),
        ("close", session),
    ]


def test_runtime_falls_back_to_ssh_when_tmux_missing():
    ssh_backend = FakeSshBackend()
    runtime = RemoteTerminalRuntime(
        backend=None,  # force auto-fallback path
    )
    # Inject our fake backends so we control the behavior
    runtime._tmux_backend = FakeTmuxBackend()
    runtime._ssh_backend = ssh_backend

    session = runtime.create_session("banwagong", "main")

    assert session.backend == "ssh"
    result = runtime.exec(session, "uname -a")
    assert result.exit_code == 0
    # Verify exec was routed to the ssh backend
    assert ("exec", session, "uname -a", 30.0, 0.25) in ssh_backend.calls


def test_runtime_uses_tmux_when_available():
    tmux_backend = FakeBackend()
    runtime = RemoteTerminalRuntime(backend=None)
    runtime._tmux_backend = tmux_backend
    runtime._ssh_backend = FakeSshBackend()

    session = runtime.create_session("vm-ubuntu", "main")

    assert session.backend == "tmux"
    assert ("create_session", "vm-ubuntu", "main") in tmux_backend.calls


def test_runtime_explicit_backend_does_not_fallback():
    explicit = FakeBackend()
    runtime = RemoteTerminalRuntime(backend=explicit)
    runtime._tmux_backend = FakeTmuxBackend()  # would raise if used

    session = runtime.create_session("vm-ubuntu", "main")

    assert session.backend == "tmux"
    assert ("create_session", "vm-ubuntu", "main") in explicit.calls