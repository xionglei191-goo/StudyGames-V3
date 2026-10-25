"""Non-destructive game export. Run in a separate Blender background process.

The first run opens v05 and saves a new v06_game working file. Later runs use
the manifest's current version, retain object/marker edits, and add missing markers.
No source geometry is regenerated and no v05 file is written.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

BASE = Path(__file__).resolve().parent
PROJECT = BASE.parents[2]
SOURCE = BASE / "alphabet_island_layout_v05.blend"
WORKING = BASE / "alphabet_island_layout_v06_game.blend"
OUTPUT = BASE / "alphabet_island_layout_v06_game.glb"
MANIFEST = BASE / "game_map_manifest.json"
EXPORT_VERSION = 6
if MANIFEST.is_file():
    _current_manifest = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    WORKING = (PROJECT / _current_manifest.get("working_blend", str(WORKING.relative_to(PROJECT)))).resolve()
    WORKING.relative_to(BASE.resolve())
    OUTPUT = WORKING.with_suffix(".glb")
    EXPORT_VERSION = int(_current_manifest.get("version", 6))
EXCLUDED = ("editor_only", "presentation_only", "site_clearance_hidden", "superseded_by_v03", "superseded_by_v04", "superseded_by_v05", "school_site_clearance")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def eligible(obj):
    if obj.name == "ALPHA_Ocean_Presentation":
        return True
    return obj.type not in {"LIGHT", "CAMERA"} and not any(obj.get(key, False) for key in EXCLUDED)


def prepare_export_geometry():
    """Convert renderable curves in memory after saving the editable source."""
    curves = [obj for obj in bpy.context.scene.objects if eligible(obj) and obj.type in {"CURVE", "FONT", "SURFACE"}]
    if curves:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in curves:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = curves[0]
        bpy.ops.object.convert(target="MESH")


def collision_kind(obj):
    if obj.type != "MESH" or not eligible(obj):
        return "none"
    name = obj.name.lower()
    collections = " ".join(c.name.lower() for c in obj.users_collection)
    if name in {"alpha_central_lake", "alpha_river_water", "alpha_v3_lake_deep_to_shallow"}:
        return "water"
    if "_tripo_" in name:
        return "building"
    if any(part in name for part in ["_cream_walls", "_main_walls", "_wing_walls", "_library_walls", "_canteen_walls"]):
        return "building"
    if "_trunk" in name:
        return "trunk"
    if name == "alpha_home_fountain_base":
        return "fountain"
    if any(part in name for part in ["_fence_rail", "_boundary_rail", "bridge_rail", "_fence_post", "gate_pier"]):
        return "barrier"
    if any(part in name for part in ["continuous_terrain", "coastal_sand_shelf", "lake_islet", "_plot_pad", "_entry_step", "_porch_plank", "_courtyard_base", "_home_plaza", "_home_stone_foundation"]):
        return "ground"
    if "paths" in collections and "lamp" not in name:
        return "ground"
    if "bridges_docks" in collections and any(part in name for part in ["_deck", "_plank"]):
        return "ground"
    if "plots" in collections and obj.type == "MESH":
        return "ground"
    if any(part in name for part in ["entry_paver", "gate_paver", "entry_stone", "porch_deck", "orchard_path", "welcome_court", "school_stair"]):
        return "ground"
    return "none"


def world_bounds(objects):
    points = [obj.matrix_world @ Vector(p) for obj in objects if obj.type == "MESH" for p in obj.bound_box]
    if not points:
        raise RuntimeError("No mesh bounds available")
    return Vector([min(p[i] for p in points) for i in range(3)]), Vector([max(p[i] for p in points) for i in range(3)])


def main():
    args = argparse.ArgumentParser()
    args.add_argument("--inspect", action="store_true")
    parsed = args.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    scene = bpy.data.scenes.get("Alphabet_Island_Layout_v01") or bpy.context.scene
    bpy.context.window.scene = scene
    bpy.context.view_layer.update()
    objects = [obj for obj in scene.objects if eligible(obj)]
    kinds = {obj.name: collision_kind(obj) for obj in objects if obj.type == "MESH"}
    if parsed.inspect:
        report = {"file": bpy.data.filepath, "objects": len(objects), "collections": {c.name: len(c.objects) for c in bpy.data.collections}, "collision_counts": dict(Counter(kinds.values())), "ground_names": [n for n, k in kinds.items() if k == "ground"], "building_names": [n for n, k in kinds.items() if k == "building"], "anchors": [{"name": o.name, "position": list(o.matrix_world.translation)} for o in objects if "LOCUS_01" in o.name or "SCHOOL_ANCHOR" in o.name or o.name == "ALPHA_Home_Cream_Walls"]}
        (BASE / "game_map_inspection.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print("SG_INSPECTION", json.dumps(report["collision_counts"]))
        return
    before_hash = sha256(SOURCE)
    if scene.get("sg_source_v05_sha256") and scene["sg_source_v05_sha256"] != before_hash:
        raise RuntimeError("The original v05 source changed since v06 was initialized")
    markers_collection = bpy.data.collections.get("SG_Gameplay_Markers")
    if markers_collection is None:
        markers_collection = bpy.data.collections.new("SG_Gameplay_Markers")
        scene.collection.children.link(markers_collection)
    graph = bpy.context.evaluated_depsgraph_get()
    floors = [(o, BVHTree.FromObject(o, graph)) for o in objects if kinds.get(o.name) == "ground"]

    def ground_height(x, y, fallback):
        highest = None
        for obj, tree in floors:
            inverse = obj.matrix_world.inverted()
            origin = inverse @ Vector((x, y, 250))
            direction = (inverse.to_3x3() @ Vector((0, 0, -1))).normalized()
            hit, _normal, _index, _distance = tree.ray_cast(origin, direction, 600)
            if hit is not None:
                point = obj.matrix_world @ hit
                if highest is None or point.z > highest:
                    highest = point.z
        return fallback if highest is None else highest

    def add_marker(name, parent, xyz, kind, **properties):
        marker = bpy.data.objects.get(name)
        created = marker is None
        if created:
            marker = bpy.data.objects.new(name, None)
            markers_collection.objects.link(marker)
            marker.empty_display_type = "ARROWS"
            marker.empty_display_size = .7
            marker.show_in_front = True
            marker.parent = parent
            marker.matrix_parent_inverse = Matrix.Identity(4)
            marker.matrix_world = Matrix.Translation(Vector(xyz))
        marker["sg_kind"] = kind
        marker["sg_generated_initial_position"] = created or marker.get("sg_generated_initial_position", False)
        for key, value in properties.items():
            if key not in marker:
                marker[key] = value
        bpy.context.view_layer.update()
        return marker

    layout = json.loads((BASE / "layout.json").read_text(encoding="utf-8"))
    rows = {row["letter"]: row for row in layout["landmarks"]}
    doors = {}
    for letter, row in rows.items():
        socket = bpy.data.objects[f"ALPHA_LANDMARK_{letter}_SOCKET"]
        meshes = [o for o in socket.children_recursive if o.type == "MESH" and eligible(o)]
        mn, mx = world_bounds(meshes)
        point = Vector(((mn.x + mx.x) / 2, mn.y - 1.9, mn.z))
        anchor = bpy.data.objects.get(f"ALPHA_{letter}_LOCUS_01")
        if letter == "B" and anchor:
            point = anchor.matrix_world.translation.copy()
        point.z = ground_height(point.x, point.y, point.z) + .06
        doors[letter] = add_marker(f"SG_DOOR_{letter}", socket, point, "door", sg_id=f"landmark_{letter}", sg_destination=f"landmark_{letter}", sg_label=f"{letter} · {row['name']}", sg_radius=2.6)
    home = bpy.data.objects["ALPHA_Home_Cream_Walls"]
    mn, mx = world_bounds([home])
    point = Vector(((mn.x + mx.x) / 2, mn.y - 2.0, mn.z))
    point.z = ground_height(point.x, point.y, point.z) + .06
    home_door = add_marker("SG_DOOR_HOME", home, point, "door", sg_id="home_gate", sg_destination="home", sg_label="回到我的小屋", sg_radius=2.6)
    school = bpy.data.objects["ALPHA_SCHOOL_ROOT"]
    # The v05 reserved SCHOOL_ANCHOR_* empties all resolve to (0,0,0).
    # Derive the working marker from the actual two masonry gate piers instead.
    gate_piers = [o for o in objects if o.name.startswith("ALPHA_School_Gate_Pier")]
    if len(gate_piers) != 2:
        raise RuntimeError("Expected two physical school gate piers")
    gate_min, gate_max = world_bounds(gate_piers)
    point = Vector(((gate_min.x + gate_max.x) / 2, gate_min.y - .9, gate_min.z))
    point.z = ground_height(point.x, point.y, point.z) + .06
    add_marker("SG_DOOR_SCHOOL", school, point, "door", sg_id="school_gate", sg_destination="school", sg_label="进入字母学校", sg_radius=2.7)
    point = home_door.matrix_world.translation + Vector((-3.2, -3.0, 0))
    point.z = ground_height(point.x, point.y, point.z) + .08
    add_marker("SG_SPAWN", home, point, "spawn")
    point = home_door.matrix_world.translation + Vector((3.1, -1.5, 0))
    point.z = ground_height(point.x, point.y, point.z) + .04
    add_marker("SG_NPC_BEAR", home, point, "npc", sg_npc="bear", sg_name="熊叔", sg_id="baker", sg_label="和熊叔打招呼", sg_radius=2.5, sg_greeting="good_morning")
    point = doors["C"].matrix_world.translation + Vector((-3.1, -1.0, 0))
    point.z = ground_height(point.x, point.y, point.z) + .04
    add_marker("SG_NPC_RABBIT", bpy.data.objects["ALPHA_LANDMARK_C_SOCKET"], point, "npc", sg_npc="rabbit", sg_name="兔兔", sg_id="gardener", sg_label="和兔兔聊聊", sg_radius=2.5, sg_greeting="hello")
    point = doors["A"].matrix_world.translation + Vector((4.2, -.6, 0))
    point.z = ground_height(point.x, point.y, point.z) + .04
    add_marker("SG_APPLE_TREE", bpy.data.objects["ALPHA_LANDMARK_A_SOCKET"], point, "collect", sg_id="orchard", sg_label="采摘果园里的苹果", sg_radius=2.6)
    point = doors["C"].matrix_world.translation + Vector((3.2, -.7, 0))
    point.z = ground_height(point.x, point.y, point.z) + .04
    add_marker("SG_BAKERY_SHOP", bpy.data.objects["ALPHA_LANDMARK_C_SOCKET"], point, "shop", sg_id="bakery", sg_label="逛逛蛋糕商店", sg_radius=2.5)
    # Only fill missing collision tags, so artists may override one object in v06.
    for obj in objects:
        if obj.type == "MESH" and "sg_collision" not in obj:
            obj["sg_collision"] = kinds[obj.name]
    # Recover external textures by basename when the original Mac path is stale.
    relinked = []
    for image in bpy.data.images:
        if image.packed_file or not image.filepath:
            continue
        resolved = Path(bpy.path.abspath(image.filepath))
        if not resolved.exists():
            matches = list(BASE.rglob(Path(image.filepath).name))
            if matches:
                image.filepath = str(matches[0])
                image.reload()
                relinked.append(image.name)
    scene["sg_game_export_version"] = EXPORT_VERSION
    scene["sg_source_v05_sha256"] = before_hash
    scene["sg_editing_note"] = "Edit this current versioned working file; sync preserves existing SG markers and all model edits."
    bpy.ops.wm.save_as_mainfile(filepath=str(WORKING), compress=True)
    prepare_export_geometry()
    bpy.ops.object.select_all(action="DESELECT")
    exported = [obj for obj in scene.objects if eligible(obj)]
    for obj in exported:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", use_selection=True, use_active_scene=True, export_apply=True, export_extras=True, export_cameras=False, export_lights=False, export_yup=True)
    after_hash = sha256(SOURCE)
    assert before_hash == after_hash, "v05 source was modified"
    mn, mx = world_bounds([o for o in exported if "continuous_terrain" in o.name.lower()])
    markers = [{"name": o.name, "parent": o.parent.name if o.parent else None, "world_blender": list(o.matrix_world.translation), "world_godot": [o.matrix_world.translation.x, o.matrix_world.translation.z, -o.matrix_world.translation.y], "properties": {key: o[key] for key in o.keys() if key.startswith("sg_")}} for o in exported if o.name.startswith("SG_")]
    report = {"version": 6, "working_blend": str(WORKING.relative_to(PROJECT)), "working_blend_sha256": sha256(WORKING), "source_v05_sha256": before_hash, "source_v05_glb_sha256": sha256(BASE / "alphabet_island_layout_v05.glb"), "source_preserved": before_hash == after_hash, "glb_sha256": sha256(OUTPUT), "glb_bytes": OUTPUT.stat().st_size, "marker_count": len(markers), "markers": markers, "collision_counts": dict(Counter(o.get("sg_collision", "none") for o in exported if o.type == "MESH")), "collision_by_node": {o.name: o.get("sg_collision", "none") for o in exported if o.type == "MESH"}, "terrain_bounds_godot": [mn.x, -mx.y, mx.x - mn.x, mx.y - mn.y], "textures_relinked": relinked, "coordinate_contract": "Marker world_godot is audit only. Runtime reads imported node global transforms, never these stored coordinates."}
    # Preserve versioned preview/provenance fields through the ordinary export path.
    report = {**globals().get("_current_manifest", {}), **report}
    report["version"] = EXPORT_VERSION
    report["working_glb"] = str(OUTPUT.relative_to(PROJECT))
    with OUTPUT.open("rb") as stream:
        header = stream.read(20)
        data = json.loads(stream.read(struct.unpack_from("<I", header, 12)[0]))
    report["triangles"] = sum(data["accessors"][p["indices"] if "indices" in p else p["attributes"]["POSITION"]]["count"] // 3
                              for node in data.get("nodes", []) if "mesh" in node for p in data["meshes"][node["mesh"]].get("primitives", []) if p.get("mode",4)==4)
    MANIFEST.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("SG_EXPORT_OK", json.dumps({key: report[key] for key in ["marker_count", "collision_counts", "source_preserved", "glb_bytes"]}))


if __name__ == "__main__":
    main()
