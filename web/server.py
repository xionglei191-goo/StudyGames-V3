"""Local web client, invitation rooms and private shared progress on this computer."""
from __future__ import annotations

import argparse
import asyncio
import contextlib
import json
import math
import re
import secrets
import subprocess
import sys
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlsplit

from aiohttp import WSMsgType, web

from shared_profiles import MAX_SAVE_BYTES, ProfileError, ProfileStore

ROOT = Path(__file__).resolve().parents[1]
PROTOCOL = 1
MAX_PLAYERS = 4
RECONNECT_SECONDS = 90
LOADING_SECONDS = 1800
EMPTY_ROOM_SECONDS = 900
OUTFITS = {"yellow", "pink", "blue"}
ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


class RoomError(Exception):
    def __init__(self, message: str, status: int = 400, code: str = "invalid_request"):
        self.message, self.status, self.code = message, status, code


@dataclass
class Member:
    id: str
    token: str
    nickname: str
    outfit: str
    joined: float
    last_seen: float
    ws: web.WebSocketResponse | None = None
    connected_once: bool = False
    pose: dict | None = None
    sequence: int = -1
    last_pose: float = 0
    last_wave: float = 0

    def public(self) -> dict:
        return {"id": self.id, "nickname": self.nickname, "outfit": self.outfit,
                "online": self.ws is not None and not self.ws.closed,
                "pose": self.pose}


@dataclass
class Room:
    code: str
    host: str
    members: dict[str, Member] = field(default_factory=dict)
    last_active: float = field(default_factory=time.monotonic)

    def public(self) -> dict:
        return {"code": self.code, "host": self.host, "capacity": MAX_PLAYERS,
                "members": [member.public() for member in self.members.values()]}


def nickname(value: object) -> str:
    if not isinstance(value, str):
        raise RoomError("请填写一个昵称。")
    value = "".join(c for c in value.strip() if c.isalnum() or c in " _-")[:12].strip()
    if not value:
        raise RoomError("请用汉字、字母或数字填写昵称。")
    return value


def load_scenes() -> dict[str, list[float]]:
    manifest = json.loads((ROOT / "game/data/interiors_manifest.json").read_text("utf-8"))
    scenes = {row["room_id"]: row["bounds"] for row in manifest["rooms"]}
    # Island is much wider than an interior; exact movement/collision remains in the client.
    scenes["village"] = [-500, -500, 1000, 1000]
    return scenes


class Rooms:
    def __init__(self, clock=time.monotonic):
        self.clock = clock
        self.rooms: dict[str, Room] = {}
        self.tokens: dict[str, tuple[str, str]] = {}
        self.scenes = load_scenes()
        self.requests: dict[str, deque] = defaultdict(deque)

    def limit(self, key: str, maximum: int = 20, window: float = 60) -> None:
        now = self.clock()
        times = self.requests[key]
        while times and times[0] <= now - window:
            times.popleft()
        if len(times) >= maximum:
            raise RoomError("操作太快了，请稍等一会儿。", 429, "rate_limited")
        times.append(now)

    def create(self, name: object, outfit: object = "yellow") -> tuple[Room, Member]:
        self.cleanup()
        if len(self.rooms) >= 64:
            raise RoomError("小岛房间暂时已满，请稍后再试。", 503, "server_full")
        while (code := "".join(secrets.choice(ALPHABET) for _ in range(8))) in self.rooms:
            pass
        member = self.member(name, outfit)
        room = Room(code, member.id, {member.id: member}, self.clock())
        self.rooms[code] = room
        self.tokens[member.token] = (code, member.id)
        return room, member

    def member(self, name: object, outfit: object) -> Member:
        name = nickname(name)
        if not isinstance(outfit, str) or outfit not in OUTFITS:
            raise RoomError("请选择已有的服装颜色。")
        now = self.clock()
        return Member(secrets.token_hex(6), secrets.token_urlsafe(32), name, outfit, now, now)

    def join(self, code: str, name: object, outfit: object = "yellow") -> tuple[Room, Member]:
        self.cleanup()
        code = re.sub(r"[\s-]", "", code).upper()
        room = self.rooms.get(code)
        if not room:
            raise RoomError("没有找到这个房间，请检查邀请码或请朋友重新创建。", 404, "room_missing")
        if len(room.members) >= MAX_PLAYERS:
            raise RoomError("这个房间已有 4 位朋友，请等一个空位。", 409, "room_full")
        member = self.member(name, outfit)
        room.members[member.id] = member
        room.last_active = self.clock()
        self.tokens[member.token] = (code, member.id)
        return room, member

    def session(self, token: object) -> tuple[Room, Member]:
        if not isinstance(token, str) or len(token) > 128:
            raise RoomError("这次邀请已结束，请重新加入房间。", 401, "session_expired")
        entry = self.tokens.get(token)
        room = self.rooms.get(entry[0]) if entry else None
        member = room.members.get(entry[1]) if room and entry else None
        if not member:
            raise RoomError("这次邀请已结束，请重新加入房间。", 401, "session_expired")
        return room, member

    def remove(self, room: Room, member: Member) -> None:
        room.members.pop(member.id, None)
        self.tokens.pop(member.token, None)
        room.last_active = self.clock()
        if room.host == member.id:
            room.host = next(iter(room.members), "")

    def cleanup(self) -> list[Room]:
        changed = []
        now = self.clock()
        for room in list(self.rooms.values()):
            for member in list(room.members.values()):
                grace = RECONNECT_SECONDS if member.connected_once else LOADING_SECONDS
                if member.ws is None and now - member.last_seen > grace:
                    self.remove(room, member)
                    changed.append(room)
            if not room.members and now - room.last_active > EMPTY_ROOM_SECONDS:
                self.rooms.pop(room.code, None)
        for key in list(self.requests):
            if not self.requests[key] or now - self.requests[key][-1] > 120:
                del self.requests[key]
        return changed

    def pose(self, member: Member, value: dict) -> bool:
        seq = value.get("seq")
        scene, position, rotation = value.get("scene"), value.get("p"), value.get("r")
        if type(seq) is not int or not 0 <= seq < 2**53 or seq <= member.sequence:
            return False
        if not isinstance(scene, str) or scene not in self.scenes:
            raise RoomError("无法进入这个场景。")
        if not isinstance(position, list) or len(position) != 3:
            raise RoomError("位置数据不完整。")
        values = [*position, rotation]
        if any(type(v) not in (int, float) or not math.isfinite(v) for v in values):
            raise RoomError("位置数据无效。")
        x, z, width, depth = self.scenes[scene]
        if not (x - 2 <= position[0] <= x + width + 2 and z - 2 <= position[2] <= z + depth + 2 and -100 <= position[1] <= 150):
            raise RoomError("这个位置在场景范围外。")
        outfit = value.get("outfit", member.outfit)
        if not isinstance(outfit, str) or outfit not in OUTFITS:
            raise RoomError("服装颜色无效。")
        now = self.clock()
        # Only presence is shared: no client can send another member ID, coins, or learning data.
        member.pose = {"scene": scene, "p": [round(v, 3) for v in position],
                       "r": round(rotation % math.tau, 4), "seq": seq,
                       "moving": value.get("moving") is True}
        member.outfit, member.sequence, member.last_pose = outfit, seq, now
        return True


ROOMS = web.AppKey("rooms", Rooms)
BUILD = web.AppKey("build", Path)
PROFILES = web.AppKey("profiles", ProfileStore)


@web.middleware
async def boundary(request: web.Request, handler):
    origin = request.headers.get("Origin")
    if origin and urlsplit(origin).netloc != request.host:
        return web.json_response({"error": "请从当前游戏网址进入。", "code": "origin_mismatch"}, status=403)
    try:
        response = await handler(request)
    except (RoomError, ProfileError) as error:
        response = web.json_response({"error": error.message, "code": error.code}, status=error.status)
    except web.HTTPRequestEntityTooLarge:
        response = web.json_response({"error": "请求内容太大，已有进度未被覆盖。", "code": "request_too_large"}, status=413)
    except OSError:
        if not request.path.startswith("/api/profiles"):
            raise
        response = web.json_response({"error": "暂时无法读写本机存档，请保留此页面并检查磁盘空间与文件权限。", "code": "profile_io_error"}, status=503)
    if not isinstance(response, web.WebSocketResponse):
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "same-origin"
        if request.path.startswith("/api/"):
            response.headers["Cache-Control"] = "no-store"
    return response


async def body(request: web.Request, maximum=4096) -> dict:
    if request.content_type != "application/json":
        raise RoomError("请求格式无效。")
    try:
        raw = await request.read()
        if len(raw) > maximum:
            raise web.HTTPRequestEntityTooLarge(max_size=maximum, actual_size=len(raw))
        value = json.loads(raw)
    except (ValueError, UnicodeError):
        raise RoomError("请求格式无效。") from None
    if not isinstance(value, dict):
        raise RoomError("请求格式无效。")
    return value


def credentials(room: Room, member: Member) -> dict:
    return {"protocol": PROTOCOL, "token": member.token, "id": member.id,
            "nickname": member.nickname, "outfit": member.outfit, "room": room.public()}


async def broadcast(room: Room, message: dict | None = None) -> None:
    data = message or {"type": "snapshot", "room": room.public()}
    for member in list(room.members.values()):
        if member.ws is not None and not member.ws.closed:
            with contextlib.suppress(ConnectionError, RuntimeError, asyncio.TimeoutError):
                await asyncio.wait_for(member.ws.send_json(data), timeout=1.0)


async def create_room(request: web.Request):
    rooms = request.app[ROOMS]
    rooms.limit("http:" + (request.remote or "local"))
    data = await body(request)
    room, member = rooms.create(data.get("nickname"), data.get("outfit", "yellow"))
    return web.json_response(credentials(room, member), status=201)


async def join_room(request: web.Request):
    rooms = request.app[ROOMS]
    rooms.limit("http:" + (request.remote or "local"))
    data = await body(request)
    room, member = rooms.join(request.match_info["code"], data.get("nickname"), data.get("outfit", "yellow"))
    await broadcast(room)
    return web.json_response(credentials(room, member), status=201)


async def resume(request: web.Request):
    rooms = request.app[ROOMS]
    rooms.cleanup()
    room, member = rooms.session((await body(request)).get("token"))
    member.last_seen = rooms.clock()
    return web.json_response(credentials(room, member))


async def leave(request: web.Request):
    rooms = request.app[ROOMS]
    room, member = rooms.session((await body(request)).get("token"))
    rooms.remove(room, member)
    if member.ws is not None:
        await member.ws.close(code=1000, message=b"left")
    await broadcast(room)
    return web.json_response({"ok": True})


async def socket(request: web.Request):
    rooms = request.app[ROOMS]
    rooms.limit("ws:" + (request.remote or "local"), maximum=60)
    ws = web.WebSocketResponse(heartbeat=15, max_msg_size=4096, receive_timeout=45)
    await ws.prepare(request)
    room = member = None
    try:
        hello = await asyncio.wait_for(ws.receive_json(), timeout=8)
        if not isinstance(hello, dict) or hello.get("type") != "hello" or hello.get("protocol") != PROTOCOL:
            raise RoomError("游戏版本不同，请刷新页面。", 400, "protocol_mismatch")
        rooms.cleanup()
        room, member = rooms.session(hello.get("token"))
        if member.ws is not None and not member.ws.closed:
            # A duplicated tab must not take over the original player's connection.
            raise RoomError("这个角色已在另一个页面中。请返回入口，用新角色加入。", 409, "already_connected")
        member.ws, member.connected_once, member.sequence = ws, True, -1
        member.last_seen = rooms.clock()
        await ws.send_json({"type": "welcome", "id": member.id, "room": room.public()})
        await broadcast(room)
        async for message in ws:
            if message.type == WSMsgType.TEXT:
                rooms.limit("packet:" + member.id, maximum=60, window=1)
                try:
                    value = json.loads(message.data)
                except (ValueError, UnicodeError):
                    raise RoomError("消息格式无效。") from None
                if not isinstance(value, dict):
                    raise RoomError("消息格式无效。")
                member.last_seen = room.last_active = rooms.clock()
                kind = value.get("type")
                if kind == "pose":
                    if rooms.pose(member, value):
                        await broadcast(room)
                elif kind == "wave":
                    if rooms.clock() - member.last_wave >= 0.7:
                        member.last_wave = rooms.clock()
                        await broadcast(room, {"type": "wave", "id": member.id})
                elif kind == "ping":
                    await ws.send_json({"type": "pong"})
                else:
                    raise RoomError("暂不支持这个操作。")
            elif message.type in (WSMsgType.CLOSE, WSMsgType.CLOSED, WSMsgType.ERROR):
                break
    except RoomError as error:
        with contextlib.suppress(ConnectionError):
            await ws.send_json({"type": "error", "error": error.message, "code": error.code})
        await ws.close(code=1008)
    except (asyncio.TimeoutError, ValueError, TypeError, ConnectionError):
        await ws.close(code=1008)
    finally:
        # Do not detach a live player when a second tab failed to authenticate.
        if member is not None and member.ws is ws:
            member.ws = None
            member.last_seen = rooms.clock()
            if room is not None:
                await broadcast(room)
    return ws


async def health(request: web.Request):
    return web.json_response({"ok": True, "service":"alphabet-island-online", "protocol": PROTOCOL, "capacity": MAX_PLAYERS,
                              "shared_profiles": True,
                              "build_ready": (request.app[BUILD] / "index.html").is_file()})


async def profile_routes(request: web.Request):
    store = request.app[PROFILES]
    if request.method == "GET":
        return web.json_response(store.list_profiles())
    data = await body(request)
    return web.json_response(store.create(data.get("nickname"), data.get("outfit", "yellow"), data.get("legacy_id")), status=201)


async def profile_action(request: web.Request):
    store = request.app[PROFILES]
    profile_id, action = request.match_info["profile_id"], request.match_info["action"]
    if action not in {"lease", "heartbeat", "save", "release", "recoveries"}:
        raise web.HTTPNotFound()
    if request.method == "GET":
        if action != "recoveries":
            raise web.HTTPMethodNotAllowed(request.method, ["POST"])
        return web.json_response(store.recoveries(profile_id))
    # JSON escapes may expand a save's UTF-8 bytes. The state itself is still 8 MB.
    data = await body(request, maximum=MAX_SAVE_BYTES * 2 + 4096 if action in {"save", "recoveries"} else 4096)
    token = data.get("token")
    if action == "lease":
        result = store.acquire(profile_id, token)
    elif action == "heartbeat":
        result = store.heartbeat(profile_id, token)
    elif action == "release":
        result = store.release(profile_id, token)
    elif action == "save":
        result = store.save(profile_id, token, data.get("revision"), data.get("state"))
    else:
        result = store.add_recovery(profile_id, data.get("state"), data.get("base_revision"), data.get("reason"))
    return web.json_response(result)


async def recovery_download(request: web.Request):
    state = request.app[PROFILES].recovery_state(request.match_info["profile_id"], request.match_info["recovery_id"])
    response = web.Response(text=state, content_type="application/json")
    response.headers["Content-Disposition"] = 'attachment; filename="island-recovery.json"'
    return response


async def recovery_restore(request: web.Request):
    data = await body(request)
    return web.json_response(request.app[PROFILES].restore(request.match_info["profile_id"], request.match_info["recovery_id"], data.get("token"), data.get("revision")))


async def launch_native(request: web.Request):
    if request.remote not in {"127.0.0.1", "::1"}:
        raise ProfileError("电脑单机只能在这台电脑的入口启动。", 403, "local_only")
    await body(request)
    store = request.app[PROFILES]
    profile_id = request.match_info["profile_id"]
    profile = store.get_profile(profile_id)
    if profile.get("pending_browser_import", False):
        raise ProfileError("这个角色的旧进度仍在浏览器里，请先从原浏览器进入并保存返回。", 409, "pending_browser_import")
    engine = Path("F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe")
    if not engine.is_file():
        raise ProfileError("没有找到本机 Godot，请使用 start-game.ps1 指定安装位置。", 503, "engine_missing")
    status_path = ROOT / ".local" / ("native-launch-" + secrets.token_hex(12) + ".json")
    status_path.parent.mkdir(parents=True, exist_ok=True)
    command = [sys.executable, str(ROOT / "web/native_runner.py"), "--profile-id", profile_id,
               "--profile-root", str(store.root), "--godot", str(engine), "--status-file", str(status_path), "--no-dialog"]
    process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    try:
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if status_path.is_file():
                try:
                    result = json.loads(status_path.read_text("utf-8"))
                except (ValueError, UnicodeError):
                    await asyncio.sleep(0.1)
                    continue
                if result.get("ok"):
                    return web.json_response(result)
                raise ProfileError(result.get("error", "单机没有启动，请稍后再试。"), 409, result.get("code", "native_launch_failed"))
            if process.poll() is not None:
                raise ProfileError("单机没有启动，请检查本机启动记录。", 503, "native_launch_failed")
            await asyncio.sleep(0.1)
        raise ProfileError("单机仍在启动，请稍等并查看游戏窗口。不要重复启动同一角色。", 504, "native_launch_pending")
    finally:
        with contextlib.suppress(FileNotFoundError):
            status_path.unlink()


async def static(request: web.Request):
    name = request.match_info.get("path", "") or "index.html"
    base = request.app[BUILD]
    path = (base / name).resolve()
    if not path.is_relative_to(base) or not path.is_file() or name.startswith("."):
        raise web.HTTPNotFound()
    response = web.FileResponse(path)
    response.headers["Cache-Control"] = "public, max-age=31536000, immutable" if re.search(r"\.[0-9a-f]{12}\.pck$", path.name) else "no-cache"
    if path.suffix == ".wasm":
        response.content_type = "application/wasm"
    return response


async def lifecycle(app: web.Application):
    async def clean():
        while True:
            await asyncio.sleep(10)
            app[PROFILES].cleanup()
            for room in app[ROOMS].cleanup():
                await broadcast(room)
    task = asyncio.create_task(clean())
    yield
    task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await task
    app[PROFILES].close()
    for room in app[ROOMS].rooms.values():
        for member in room.members.values():
            if member.ws is not None:
                await member.ws.close(code=1001, message=b"server stopping")


def create_app(build: Path | None = None, rooms: Rooms | None = None, profiles: ProfileStore | None = None) -> web.Application:
    app = web.Application(middlewares=[boundary], client_max_size=MAX_SAVE_BYTES * 2 + 4096)
    app[ROOMS], app[BUILD] = rooms or Rooms(), (build or ROOT / "build/web-online").resolve()
    app[PROFILES] = profiles or ProfileStore()
    app.router.add_get("/health", health)
    app.router.add_post("/api/rooms", create_room)
    app.router.add_post("/api/rooms/{code}/join", join_room)
    app.router.add_post("/api/session/resume", resume)
    app.router.add_post("/api/session/leave", leave)
    app.router.add_get("/api/profiles", profile_routes)
    app.router.add_post("/api/profiles", profile_routes)
    app.router.add_post("/api/profiles/{profile_id}/launch-native", launch_native)
    app.router.add_get("/api/profiles/{profile_id}/{action}", profile_action)
    app.router.add_post("/api/profiles/{profile_id}/{action}", profile_action)
    app.router.add_get("/api/profiles/{profile_id}/recoveries/{recovery_id}", recovery_download)
    app.router.add_post("/api/profiles/{profile_id}/recoveries/{recovery_id}/restore", recovery_restore)
    app.router.add_get("/ws", socket)
    app.router.add_get("/{path:.*}", static)
    app.cleanup_ctx.append(lifecycle)
    return app


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=4189)
    parser.add_argument("--build", type=Path, default=ROOT / "build/web-online")
    parser.add_argument("--profile-root", type=Path, default=None, help="Isolated shared-save store for validation")
    args = parser.parse_args()
    # Tokens travel only in JSON bodies; access logging is off for this local service.
    profile_store = ProfileStore(args.profile_root, legacy_path=args.profile_root / "missing-legacy.json") if args.profile_root else ProfileStore()
    web.run_app(create_app(args.build, profiles=profile_store), host=args.host, port=args.port, access_log=None)
