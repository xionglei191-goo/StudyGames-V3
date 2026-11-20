"""Shared Blender 5.2+ modeling primitives, storybook PBR materials, and GLB exporter."""
from __future__ import annotations

import hashlib
import math
import shutil
from pathlib import Path
from typing import Callable

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector
from surface_finishes import prepare_part


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgba(hex_str: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    h = hex_str.strip().lstrip("#")
    return (
        srgb_to_linear(int(h[0:2], 16) / 255.0),
        srgb_to_linear(int(h[2:4], 16) / 255.0),
        srgb_to_linear(int(h[4:6], 16) / 255.0),
        alpha,
    )


MAT_SPECS: dict[str, tuple[str, str, float, float, float]] = {
    # key: (material_name, hex, roughness, metallic, alpha)
    "tint": ("L2_TintPrimary", "5b9bd5", 0.54, 0.0, 1.0),
    "tint_light": ("L2_TintSecondary", "8fc3ee", 0.56, 0.0, 1.0),
    "tint_dark": ("L2_TintDark", "3a6c9c", 0.60, 0.0, 1.0),
    "cream": ("L2_Cream", "fbf5e6", 0.46, 0.0, 1.0),
    "paper": ("L2_Paper", "f5edd8", 0.78, 0.0, 1.0),
    "white": ("L2_White", "fcfbf8", 0.40, 0.0, 1.0),
    "wood": ("L2_Wood", "c59260", 0.64, 0.0, 1.0),
    "wood_dark": ("L2_WoodDark", "845838", 0.68, 0.0, 1.0),
    "gold": ("L2_Gold", "e3b75e", 0.31, 0.79, 1.0),
    "silver": ("L2_Silver", "d7dadd", 0.27, 0.86, 1.0),
    "charcoal": ("L2_Charcoal", "332d29", 0.55, 0.05, 1.0),
    "leaf": ("L2_Leaf", "5fae62", 0.60, 0.0, 1.0),
    "leaf_light": ("L2_LeafLight", "90d27d", 0.58, 0.0, 1.0),
    "berry": ("L2_Berry", "df524a", 0.44, 0.0, 1.0),
    "orange": ("L2_Orange", "ef8b38", 0.48, 0.0, 1.0),
    "yellow": ("L2_Yellow", "f5cf48", 0.46, 0.0, 1.0),
    "bread": ("L2_Bread", "dca362", 0.72, 0.0, 1.0),
    "crumb": ("L2_Crumb", "f4e0ba", 0.76, 0.0, 1.0),
    "apple_flesh": ("L2_AppleFlesh", "f4dfac", 0.57, 0.0, 1.0),
    "terracotta": ("L2_Terracotta", "cb7952", 0.72, 0.0, 1.0),
    "soil": ("L2_Soil", "614633", 0.88, 0.0, 1.0),
    "pink": ("L2_Pink", "ee98ae", 0.54, 0.0, 1.0),
    "sky": ("L2_Sky", "6ebae8", 0.44, 0.0, 1.0),
    "water": ("L2_GlassWater", "82ccf0", 0.12, 0.04, 0.66),
    "glass": ("L2_ClearGlass", "d1e4e3", 0.12, 0.0, 0.27),
}

MATERIALS: dict[str, bpy.types.Material] = {}


def init_materials() -> dict[str, bpy.types.Material]:
    MATERIALS.clear()
    for key, (mname, hx, rough, metal, alpha) in MAT_SPECS.items():
        mat = bpy.data.materials.get(mname) or bpy.data.materials.new(mname)
        if not mat.use_nodes:
            mat.use_nodes = True
        col = rgba(hx, alpha)
        mat.diffuse_color = col
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = col
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if alpha < 0.999:
            bsdf.inputs["Alpha"].default_value = alpha
            if hasattr(mat, "surface_render_method"):
                mat.surface_render_method = "BLENDED"
        MATERIALS[key] = mat
    return MATERIALS


def _apply_rot_and_finish(obj: bpy.types.Object, name: str, mat_key: str, rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0), smooth: bool = True) -> bpy.types.Object:
    obj.name = name
    mat = MATERIALS[mat_key]
    if len(obj.data.materials) == 0:
        obj.data.materials.append(mat)
    else:
        obj.data.materials[0] = mat
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    if any(abs(a) > 1e-5 for a in rot_deg):
        obj.rotation_euler = Euler(tuple(math.radians(a) for a in rot_deg), "XYZ")
    return obj


def rbox(
    name: str,
    loc: tuple[float, float, float],
    size: tuple[float, float, float],
    mat: str = "tint",
    bevel: float = 0.018,
    segs: int = 3,
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
    subsurf: int = 0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    min_dim = min(size)
    bv = min(bevel, min_dim * 0.42)
    if bv > 0.0008:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bv
        mod.segments = segs
        mod.limit_method = "NONE"
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if subsurf > 0:
        sub = obj.modifiers.new("Subsurf", "SUBSURF")
        sub.levels = subsurf
        sub.render_levels = subsurf
        bpy.ops.object.modifier_apply(modifier=sub.name)
    return _apply_rot_and_finish(obj, name, mat, rot, True)


def rcyl(
    name: str,
    loc: tuple[float, float, float],
    radius: float,
    depth: float,
    mat: str = "tint",
    bevel: float = 0.010,
    verts: int = 36,
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    bv = min(bevel, min(radius, depth) * 0.38)
    if bv > 0.0006:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bv
        mod.segments = 3
        mod.angle_limit = math.radians(35.0)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return _apply_rot_and_finish(obj, name, mat, rot, True)


def rcone(
    name: str,
    loc: tuple[float, float, float],
    r_bottom: float,
    r_top: float,
    depth: float,
    mat: str = "tint",
    bevel: float = 0.008,
    verts: int = 36,
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r_bottom, radius2=r_top, depth=depth, location=loc)
    obj = bpy.context.object
    bv = min(bevel, min(max(r_bottom, r_top), depth) * 0.28)
    if bv > 0.0006 and r_top > 0.003:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bv
        mod.segments = 2
        mod.angle_limit = math.radians(32.0)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return _apply_rot_and_finish(obj, name, mat, rot, True)


def ellipsoid(
    name: str,
    loc: tuple[float, float, float],
    radii: tuple[float, float, float],
    mat: str = "tint",
    segs: int = 32,
    rings: int = 18,
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=1.0, location=loc)
    obj = bpy.context.object
    obj.scale = radii
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _apply_rot_and_finish(obj, name, mat, rot, True)


def rtorus(
    name: str,
    loc: tuple[float, float, float],
    major_r: float,
    minor_r: float,
    mat: str = "tint",
    major_seg: int = 36,
    minor_seg: int = 16,
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_r,
        minor_radius=minor_r,
        major_segments=major_seg,
        minor_segments=minor_seg,
        location=loc,
    )
    obj = bpy.context.object
    return _apply_rot_and_finish(obj, name, mat, rot, True)


def curve_tube(
    name: str,
    points: list[tuple[float, float, float]],
    radius: float,
    mat: str = "wood",
    closed: bool = False,
    bevel_res: int = 3,
    smooth_spline: bool = True,
    radii_mult: list[float] | None = None,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = bevel_res
    curve.fill_mode = "FULL"
    curve.use_fill_caps = True
    curve.resolution_u = 8 if smooth_spline else 2

    stype = "NURBS" if (smooth_spline and len(points) >= 3) else "POLY"
    spline = curve.splines.new(stype)
    spline.points.add(len(points) - 1)
    for idx, p in enumerate(points):
        spline.points[idx].co = (p[0], p[1], p[2], 1.0)
        if radii_mult and idx < len(radii_mult):
            spline.points[idx].radius = radii_mult[idx]
    spline.use_cyclic_u = closed
    if stype == "NURBS" and not closed:
        spline.use_endpoint_u = True
        spline.order_u = min(4, len(points))

    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return _apply_rot_and_finish(bpy.context.object, name, mat, (0.0, 0.0, 0.0), True)


def lathe(
    name: str,
    profile_rz: list[tuple[float, float]],
    mat: str = "cream",
    steps: int = 40,
    loc: tuple[float, float, float] = (0.0, 0.0, 0.0),
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
    subsurf: int = 1,
) -> bpy.types.Object:
    """Revolve a 2D (radius, z) profile around Z axis to create smooth vessels, bowls, bottles, bells."""
    bm = bmesh.new()
    prof_verts = [bm.verts.new((max(0.0, r), 0.0, z)) for r, z in profile_rz]
    edges = [bm.edges.new((prof_verts[i], prof_verts[i + 1])) for i in range(len(prof_verts) - 1)]
    bmesh.ops.spin(
        bm,
        geom=prof_verts + edges,
        cent=(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        angle=math.tau,
        steps=steps,
        use_merge=True,
    )
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if subsurf > 0:
        sub = obj.modifiers.new("Subsurf", "SUBSURF")
        sub.levels = subsurf
        sub.render_levels = subsurf
        bpy.ops.object.modifier_apply(modifier=sub.name)
    return _apply_rot_and_finish(obj, name, mat, rot, True)


def botanical_leaf(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    width: float,
    arch: float = 0.018,
    mat: str = "leaf",
    vein_mat: str = "leaf_light",
) -> list[bpy.types.Object]:
    a, b = Vector(start), Vector(end)
    d = b - a
    perp = Vector((-d.y, d.x, 0.0))
    if perp.length < 1e-5:
        perp = Vector((1.0, 0.0, 0.0))
    side = perp.normalized() * width
    q1 = a.lerp(b, 0.35) + Vector((0.0, 0.0, arch * 0.85))
    mid = a.lerp(b, 0.55) + Vector((0.0, 0.0, arch))
    q3 = a.lerp(b, 0.80) + Vector((0.0, 0.0, arch * 0.55))
    thick = Vector((0.0, 0.0, max(0.004, width * 0.12)))

    verts = [
        a,
        q1 + side * 0.78,
        mid + side,
        q3 + side * 0.58,
        b,
        q3 - side * 0.58,
        mid - side,
        q1 - side * 0.78,
        mid + thick,
        mid - thick,
    ]
    faces = [
        (0, 1, 8), (1, 2, 8), (2, 3, 8), (3, 4, 8),
        (4, 5, 8), (5, 6, 8), (6, 7, 8), (7, 0, 8),
        (1, 0, 9), (2, 1, 9), (3, 2, 9), (4, 3, 9),
        (5, 4, 9), (6, 5, 9), (7, 6, 9), (0, 7, 9),
    ]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([ tuple(v) for v in verts ], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    bpy.ops.object.modifier_apply(modifier=sub.name)
    _apply_rot_and_finish(obj, name, mat, (0.0, 0.0, 0.0), True)
    vein = curve_tube(
        name + "_vein",
        [tuple(a + Vector((0, 0, 0.004))), tuple(mid + thick * 1.05), tuple(b)],
        max(0.0025, width * 0.07),
        vein_mat,
    )
    return [obj, vein]


def star_mesh(
    name: str,
    loc: tuple[float, float, float],
    outer_r: float,
    inner_r: float,
    thickness: float,
    points: int = 5,
    mat: str = "yellow",
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    verts: list[tuple[float, float, float]] = []
    n = points * 2
    for i in range(n):
        ang = math.pi / 2.0 + i * math.tau / n
        r = outer_r if (i % 2 == 0) else inner_r
        verts.append((r * math.cos(ang), r * math.sin(ang), 0.0))
    verts.append((0.0, 0.0, thickness * 0.5))
    verts.append((0.0, 0.0, -thickness * 0.5))
    top_i = n
    bot_i = n + 1
    faces = []
    for i in range(n):
        nxt = (i + 1) % n
        faces.append((i, nxt, top_i))
        faces.append((nxt, i, bot_i))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    bpy.ops.object.modifier_apply(modifier=sub.name)
    return _apply_rot_and_finish(obj, name, mat, rot, True)


def collect_and_export(
    key: str,
    build_fn: Callable[[], None],
    target_max_dim: float | None,
    out_dir: Path,
    runtime_dir: Path,
) -> tuple[bpy.types.Object, dict]:
    existing = set(bpy.data.objects)
    build_fn()
    created = [o for o in bpy.data.objects if o not in existing and o.type == "MESH"]
    if not created:
        raise RuntimeError(f"Builder '{key}' produced no mesh objects!")
    for part in created:
        prepare_part(key, part)

    bpy.ops.object.select_all(action="DESELECT")
    for o in created:
        o.select_set(True)
    bpy.context.view_layer.objects.active = created[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(created) > 1:
        bpy.ops.object.join()

    obj = bpy.context.object
    obj.name = f"L2_{key}"

    # Clean topology & normals
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()

    # Center X/Y and ground min Z == 0.0, then normalize max dimension to target_max_dim
    coords = [v.co.copy() for v in obj.data.vertices]
    lo = [min(c[i] for c in coords) for i in range(3)]
    hi = [max(c[i] for c in coords) for i in range(3)]
    cx = 0.5 * (lo[0] + hi[0])
    cy = 0.5 * (lo[1] + hi[1])
    min_z = lo[2]
    cur_max = max(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], 1e-4)
    if target_max_dim is not None:
        xf = Matrix.Scale(target_max_dim / cur_max, 4) @ Matrix.Translation(Vector((-cx, -cy, -min_z)))
        obj.data.transform(xf)
    obj.data.update()

    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    obj.location = (0.0, 0.0, 0.0)

    # Textured parts already carry physical-scale UVs in their own grain direction.
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    obj.data.calc_loop_triangles()
    coords2 = [v.co for v in obj.data.vertices]
    lo2 = [min(c[i] for c in coords2) for i in range(3)]
    hi2 = [max(c[i] for c in coords2) for i in range(3)]

    glb_name = f"l2_{key}.glb"
    src_glb = out_dir / glb_name
    rt_glb = runtime_dir / glb_name

    bpy.ops.export_scene.gltf(
        filepath=str(src_glb),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )
    shutil.copy2(src_glb, rt_glb)

    mat_names = [m.name for m in obj.data.materials if m is not None]
    record = {
        "id": key,
        "filename": glb_name,
        "runtime_path": f"res://assets/props/{runtime_dir.name}/{glb_name}",
        "sha256": hashlib.sha256(rt_glb.read_bytes()).hexdigest(),
        "bytes": rt_glb.stat().st_size,
        "vertices": len(obj.data.vertices),
        "triangles": len(obj.data.loop_triangles),
        "materials": mat_names,
        "tintable": any(m.startswith("L2_Tint") for m in mat_names),
        "bounds_godot_min": [round(lo2[0], 4), round(lo2[2], 4), round(-hi2[1], 4)],
        "bounds_godot_size": [
            round(hi2[0] - lo2[0], 4),
            round(hi2[2] - lo2[2], 4),
            round(hi2[1] - lo2[1], 4),
        ],
        "pivot": "bottom_center_grounded",
    }
    return obj, record
