"""Desktop launch/lifetime regression using temporary profile roots only."""
import ctypes
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from shared_profiles import ProfileError, ProfileStore

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT_TEST_PATH", "F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe"))


def process_stopped(pid, timeout=10000):
    from ctypes import wintypes as wt
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
    kernel.OpenProcess.restype = wt.HANDLE
    kernel.WaitForSingleObject.argtypes = [wt.HANDLE, wt.DWORD]
    kernel.WaitForSingleObject.restype = wt.DWORD
    kernel.CloseHandle.argtypes = [wt.HANDLE]
    handle = kernel.OpenProcess(0x00100000, False, pid)
    if not handle:
        return ctypes.get_last_error() == 87
    try:
        return kernel.WaitForSingleObject(handle, timeout) == 0
    finally:
        kernel.CloseHandle(handle)


@unittest.skipUnless(os.name == "nt" and GODOT.is_file(), "Windows Godot test runtime is required")
class DesktopLifetime(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="alphabet-native-test-")
        self.root = Path(self.temporary.name)
        self.store = ProfileStore(self.root / "profiles", self.root / "missing-legacy.json")
        self.profile = self.store.create("测试角色", "pink")
        self.profile_id = self.profile["id"]
        self.status = self.root / "status.json"

    def tearDown(self):
        self.store.close()
        self.temporary.cleanup()

    def command(self, quit_after=None):
        args = [sys.executable, str(ROOT / "web/native_runner.py"), "--godot", str(GODOT),
                "--profile-root", str(self.store.root), "--profile-id", self.profile_id,
                "--legacy-path", str(self.root / "missing-legacy.json"),
                "--status-file", str(self.status), "--no-dialog", "--engine-arg=--headless"]
        if quit_after:
            args += ["--engine-arg=--quit-after", "--engine-arg=" + str(quit_after)]
        return args

    def read_status(self):
        return json.loads(self.status.read_text("utf-8"))

    def test_real_game_fresh_outfit_and_existing_progress(self):
        result = subprocess.run(self.command(30), capture_output=True, text=True, timeout=45)
        log_file = self.store.save_path(self.profile_id).parent / "native-game.log"
        diagnostics = log_file.read_text("utf-8") if log_file.exists() else result.stderr
        self.assertEqual(result.returncode, 0, diagnostics)
        self.assertEqual(self.read_status()["status"], "stopped")
        self.assertTrue(self.read_status()["ok"])
        path = self.store.save_path(self.profile_id)
        saved = json.loads(path.read_text("utf-8"))
        self.assertEqual(saved["outfit"], "pink")
        saved["outfit"], saved["coins"] = "blue", 77
        path.write_text(json.dumps(saved), "utf-8")
        result = subprocess.run(self.command(30), capture_output=True, text=True, timeout=45)
        self.assertEqual(result.returncode, 0, result.stderr)
        resumed = json.loads(path.read_text("utf-8"))
        self.assertEqual(resumed["outfit"], "blue")
        self.assertEqual(resumed["coins"], 77)
        log = (path.parent / "native-game.log").read_text("utf-8")
        self.assertNotIn("SCRIPT ERROR", log)
        self.assertNotIn("ERROR:", log)
        with self.store.lock_profile(self.profile_id):
            pass

    def test_busy_profile_refuses_before_game_launch(self):
        with self.store.lock_profile(self.profile_id):
            result = subprocess.run(self.command(30), capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 1)
        self.assertFalse(self.read_status()["ok"])
        self.assertEqual(self.read_status()["code"], "profile_busy")
        self.assertFalse(self.store.save_path(self.profile_id).exists())

    def test_pending_legacy_browser_role_cannot_be_started_as_empty_native(self):
        metadata = self.store.save_path(self.profile_id).parent / "profile.json"
        profile = json.loads(metadata.read_text("utf-8"))
        profile["pending_browser_import"] = True
        metadata.write_text(json.dumps(profile), "utf-8")
        result = subprocess.run(self.command(30), capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.read_status()["code"], "browser_import_pending")
        self.assertFalse(self.store.save_path(self.profile_id).exists())

    def test_supervisor_crash_kills_child_before_next_profile_session(self):
        supervisor = subprocess.Popen(self.command(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        child_pid = None
        try:
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline and not self.status.exists():
                self.assertIsNone(supervisor.poll())
                time.sleep(0.05)
            started = self.read_status()
            self.assertTrue(started["ok"], started)
            child_pid = started["pid"]
            self.assertFalse(process_stopped(child_pid, 0))
            with self.assertRaises(ProfileError) as blocked:
                self.store.lock_profile(self.profile_id)
            self.assertEqual(blocked.exception.code, "profile_busy")
            supervisor.kill()
            supervisor.wait(timeout=10)
            self.assertTrue(process_stopped(child_pid), "Job Object must terminate a child whose supervisor died")
            with self.store.lock_profile(self.profile_id):
                pass
        finally:
            if supervisor.poll() is None:
                supervisor.kill()
                supervisor.wait(timeout=10)
            if child_pid:
                self.assertTrue(process_stopped(child_pid), "No live test game may outlast its lock")


if __name__ == "__main__":
    unittest.main()
