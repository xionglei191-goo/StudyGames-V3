"""Storage/lease regressions use temporary roots and never touch the user's save."""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from aiohttp.test_utils import TestClient, TestServer

from server import create_app
from shared_profiles import EMPTY_REVISION, LEASE_SECONDS, ProfileError, ProfileStore, validate_state


def state(coins=48, outfit="yellow"):
    return json.dumps({"version": 1, "coins": coins, "apples": 0, "cakes": 0, "day": 1, "unit": 1, "harvested": 0,
                       "quests": {"greet_done": False, "delivery_done": False},
                       "decorations_owned": {"flower_box": False, "picnic": False, "lamp": False},
                       "decorations_placed": {"flower_box": False, "picnic": False, "lamp": False},
                       "completed_units": {"1": False, "2": False, "3": False}, "learning": {}, "outfit": outfit,
                       "journey": {"preserved_nested_future_field": ["字母", {"x": 1}]}})


class StoreRules(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.legacy = self.root / "legacy.json"
        self.now = 100.0
        self.store = ProfileStore(self.root / "profiles", self.legacy, lambda: self.now)

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def profile(self):
        return self.store.ensure_default()

    def assertCode(self, code, function, *args):
        with self.assertRaises(ProfileError) as error:
            function(*args)
        self.assertEqual(error.exception.code, code)

    def test_import_copies_original_bytes_once_and_preserves_provenance(self):
        original = state(48, "pink").encode("utf-8")
        self.legacy.write_bytes(original)
        profile_id = self.profile()
        path = self.store.save_path(profile_id)
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(Path(str(path) + ".bak").read_bytes(), original)
        self.assertEqual((path.parent / "import-original.json").read_bytes(), original)
        self.assertEqual(self.store.get_profile(profile_id)["import"]["sha256"], hashlib.sha256(original).hexdigest())
        self.assertEqual(self.store.get_profile(profile_id)["import"]["source"], str(self.legacy.resolve()))
        lease = self.store.acquire(profile_id)
        self.store.save(profile_id, lease["token"], lease["revision"], state(49))
        self.assertEqual(self.profile(), profile_id)
        self.assertEqual(self.legacy.read_bytes(), original)
        self.assertEqual(json.loads(path.read_text())["coins"], 49)

    def test_legacy_backup_fallback_and_both_corrupt_are_not_empty(self):
        self.legacy.write_text("broken")
        backup = Path(str(self.legacy) + ".bak")
        backup.write_text(state())
        profile_id = self.profile()
        self.assertEqual(self.store.get_profile(profile_id)["import"]["source"], str(backup.resolve()))
        self.assertEqual(self.legacy.read_text(), "broken")
        bad = ProfileStore(self.root / "bad", self.root / "broken.json")
        bad.legacy_path.write_text("bad")
        self.assertCode("legacy_corrupt", bad.ensure_default)
        self.assertFalse((bad.root / "default.json").exists())

    def test_same_and_cross_process_lock_excludes_native_and_web(self):
        profile_id = self.profile()
        lease = self.store.acquire(profile_id)
        self.assertCode("profile_busy", self.store.lock_profile, profile_id)
        source = "from pathlib import Path; from shared_profiles import ProfileStore,ProfileError; import sys\ns=ProfileStore(Path(sys.argv[1]),Path(sys.argv[1])/'missing');\ntry:\n l=s.lock_profile(sys.argv[2]); l.close(); print('acquired')\nexcept ProfileError as e: print(e.code)"
        args = [getattr(sys, "_base_executable", sys.executable), "-c", source, str(self.store.root), profile_id]
        child = subprocess.run(args, cwd=Path(__file__).parent, capture_output=True, text=True)
        self.assertEqual(child.returncode, 0, child.stderr)
        self.assertEqual(child.stdout.strip(), "profile_busy")
        self.store.release(profile_id, lease["token"])
        child = subprocess.run(args, cwd=Path(__file__).parent, capture_output=True, text=True)
        self.assertEqual(child.stdout.strip(), "acquired")

    def test_crashed_process_releases_lock(self):
        profile_id = self.profile()
        source = "from pathlib import Path; from shared_profiles import ProfileStore; import sys,time\ns=ProfileStore(Path(sys.argv[1]),Path(sys.argv[1])/'missing');l=s.lock_profile(sys.argv[2]);print('locked',flush=True);time.sleep(60)"
        # The Windows venv executable can be a launcher that spawns another Python.
        # Kill the actual lock owner, not that launcher, when testing crash cleanup.
        child = subprocess.Popen([getattr(sys, "_base_executable", sys.executable), "-c", source, str(self.store.root), profile_id], cwd=Path(__file__).parent,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertEqual(child.stdout.readline().strip(), "locked")
            self.assertCode("profile_busy", self.store.lock_profile, profile_id)
            child.kill()
            child.wait(timeout=5)
            with self.store.lock_profile(profile_id):
                pass
        finally:
            if child.poll() is None:
                child.kill()
                child.wait(timeout=5)
            child.stdout.close()
            child.stderr.close()

    def test_expiry_and_restart_reject_old_tokens(self):
        profile_id = self.profile()
        first = self.store.acquire(profile_id)
        self.now += LEASE_SECONDS + 1
        self.assertCode("lease_expired", self.store.save, profile_id, first["token"], "empty", state())
        second = self.store.acquire(profile_id)
        self.store.close()
        restarted = ProfileStore(self.store.root, self.legacy)
        try:
            self.assertCode("lease_expired", restarted.acquire, profile_id, second["token"])
            fresh = restarted.acquire(profile_id)
            self.assertNotEqual(fresh["token"], second["token"])
        finally:
            restarted.close()

    def test_cas_native_change_backup_and_lost_response_retry(self):
        profile_id = self.profile()
        lease = self.store.acquire(profile_id)
        saved = self.store.save(profile_id, lease["token"], EMPTY_REVISION, state(50))
        self.assertEqual(saved, self.store.save(profile_id, lease["token"], EMPTY_REVISION, state(50)))
        self.assertCode("revision_conflict", self.store.save, profile_id, lease["token"], EMPTY_REVISION, state(51))
        self.store.save(profile_id, lease["token"], saved["revision"], state(51))
        self.assertEqual(Path(str(self.store.save_path(profile_id)) + ".bak").read_text(), state(50))
        self.store.release(profile_id, lease["token"])
        with self.store.lock_profile(profile_id):
            self.store.save_path(profile_id).write_text(state(52), encoding="utf-8")
        fresh = self.store.acquire(profile_id)
        self.assertEqual(json.loads(fresh["state"])["coins"], 52)
        self.assertCode("revision_conflict", self.store.save, profile_id, fresh["token"], saved["revision"], state(53))

    def test_invalid_save_does_not_touch_primary_or_backup(self):
        profile_id = self.profile()
        lease = self.store.acquire(profile_id)
        revision = self.store.save(profile_id, lease["token"], lease["revision"], state())["revision"]
        path = self.store.save_path(profile_id)
        before = (path.read_bytes(), Path(str(path) + ".bak").read_bytes())
        for raw in ["{}", "[]", "null", '{"version":1}', state().replace('"coins": 48', '"coins": -1'), state().replace('"coins": 48', '"coins": NaN'), state().replace('"coins": 48', '"coins": true')]:
            self.assertCode("invalid_save", self.store.save, profile_id, lease["token"], revision, raw)
        malformed = json.loads(state())
        malformed["learning"] = {"u1_greeting": []}
        malformed["completed_units"]["1"] = True
        self.assertCode("invalid_save", validate_state, json.dumps(malformed))
        self.assertCode("invalid_save", validate_state, state().replace('"coins": 48', '"coins": ' + str(10**400)))
        self.assertEqual(before, (path.read_bytes(), Path(str(path) + ".bak").read_bytes()))

    def test_primary_corruption_recovers_backup_without_discarding_bad_file(self):
        profile_id = self.profile()
        path = self.store.save_path(profile_id)
        path.write_text("broken")
        Path(str(path) + ".bak").write_text(state())
        with self.store.lock_profile(profile_id):
            snapshot = self.store.snapshot(profile_id)
        self.assertTrue(snapshot["recovered_from_backup"])
        self.assertEqual(path.read_text(), state())
        self.assertEqual(next(path.parent.glob("progress.corrupt-*.json")).read_text(), "broken")
        path.write_text("broken again")
        Path(str(path) + ".bak").write_text("broken backup")
        self.assertCode("save_corrupt", self.store.acquire, profile_id)
        with self.store.lock_profile(profile_id):
            pass

    def test_recovery_is_explicit_and_cas_guarded_preserves_replaced_version(self):
        profile_id = self.profile()
        lease = self.store.acquire(profile_id)
        revision = self.store.save(profile_id, lease["token"], lease["revision"], state(50))["revision"]
        recovery = self.store.add_recovery(profile_id, state(49), "old", "connection_lost")["recovery_id"]
        self.assertEqual(json.loads(self.store.save_path(profile_id).read_text())["coins"], 50)
        self.assertEqual(self.store.recoveries(profile_id)["recoveries"][0]["reason"], "connection_lost")
        self.assertCode("revision_conflict", self.store.restore, profile_id, recovery, lease["token"], "old")
        self.store.restore(profile_id, recovery, lease["token"], revision)
        self.assertEqual(json.loads(self.store.save_path(profile_id).read_text())["coins"], 49)
        self.assertEqual(len(self.store.recoveries(profile_id)["recoveries"]), 2)
        self.assertEqual(self.store.recovery_state(profile_id, recovery), state(49))

    def test_legacy_profile_import_identity_cannot_overwrite_existing(self):
        legacy_id = "a" * 24
        created = self.store.create("网页小芽", "pink", legacy_id)
        self.assertEqual(created["id"], legacy_id)
        again = self.store.create("别的昵称", "blue", legacy_id)
        self.assertEqual(again["nickname"], "网页小芽")
        self.assertEqual(again["outfit"], "pink")
        self.assertTrue(again["pending_browser_import"])
        listed = next(p for p in self.store.list_profiles()["profiles"] if p["id"] == legacy_id)
        self.assertTrue(listed["pending_browser_import"])
        lease = self.store.acquire(legacy_id)
        self.assertCode("invalid_save", self.store.save, legacy_id, lease["token"], lease["revision"], "{}")
        self.assertTrue(self.store.get_profile(legacy_id)["pending_browser_import"])
        self.store.save(legacy_id, lease["token"], lease["revision"], state(48, "pink"))
        self.assertFalse(self.store.get_profile(legacy_id)["pending_browser_import"])
        self.assertCode("profile_missing", self.store.create, "坏路径", "yellow", "../../bad")

    def test_list_marks_busy_without_loading_private_progress(self):
        profile_id = self.profile()
        self.store.acquire(profile_id)
        listed = self.store.list_profiles()
        self.assertEqual(listed["default_id"], profile_id)
        self.assertTrue(listed["profiles"][0]["busy"])
        self.assertNotIn("state", listed["profiles"][0])


class SharedRoutes(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.store = ProfileStore(self.root / "profiles", self.root / "missing.json")
        self.client = TestClient(TestServer(create_app(self.root, profiles=self.store)))
        await self.client.start_server()

    async def asyncTearDown(self):
        await self.client.close()
        self.temp.cleanup()

    async def post(self, path, data, status=200):
        response = await self.client.post(path, json=data)
        result = await response.json()
        self.assertEqual(response.status, status, result)
        return result

    async def test_http_roundtrip_save_recovery_and_origin(self):
        response = await self.client.get("/api/profiles")
        profile_id = (await response.json())["default_id"]
        base = "/api/profiles/" + profile_id
        lease = await self.post(base + "/lease", {})
        await self.post(base + "/lease", {}, 409)
        await self.post(base + "/heartbeat", {"token": lease["token"]})
        revision = (await self.post(base + "/save", {"token": lease["token"], "revision": lease["revision"], "state": state()}))["revision"]
        recovery = await self.post(base + "/recoveries", {"state": state(49), "base_revision": revision, "reason": "network"})
        recovery_id = recovery["recovery_id"]
        response = await self.client.get(base + "/recoveries")
        self.assertEqual(len((await response.json())["recoveries"]), 1)
        response = await self.client.get(base + "/recoveries/" + recovery_id)
        self.assertEqual(json.loads(await response.text())["coins"], 49)
        await self.post(base + "/recoveries/" + recovery_id + "/restore", {"token": lease["token"], "revision": revision})
        response = await self.client.post(base + "/save", json={"token": lease["token"], "state": state()}, headers={"Origin": "https://unrelated.invalid"})
        self.assertEqual(response.status, 403)
        await self.post(base + "/release", {"token": lease["token"]})
        await self.post(base + "/heartbeat", {"token": lease["token"]}, 409)

    async def test_large_save_allowed_but_room_body_stays_small(self):
        profile = await self.post("/api/profiles", {"nickname": "测试角色", "outfit": "blue"}, 201)
        base = "/api/profiles/" + profile["id"]
        lease = await self.post(base + "/lease", {})
        value = json.loads(state())
        value["journey"]["large_future_record"] = "字" * 20000
        await self.post(base + "/save", {"token": lease["token"], "revision": lease["revision"], "state": json.dumps(value)})
        result = await self.post("/api/rooms", {"nickname": "测试", "unexpected": "x" * 5000}, 413)
        self.assertEqual(result["code"], "request_too_large")

    async def test_interrupted_legacy_import_cannot_launch_empty_native_role(self):
        profile = await self.post("/api/profiles", {"nickname": "旧网页角色", "outfit": "pink", "legacy_id": "b" * 24}, 201)
        result = await self.post("/api/profiles/" + profile["id"] + "/launch-native", {}, 409)
        self.assertEqual(result["code"], "pending_browser_import")
        self.assertFalse(self.store.save_path(profile["id"]).exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
