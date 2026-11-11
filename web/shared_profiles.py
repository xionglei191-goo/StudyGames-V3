"""Local shared progress, process locks, leases and recoverable CAS writes.

The original Godot save is imported by copying. All later native/web writes use
the profile's progress.json; a separate stable lock file survives atomic saves.
This is a trusted, local desktop store, not an internet account service.
"""
from __future__ import annotations

import contextlib
import hashlib
import json
import math
import os
import re
import secrets
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROOT = ROOT / ".local/shared-profiles"
MAX_SAVE_BYTES = 8 * 1024 * 1024
LEASE_SECONDS = 180
EMPTY_REVISION = "empty"
ID_PATTERN = re.compile(r"^[a-f0-9]{24}$")
OUTFITS = {"yellow", "pink", "blue", "mint", "lavender", "caramel"}
UNIT_QUESTIONS = {
    "1": {"u1_greeting", "u1_morning", "u1_goodbye"},
    "2": {"u2_name", "u2_intro", "u2_polite"},
    "3": {"u3_age", "u3_nine", "u3_birthday"},
}


class ProfileError(Exception):
    def __init__(self, message: str, status: int = 400, code: str = "invalid_profile"):
        super().__init__(message)
        self.message, self.status, self.code = message, status, code


class FileLock:
    """Nonblocking advisory lock held by an open descriptor, including on Windows."""
    def __init__(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.file = path.open("a+b")
        try:
            if path.stat().st_size == 0:
                self.file.write(b"0")
                self.file.flush()
            self.file.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(self.file.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            self.file.close()
            raise ProfileError("这个角色正在另一端游玩。请先保存并退出，再继续这个角色。", 409, "profile_busy") from None

    def close(self):
        if self.file.closed:
            return
        try:
            self.file.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(self.file.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.file.fileno(), fcntl.LOCK_UN)
        finally:
            self.file.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def atomic_write(path: Path, raw: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".tmp-" + secrets.token_hex(6))
    try:
        with temp.open("xb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        with contextlib.suppress(FileNotFoundError):
            temp.unlink()


def write_json(path: Path, value):
    atomic_write(path, json.dumps(value, ensure_ascii=False, indent=2).encode("utf-8"))


def integer(value, low=0, high=1_000_000):
    if type(value) is int:
        return low <= value <= high
    return type(value) is float and math.isfinite(value) and value.is_integer() and low <= value <= high


def validate_state(raw: object) -> dict:
    """Validate the shared v1 envelope and core invariants without rewriting data.

    Godot remains the detailed validator for the evolving journey/review schema.
    We retain unknown extension fields so transfers cannot discard newer records.
    """
    try:
        valid_text = isinstance(raw, str) and len(raw.encode("utf-8")) <= MAX_SAVE_BYTES
    except UnicodeError:
        valid_text = False
    if not valid_text:
        raise ProfileError("存档内容无效或超过 8 MB，已有进度未被覆盖。", 400, "invalid_save")
    try:
        value = json.loads(raw, parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
    except (ValueError, UnicodeError, RecursionError):
        raise ProfileError("存档不是有效的 JSON，已有进度未被覆盖。", 400, "invalid_save") from None
    valid = isinstance(value, dict) and integer(value.get("version"), 1, 1)
    if valid:
        valid = all(integer(value.get(key)) for key in ("coins", "apples", "cakes"))
        valid &= integer(value.get("day"), 1) and integer(value.get("unit"), 1, 3) and integer(value.get("harvested"), 0, 3)
        valid &= isinstance(value.get("outfit"), str) and value["outfit"] in OUTFITS
    sections = {"quests": {"greet_done", "delivery_done"},
                "decorations_owned": {"flower_box", "picnic", "lamp"},
                "decorations_placed": {"flower_box", "picnic", "lamp"},
                "completed_units": {"1", "2", "3"}}
    if valid:
        for section, keys in sections.items():
            values = value.get(section)
            if not isinstance(values, dict) or set(values) != keys or any(type(v) is not bool for v in values.values()):
                valid = False
                break
    if valid:
        valid &= not value["quests"]["delivery_done"] or value["quests"]["greet_done"]
        valid &= all(not placed or value["decorations_owned"][key] for key, placed in value["decorations_placed"].items())
        valid &= isinstance(value.get("learning"), dict)
        valid &= all(isinstance(value[key], dict) for key in ("life", "preferences", "journey", "reviews", "wardrobe", "v4") if key in value)
    if valid:
        known_questions = set().union(*UNIT_QUESTIONS.values())
        record_keys = {"exposed", "assisted", "independent", "attempts", "last_seen"}
        for question, record in value["learning"].items():
            if question not in known_questions or not isinstance(record, dict) or set(record) != record_keys:
                valid = False
                break
            if not all(integer(count, 0, 32_503_680_000 if key == "last_seen" else 1_000_000) for key, count in record.items()):
                valid = False
                break
            if record["assisted"] + record["independent"] > record["attempts"]:
                valid = False
                break
        if valid:
            completed = 0
            saw_unfinished = False
            for unit, questions in UNIT_QUESTIONS.items():
                if value["completed_units"][unit]:
                    if saw_unfinished or any(sum(value["learning"].get(question, {}).get(key, 0) for key in ("assisted", "independent")) < 1 for question in questions):
                        valid = False
                        break
                    completed += 1
                else:
                    saw_unfinished = True
            valid &= value["unit"] == min(3, completed + 1)
        if "preferences" in value:
            valid &= all(type(value["preferences"].get(key)) is bool for key in ("voice", "effects", "reduced_motion"))
            valid &= "fixed_day" not in value["preferences"] or type(value["preferences"]["fixed_day"]) is bool
    if not valid:
        raise ProfileError("存档结构不完整，已有进度未被覆盖。请保留这份文件以便恢复。", 400, "invalid_save")
    return value


@dataclass
class Lease:
    profile_id: str
    token: str
    lock: FileLock
    expires: float


class ProfileStore:
    def __init__(self, root: Path = DEFAULT_ROOT, legacy_path: Path | None = None, clock=time.monotonic):
        self.root = Path(root).resolve()
        self.legacy_path = Path(legacy_path) if legacy_path is not None else Path(os.environ.get("APPDATA", Path.home() / ".local/share")) / "Godot/app_userdata/字母岛 · 我的第一天/island-save-v1.json"
        self.clock = clock
        self.leases: dict[str, Lease] = {}

    def _directory(self, profile_id: str) -> Path:
        if not isinstance(profile_id, str) or not ID_PATTERN.fullmatch(profile_id):
            raise ProfileError("角色编号无效。", 404, "profile_missing")
        return self.root / profile_id

    def save_path(self, profile_id: str) -> Path:
        return self._directory(profile_id) / "progress.json"

    def get_profile(self, profile_id: str) -> dict:
        try:
            profile = json.loads((self._directory(profile_id) / "profile.json").read_text("utf-8"))
            if not isinstance(profile, dict) or profile.get("id") != profile_id:
                raise ValueError()
            return profile
        except FileNotFoundError:
            raise ProfileError("没有找到这个角色，请返回入口重新选择。", 404, "profile_missing") from None
        except (ValueError, UnicodeError):
            raise ProfileError("角色资料无法读取，请保留存档目录并检查备份。", 409, "profile_corrupt") from None

    def lock_profile(self, profile_id: str) -> FileLock:
        self.get_profile(profile_id)
        return FileLock(self._directory(profile_id) / "session.lock")

    def _create(self, name: object, outfit: object, default=False, profile_id=None, pending_browser_import=False) -> dict:
        if not isinstance(name, str):
            raise ProfileError("请填写一个昵称。")
        name = "".join(c for c in name.strip() if c.isalnum() or c in " _-")[:12].strip()
        if not name or not isinstance(outfit, str) or outfit not in OUTFITS:
            raise ProfileError("请填写昵称并选择已有的衣服颜色。")
        profile_id = profile_id or secrets.token_hex(12)
        profile = {"id": profile_id, "nickname": name, "outfit": outfit, "default": default, "created_at": time.time()}
        if pending_browser_import:
            profile["pending_browser_import"] = True
        directory = self._directory(profile_id)
        directory.mkdir(parents=True)
        write_json(directory / "profile.json", profile)
        return profile

    def ensure_default(self) -> str:
        with FileLock(self.root / "catalog.lock"):
            index = self.root / "default.json"
            if index.exists():
                try:
                    profile_id = json.loads(index.read_text("utf-8"))["default_id"]
                    self.get_profile(profile_id)
                    return profile_id
                except (ValueError, KeyError, TypeError):
                    raise ProfileError("默认角色记录无法读取，请检查共享存档目录。", 409, "profile_corrupt") from None
            source = None
            source_raw = None
            candidates = [self.legacy_path, Path(str(self.legacy_path) + ".bak")]
            for candidate in candidates:
                if not candidate.is_file():
                    continue
                try:
                    raw = candidate.read_bytes()
                    validate_state(raw.decode("utf-8-sig"))
                    source, source_raw = candidate, raw
                    break
                except (ProfileError, UnicodeError):
                    continue
            if source is None and any(path.exists() for path in candidates):
                raise ProfileError("原单机存档和备份都无法读取，尚未建立空白角色。请先恢复原存档。", 409, "legacy_corrupt")
            outfit = validate_state(source_raw.decode("utf-8-sig"))["outfit"] if source_raw is not None else "yellow"
            profile = self._create("我的单机角色", outfit, default=True)
            if source is not None:
                # Keep a permanent import copy in addition to the rotating save backup.
                atomic_write(self.save_path(profile["id"]), source_raw)
                atomic_write(Path(str(self.save_path(profile["id"])) + ".bak"), source_raw)
                atomic_write(self._directory(profile["id"]) / "import-original.json", source_raw)
                profile["import"] = {"source": str(source.resolve()), "sha256": digest(source_raw), "copied_at": time.time()}
                write_json(self._directory(profile["id"]) / "profile.json", profile)
            write_json(index, {"default_id": profile["id"]})
            return profile["id"]

    def create(self, nickname: object, outfit: object = "yellow", legacy_id: object = None) -> dict:
        self.ensure_default()
        with FileLock(self.root / "catalog.lock"):
            if legacy_id is not None:
                self._directory(legacy_id)
                if (self._directory(legacy_id) / "profile.json").exists():
                    profile = self.get_profile(legacy_id)
                    return {**profile, "has_save": self.save_path(legacy_id).exists()}
            if len(list(self.root.glob("*/profile.json"))) >= 100:
                raise ProfileError("已有 100 个角色，请先整理本机角色。", 409, "profile_limit")
            # Publish the pending flag with the first metadata write, before any
            # other process can mistake the role for a new empty native save.
            profile = self._create(nickname, outfit, profile_id=legacy_id, pending_browser_import=legacy_id is not None)
        return {**profile, "has_save": False, "revision": EMPTY_REVISION, "busy": False}

    def snapshot(self, profile_id: str, repair=True) -> dict:
        """Read the canonical snapshot. Call while owning this profile's lock."""
        self.get_profile(profile_id)
        path = self.save_path(profile_id)
        backup = Path(str(path) + ".bak")
        recovered = False
        try:
            raw = path.read_bytes()
            validate_state(raw.decode("utf-8-sig"))
        except (FileNotFoundError, ProfileError, UnicodeError):
            if not path.exists() and not backup.exists():
                return {"revision": EMPTY_REVISION, "state": None, "recovered_from_backup": False}
            if not repair:
                raise ProfileError("共享存档无法读取，请先恢复备份。", 409, "save_corrupt") from None
            try:
                raw = backup.read_bytes()
                validate_state(raw.decode("utf-8-sig"))
            except (FileNotFoundError, ProfileError, UnicodeError):
                raise ProfileError("共享存档和备份都无法读取，原文件已保留。请恢复备份后再进入。", 409, "save_corrupt") from None
            if path.exists():
                atomic_write(path.with_name("progress.corrupt-" + secrets.token_hex(6) + ".json"), path.read_bytes())
            atomic_write(path, raw)
            recovered = True
        return {"revision": digest(raw), "state": raw.decode("utf-8-sig"), "recovered_from_backup": recovered}

    def list_profiles(self) -> dict:
        default_id = self.ensure_default()
        self.cleanup()
        profiles = []
        for directory in sorted(self.root.iterdir(), key=lambda path: path.name):
            if not ID_PATTERN.fullmatch(directory.name) or not (directory / "profile.json").is_file():
                continue
            profile = self.get_profile(directory.name)
            item = {key: profile[key] for key in ("id", "nickname", "outfit", "default")}
            item["pending_browser_import"] = profile.get("pending_browser_import", False)
            item.update(has_save=self.save_path(profile["id"]).exists(), revision=None, busy=False)
            try:
                with self.lock_profile(profile["id"]):
                    snapshot = self.snapshot(profile["id"], repair=False)
                    item["revision"] = snapshot["revision"]
                    if snapshot["state"]:
                        item["outfit"] = validate_state(snapshot["state"])["outfit"]
            except ProfileError as error:
                if error.code == "profile_busy":
                    item["busy"] = True
                elif error.code == "save_corrupt":
                    item["needs_recovery"] = True
                else:
                    raise
            profiles.append(item)
        profiles.sort(key=lambda item: not item["default"])
        return {"profiles": profiles, "default_id": default_id}

    def cleanup(self):
        for profile_id, lease in list(self.leases.items()):
            if lease.expires <= self.clock():
                lease.lock.close()
                del self.leases[profile_id]

    def close(self):
        for lease in self.leases.values():
            lease.lock.close()
        self.leases.clear()

    def _lease(self, profile_id: str, token: object) -> Lease:
        self.cleanup()
        lease = self.leases.get(profile_id)
        if not lease or not isinstance(token, str) or not secrets.compare_digest(lease.token, token):
            raise ProfileError("这次保存连接已过期。当前页面的进度会保留，请返回入口恢复后再继续。", 409, "lease_expired")
        lease.expires = self.clock() + LEASE_SECONDS
        return lease

    def acquire(self, profile_id: str, token: object = None) -> dict:
        self.cleanup()
        if token is not None:
            lease = self._lease(profile_id, token)
            snapshot = self.snapshot(profile_id)
        else:
            lock = self.lock_profile(profile_id)
            try:
                snapshot = self.snapshot(profile_id)
            except Exception:
                lock.close()
                raise
            lease = Lease(profile_id, secrets.token_urlsafe(32), lock, self.clock() + LEASE_SECONDS)
            self.leases[profile_id] = lease
        return {"token": lease.token, **snapshot, "profile": self.get_profile(profile_id), "lease_seconds": LEASE_SECONDS}

    def heartbeat(self, profile_id: str, token: object) -> dict:
        self._lease(profile_id, token)
        return {"ok": True, "lease_seconds": LEASE_SECONDS}

    def release(self, profile_id: str, token: object) -> dict:
        lease = self._lease(profile_id, token)
        lease.lock.close()
        del self.leases[profile_id]
        return {"ok": True}

    def save(self, profile_id: str, token: object, revision: object, state: object) -> dict:
        self._lease(profile_id, token)
        parsed = validate_state(state)
        current = self.snapshot(profile_id, repair=False)
        raw = state.encode("utf-8")
        new_revision = digest(raw)
        # A lost HTTP response can be retried without producing a false conflict.
        if current["revision"] == new_revision:
            self._saved_metadata(profile_id, parsed)
            return {"revision": new_revision}
        if not isinstance(revision, str) or revision != current["revision"]:
            raise ProfileError("另一端已有更新的进度，未覆盖它。请保留当前恢复副本后选择继续的版本。", 409, "revision_conflict")
        path = self.save_path(profile_id)
        backup = Path(str(path) + ".bak")
        if current["state"] is not None:
            atomic_write(backup, path.read_bytes())
        atomic_write(path, raw)
        if not backup.exists():
            atomic_write(backup, raw)
        self._saved_metadata(profile_id, parsed)
        return {"revision": new_revision}

    def _saved_metadata(self, profile_id: str, parsed: dict):
        profile = self.get_profile(profile_id)
        if profile["outfit"] != parsed["outfit"] or profile.get("pending_browser_import", False):
            profile["outfit"] = parsed["outfit"]
            profile["pending_browser_import"] = False
            write_json(self._directory(profile_id) / "profile.json", profile)

    def add_recovery(self, profile_id: str, state: object, base_revision: object = None, reason: object = None) -> dict:
        self.get_profile(profile_id)
        parsed = validate_state(state)
        if base_revision is not None and (not isinstance(base_revision, str) or len(base_revision) > 64):
            raise ProfileError("恢复副本的版本编号无效。")
        if reason is not None and (not isinstance(reason, str) or len(reason) > 200):
            raise ProfileError("恢复副本的说明太长或格式无效。")
        raw = state.encode("utf-8")
        recovery_id = digest(raw)[:24]
        directory = self._directory(profile_id) / "recoveries"
        # Content addressing makes a lost response retry safe without losing copies.
        if not (directory / (recovery_id + ".json")).exists():
            atomic_write(directory / (recovery_id + ".json"), raw)
        if not (directory / (recovery_id + ".meta.json")).exists():
            write_json(directory / (recovery_id + ".meta.json"), {"id": recovery_id, "recovery_id": recovery_id, "created_at": time.time(), "base_revision": base_revision, "reason": reason or "manual_recovery",
                       "sha256": digest(raw), "bytes": len(raw), "coins": parsed["coins"], "day": parsed["day"], "outfit": parsed["outfit"]})
        return {"recovery_id": recovery_id}

    def recoveries(self, profile_id: str) -> dict:
        self.get_profile(profile_id)
        items = []
        for path in (self._directory(profile_id) / "recoveries").glob("*.meta.json"):
            with contextlib.suppress(ValueError, UnicodeError):
                items.append(json.loads(path.read_text("utf-8")))
        return {"recoveries": sorted(items, key=lambda item: item["created_at"], reverse=True)}

    def recovery_state(self, profile_id: str, recovery_id: str) -> str:
        self.get_profile(profile_id)
        if not ID_PATTERN.fullmatch(recovery_id):
            raise ProfileError("没有找到这份恢复副本。", 404, "recovery_missing")
        path = self._directory(profile_id) / "recoveries" / (recovery_id + ".json")
        try:
            return path.read_text("utf-8")
        except FileNotFoundError:
            raise ProfileError("没有找到这份恢复副本。", 404, "recovery_missing") from None

    def restore(self, profile_id: str, recovery_id: str, token: object, revision: object) -> dict:
        self._lease(profile_id, token)
        raw = self.recovery_state(profile_id, recovery_id)
        current = self.snapshot(profile_id, repair=False)
        if revision != current["revision"]:
            raise ProfileError("共享进度已经改变，请刷新版本信息后再选择恢复。", 409, "revision_conflict")
        # Preserve the current version permanently before the explicit replacement.
        if current["state"] is not None:
            self.add_recovery(profile_id, current["state"], current["revision"])
        return self.save(profile_id, token, revision, raw)
