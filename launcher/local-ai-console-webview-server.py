#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import threading
import time
import tomllib
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


def clean_string(value: Any, default: str = "") -> str:
    if not isinstance(value, str):
        return default
    value = value.strip()
    return value or default


def clean_mode(value: Any, default: str = "local") -> str:
    value = clean_string(value, default)
    return value if value in {"local", "remote"} else default


def read_config(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    with path.open("rb") as handle:
        return tomllib.load(handle)


def toml_literal(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    return json.dumps("" if value is None else str(value))


def set_top_level_key(path: Path, key: str, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = path.read_text().splitlines() if path.exists() else []
    pattern = re.compile(rf"^\s*{re.escape(key)}\s*=")
    replacement = f"{key} = {toml_literal(value)}"

    for index, line in enumerate(lines):
        if pattern.match(line):
            lines[index] = replacement
            break
    else:
        if lines and lines[-1].strip():
            lines.append("")
        lines.append(replacement)

    path.write_text("\n".join(lines).rstrip() + "\n")


def build_state(config_path: Path, active_mode: str) -> dict[str, Any]:
    config = read_config(config_path)
    remote_url = clean_string(config.get("local_llm_console_remote_url"), "")
    return {
        "currentMode": clean_mode(
            active_mode or config.get("local_llm_console_mode"),
            "local",
        ),
        "hasRemoteSettings": remote_url != "",
        "remoteUrl": remote_url,
        "remoteTransport": clean_string(
            config.get("local_llm_console_remote_transport"),
            "tailscale",
        ),
    }


def relaunch_app(command: str) -> None:
    if not command.strip():
        raise RuntimeError("No relaunch command is configured for Local LLM Console.")
    subprocess.Popen(
        shlex.split(command),
        start_new_session=True,
        close_fds=True,
        env=os.environ.copy(),
    )


def schedule_current_app_exit(pid_file: Path) -> None:
    if not pid_file.is_file():
        return
    try:
        app_pid = int(pid_file.read_text().strip())
    except ValueError:
        return

    def terminate_later() -> None:
        time.sleep(0.35)
        try:
            os.kill(app_pid, 15)
        except OSError:
            return

    threading.Thread(target=terminate_later, daemon=True).start()


def make_handler(
    directory: str,
    *,
    config_path: Path,
    pid_file: Path,
    relaunch_command: str,
    active_mode: str,
    host_service_helper: Path,
):
    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=directory, **kwargs)

        def log_message(self, fmt: str, *args: Any) -> None:
            print(
                f"[local-ai-console-webview] {self.address_string()} - {fmt % args}",
                flush=True,
            )

        def send_json(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
            body = json.dumps(payload).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def read_json_body(self) -> dict[str, Any]:
            content_length = int(self.headers.get("Content-Length", "0"))
            if content_length <= 0:
                return {}
            raw_body = self.rfile.read(content_length)
            if not raw_body:
                return {}
            try:
                return json.loads(raw_body.decode("utf-8"))
            except json.JSONDecodeError as exc:
                raise ValueError("Invalid JSON request body.") from exc

        def do_GET(self) -> None:
            if self.path.rstrip("/") == "/__local-llm-console/state":
                self.send_json(
                    HTTPStatus.OK,
                    build_state(
                        config_path,
                        os.environ.get("LOCAL_LLM_CONSOLE_ACTIVE_MODE", active_mode),
                    ),
                )
                return
            super().do_GET()

        def do_POST(self) -> None:
            route = self.path.rstrip("/")
            try:
                payload = self.read_json_body()
            except ValueError as exc:
                self.send_json(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
                return

            if route == "/__local-llm-console/session-mode":
                mode = clean_mode(payload.get("mode"), "")
                if mode not in {"local", "remote"}:
                    self.send_json(
                        HTTPStatus.BAD_REQUEST,
                        {"error": "A valid session mode is required."},
                    )
                    return

                state = build_state(config_path, active_mode)
                if mode == "remote" and not state["hasRemoteSettings"]:
                    self.send_json(
                        HTTPStatus.BAD_REQUEST,
                        {"error": "Configure a remote host URL before connecting."},
                    )
                    return

                try:
                    set_top_level_key(config_path, "local_llm_console_mode", mode)
                    relaunch_app(relaunch_command)
                    schedule_current_app_exit(pid_file)
                except Exception as exc:  # noqa: BLE001
                    self.send_json(
                        HTTPStatus.INTERNAL_SERVER_ERROR,
                        {"error": str(exc)},
                    )
                    return

                self.send_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "currentMode": mode,
                        "hasRemoteSettings": state["hasRemoteSettings"],
                        "remoteUrl": state["remoteUrl"],
                        "relaunching": True,
                    },
                )
                return

            if route == "/__local-llm-console/host-service":
                action = clean_string(payload.get("action"), "reload")
                if action not in {"start", "stop", "reload"}:
                    self.send_json(
                        HTTPStatus.BAD_REQUEST,
                        {"error": "A valid host-service action is required."},
                    )
                    return

                if not host_service_helper.is_file():
                    self.send_json(
                        HTTPStatus.INTERNAL_SERVER_ERROR,
                        {"error": "Local host-service helper is unavailable."},
                    )
                    return

                try:
                    result = subprocess.run(
                        [str(host_service_helper), action],
                        capture_output=True,
                        text=True,
                        timeout=20,
                        check=False,
                        env=os.environ.copy(),
                    )
                except Exception as exc:  # noqa: BLE001
                    self.send_json(
                        HTTPStatus.INTERNAL_SERVER_ERROR,
                        {"error": str(exc)},
                    )
                    return

                if result.returncode != 0:
                    message = (
                        result.stderr.strip()
                        or result.stdout.strip()
                        or "Unable to apply host settings."
                    )
                    self.send_json(
                        HTTPStatus.INTERNAL_SERVER_ERROR,
                        {"error": message},
                    )
                    return

                self.send_json(
                    HTTPStatus.OK,
                    {"ok": True, "action": action},
                )
                return

            self.send_error(HTTPStatus.NOT_FOUND, "Not found")

    return Handler


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5175)
    args = parser.parse_args()

    config_path = Path(
        os.environ.get("LOCAL_LLM_CONSOLE_CONFIG_PATH", "")
    ).expanduser()
    pid_file = Path(
        os.environ.get("LOCAL_LLM_CONSOLE_APP_PID_FILE", "")
    ).expanduser()
    relaunch_command = os.environ.get("LOCAL_LLM_CONSOLE_RELAUNCH_COMMAND", "")
    host_service_helper = Path(
        os.environ.get("LOCAL_LLM_CONSOLE_HOST_SERVICE_HELPER", "")
    ).expanduser()
    if not str(host_service_helper):
        host_service_helper = Path(__file__).with_name("local-ai-console-host-service")
    active_mode = clean_mode(
        os.environ.get("LOCAL_LLM_CONSOLE_ACTIVE_MODE", "local"),
        "local",
    )

    handler = make_handler(
        args.directory,
        config_path=config_path,
        pid_file=pid_file,
        relaunch_command=relaunch_command,
        active_mode=active_mode,
        host_service_helper=host_service_helper,
    )
    server = ThreadingHTTPServer((args.host, args.port), handler)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
