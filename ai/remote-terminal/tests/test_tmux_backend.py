import subprocess

import pytest

from remote_terminal.models import (
    BackendCommandError,
    CommandTimeoutError,
    MarkerParseError,
    MissingDependencyError,
    SessionRef,
    ValidationError,
)
from remote_terminal.tmux_backend import TmuxBackend


class FakeRunner:
    def __init__(self, responses=None):
        self.calls = []
        self.responses = list(responses or [])

    def __call__(self, args, **kwargs):
        self.calls.append(args)
        if self.responses:
            response = self.responses.pop(0)
            if isinstance(response, BaseException):
                raise response
            return response
        return subprocess.CompletedProcess(args, 0, "", "")


class FakeClock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


def completed(args=None, returncode=0, stdout="", stderr=""):
    return subprocess.CompletedProcess(args or [], returncode, stdout, stderr)


@pytest.mark.parametrize("host", ["-bad", "bad\nhost", "bad\rhost", "\x01host", "host\x07", "\thost", "host\x1b", ""])
def test_rejects_invalid_host_before_ssh(host):
    runner = FakeRunner()
    backend = TmuxBackend(command_runner=runner)

    with pytest.raises(ValidationError):
        backend.create_session(host, "main")

    assert runner.calls == []


@pytest.mark.parametrize("name", ["bad/name", "bad name", "bad:name", ""])
def test_rejects_invalid_session_name_before_ssh(name):
    runner = FakeRunner()
    backend = TmuxBackend(command_runner=runner)

    with pytest.raises(ValidationError):
        backend.create_session("macmini", name)

    assert runner.calls == []


def test_create_session_attaches_when_session_exists():
    runner = FakeRunner([completed(stdout="")])
    backend = TmuxBackend(command_runner=runner)

    session = backend.create_session("macmini", "main")

    assert session == SessionRef(host="macmini", name="main")
    assert runner.calls == [["ssh", "macmini", "tmux has-session -t main"]]


def test_create_session_creates_missing_session():
    runner = FakeRunner(
        [
            completed(returncode=1, stderr="can't find session"),
            completed(stdout=""),
        ]
    )
    backend = TmuxBackend(command_runner=runner)

    session = backend.create_session("macmini", "main")

    assert session == SessionRef(host="macmini", name="main")
    assert runner.calls == [
        ["ssh", "macmini", "tmux has-session -t main"],
        ["ssh", "macmini", "tmux new-session -d -s main /bin/sh"],
    ]


def test_create_session_uses_custom_tmux_path_and_shell():
    runner = FakeRunner(
        [
            completed(returncode=1, stderr="can't find session"),
            completed(stdout=""),
        ]
    )
    backend = TmuxBackend(
        command_runner=runner,
        remote_tmux="/opt/homebrew/bin/tmux",
        remote_shell="/bin/zsh -f",
    )

    session = backend.create_session("macmini", "main")

    assert session == SessionRef(host="macmini", name="main")
    assert runner.calls == [
        [
            "ssh",
            "macmini",
            "PATH=/opt/homebrew/bin:$PATH /opt/homebrew/bin/tmux has-session -t main",
        ],
        [
            "ssh",
            "macmini",
            "PATH=/opt/homebrew/bin:$PATH /opt/homebrew/bin/tmux new-session -d -s main '/bin/zsh -f'",
        ],
    ]


def test_create_session_reports_missing_remote_tmux():
    runner = FakeRunner([completed(returncode=127, stderr="tmux: not found")])
    backend = TmuxBackend(command_runner=runner)

    with pytest.raises(MissingDependencyError, match="tmux"):
        backend.create_session("macmini", "main")


def test_write_sends_literal_chunks_and_enter_events():
    runner = FakeRunner()
    backend = TmuxBackend(command_runner=runner)

    backend.write(SessionRef("macmini", "main"), "cd /tmp\npwd\n")

    assert runner.calls == [
        ["ssh", "macmini", "tmux send-keys -t main -l -- 'cd /tmp'"],
        ["ssh", "macmini", "tmux send-keys -t main Enter"],
        ["ssh", "macmini", "tmux send-keys -t main -l -- pwd"],
        ["ssh", "macmini", "tmux send-keys -t main Enter"],
    ]


def test_read_captures_requested_line_count():
    runner = FakeRunner([completed(stdout="pane text\n")])
    backend = TmuxBackend(command_runner=runner)

    output = backend.read(SessionRef("macmini", "main"), lines=50)

    assert output == "pane text\n"
    assert runner.calls == [
        ["ssh", "macmini", "tmux capture-pane -t main -p -S -50"]
    ]


def test_exec_sends_marker_polls_and_parses_exit_code():
    runner = FakeRunner(
        [
            completed(),  # send-keys -l (start marker printf)
            completed(),  # send-keys Enter
            completed(),  # send-keys -l (pwd)
            completed(),  # send-keys Enter
            completed(),  # send-keys -l (end marker printf)
            completed(),  # send-keys Enter
            completed(stdout="waiting\n"),
            completed(
                stdout=(
                    "sh-3.2$ printf '__REMOTE_TERMINAL_START:nonce-1\\n'\n"
                    "__REMOTE_TERMINAL_START:nonce-1\n"
                    "sh-3.2$ pwd\n/tmp\n"
                    "sh-3.2$ printf '\\n__REMOTE_TERMINAL_DONE:nonce-1:%s\\n' \"$?\"\n"
                    "\n__REMOTE_TERMINAL_DONE:nonce-1:0\n"
                )
            ),
        ]
    )
    clock = FakeClock()
    backend = TmuxBackend(
        command_runner=runner,
        nonce_factory=lambda: "nonce-1",
        sleeper=clock.sleep,
        clock=clock,
    )

    result = backend.exec(
        SessionRef("macmini", "main"),
        "pwd",
        timeout=5.0,
        poll_interval=0.5,
    )

    assert result.command == "pwd"
    assert result.exit_code == 0
    assert result.marker == "__REMOTE_TERMINAL_DONE:nonce-1:"
    assert "/tmp" in result.output
    # Output must NOT contain the start marker printf echo or output
    assert "__REMOTE_TERMINAL_START" not in result.output
    assert runner.calls == [
        [
            "ssh",
            "macmini",
            "tmux send-keys -t main -l -- 'printf '\"'\"'__REMOTE_TERMINAL_START:nonce-1\\n'\"'\"''",
        ],
        ["ssh", "macmini", "tmux send-keys -t main Enter"],
        ["ssh", "macmini", "tmux send-keys -t main -l -- pwd"],
        ["ssh", "macmini", "tmux send-keys -t main Enter"],
        [
            "ssh",
            "macmini",
            "tmux send-keys -t main -l -- 'printf '\"'\"'\\n__REMOTE_TERMINAL_DONE:nonce-1:%s\\n'\"'\"' \"$?\"'",
        ],
        ["ssh", "macmini", "tmux send-keys -t main Enter"],
        ["ssh", "macmini", "tmux capture-pane -t main -p -S -200"],
        ["ssh", "macmini", "tmux capture-pane -t main -p -S -200"],
    ]


def test_exec_raises_timeout_with_latest_output():
    runner = FakeRunner(
        [
            completed(),  # send-keys -l (start marker printf)
            completed(),  # send-keys Enter
            completed(),  # send-keys -l (command)
            completed(),  # send-keys Enter
            completed(),  # send-keys -l (end marker printf)
            completed(),  # send-keys Enter
            completed(stdout="still running\n"),
            completed(stdout="latest output\n"),
            completed(stdout="latest output\n"),
            completed(stdout="latest output\n"),
        ]
    )
    clock = FakeClock()
    backend = TmuxBackend(
        command_runner=runner,
        nonce_factory=lambda: "nonce-timeout",
        sleeper=clock.sleep,
        clock=clock,
    )

    with pytest.raises(CommandTimeoutError) as excinfo:
        backend.exec(
            SessionRef("macmini", "main"),
            "sleep 10",
            timeout=1.0,
            poll_interval=0.5,
        )

    message = str(excinfo.value)
    assert "__REMOTE_TERMINAL_DONE:nonce-timeout:" in message
    assert "latest output" in message


def test_exec_raises_marker_parse_error_for_bad_exit_code():
    runner = FakeRunner(
        [
            completed(),  # send-keys -l (start marker printf)
            completed(),  # send-keys Enter
            completed(),  # send-keys -l (command)
            completed(),  # send-keys Enter
            completed(),  # send-keys -l (end marker printf)
            completed(),  # send-keys Enter
            completed(stdout="__REMOTE_TERMINAL_DONE:nonce-bad:not-an-int\n"),
        ]
    )
    backend = TmuxBackend(command_runner=runner, nonce_factory=lambda: "nonce-bad")

    with pytest.raises(MarkerParseError):
        backend.exec(SessionRef("macmini", "main"), "pwd")


def test_interrupt_sends_ctrl_c():
    runner = FakeRunner()
    backend = TmuxBackend(command_runner=runner)

    backend.interrupt(SessionRef("macmini", "main"))

    assert runner.calls == [["ssh", "macmini", "tmux send-keys -t main C-c"]]


def test_close_kills_only_named_session():
    runner = FakeRunner()
    backend = TmuxBackend(command_runner=runner)

    backend.close(SessionRef("macmini", "main"))

    assert runner.calls == [["ssh", "macmini", "tmux kill-session -t main"]]


def test_ssh_file_not_found_reports_missing_local_ssh():
    runner = FakeRunner([FileNotFoundError("ssh")])
    backend = TmuxBackend(command_runner=runner)

    with pytest.raises(MissingDependencyError, match="ssh"):
        backend.read(SessionRef("macmini", "main"))


def test_nonzero_backend_command_includes_context():
    runner = FakeRunner([completed(returncode=255, stderr="connection failed")])
    backend = TmuxBackend(command_runner=runner)

    with pytest.raises(BackendCommandError) as excinfo:
        backend.read(SessionRef("macmini", "main"))

    message = str(excinfo.value)
    assert "read" in message
    assert "macmini" in message
    assert "main" in message
    assert "255" in message
    assert "connection failed" in message


def test_read_rejects_non_positive_lines():
    runner = FakeRunner()
    backend = TmuxBackend(command_runner=runner)

    with pytest.raises(ValidationError):
        backend.read(SessionRef("macmini", "main"), lines=0)

    assert runner.calls == []


def test_exec_rejects_non_positive_timeout():
    runner = FakeRunner()
    backend = TmuxBackend(command_runner=runner)

    with pytest.raises(ValidationError):
        backend.exec(SessionRef("macmini", "main"), "pwd", timeout=0)

    assert runner.calls == []


def test_exec_rejects_non_positive_poll_interval():
    runner = FakeRunner()
    backend = TmuxBackend(command_runner=runner)

    with pytest.raises(ValidationError):
        backend.exec(SessionRef("macmini", "main"), "pwd", poll_interval=0)

    assert runner.calls == []


def test_exec_skips_literal_marker_text_and_parses_real_marker():
    # When send-keys -l sends the marker command lines to the pane, the
    # literal text "__REMOTE_TERMINAL_DONE:<nonce>:%s\n' \"$?\"" appears
    # in the pane before printf executes. _parse_marker must skip that
    # occurrence and find the real marker line with an integer exit code.
    runner = FakeRunner(
        [
            completed(),  # send-keys -l (start marker printf)
            completed(),  # send-keys Enter
            completed(),  # send-keys -l (pwd)
            completed(),  # send-keys Enter
            completed(),  # send-keys -l (end marker printf)
            completed(),  # send-keys Enter
            # First poll: literal marker command text visible, no real
            # marker output yet — must NOT raise MarkerParseError.
            completed(
                stdout=(
                    "sh-3.2$ printf '__REMOTE_TERMINAL_START:nonce-skip\\n'\n"
                    "__REMOTE_TERMINAL_START:nonce-skip\n"
                    "$ pwd\n"
                    "$ printf '\\n__REMOTE_TERMINAL_DONE:nonce-skip:%s\\n' \"$?\"\n"
                )
            ),
            # Second poll: real marker line now present.
            completed(
                stdout=(
                    "sh-3.2$ printf '__REMOTE_TERMINAL_START:nonce-skip\\n'\n"
                    "__REMOTE_TERMINAL_START:nonce-skip\n"
                    "$ pwd\n/tmp\n"
                    "$ printf '\\n__REMOTE_TERMINAL_DONE:nonce-skip:%s\\n' \"$?\"\n"
                    "\n__REMOTE_TERMINAL_DONE:nonce-skip:0\n"
                )
            ),
        ]
    )
    clock = FakeClock()
    backend = TmuxBackend(
        command_runner=runner,
        nonce_factory=lambda: "nonce-skip",
        sleeper=clock.sleep,
        clock=clock,
    )

    result = backend.exec(
        SessionRef("macmini", "main"),
        "pwd",
        timeout=5.0,
        poll_interval=0.5,
    )

    assert result.exit_code == 0
    assert result.marker == "__REMOTE_TERMINAL_DONE:nonce-skip:"
    assert "/tmp" in result.output
    # Output is between start and end markers — no start marker text
    assert "__REMOTE_TERMINAL_START" not in result.output


def test_parse_marker_returns_none_when_only_literal_text_present():
    # Unit-level: when the pane contains only the echoed marker command
    # (no real marker output yet), _parse_marker must return None so the
    # poll loop continues, rather than raising MarkerParseError.
    from remote_terminal.tmux_backend import TmuxBackend

    end_marker = "__REMOTE_TERMINAL_DONE:nonce-x:"
    start_marker = "__REMOTE_TERMINAL_START:nonce-x"
    pane_with_literal_only = (
        "$ printf '\\n__REMOTE_TERMINAL_DONE:nonce-x:%s\\n' \"$?\"\n"
    )
    assert TmuxBackend._parse_marker(pane_with_literal_only, end_marker, start_marker) is None


def test_exec_excludes_previous_history():
    # The start marker ensures exec returns only the current command's
    # output, not accumulated history from previous exec calls.
    runner = FakeRunner(
        [
            completed(),  # send-keys -l (start marker printf)
            completed(),  # send-keys Enter
            completed(),  # send-keys -l (echo BBB)
            completed(),  # send-keys Enter
            completed(),  # send-keys -l (end marker printf)
            completed(),  # send-keys Enter
            # Pane contains history from a previous exec (echo AAA) plus
            # the current exec (echo BBB).
            completed(
                stdout=(
                    "sh-3.2$ printf '__REMOTE_TERMINAL_START:old-nonce\\n'\n"
                    "__REMOTE_TERMINAL_START:old-nonce\n"
                    "sh-3.2$ echo AAA\nAAA\n"
                    "sh-3.2$ printf '\\n__REMOTE_TERMINAL_DONE:old-nonce:%s\\n' \"$?\"\n"
                    "\n__REMOTE_TERMINAL_DONE:old-nonce:0\n"
                    "sh-3.2$ printf '__REMOTE_TERMINAL_START:nonce-2\\n'\n"
                    "__REMOTE_TERMINAL_START:nonce-2\n"
                    "sh-3.2$ echo BBB\nBBB\n"
                    "sh-3.2$ printf '\\n__REMOTE_TERMINAL_DONE:nonce-2:%s\\n' \"$?\"\n"
                    "\n__REMOTE_TERMINAL_DONE:nonce-2:0\n"
                )
            ),
        ]
    )
    backend = TmuxBackend(
        command_runner=runner,
        nonce_factory=lambda: "nonce-2",
    )

    result = backend.exec(SessionRef("macmini", "main"), "echo BBB")

    assert result.exit_code == 0
    assert "BBB" in result.output
    # Previous command's output must NOT appear
    assert "AAA" not in result.output
    assert "old-nonce" not in result.output
    assert "__REMOTE_TERMINAL_START" not in result.output


def test_create_session_quotes_tmux_path_with_spaces():
    runner = FakeRunner(
        [
            completed(returncode=1, stderr="can't find session"),
            completed(stdout=""),
        ]
    )
    backend = TmuxBackend(
        command_runner=runner,
        remote_tmux="/opt/my tools/tmux",
    )

    session = backend.create_session("macmini", "main")

    assert session == SessionRef(host="macmini", name="main")
    # The PATH prefix must quote the directory to handle spaces
    assert runner.calls == [
        [
            "ssh",
            "macmini",
            "PATH='/opt/my tools':$PATH '/opt/my tools/tmux' has-session -t main",
        ],
        [
            "ssh",
            "macmini",
            "PATH='/opt/my tools':$PATH '/opt/my tools/tmux' new-session -d -s main /bin/sh",
        ],
    ]