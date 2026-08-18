"""Disposable, fail-closed URL broker prototype for the sandbox experiment."""

from __future__ import annotations

import argparse
import hmac
import json
import os
import secrets
import stat
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


MAX_BODY_BYTES = 16 * 1024
MAX_URL_BYTES = 8 * 1024


def safe_url(value: object) -> str:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError("URL must be a non-empty string without surrounding whitespace")
    if len(value.encode("utf-8")) > MAX_URL_BYTES:
        raise ValueError("URL is too long")
    if any(ord(character) < 0x20 or ord(character) == 0x7F for character in value):
        raise ValueError("URL contains a control character")

    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme.lower() not in {"http", "https"}:
        raise ValueError("URL scheme must be http or https")
    if not parsed.netloc or not parsed.hostname:
        raise ValueError("URL must have a host")
    if parsed.username is not None or parsed.password is not None:
        raise ValueError("URL user information is not allowed")
    try:
        parsed.port
    except ValueError as error:
        raise ValueError("URL has an invalid port") from error
    return value


def read_token(path: Path) -> str:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise ValueError("token path is not a regular file")
        if metadata.st_uid != os.getuid():
            raise ValueError("token file must be owned by the current user")
        if stat.S_IMODE(metadata.st_mode) & 0o077:
            raise ValueError("token file permissions must not grant group or other access")
        with os.fdopen(descriptor, "r", encoding="utf-8") as input_file:
            descriptor = -1
            token = input_file.read().strip()
    finally:
        if descriptor >= 0:
            os.close(descriptor)
    if len(token) < 32:
        raise ValueError("token must contain at least 32 characters")
    return token


def create_token(path: Path) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        os.write(descriptor, f"{secrets.token_hex(32)}\n".encode())
    finally:
        os.close(descriptor)


class BrokerServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(
        self,
        address: tuple[str, int],
        workspace: str,
        profile: str,
        token: str,
        cmux: str,
    ) -> None:
        super().__init__(address, BrokerHandler)
        self.bound_workspace = workspace
        self.bound_profile = profile
        self.bearer_token = token
        self.cmux = cmux


class BrokerHandler(BaseHTTPRequestHandler):
    server: BrokerServer

    def log_message(self, format: str, *args: object) -> None:
        return

    def _reply(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
        encoded = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(encoded)

    def do_POST(self) -> None:
        if self.path != "/open":
            self._reply(HTTPStatus.NOT_FOUND, {"opened": False, "error": "not found"})
            return

        raw_length = self.headers.get("Content-Length")
        try:
            length = int(raw_length or "")
        except ValueError:
            length = -1
        if length < 0 or length > MAX_BODY_BYTES:
            self._reply(
                HTTPStatus.REQUEST_ENTITY_TOO_LARGE,
                {"opened": False, "error": "invalid request size"},
            )
            return

        raw_body = self.rfile.read(length)
        try:
            request = json.loads(raw_body)
        except (UnicodeDecodeError, json.JSONDecodeError):
            self._reply(HTTPStatus.BAD_REQUEST, {"opened": False, "error": "invalid JSON"})
            return
        if not isinstance(request, dict):
            self._reply(HTTPStatus.BAD_REQUEST, {"opened": False, "error": "invalid request"})
            return

        candidate_url = request.get("url") if isinstance(request.get("url"), str) else None
        failure_url = candidate_url or ""
        authorization = self.headers.get("Authorization", "")
        expected = f"Bearer {self.server.bearer_token}"
        if not hmac.compare_digest(authorization, expected):
            self._reply(
                HTTPStatus.UNAUTHORIZED,
                {"opened": False, "url": failure_url, "error": "authentication failed"},
            )
            return

        if request.get("workspace") != self.server.bound_workspace:
            self._reply(
                HTTPStatus.FORBIDDEN,
                {"opened": False, "url": failure_url, "error": "workspace mismatch"},
            )
            return
        if request.get("profile") != self.server.bound_profile:
            self._reply(
                HTTPStatus.FORBIDDEN,
                {"opened": False, "url": failure_url, "error": "profile mismatch"},
            )
            return
        try:
            url = safe_url(candidate_url)
        except ValueError as error:
            self._reply(
                HTTPStatus.BAD_REQUEST,
                {"opened": False, "url": failure_url, "error": str(error)},
            )
            return

        command = [
            self.server.cmux,
            "new-pane",
            "--type",
            "browser",
            "--workspace",
            self.server.bound_workspace,
            "--url",
            url,
            "--profile",
            self.server.bound_profile,
            "--focus",
            "false",
        ]
        try:
            result = subprocess.run(
                command,
                check=False,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=10,
                env={"PATH": os.defpath},
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            self._reply(
                HTTPStatus.BAD_GATEWAY,
                {"opened": False, "url": url, "error": f"cmux unavailable: {type(error).__name__}"},
            )
            return
        if result.returncode != 0:
            self._reply(
                HTTPStatus.BAD_GATEWAY,
                {"opened": False, "url": url, "error": "cmux rejected request"},
            )
            return
        self._reply(HTTPStatus.OK, {"opened": True, "url": url})


def run_server(arguments: argparse.Namespace) -> int:
    token = read_token(Path(arguments.token_file))
    server = BrokerServer(
        (arguments.listen, arguments.port),
        arguments.workspace,
        arguments.profile,
        token,
        arguments.cmux,
    )
    if arguments.ready_file:
        ready_file = Path(arguments.ready_file)
        descriptor = os.open(ready_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            json.dump({"host": server.server_address[0], "port": server.server_address[1]}, output)
            output.write("\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


def request_open(arguments: argparse.Namespace) -> int:
    url = arguments.url
    try:
        safe_url(url)
        token = read_token(Path(arguments.token_file))
        payload = json.dumps(
            {"workspace": arguments.workspace, "profile": arguments.profile, "url": url}
        ).encode()
        request = urllib.request.Request(
            f"{arguments.endpoint.rstrip('/')}/open",
            data=payload,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=5) as response:
            body = json.load(response)
        if body.get("opened") is True:
            return 0
    except (OSError, ValueError, urllib.error.URLError, json.JSONDecodeError):
        pass
    print(url)
    return 1


def parser() -> argparse.ArgumentParser:
    top = argparse.ArgumentParser()
    commands = top.add_subparsers(dest="command", required=True)

    token = commands.add_parser("create-token")
    token.add_argument("token_file")

    serve = commands.add_parser("serve")
    serve.add_argument("--workspace", required=True)
    serve.add_argument("--profile", required=True)
    serve.add_argument("--token-file", required=True)
    serve.add_argument("--cmux", required=True)
    serve.add_argument("--listen", default="127.0.0.1", choices=["127.0.0.1"])
    serve.add_argument("--port", type=int, default=0)
    serve.add_argument("--ready-file")

    request = commands.add_parser("request")
    request.add_argument("--endpoint", required=True)
    request.add_argument("--workspace", required=True)
    request.add_argument("--profile", required=True)
    request.add_argument("--token-file", required=True)
    request.add_argument("url")
    return top


def main() -> int:
    arguments = parser().parse_args()
    if arguments.command == "create-token":
        create_token(Path(arguments.token_file))
        return 0
    if arguments.command == "serve":
        return run_server(arguments)
    return request_open(arguments)


if __name__ == "__main__":
    raise SystemExit(main())
