"""Split an unencrypted Godot 4.7 PCK into one initial pack and lazy interior packs.

Resource payloads and MD5s are copied byte-for-byte; Blender sources/imports stay unchanged.
The writer deliberately rejects other pack versions rather than guessing their format.
"""
from __future__ import annotations
import hashlib
import json
import os
import re
import shutil
import struct
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/web-online"
SOURCE = BUILD / "index.pck"


def read_pack(path: Path):
    rows = []
    with path.open("rb") as stream:
        header = stream.read(112)
        magic, version, major, minor, patch, flags = struct.unpack("<6I", header[:24])
        if (magic, version, flags) != (0x43504447, 4, 2):
            raise ValueError("Expected a Godot v4 unencrypted PCK with relative file offsets")
        base, directory = struct.unpack("<QQ", header[24:40])
        if base != 112:
            raise ValueError("Unexpected PCK header size")
        stream.seek(directory)
        count = struct.unpack("<I", stream.read(4))[0]
        for _ in range(count):
            length = struct.unpack("<I", stream.read(4))[0]
            name = stream.read(length).rstrip(b"\0").decode("utf-8")
            offset, size = struct.unpack("<QQ", stream.read(16))
            digest = stream.read(16)
            entry_flags = struct.unpack("<I", stream.read(4))[0]
            if entry_flags != 0:
                raise ValueError("Encrypted or removed pack entries are unsupported")
            if offset + base + size > directory:
                raise ValueError("PCK entry extends outside its data region")
            rows.append({"path":name, "offset":offset + base, "size":size, "md5":digest})
    return header, rows


def imported_sources(rows):
    reverse = {}
    for path in (ROOT / "game").rglob("*.import"):
        text = path.read_text("utf-8")
        source = re.search(r'source_file="(.*?)"', text)
        if source:
            for target in re.findall(r'"(res://\.godot/[^"\n]+)"', text):
                reverse[target[6:]] = source[1][6:]
    with SOURCE.open("rb") as stream:
        for row in rows:
            if row["path"].endswith(".remap") and row["size"] < 4096:
                stream.seek(row["offset"])
                text = stream.read(row["size"]).decode("utf-8", errors="replace")
                target = re.search(r'path="res://([^"\n]+)"', text)
                if target:
                    reverse[target[1]] = row["path"][:-6]
    return reverse


def write_pack(header: bytes, rows: list, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    table = []
    with SOURCE.open("rb") as source, path.open("wb") as output:
        output.write(header)
        for row in rows:
            output.write(b"\0" * (-output.tell() % 16))
            relative = output.tell() - 112
            source.seek(row["offset"])
            remaining = row["size"]
            digest = hashlib.md5()
            while remaining:
                chunk = source.read(min(remaining, 1024 * 1024))
                if not chunk:
                    raise ValueError("Truncated input pack")
                output.write(chunk)
                digest.update(chunk)
                remaining -= len(chunk)
            if digest.digest() != row["md5"]:
                raise ValueError("Input resource checksum mismatch: " + row["path"])
            table.append((row, relative))
        output.write(b"\0" * (-output.tell() % 16))
        directory = output.tell()
        output.write(struct.pack("<I", len(table)))
        for row, relative in table:
            name = row["path"].encode("utf-8") + b"\0"
            name += b"\0" * (-len(name) % 4)
            output.write(struct.pack("<I", len(name)) + name)
            output.write(struct.pack("<QQ", relative, row["size"]))
            output.write(row["md5"] + struct.pack("<I", 0))
        output.seek(32)
        output.write(struct.pack("<Q", directory))
    with path.open("rb") as packed:
        return hashlib.file_digest(packed, "sha256").hexdigest()


def main():
    header, rows = read_pack(SOURCE)
    reverse = imported_sources(rows)
    room_ids = sorted((row["room_id"] for row in json.loads((ROOT / "game/data/interiors_manifest.json").read_text("utf-8"))["rooms"]), key=len, reverse=True)
    groups = defaultdict(list)
    for row in rows:
        source = reverse.get(row["path"], row["path"])
        group = "initial"
        if source.startswith("assets/interiors/"):
            filename = source.rsplit("/", 1)[-1]
            for room in room_ids:
                if filename.startswith(room + ".") or filename.startswith(room + "_"):
                    group = room
                    break
        groups[group].append(row)
    manifest = {}
    staging = ROOT / ".local/web-pack-staging"
    staging.mkdir(parents=True, exist_ok=True)
    for group, entries in sorted(groups.items()):
        target = staging / (group + ".pck")
        digest = write_pack(header, entries, target)
        if group == "initial":
            initial = target
        else:
            relative = f"packs/{group}.{digest[:12]}.pck"
            destination = BUILD / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            os.replace(target, destination)
            manifest[group] = {"url":relative, "sha256":digest, "bytes":destination.stat().st_size}
    original_bytes = SOURCE.stat().st_size
    os.replace(initial, SOURCE)
    with SOURCE.open("rb") as stream:
        initial_hash = hashlib.file_digest(stream, "sha256").hexdigest()
    main_pack_name = "island." + initial_hash[:12] + ".pck"
    hashed_pack = BUILD / main_pack_name
    if not hashed_pack.exists():
        # Never hardlink the export target: the next export truncates index.pck in place.
        temporary = hashed_pack.with_suffix(".tmp")
        shutil.copyfile(SOURCE, temporary)
        os.replace(temporary, hashed_pack)
    html = (BUILD / "index.html").read_text("utf-8")
    match = re.search(r'window.ALPHABET_ENGINE_CONFIG = (.*?);</script>', html)
    if not match:
        raise ValueError("Expected the online HTML shell")
    config = json.loads(match[1])
    config["mainPack"] = main_pack_name
    config["fileSizes"].pop("index.pck", None)
    config["fileSizes"][main_pack_name] = SOURCE.stat().st_size
    replacement = "window.ALPHABET_ENGINE_CONFIG = " + json.dumps(config, ensure_ascii=False) + ";window.ALPHABET_ROOM_PACKS = " + json.dumps(manifest, ensure_ascii=False) + ";</script>"
    html = html[:match.start()] + replacement + html[match.end():]
    (BUILD / "index.html").write_text(html, encoding="utf-8")
    report = {"original_pack_bytes":original_bytes, "initial_pack_bytes":SOURCE.stat().st_size,
              "main_pack":main_pack_name, "main_pack_sha256":initial_hash,
              "engine_bytes":(BUILD / "index.wasm").stat().st_size,
              "room_count":len(manifest), "rooms":manifest,
              "resource_count":len(rows), "resource_payloads_md5_verified":True}
    (BUILD / "build-info.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({key:value for key,value in report.items() if key != "rooms"}, indent=2))


if __name__ == "__main__":
    main()
