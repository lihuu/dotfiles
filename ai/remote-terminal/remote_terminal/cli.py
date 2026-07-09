from __future__ import annotations

import argparse
import sys

from remote_terminal.models import RemoteTerminalError, SessionRef, ValidationError
from remote_terminal.runtime import RemoteTerminalRuntime


def parse_session_id(value: str) -> SessionRef:
    parts = value.split("/")
    if len(parts) != 2 or not parts[0] or not parts[1]:
        raise ValidationError("session id must use <host>/<name> format")
    return SessionRef(host=parts[0], name=parts[1])


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="remote-terminal")
    subparsers = parser.add_subparsers(dest="command", required=True)

    create_parser = subparsers.add_parser("create")
    create_parser.add_argument("host")
    create_parser.add_argument("name")

    write_parser = subparsers.add_parser("write")
    write_parser.add_argument("session_id")
    write_parser.add_argument("text")

    read_parser = subparsers.add_parser("read")
    read_parser.add_argument("session_id")
    read_parser.add_argument("--lines", type=int, default=200)

    exec_parser = subparsers.add_parser("exec")
    exec_parser.add_argument("session_id")
    exec_parser.add_argument("remote_command")
    exec_parser.add_argument("--timeout", type=float, default=30.0)

    interrupt_parser = subparsers.add_parser("interrupt")
    interrupt_parser.add_argument("session_id")

    close_parser = subparsers.add_parser("close")
    close_parser.add_argument("session_id")

    return parser


def main(
    argv: list[str] | None = None,
    runtime: RemoteTerminalRuntime | None = None,
) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    active_runtime = runtime or RemoteTerminalRuntime()

    try:
        if args.command == "create":
            session = active_runtime.create_session(args.host, args.name)
            print(session.session_id)
            return 0

        session = parse_session_id(args.session_id)

        if args.command == "write":
            active_runtime.write(session, args.text)
            return 0
        if args.command == "read":
            print(active_runtime.read(session, lines=args.lines), end="")
            return 0
        if args.command == "exec":
            result = active_runtime.exec(session, args.remote_command, timeout=args.timeout)
            print(result.output, end="")
            return result.exit_code
        if args.command == "interrupt":
            active_runtime.interrupt(session)
            return 0
        if args.command == "close":
            active_runtime.close(session)
            return 0
    except RemoteTerminalError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    parser.error(f"unsupported command: {args.command}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())