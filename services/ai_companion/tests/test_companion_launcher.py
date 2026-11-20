"""Windows launcher checks use temporary ports and processes created by the test."""
from __future__ import annotations

import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

import pytest

ROOT = Path(__file__).resolve().parents[3]
pytestmark = pytest.mark.skipif(os.name != "nt", reason="PowerShell desktop launcher")
NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def health(port):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=0.5) as response:
        return json.load(response)


def wait_ready(process, port):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise AssertionError("fixture exited before startup")
        try:
            return health(port)
        except (OSError, urllib.error.URLError):
            time.sleep(0.05)
    raise AssertionError("fixture did not start")


def run_launcher(port, *args):
    return subprocess.run(
        ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "start-ai-companion.ps1"), "-Port", str(port), *args],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30,
        creationflags=NO_WINDOW,
    )


@pytest.mark.parametrize("args", [(), ("-Restart",)])
def test_unrelated_healthy_service_is_neither_accepted_nor_stopped(tmp_path, args):
    helper = tmp_path / "unrelated_service.py"
    helper.write_text(
        "from http.server import BaseHTTPRequestHandler, HTTPServer\n"
        "import sys\n"
        "class Handler(BaseHTTPRequestHandler):\n"
        " def do_GET(self):\n"
        "  self.send_response(200); self.end_headers(); self.wfile.write(b'{\"ok\":true,\"service\":\"unrelated-test-service\"}')\n"
        " def log_message(self, *args): pass\n"
        "HTTPServer(('127.0.0.1',int(sys.argv[1])),Handler).serve_forever()\n",
        encoding="utf-8",
    )
    port = free_port()
    process = subprocess.Popen([sys.executable, str(helper), str(port)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=NO_WINDOW)
    try:
        wait_ready(process, port)
        result = run_launcher(port, *args)
        assert result.returncode != 0, result.stdout
        assert process.poll() is None, "launcher stopped an unrelated process"
        assert health(port)["service"] == "unrelated-test-service"
    finally:
        # Only this test's child tree is stopped, never a process discovered by port.
        if process.poll() is None:
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True, timeout=5, creationflags=NO_WINDOW)
        process.wait(timeout=5)
