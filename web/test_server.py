"""Real HTTP/WebSocket tests plus deterministic invitation expiry checks."""
import asyncio
import json
import tempfile
import unittest
from pathlib import Path

from aiohttp import WSMsgType
from aiohttp.test_utils import TestClient, TestServer

from server import MAX_PLAYERS, RECONNECT_SECONDS, RoomError, Rooms, create_app


class RoomRules(unittest.TestCase):
    def setUp(self):
        self.now = 100.0
        self.rooms = Rooms(lambda: self.now)

    def test_capacity_identity_and_private_records(self):
        room, first = self.rooms.create("小芽")
        for number in range(MAX_PLAYERS - 1):
            self.rooms.join(room.code, "朋友" + str(number))
        with self.assertRaises(RoomError) as error:
            self.rooms.join(room.code, "第五位")
        self.assertEqual(error.exception.code, "room_full")
        public = json.dumps(room.public(), ensure_ascii=False)
        self.assertNotIn(first.token, public)
        self.assertNotIn("learning", public)
        self.assertEqual(len({m.id for m in room.members.values()}), 4)
        self.assertEqual(len({m.token for m in room.members.values()}), 4)

    def test_reconnect_grace_and_host_transfer(self):
        room, host = self.rooms.create("主人")
        _, guest = self.rooms.join(room.code, "客人")
        host.connected_once = True
        self.now += RECONNECT_SECONDS - 1
        self.rooms.cleanup()
        self.assertEqual(self.rooms.session(host.token)[1].id, host.id)
        self.now += 2
        self.rooms.cleanup()
        self.assertEqual(room.host, guest.id)
        with self.assertRaises(RoomError):
            self.rooms.session(host.token)

    def test_loading_reservation_is_bounded(self):
        room, member = self.rooms.create("慢慢来")
        self.now += 600
        self.rooms.cleanup()
        self.assertIn(member.id, room.members)
        self.now += 1201
        self.rooms.cleanup()
        self.assertFalse(room.members)
        self.now += 901
        self.rooms.cleanup()
        self.assertNotIn(room.code, self.rooms.rooms)

    def test_pose_validation_order_and_no_foreign_mutations(self):
        room, first = self.rooms.create("小芽")
        _, second = self.rooms.join(room.code, "小云")
        pose = {"seq":1, "scene":"village", "p":[1.0,0.1,2.0], "r":1.2,
                "outfit":"blue", "moving":True, "id":second.id,
                "learning":{"mastered":True}, "coins":99999}
        self.assertTrue(self.rooms.pose(first, pose))
        self.assertIsNone(second.pose)
        self.assertEqual(first.outfit, "blue")
        self.assertNotIn("learning", first.pose)
        self.assertNotIn("coins", first.pose)
        self.assertFalse(self.rooms.pose(first, {**pose,"p":[2,0,3]}))
        self.assertEqual(first.pose["p"], [1.0,0.1,2.0])
        for bad in [{"scene":"missing"}, {"p":[float('nan'),0,0]},
                    {"p":[0,0]}, {"p":[10000,0,0]}, {"outfit":[]}, {"r":True}]:
            with self.subTest(bad=bad), self.assertRaises(RoomError):
                self.rooms.pose(first, {**pose,"seq":2,**bad})
        self.assertEqual(first.sequence, 1)

    def test_names_and_input_types(self):
        for name in [None, [], "<>\n\t"]:
            with self.subTest(name=name), self.assertRaises(RoomError):
                self.rooms.create(name)
        with self.assertRaises(RoomError):
            self.rooms.create("朋友", [])
        _, member = self.rooms.create(" <小芽> \n")
        self.assertEqual(member.nickname, "小芽")


class NetworkRoutes(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "index.html").write_text("<h1>test island</h1>", encoding="utf-8")
        (self.root / "index.wasm").write_bytes(b"\x00asm")
        self.rooms = Rooms()
        self.client = TestClient(TestServer(create_app(self.root, self.rooms)))
        await self.client.start_server()
        self.sockets = []

    async def asyncTearDown(self):
        for ws in self.sockets:
            await ws.close()
        await self.client.close()
        self.temp.cleanup()

    async def create(self, name="小芽"):
        response = await self.client.post("/api/rooms", json={"nickname":name,"outfit":"yellow"})
        self.assertEqual(response.status, 201)
        return await response.json()

    async def connect(self, session):
        ws = await self.client.ws_connect("/ws")
        self.sockets.append(ws)
        await ws.send_json({"type":"hello","protocol":1,"token":session["token"]})
        first = await self.until(ws, lambda value: value.get("type") in {"welcome","error"})
        return ws, first

    async def until(self, ws, predicate):
        for _ in range(30):
            message = await asyncio.wait_for(ws.receive(), timeout=3)
            self.assertEqual(message.type, WSMsgType.TEXT)
            value = json.loads(message.data)
            if predicate(value):
                return value
        self.fail("Expected packet did not arrive")

    async def test_http_and_same_origin(self):
        response = await self.client.get("/health")
        self.assertTrue((await response.json())["build_ready"])
        response = await self.client.get("/")
        self.assertEqual(response.status, 200)
        self.assertIn("test island", await response.text())
        response = await self.client.get("/index.wasm")
        self.assertEqual(response.content_type, "application/wasm")
        response = await self.client.get("/server.py")
        self.assertEqual(response.status, 404)
        response = await self.client.post("/api/rooms", json={"nickname":"小芽"}, headers={"Origin":"https://unrelated.invalid"})
        self.assertEqual(response.status, 403)
        response = await self.client.post("/api/rooms", json=[])
        self.assertEqual(response.status, 400)
        response = await self.client.post("/api/rooms", json={"nickname":"小芽","outfit":[]})
        self.assertEqual(response.status, 400)
        response = await self.client.post("/api/session/resume", json={"token":"missing"})
        self.assertEqual(response.status, 401)

    async def test_two_players_pose_wave_and_separate_room(self):
        first = await self.create()
        code = first["room"]["code"]
        response = await self.client.post(f"/api/rooms/{code}/join", json={"nickname":"小云","outfit":"blue"})
        second = await response.json()
        ws1, welcome1 = await self.connect(first)
        ws2, welcome2 = await self.connect(second)
        self.assertEqual(welcome1["id"], first["id"])
        self.assertEqual(welcome2["id"], second["id"])
        other = await self.create("另一座岛")
        ws3, welcome3 = await self.connect(other)
        self.assertEqual(len(welcome3["room"]["members"]), 1)
        await ws1.send_json({"type":"pose","seq":1,"scene":"village","p":[1,0.2,2],"r":0,"outfit":"pink","moving":True})
        packet = await self.until(ws2, lambda value: value.get("type") == "snapshot" and any(m["id"] == first["id"] and m["pose"] for m in value["room"]["members"]))
        seen = next(m for m in packet["room"]["members"] if m["id"] == first["id"])
        self.assertEqual(seen["pose"]["p"], [1,0.2,2])
        self.assertEqual(seen["outfit"], "pink")
        self.assertNotIn(other["id"], json.dumps(packet))
        self.assertNotIn(first["token"], json.dumps(packet))
        self.assertIsNone(self.rooms.session(other["token"])[1].pose)
        await ws1.send_json({"type":"wave"})
        wave = await self.until(ws2, lambda value: value.get("type") == "wave")
        self.assertEqual(wave["id"], first["id"])
        await ws1.close()
        disconnected = await self.until(ws2, lambda value: value.get("type") == "snapshot" and any(m["id"] == first["id"] and not m["online"] for m in value["room"]["members"]))
        self.assertEqual(len(disconnected["room"]["members"]), 2)
        restored, welcome = await self.connect(first)
        self.assertEqual(welcome["id"], first["id"])
        self.assertEqual(len(welcome["room"]["members"]), 2)
        response = await self.client.post("/api/session/leave", json={"token":first["token"]})
        self.assertEqual(response.status, 200)
        self.assertEqual(self.rooms.rooms[code].host, second["id"])

    async def test_duplicate_session_cannot_displace_first_tab(self):
        first = await self.create()
        original, _ = await self.connect(first)
        duplicate, failure = await self.connect(first)
        self.assertEqual(failure["code"], "already_connected")
        self.assertFalse(original.closed)
        await original.send_json({"type":"ping"})
        self.assertEqual((await self.until(original, lambda v: v.get("type") == "pong"))["type"], "pong")

    async def test_full_room_unknown_code_and_bad_protocol(self):
        first = await self.create()
        for number in range(3):
            response = await self.client.post(f'/api/rooms/{first["room"]["code"]}/join', json={"nickname":f"朋友{number}"})
            self.assertEqual(response.status, 201)
        response = await self.client.post(f'/api/rooms/{first["room"]["code"]}/join', json={"nickname":"第五位"})
        self.assertEqual(response.status, 409)
        self.assertEqual((await response.json())["code"], "room_full")
        response = await self.client.post('/api/rooms/AAAAAAAA/join', json={"nickname":"朋友"})
        self.assertEqual(response.status, 404)
        ws = await self.client.ws_connect('/ws')
        self.sockets.append(ws)
        await ws.send_json({"type":"hello","protocol":99,"token":first["token"]})
        failure = await self.until(ws, lambda value: value.get("type") == "error")
        self.assertEqual(failure["code"], "protocol_mismatch")


if __name__ == "__main__":
    unittest.main(verbosity=2)
