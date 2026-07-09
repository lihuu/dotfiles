from remote_terminal.models import ExecResult, SessionRef
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