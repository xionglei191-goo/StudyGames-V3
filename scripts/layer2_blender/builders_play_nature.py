"""Blender 5.2+ builders for Toys, Sports, Music, Weather/Science, Plants & Animals (23 models)."""
from __future__ import annotations

import math
import bpy
from mathutils import Vector
from mathutils.geometry import interpolate_bezier

from primitives import (
    MATERIALS,
    botanical_leaf,
    curve_tube,
    ellipsoid,
    lathe,
    rbox,
    rcone,
    rcyl,
    rtorus,
    star_mesh,
)


def build_teddy() -> None:
    ellipsoid("Bear_torso", (0.0, 0.0, 0.095), (0.082, 0.072, 0.088), "tint")
    ellipsoid("Bear_belly", (0.0, -0.056, 0.092), (0.052, 0.024, 0.058), "cream")
    ellipsoid("Bear_head", (0.0, -0.005, 0.215), (0.076, 0.070, 0.072), "tint_light")
    ellipsoid("Bear_snout", (0.0, -0.068, 0.200), (0.032, 0.026, 0.025), "cream")
    ellipsoid("Bear_nose", (0.0, -0.090, 0.206), (0.012, 0.009, 0.009), "charcoal")
    for sx in (-1.0, 1.0):
        ellipsoid("Bear_ear", (sx * 0.058, 0.0, 0.272), (0.026, 0.016, 0.026), "tint")
        ellipsoid("Bear_inner_ear", (sx * 0.058, -0.010, 0.270), (0.015, 0.008, 0.015), "pink")
        ellipsoid("Bear_eye", (sx * 0.028, -0.068, 0.228), (0.009, 0.008, 0.009), "charcoal")
        ellipsoid("Bear_arm", (sx * 0.088, -0.018, 0.118), (0.028, 0.032, 0.056), "tint", rot=(18.0, sx * -22.0, 0.0))
        ellipsoid("Bear_leg", (sx * 0.052, -0.058, 0.038), (0.034, 0.052, 0.034), "tint")
        ellipsoid("Bear_pad", (sx * 0.052, -0.104, 0.038), (0.022, 0.010, 0.022), "cream")
    rtorus("Bear_ribbon", (0.0, 0.0, 0.158), 0.056, 0.009, "berry")


def build_ball() -> None:
    ellipsoid("PlayBall_core", (0.0, 0.0, 0.115), (0.115, 0.115, 0.115), "tint", segs=36, rings=20)
    rtorus("PlayBall_band_eq", (0.0, 0.0, 0.115), 0.114, 0.009, "cream")
    rtorus("PlayBall_band_mer", (0.0, 0.0, 0.115), 0.114, 0.008, "yellow", rot=(90.0, 0.0, 0.0))
    for sz in (-1.0, 1.0):
        ellipsoid("PlayBall_cap", (0.0, 0.0, 0.115 + sz * 0.108), (0.038, 0.038, 0.014), "white")


def build_football() -> None:
    ellipsoid("Soccer_white", (0.0, 0.0, 0.115), (0.115, 0.115, 0.115), "white", segs=38, rings=22)
    # 12 regular icosahedron directions for classic black soccer pentagons!
    phi = (1.0 + math.sqrt(5.0)) * 0.5
    dirs = [
        (0, 1, phi), (0, -1, phi), (0, 1, -phi), (0, -1, -phi),
        (1, phi, 0), (-1, phi, 0), (1, -phi, 0), (-1, -phi, 0),
        (phi, 0, 1), (-phi, 0, 1), (phi, 0, -1), (-phi, 0, -1),
    ]
    for dx, dy, dz in dirs:
        ln = math.sqrt(dx * dx + dy * dy + dz * dz)
        nx, ny, nz = dx / ln, dy / ln, dz / ln
        px, py, pz = nx * 0.111, ny * 0.111, 0.115 + nz * 0.111
        pitch = math.degrees(math.acos(max(-1.0, min(1.0, nz))))
        yaw = math.degrees(math.atan2(ny, nx)) + 90.0
        rcyl("Soccer_pent", (px, py, pz), 0.034, 0.012, "charcoal", bevel=0.004, verts=5, rot=(pitch, 0.0, yaw))


def build_basketball() -> None:
    ellipsoid("BBall_orange", (0.0, 0.0, 0.115), (0.115, 0.115, 0.115), "orange", segs=38, rings=22)
    rtorus("BBall_seam_h", (0.0, 0.0, 0.115), 0.115, 0.0045, "charcoal")
    rtorus("BBall_seam_v1", (0.0, 0.0, 0.115), 0.115, 0.0045, "charcoal", rot=(90.0, 0.0, 0.0))
    rtorus("BBall_seam_v2", (0.0, 0.0, 0.115), 0.115, 0.0045, "charcoal", rot=(90.0, 0.0, 90.0))
    for sx in (-1.0, 1.0):
        rtorus("BBall_rib", (sx * 0.056, 0.0, 0.115), 0.098, 0.0042, "charcoal", rot=(0.0, 90.0, 0.0))


def build_kite() -> None:
    rbox("Kite_stand", (0.0, 0.035, 0.015), (0.14, 0.06, 0.026), "wood", bevel=0.008)
    rbox("Kite_diamond", (0.0, -0.005, 0.175), (0.19, 0.016, 0.19), "tint", bevel=0.008, rot=(-14.0, 45.0, 0.0))
    rbox("Kite_inner", (0.0, -0.014, 0.175), (0.12, 0.008, 0.12), "tint_light", bevel=0.005, rot=(-14.0, 45.0, 0.0))
    rbox("Kite_spar_v", (0.0, -0.018, 0.175), (0.010, 0.010, 0.25), "wood", bevel=0.002, rot=(-14.0, 0.0, 0.0))
    rbox("Kite_spar_h", (0.0, -0.018, 0.175), (0.25, 0.010, 0.010), "wood", bevel=0.002, rot=(-14.0, 0.0, 0.0))
    curve_tube("Kite_tail", [(0.0, 0.02, 0.055), (0.055, -0.02, 0.032), (0.115, -0.055, 0.022)], 0.006, "cream")
    for tx, ty, mk in [(0.048, -0.018, "berry"), (0.098, -0.048, "yellow")]:
        rbox("Kite_bow", (tx, ty, 0.032), (0.032, 0.018, 0.012), mk, bevel=0.004, rot=(0.0, 0.0, 28.0))


def build_rope() -> None:
    for r, z in [(0.105, 0.020), (0.088, 0.038)]:
        rtorus("Rope_coil", (0.0, 0.015, z), r, 0.014, "tint")
    for sx, yaw in ((-0.105, -26.0), (0.105, 26.0)):
        rcone("Rope_handle", (sx, -0.068, 0.034), 0.020, 0.014, 0.115, "berry", bevel=0.005, rot=(78.0, 0.0, yaw))
        rcyl("Rope_collar", (sx * 0.85, -0.018, 0.042), 0.022, 0.018, "cream", bevel=0.004, rot=(78.0, 0.0, yaw))


def build_bell() -> None:
    lathe(
        "Bell_cup",
        [(0.022, 0.165), (0.036, 0.160), (0.072, 0.115), (0.112, 0.038), (0.122, 0.024), (0.110, 0.022), (0.064, 0.108), (0.020, 0.155)],
        "gold",
        steps=40,
    )
    ellipsoid("Bell_clapper", (0.0, 0.0, 0.030), (0.024, 0.024, 0.024), "gold")
    lathe(
        "Bell_handle",
        [(0.0, 0.162), (0.024, 0.165), (0.018, 0.215), (0.028, 0.268), (0.018, 0.285), (0.0, 0.285)],
        "wood_dark",
        steps=32,
    )


def _soundbox(name, width, height, depth, waist):
    # A single double-bout outline with maple ribs, a spruce face and binding.
    segments = [
        ((0, 0), (.61, -.012), (1, .11), (1, .29)),
        ((1, .29), (1, .43), (waist, .46), (waist, .56)),
        ((waist, .56), (waist, .66), (.79, .67), (.77, .79)),
        ((.77, .79), (.73, .94), (.40, 1.0), (0, 1.0)),
    ]
    side = []
    for points in segments:
        controls = [Vector((x * width, 0, 0.026 + z * height)) for x, z in points]
        side.extend(interpolate_bezier(*controls, 9)[:-1])
    side.append(Vector((0, 0, 0.026 + height)))
    outline = side + [Vector((-p.x, 0, p.z)) for p in reversed(side[1:-1])]
    n = len(outline)
    verts = [(p.x, y, p.z) for y in (depth, -depth) for p in outline]
    faces = [tuple(reversed(range(n)))]
    faces.extend((i, (i+1)%n, n+(i+1)%n, n+i) for i in range(n))
    faces.append(tuple(range(n, 2*n)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(MATERIALS["wood"])
    mesh.materials.append(MATERIALS["wood_dark"])
    for face in list(mesh.polygons)[1:-1]:
        face.material_index = 1
        face.use_smooth = True
    curve_tube(name+"_binding", [(p.x, -depth, p.z) for p in outline],
               0.0017, "cream", closed=True, smooth_spline=False, bevel_res=1)


def _strings(name, number, bridge, nut, spread):
    for i in range(number):
        t = (i / (number-1) - 0.5) * spread
        curve_tube(name+"_string", [(t, bridge[0], bridge[1]), (t*0.68, nut[0], nut[1])],
                   0.00085, "silver", smooth_spline=False, bevel_res=1)


def build_violin() -> None:
    rbox("Violin_stand", (0,0.008,0.012), (0.13,0.075,0.024), "wood_dark", bevel=0.008)
    _soundbox("Violin_maple_body",0.069,0.191,0.018,0.40)
    rbox("Violin_neck",(0,0,0.255),(0.023,0.023,0.130),"wood_dark",bevel=0.006)
    rbox("Violin_fingerboard",(0,-0.016,0.246),(0.027,0.009,0.155),"charcoal",bevel=0.004)
    rbox("Violin_bridge",(0,-0.021,0.11),(0.043,0.019,0.006),"wood",bevel=0.002)
    rbox("Violin_tailpiece",(0,-0.023,0.065),(0.020,0.010,0.050),"charcoal",bevel=0.007)
    for s in (-1,1):
        curve_tube("Violin_soundhole",[(s*0.032,-0.019,0.086),(s*0.039,-0.020,0.087),
            (s*0.037,-0.020,0.101),(s*0.028,-0.020,0.130),(s*0.031,-0.020,0.141),
            (s*0.037,-0.019,0.138)],0.0021,"charcoal",bevel_res=2)
        for z in (0.322,0.338):
            ellipsoid("Violin_peg",(s*0.020,0,z+s*0.003),(0.010,0.005,0.006),"charcoal",segs=12,rings=8)
    ellipsoid("Violin_scroll",(0,0.001,0.345),(0.015,0.016,0.025),"wood")
    _strings("Violin",4,(-0.031,0.082),(-0.024,0.321),0.028)
    curve_tube("Violin_bow",[(0.072,-0.024,0.016),(0.086,-0.022,0.160),(0.103,-0.024,0.337)],0.0033,"wood_dark")
    curve_tube("Violin_horsehair",[(0.079,-0.024,0.044),(0.103,-0.024,0.334)],0.0013,"cream")


def build_guitar() -> None:
    rbox("Guitar_stand",(0,0.01,0.013),(0.14,0.082,0.026),"wood_dark",bevel=0.008)
    _soundbox("Guitar_spruce_body",0.094,0.215,0.025,0.56)
    rcyl("Guitar_soundhole",(0,-0.026,0.165),0.026,0.002,"charcoal",bevel=0,rot=(90,0,0))
    rtorus("Guitar_rosette",(0,-0.027,0.165),0.029,0.002,"wood_dark",rot=(90,0,0))
    rtorus("Guitar_rosette_inlay",(0,-0.027,0.165),0.033,0.0012,"cream",rot=(90,0,0))
    rbox("Guitar_bridge",(0,-0.028,0.089),(0.069,0.010,0.013),"wood_dark",bevel=0.004)
    rbox("Guitar_saddle",(0,-0.035,0.093),(0.042,0.004,0.003),"cream",bevel=0)
    rbox("Guitar_neck",(0,-0.013,0.276),(0.027,0.025,0.165),"wood_dark",bevel=0.005)
    rbox("Guitar_fretboard",(0,-0.027,0.274),(0.030,0.006,0.167),"charcoal",bevel=0.002)
    for i in range(1,14):
        z = 0.357 - 0.264 * (1.0 - 2**(-i/12))
        rbox("Guitar_fret",(0,-0.030,z),(0.030,0.002,0.0015),"silver",bevel=0)
    rbox("Guitar_head",(0,-0.009,0.382),(0.039,0.018,0.053),"wood",bevel=0.006)
    for s in (-1,1):
        for z in (0.368,0.383,0.398):
            ellipsoid("Guitar_tuner",(s*0.022,-0.009,z),(0.008,0.004,0.004),"silver",segs=12,rings=8)
    _strings("Guitar",6,(-0.036,0.093),(-0.032,0.362),0.038)


def build_star() -> None:
    rbox("Star_pedestal", (0.0, 0.0, 0.014), (0.12, 0.07, 0.024), "cream", bevel=0.008)
    star_mesh("Star_plump", (0.0, 0.0, 0.145), 0.135, 0.062, 0.068, 5, "yellow", rot=(90.0, 0.0, 0.0))


def build_sun() -> None:
    for px in (-0.055, 0.0, 0.055):
        ellipsoid("Sun_cloud_base", (px, 0.0, 0.028), (0.048, 0.038, 0.028), "white")
    ellipsoid("Sun_core", (0.0, 0.0, 0.165), (0.088, 0.042, 0.088), "yellow")
    for i in range(10):
        ang = i * math.tau / 10.0
        rx, rz = 0.115 * math.cos(ang), 0.165 + 0.115 * math.sin(ang)
        rcone("Sun_ray", (rx, 0.0, rz), 0.022, 0.006, 0.048, "orange" if i % 2 == 0 else "yellow", bevel=0.003, rot=(0.0, 90.0 - math.degrees(ang), 0.0))


def build_cloud() -> None:
    rcyl("Cloud_stand_base", (0.0, 0.0, 0.010), 0.065, 0.018, "cream", bevel=0.006)
    rcyl("Cloud_stand_rod", (0.0, 0.0, 0.055), 0.008, 0.085, "water", bevel=0.002)
    for cx, cy, cz, rx, rz in [
        (0.0, 0.0, 0.135, 0.075, 0.062),
        (-0.068, 0.005, 0.115, 0.056, 0.046),
        (0.068, -0.005, 0.118, 0.058, 0.048),
        (-0.028, -0.018, 0.155, 0.052, 0.046),
        (0.035, 0.012, 0.152, 0.048, 0.044),
    ]:
        ellipsoid("Cloud_puff", (cx, cy, cz), (rx, 0.055, rz), "white")


def build_rain_jar() -> None:
    lathe(
        "RainJar_glass",
        [(0.0, 0.0), (0.082, 0.0), (0.095, 0.028), (0.095, 0.175), (0.068, 0.205), (0.068, 0.228), (0.058, 0.228), (0.058, 0.018), (0.0, 0.018)],
        "water",
        steps=38,
    )
    rcyl("RainJar_cork", (0.0, 0.0, 0.232), 0.062, 0.028, "wood", bevel=0.006)
    for cx, cz, r in [(-0.024, 0.165, 0.032), (0.018, 0.170, 0.036), (0.0, 0.158, 0.030)]:
        ellipsoid("RainJar_cloud", (cx, 0.0, cz), (r, r * 0.85, r * 0.78), "white")
    for dx, dz in [(-0.028, 0.095), (0.005, 0.068), (0.030, 0.105)]:
        rcone("RainJar_drop", (dx, 0.0, dz), 0.014, 0.003, 0.034, "sky", bevel=0.002)


def build_pinwheel() -> None:
    rcyl("Pin_base", (0.0, 0.0, 0.014), 0.068, 0.026, "wood", bevel=0.008)
    rcyl("Pin_stick", (0.0, 0.018, 0.135), 0.008, 0.23, "wood", bevel=0.002)
    mats = ["tint", "yellow", "berry", "leaf_light"]
    for i in range(4):
        ang = i * 90.0 + 25.0
        rad = math.radians(ang)
        px, pz = 0.052 * math.cos(rad), 0.225 + 0.052 * math.sin(rad)
        ellipsoid(f"Pin_blade_{i}", (px, -0.005, pz), (0.056, 0.014, 0.028), mats[i], rot=(18.0, -ang, 0.0))
    ellipsoid("Pin_hub", (0.0, -0.018, 0.225), (0.020, 0.014, 0.020), "white")


def _terracotta_pot() -> None:
    lathe(
        "Pot_terra",
        [(0.0, 0.0), (0.062, 0.0), (0.086, 0.105), (0.094, 0.108), (0.094, 0.128), (0.080, 0.128), (0.056, 0.016), (0.0, 0.016)],
        "terracotta",
        steps=36,
    )
    ellipsoid("Pot_soil", (0.0, 0.0, 0.114), (0.080, 0.080, 0.016), "soil")


def build_flower() -> None:
    _terracotta_pot()
    curve_tube("Flower_stem", [(0.0, 0.0, 0.115), (-0.012, 0.0, 0.185), (0.008, -0.008, 0.255)], 0.009, "leaf")
    botanical_leaf("Flower_leaf_l", (-0.006, 0.0, 0.155), (-0.082, -0.02, 0.195), 0.026, 0.012, "leaf")
    botanical_leaf("Flower_leaf_r", (-0.002, 0.0, 0.175), (0.078, 0.015, 0.212), 0.024, 0.012, "leaf")
    for i in range(6):
        ang = i * math.tau / 6.0
        px, pz = 0.008 + 0.044 * math.cos(ang), 0.262 + 0.044 * math.sin(ang)
        ellipsoid(f"Flower_petal_{i}", (px, -0.016, pz), (0.028, 0.012, 0.020), "tint", rot=(14.0, -math.degrees(ang), 0.0))
    ellipsoid("Flower_center", (0.008, -0.022, 0.262), (0.024, 0.014, 0.024), "yellow")


def build_plant() -> None:
    _terracotta_pot()
    for i in range(6):
        ang = i * math.tau / 6.0
        h = 0.235 if i % 2 == 0 else 0.198
        ex, ey = 0.105 * math.cos(ang), 0.105 * math.sin(ang)
        curve_tube(f"Plant_petiole_{i}", [(0.0, 0.0, 0.115), (ex * 0.45, ey * 0.45, h * 0.78)], 0.006, "leaf")
        botanical_leaf(f"Plant_blade_{i}", (ex * 0.32, ey * 0.32, 0.145), (ex, ey, h), 0.034, 0.018, "leaf" if i % 2 == 0 else "leaf_light")


def build_leaf() -> None:
    botanical_leaf("Single_leaf", (-0.115, 0.035, 0.022), (0.115, -0.025, 0.068), 0.075, 0.028, "leaf", "leaf_light")
    curve_tube("Leaf_petiole", [(-0.155, 0.048, 0.012), (-0.110, 0.034, 0.024)], 0.008, "wood_dark")


def build_bee() -> None:
    botanical_leaf("Bee_base_leaf", (-0.085, 0.03, 0.014), (0.095, -0.02, 0.032), 0.062, 0.016, "leaf")
    ellipsoid("Bee_body", (0.0, 0.0, 0.115), (0.062, 0.086, 0.058), "yellow")
    for sy in (-0.028, 0.022):
        rtorus("Bee_stripe", (0.0, sy, 0.115), 0.054, 0.011, "charcoal", rot=(90.0, 0.0, 0.0))
    for sx in (-1.0, 1.0):
        ellipsoid("Bee_wing", (sx * 0.058, 0.012, 0.168), (0.052, 0.028, 0.008), "water", rot=(12.0, sx * -24.0, sx * 18.0))
        ellipsoid("Bee_eye", (sx * 0.026, -0.075, 0.128), (0.010, 0.008, 0.010), "charcoal")
        curve_tube("Bee_ant", [(sx * 0.016, -0.068, 0.158), (sx * 0.034, -0.092, 0.192)], 0.004, "charcoal")


def build_bird() -> None:
    rcyl("Bird_perch", (0.0, 0.0, 0.018), 0.014, 0.18, "wood", bevel=0.004, rot=(0.0, 90.0, 0.0))
    ellipsoid("Bird_body", (0.0, 0.012, 0.088), (0.062, 0.082, 0.058), "tint", rot=(12.0, 0.0, 0.0))
    ellipsoid("Bird_breast", (0.0, -0.032, 0.082), (0.046, 0.048, 0.046), "cream")
    ellipsoid("Bird_head", (0.0, -0.035, 0.155), (0.048, 0.048, 0.046), "tint_light")
    rcone("Bird_beak", (0.0, -0.092, 0.152), 0.016, 0.002, 0.036, "orange", bevel=0.002, rot=(90.0, 0.0, 0.0))
    rbox("Bird_tail", (0.0, 0.098, 0.098), (0.046, 0.068, 0.012), "tint_dark", bevel=0.004, rot=(-24.0, 0.0, 0.0))
    for sx in (-1.0, 1.0):
        ellipsoid("Bird_wing", (sx * 0.058, 0.015, 0.092), (0.016, 0.056, 0.034), "tint_dark", rot=(14.0, 0.0, 0.0))
        ellipsoid("Bird_eye", (sx * 0.034, -0.065, 0.162), (0.008, 0.008, 0.008), "charcoal")


def build_duck() -> None:
    ellipsoid("Duck_body", (0.0, 0.015, 0.068), (0.078, 0.098, 0.062), "yellow")
    rcone("Duck_tail", (0.0, 0.105, 0.092), 0.032, 0.006, 0.048, "yellow", bevel=0.003, rot=(-55.0, 0.0, 0.0))
    ellipsoid("Duck_head", (0.0, -0.048, 0.148), (0.054, 0.054, 0.052), "yellow")
    ellipsoid("Duck_bill", (0.0, -0.105, 0.138), (0.032, 0.034, 0.014), "orange")
    for sx in (-1.0, 1.0):
        ellipsoid("Duck_wing", (sx * 0.072, 0.018, 0.075), (0.018, 0.058, 0.034), "orange", rot=(8.0, 0.0, 0.0))
        ellipsoid("Duck_eye", (sx * 0.036, -0.082, 0.158), (0.008, 0.008, 0.008), "charcoal")


def build_cat() -> None:
    ellipsoid("Cat_body", (0.0, 0.018, 0.082), (0.068, 0.078, 0.076), "tint")
    ellipsoid("Cat_chest", (0.0, -0.038, 0.082), (0.044, 0.032, 0.056), "cream")
    ellipsoid("Cat_head", (0.0, -0.018, 0.185), (0.066, 0.058, 0.058), "tint_light")
    rtorus("Cat_collar", (0.0, -0.012, 0.136), 0.044, 0.008, "berry")
    ellipsoid("Cat_bell", (0.0, -0.058, 0.132), (0.012, 0.012, 0.012), "gold")
    for sx in (-1.0, 1.0):
        rcone("Cat_ear", (sx * 0.042, -0.012, 0.242), 0.024, 0.003, 0.045, "tint", bevel=0.002, rot=(0.0, sx * 14.0, 0.0))
        ellipsoid("Cat_eye", (sx * 0.026, -0.068, 0.192), (0.009, 0.008, 0.010), "charcoal")
        ellipsoid("Cat_paw", (sx * 0.032, -0.058, 0.022), (0.022, 0.028, 0.018), "cream")
    ellipsoid("Cat_nose", (0.0, -0.074, 0.178), (0.009, 0.007, 0.007), "pink")
    curve_tube("Cat_tail", [(0.0, 0.088, 0.042), (0.068, 0.075, 0.058), (0.088, 0.015, 0.115)], 0.013, "tint_dark")


def build_dog() -> None:
    ellipsoid("Dog_body", (0.0, 0.018, 0.084), (0.070, 0.084, 0.076), "tint")
    ellipsoid("Dog_chest", (0.0, -0.042, 0.082), (0.046, 0.032, 0.058), "cream")
    ellipsoid("Dog_head", (0.0, -0.022, 0.186), (0.064, 0.062, 0.058), "tint_light")
    ellipsoid("Dog_muzzle", (0.0, -0.072, 0.172), (0.034, 0.028, 0.026), "cream")
    ellipsoid("Dog_nose", (0.0, -0.098, 0.178), (0.012, 0.009, 0.009), "charcoal")
    rtorus("Dog_collar", (0.0, -0.015, 0.136), 0.046, 0.008, "sky")
    for sx in (-1.0, 1.0):
        ellipsoid("Dog_floppy_ear", (sx * 0.064, -0.012, 0.175), (0.018, 0.028, 0.048), "tint_dark", rot=(0.0, sx * -16.0, 0.0))
        ellipsoid("Dog_eye", (sx * 0.026, -0.072, 0.198), (0.009, 0.008, 0.009), "charcoal")
        ellipsoid("Dog_paw", (sx * 0.034, -0.062, 0.022), (0.024, 0.030, 0.018), "cream")
    curve_tube("Dog_tail", [(0.0, 0.095, 0.068), (0.015, 0.132, 0.128)], 0.013, "tint_dark")


def build_gift_box() -> None:
    rbox("Gift_base", (0.0, 0.0, 0.065), (0.20, 0.20, 0.125), "tint", bevel=0.014)
    rbox("Gift_lid", (0.0, 0.0, 0.135), (0.214, 0.214, 0.036), "tint_light", bevel=0.010)
    rbox("Gift_rib_x", (0.0, 0.0, 0.078), (0.218, 0.032, 0.155), "cream", bevel=0.004)
    rbox("Gift_rib_y", (0.0, 0.0, 0.078), (0.032, 0.218, 0.155), "cream", bevel=0.004)
    for sx in (-1.0, 1.0):
        rtorus("Gift_bow", (sx * 0.032, 0.0, 0.168), 0.028, 0.009, "berry", rot=(90.0, sx * 25.0, 0.0))


PLAY_NATURE_BUILDERS: list[tuple[str, callable, float]] = [
    ("teddy", build_teddy, 0.28),
    ("ball", build_ball, 0.23),
    ("football", build_football, 0.23),
    ("basketball", build_basketball, 0.23),
    ("kite", build_kite, 0.31),
    ("rope", build_rope, 0.28),
    ("bell", build_bell, 0.26),
    ("violin", build_violin, 0.34),
    ("guitar", build_guitar, 0.35),
    ("star", build_star, 0.26),
    ("sun", build_sun, 0.28),
    ("cloud", build_cloud, 0.25),
    ("rain_jar", build_rain_jar, 0.25),
    ("pinwheel", build_pinwheel, 0.29),
    ("flower", build_flower, 0.29),
    ("plant", build_plant, 0.28),
    ("leaf", build_leaf, 0.25),
    ("bee", build_bee, 0.23),
    ("bird", build_bird, 0.24),
    ("duck", build_duck, 0.23),
    ("cat", build_cat, 0.26),
    ("dog", build_dog, 0.26),
    ("gift_box", build_gift_box, 0.24),
]
