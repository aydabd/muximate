from __future__ import annotations

import importlib.util
import io
import json
import stat
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from argparse import Namespace
from contextlib import redirect_stdout
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("url_broker.py")
SPEC = importlib.util.spec_from_file_location("url_broker", MODULE_PATH)
assert SPEC and SPEC.loader
url_broker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(url_broker)


class BrokerTest(unittest.TestCase):
    workspace = "11111111-1111-4111-8111-111111111111"
    profile = "muximate-disposable-profile"
    token = "a" * 64

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="muximate-url-broker-test-")
        self.root = Path(self.temporary.name)
        self.fake_cmux = self.root / "fake-cmux"
        self.log = Path(f"{self.fake_cmux}.log")
        self.fake_cmux.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, pathlib, sys\n"
            "pathlib.Path(os.environ.get('FAKE_CMUX_LOG', sys.argv[0] + '.log'))"
            ".write_text(json.dumps(sys.argv[1:]))\n"
            "raise SystemExit(int(os.environ.get('FAKE_CMUX_EXIT', '0')))\n",
            encoding="utf-8",
        )
        self.fake_cmux.chmod(0o700)
        self.server = url_broker.BrokerServer(
            ("127.0.0.1", 0), self.workspace, self.profile, self.token, str(self.fake_cmux)
        )
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        host, port = self.server.server_address
        self.endpoint = f"http://{host}:{port}/open"

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temporary.cleanup()

    def post(
        self,
        *,
        workspace: str | None = None,
        profile: str | None = None,
        url: str = "https://example.invalid/path",
        token: str | None = None,
    ) -> tuple[int, dict[str, object]]:
        payload = json.dumps(
            {
                "workspace": workspace or self.workspace,
                "profile": profile or self.profile,
                "url": url,
            }
        ).encode()
        request = urllib.request.Request(
            self.endpoint,
            data=payload,
            headers={"Authorization": f"Bearer {token or self.token}"},
            method="POST",
        )
        try:
            response = urllib.request.urlopen(request, timeout=2)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.status, json.load(response)

    def test_exact_binding_opens_with_one_argv_vector(self) -> None:
        url = "https://example.invalid/a?value=$(touch%20/tmp/nope)&other=a;b"
        status, body = self.post(url=url)
        self.assertEqual(status, 200)
        self.assertEqual(body, {"opened": True, "url": url})
        self.assertEqual(
            json.loads(self.log.read_text()),
            [
                "new-pane",
                "--type",
                "browser",
                "--workspace",
                self.workspace,
                "--url",
                url,
                "--profile",
                self.profile,
                "--focus",
                "false",
            ],
        )

    def test_wrong_token_workspace_and_profile_are_rejected(self) -> None:
        checks = [
            self.post(token="b" * 64),
            self.post(workspace="22222222-2222-4222-8222-222222222222"),
            self.post(profile="wrong-profile"),
        ]
        self.assertEqual([status for status, _ in checks], [401, 403, 403])
        self.assertTrue(all(body["opened"] is False for _, body in checks))
        self.assertFalse(self.log.exists())

    def test_non_http_urls_and_userinfo_are_rejected_and_returned(self) -> None:
        for url in ["file:///etc/passwd", "javascript:alert(1)", "https://user@example.invalid/"]:
            status, body = self.post(url=url)
            self.assertEqual(status, 400)
            self.assertEqual(body["opened"], False)
            self.assertEqual(body["url"], url)
        self.assertFalse(self.log.exists())

    def test_token_creation_is_exclusive_and_private(self) -> None:
        token_path = self.root / "caller.token"
        url_broker.create_token(token_path)
        self.assertEqual(stat.S_IMODE(token_path.stat().st_mode), 0o600)
        self.assertGreaterEqual(len(url_broker.read_token(token_path)), 32)
        with self.assertRaises(FileExistsError):
            url_broker.create_token(token_path)

    def test_cmux_failure_returns_url_without_fallback(self) -> None:
        failing = self.root / "failing-cmux"
        failing.write_text("#!/bin/sh\nexit 23\n", encoding="utf-8")
        failing.chmod(0o700)
        self.server.cmux = str(failing)
        url = "https://example.invalid/recover-me"
        status, body = self.post(url=url)
        self.assertEqual(status, 502)
        self.assertEqual(body, {"opened": False, "url": url, "error": "cmux rejected request"})

    def test_client_prints_url_when_broker_rejects_request(self) -> None:
        token_path = self.root / "caller.token"
        token_path.write_text(f"{self.token}\n", encoding="utf-8")
        token_path.chmod(0o600)
        url = "https://example.invalid/manual-fallback"
        output = io.StringIO()
        with redirect_stdout(output):
            status = url_broker.request_open(
                Namespace(
                    endpoint=self.endpoint.removesuffix("/open"),
                    workspace=self.workspace,
                    profile="wrong-profile",
                    token_file=str(token_path),
                    url=url,
                )
            )
        self.assertEqual(status, 1)
        self.assertEqual(output.getvalue(), f"{url}\n")


if __name__ == "__main__":
    unittest.main()
