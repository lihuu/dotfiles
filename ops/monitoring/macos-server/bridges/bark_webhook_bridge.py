#!/usr/bin/env python3
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


BARK_SERVER_URL = env("BARK_SERVER_URL", "https://api.day.app").rstrip("/")
BARK_DEVICE_KEY = env("BARK_DEVICE_KEY", "")
BARK_GROUP = env("BARK_GROUP", "Prometheus Alerts")
BARK_SOUND = env("BARK_SOUND", "")
BARK_ICON = env("BARK_ICON", "")
BARK_URL = env("BARK_URL", "")
BARK_LEVEL = env("BARK_LEVEL", "active")
BARK_AUTOMATIC_COPY = env("BARK_AUTOMATIC_COPY", "0")
BARK_IS_ARCHIVE = env("BARK_IS_ARCHIVE", "1")
BARK_BRIDGE_PORT = int(env("BARK_BRIDGE_PORT", "18080"))
BARK_BRIDGE_BIND_ADDRESS = env("BARK_BRIDGE_BIND_ADDRESS", "127.0.0.1")
MONITORED_HOSTNAME = env("MONITORED_HOSTNAME", "macos-monitor")


def build_message(payload: dict) -> tuple[str, str]:
    status = str(payload.get("status", "unknown")).upper()
    common = payload.get("commonLabels") or {}
    alerts = payload.get("alerts") or []
    alertname = common.get("alertname", "PrometheusAlert")
    title = f"[{MONITORED_HOSTNAME}] {status} {alertname}"

    lines = []
    for alert in alerts[:5]:
        labels = alert.get("labels") or {}
        annotations = alert.get("annotations") or {}
        instance = labels.get("instance", "unknown")
        severity = labels.get("severity", "unknown")
        summary = annotations.get("summary", alertname)
        description = annotations.get("description", "")
        lines.append(f"- {instance} [{severity}] {summary}")
        if description:
            lines.append(f"  {description}")

    extra = len(alerts) - 5
    if extra > 0:
      lines.append(f"... and {extra} more alerts")

    if not lines:
        lines.append("Alertmanager webhook received an empty alert set.")

    return title, "\n".join(lines)


def push_to_bark(title: str, body: str) -> tuple[int, str]:
    if not BARK_DEVICE_KEY:
        return 202, "BARK_DEVICE_KEY is empty; skip push"

    request_body = {
        "device_key": BARK_DEVICE_KEY,
        "title": title,
        "body": body,
        "group": BARK_GROUP,
        "level": BARK_LEVEL,
        "automaticallyCopy": BARK_AUTOMATIC_COPY,
        "isArchive": BARK_IS_ARCHIVE,
    }
    if BARK_SOUND:
        request_body["sound"] = BARK_SOUND
    if BARK_ICON:
        request_body["icon"] = BARK_ICON
    if BARK_URL:
        request_body["url"] = BARK_URL

    data = json.dumps(request_body).encode("utf-8")
    request = Request(
        f"{BARK_SERVER_URL}/push",
        data=data,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "curl/8.7.1",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=10) as response:
            return response.getcode(), response.read().decode("utf-8", errors="replace")
    except HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")
    except URLError as exc:
        return 502, str(exc)


class Handler(BaseHTTPRequestHandler):
    def _write(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/healthz":
            self._write(200, {"status": "ok", "configured": bool(BARK_DEVICE_KEY)})
            return
        self._write(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/alertmanager":
            self._write(404, {"error": "not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError as exc:
            self._write(400, {"error": f"invalid json: {exc}"})
            return

        title, body = build_message(payload)
        status_code, bark_response = push_to_bark(title, body)
        self._write(status_code if status_code < 600 else 500, {"title": title, "result": bark_response})

    def log_message(self, fmt: str, *args) -> None:
        sys.stdout.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), fmt % args))
        sys.stdout.flush()


def main() -> None:
    server = ThreadingHTTPServer((BARK_BRIDGE_BIND_ADDRESS, BARK_BRIDGE_PORT), Handler)
    print(
        f"Bark bridge listening on http://{BARK_BRIDGE_BIND_ADDRESS}:{BARK_BRIDGE_PORT} "
        f"(configured={bool(BARK_DEVICE_KEY)})",
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
