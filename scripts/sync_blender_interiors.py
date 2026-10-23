"""Validate and copy exported Blender rooms into the game without editing source art."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/blender/interiors/interiors_manifest.json"
TARGET = ROOT / "game/assets/interiors"
MANIFEST = ROOT / "game/data/interiors_manifest.json"
EXPECTED = {f"landmark_{chr(65+i)}" for i in range(26)} | {
    "school", "classroom", "music_room", "art_room", "science_room", "canteen", "playground", "football_field", "home",
    "home_estate", "home_bedroom", "home_kitchen", "home_dining", "home_bathroom", "home_study", "home_balcony"
}
REQUIRED = {"SG_SPAWN", "SG_EXIT", "SG_NPC_HOST"} | {
    f"SG_MEMORY_{i:02}" for i in range(1, 6)
}


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def source_path(value: str) -> Path:
    path = (ROOT / value).resolve()
    path.relative_to(ROOT)
    if not path.is_file():
        raise ValueError(f"Missing source asset: {value}")
    return path


def inspect_glb(path: Path, room_id: str) -> dict:
    with path.open("rb") as stream:
        magic, version, length = struct.unpack("<4sII", stream.read(12))
        if magic != b"glTF" or version != 2 or length != path.stat().st_size:
            raise ValueError(f"Invalid GLB header: {path}")
        chunk_length, chunk_type = struct.unpack("<II", stream.read(8))
        if chunk_type != 0x4E4F534A:
            raise ValueError(f"Missing GLB JSON: {path}")
        data = json.loads(stream.read(chunk_length))
    names = [node.get("name", "") for node in data.get("nodes", [])]
    required = set(REQUIRED)
    if room_id == "school":
        required |= {"SG_DOOR_CLASSROOM", "SG_DOOR_MUSIC_ROOM", "SG_DOOR_ART_ROOM", "SG_DOOR_SCIENCE_ROOM", "SG_DOOR_CANTEEN", "SG_DOOR_PLAYGROUND", "SG_DOOR_FOOTBALL_FIELD"}
    if room_id == "home":
        required |= {"SG_BED", "SG_WARDROBE"}
        required |= {f"SG_DECOR_MODEL_{name}" for name in ("FLOWER_BOX", "PICNIC", "LAMP")}
    if room_id == "home_estate":
        required.add("SG_HOUSE_ENTRY")
        required |= {"SG_DOOR_" + name.upper() for name in ("home", "home_bedroom", "home_kitchen", "home_dining", "home_bathroom", "home_study", "home_balcony")}
    if room_id == "home_bedroom":
        required |= {"SG_BED", "SG_WARDROBE"}
    missing = required - set(names)
    duplicate = {name for name in required if names.count(name) > 1}
    if missing or duplicate:
        raise ValueError(f"{room_id}: missing markers {sorted(missing)}, duplicate markers {sorted(duplicate)}")
    floors = [name for name in names if name.startswith("SG_FLOOR_")]
    colliders = [name for name in names if name.startswith("SG_COLLIDER_")]
    if not floors or not colliders:
        raise ValueError(f"{room_id}: expected exported floor and collision proxies")
    external = [image["uri"] for image in data.get("images", []) if image.get("uri") and not image["uri"].startswith("data:")]
    if external:
        raise ValueError(f"{room_id}: images are not embedded: {external}")
    return {"nodes":len(names),"floor_meshes":len(floors),"collision_proxies":len(colliders),
            "required_markers":sorted(required),"bytes":length,"images":len(data.get("images", []))}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--require-all", action="store_true")
    args = parser.parse_args()
    if not SOURCE.exists():
        raise SystemExit("Blender interiors have not been exported yet: " + str(SOURCE))
    source = json.loads(SOURCE.read_text(encoding="utf-8-sig"))
    entries = source.get("rooms", [])
    ids = [entry["room_id"] for entry in entries]
    if len(ids) != len(set(ids)) or set(ids) - EXPECTED:
        raise SystemExit("Invalid or duplicate room IDs in Blender manifest")
    if args.require_all and set(ids) != EXPECTED:
        raise SystemExit("Rooms not yet exported: " + ", ".join(sorted(EXPECTED-set(ids))))
    validated = []
    for entry in entries:
        room_id = entry["room_id"]
        original = source_path(entry["glb"])
        blend = source_path(entry["blend"])
        check = inspect_glb(original, room_id)
        sha = digest(original)
        target = TARGET / (room_id + ".glb")
        if args.verify_only:
            if not target.exists() or digest(target) != sha:
                raise SystemExit("Game asset is not synchronized: " + room_id)
        validated.append({"room_id":room_id,"name":entry.get("name",room_id),
                          "source_glb":str(original.relative_to(ROOT)).replace("\\","/"),
                          "source_blend":str(blend.relative_to(ROOT)).replace("\\","/"),
                          "game_glb":f"res://assets/interiors/{room_id}.glb",
                          "source_sha256":sha,"bounds":entry.get("bounds",[]),"validation":check})
    if not args.verify_only:
        TARGET.mkdir(parents=True,exist_ok=True)
        for entry in validated:
            original = ROOT / entry["source_glb"]
            target = TARGET / (entry["room_id"] + ".glb")
            if not target.exists() or digest(target) != entry["source_sha256"]:
                temp = target.with_suffix(".glb.tmp")
                shutil.copy2(original,temp)
                if digest(temp) != entry["source_sha256"]:
                    raise SystemExit("Copy verification failed: " + str(temp))
                temp.replace(target)
        output = {"schema_version":1,"source":"Blender room exports","rooms":validated}
        MANIFEST.parent.mkdir(parents=True,exist_ok=True)
        temp = MANIFEST.with_suffix(".json.tmp")
        temp.write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        temp.replace(MANIFEST)
    elif not MANIFEST.exists():
        raise SystemExit("Game interiors manifest is missing")
    else:
        current = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {(v["room_id"],v["source_sha256"]) for v in validated}
        actual = {(v["room_id"],v["source_sha256"]) for v in current["rooms"]}
        if expected != actual:
            raise SystemExit("Game interiors manifest is not synchronized")
    print(json.dumps({"status":"verified" if args.verify_only else "synchronized",
                      "rooms":len(validated),"expected":len(EXPECTED),
                      "missing":sorted(EXPECTED-set(ids))},ensure_ascii=False))


if __name__ == "__main__":
    main()
