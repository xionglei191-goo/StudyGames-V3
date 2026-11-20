"""Reproducible Blender 5.2+ pipeline for all 92 Layer-2 storybook 3D props (.glb).

Usage:
  blender --background --factory-startup --python-exit-code 1 --python scripts/build_layer2_props_v1.py
  blender --background --factory-startup --python-exit-code 1 --python scripts/build_layer2_props_v1.py -- --render-sheet --sheet-out <png_path>
"""
from __future__ import annotations

import hashlib
import json
import sys
import time
from pathlib import Path

import bpy
from mathutils import Vector

SCRIPT_DIR = Path(__file__).resolve().parent
L2_DIR = SCRIPT_DIR / "layer2_blender"
if str(L2_DIR) not in sys.path:
    sys.path.insert(0, str(L2_DIR))

from builders_home_food import HOME_FOOD_BUILDERS  # noqa: E402
from builders_play_nature import PLAY_NATURE_BUILDERS  # noqa: E402
from builders_wardrobe_study import WARDROBE_STUDY_BUILDERS  # noqa: E402
from primitives import collect_and_export, init_materials, rbox  # noqa: E402
from surface_finishes import finish_blend_materials  # noqa: E402

ROOT = SCRIPT_DIR.parent
OUT_DIR = ROOT / "assets" / "art" / "layer2_storybook_v1"
RUNTIME_DIR = ROOT / "game" / "assets" / "props" / "layer2_storybook_v1"


def parse_cli_args() -> tuple[bool, Path]:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    render_sheet = "--render-sheet" in argv
    sheet_out = OUT_DIR / "layer2_contact_sheet.png"
    if "--sheet-out" in argv:
        idx = argv.index("--sheet-out")
        if idx + 1 < len(argv):
            sheet_out = Path(argv[idx + 1])
    return render_sheet, sheet_out


def main() -> None:
    t0 = time.perf_counter()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    render_sheet, sheet_out = parse_cli_args()

    # Start from a completely clean factory scene
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    init_materials()

    all_builders = (
        list(WARDROBE_STUDY_BUILDERS)
        + list(HOME_FOOD_BUILDERS)
        + list(PLAY_NATURE_BUILDERS)
    )
    seen_keys: set[str] = set()
    for key, _, _ in all_builders:
        if key in seen_keys:
            raise RuntimeError(f"Duplicate builder key: {key}")
        seen_keys.add(key)

    objects: list[bpy.types.Object] = []
    records: list[dict] = []

    print(f"[Layer2Blender] Building & exporting {len(all_builders)} GLB props...")
    for idx, (key, build_fn, target_max_dim) in enumerate(all_builders, start=1):
        obj, rec = collect_and_export(key, build_fn, target_max_dim, OUT_DIR, RUNTIME_DIR)
        obj.hide_set(True)
        objects.append(obj)
        records.append(rec)
        if idx % 15 == 0 or idx == len(all_builders):
            print(
                f"  [{idx:02d}/{len(all_builders)}] {rec['filename']} "
                f"({rec['triangles']} tris, {rec['bytes']} B)"
            )

    # Arrange all 92 props on a neat 10x10 studio grid in the editable .blend source
    cols = 10
    rows = (len(objects) + cols - 1) // cols
    spacing_x = 0.50
    spacing_y = 0.50
    origin_x = -0.5 * (cols - 1) * spacing_x
    origin_y = 0.5 * (rows - 1) * spacing_y

    for i, obj in enumerate(objects):
        r = i // cols
        c = i % cols
        obj.hide_set(False)
        obj.hide_render = False
        obj.location = (origin_x + c * spacing_x, origin_y - r * spacing_y, 0.0)

    blend_path = OUT_DIR / "layer2_storybook_v1.blend"
    finish_blend_materials(ROOT)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    total_bytes = sum(r["bytes"] for r in records)
    total_tris = sum(r["triangles"] for r in records)
    manifest = {
        "schema_version": 1,
        "revision": "layer2-storybook-v1.1",
        "tool": f"Blender {bpy.app.version_string}",
        "source_script": "scripts/build_layer2_props_v1.py",
        "editable_source": {
            "path": "layer2_storybook_v1.blend",
            "sha256": hashlib.sha256(blend_path.read_bytes()).hexdigest(),
        },
        "authorship": "Original Blender 5.2 authored 3D meshes with rounded bevels, lathe revolutions, 3D NURBS tubes, and storybook PBR materials.",
        "surface_details": "Physically scaled local UVs. The editable blend packs the project's original world_refresh_v3 detail and normal tiles. Godot binds these shared maps to the named GLB material finishes.",
        "count": len(records),
        "total_bytes": total_bytes,
        "total_triangles": total_tris,
        "assets": records,
    }
    (OUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (RUNTIME_DIR / "manifest.json").write_text(
        json.dumps(
            {
                "revision": manifest["revision"],
                "count": len(records),
                "assets": {
                    r["id"]: {
                        "runtime_path": r["runtime_path"],
                        "tintable": r["tintable"],
                        "bounds_godot_size": r["bounds_godot_size"],
                        "triangles": r["triangles"],
                    }
                    for r in records
                },
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    dt = time.perf_counter() - t0
    print(
        f"[Layer2Blender] Export complete in {dt:.2f}s: "
        f"{len(records)} GLBs, {total_tris} total tris, {total_bytes / 1024:.1f} KB."
    )

    if render_sheet:
        sheet_out.parent.mkdir(parents=True, exist_ok=True)
        floor_w = cols * spacing_x + 0.9
        floor_d = rows * spacing_y + 0.9
        rbox("Studio_Floor", (0.0, 0.0, -0.03), (floor_w, floor_d, 0.06), "paper", bevel=0.01)

        scene = bpy.context.scene
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 20
        if hasattr(scene.cycles, "use_denoising"):
            scene.cycles.use_denoising = False
        scene.render.resolution_x = 1800
        scene.render.resolution_y = 1680
        scene.render.resolution_percentage = 100
        if scene.world is None:
            scene.world = bpy.data.worlds.new("StudioWorld")
        if scene.world.use_nodes and "Background" in scene.world.node_tree.nodes:
            bg = scene.world.node_tree.nodes["Background"]
            bg.inputs[0].default_value = (0.72, 0.70, 0.66, 1.0)
            bg.inputs[1].default_value = 0.95
        else:
            scene.world.color = (0.68, 0.66, 0.62)

        for loc, power, sz in [
            ((2.2, -5.5, 7.5), 620.0, 7.0),
            ((-4.8, 2.5, 5.2), 280.0, 6.0),
            ((0.0, 5.5, 4.5), 180.0, 5.5),
        ]:
            bpy.ops.object.light_add(type="AREA", location=loc)
            light = bpy.context.object
            light.data.energy = power
            light.data.shape = "DISK"
            light.data.size = sz
            light.rotation_euler = (Vector((0.0, 0.0, 0.0)) - light.location).to_track_quat("-Z", "Y").to_euler()

        bpy.ops.object.camera_add(location=(0.0, -5.8, 7.2))
        cam = bpy.context.object
        cam.rotation_euler = (Vector((0.0, -0.10, 0.08)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 5.45
        scene.camera = cam
        scene.view_settings.view_transform = "AgX"
        scene.render.filepath = str(sheet_out)
        print(f"[Layer2Blender] Rendering studio contact sheet -> {sheet_out} ...")
        bpy.ops.render.render(write_still=True)
        print("[Layer2Blender] Contact sheet rendered successfully.")


if __name__ == "__main__":
    main()
