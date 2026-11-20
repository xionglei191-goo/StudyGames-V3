"""Blender 5.2+ builders for Wardrobe, Footwear, Books, Stationery, and Art props (27 models)."""
from __future__ import annotations

import math
import bpy

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


def _tailored_body(name, sections, fabric, pleats=0):
    # Horizontal sections share a continuous shoulder, waist and hem. Front and
    # back bow out slightly between seams, like fabric resting on a hanger.
    rings = 80 if pleats else 48
    verts = []
    for z, width, depth, drape in sections:
        for i in range(rings):
            angle = i * math.tau / rings
            c, s = math.cos(angle), math.sin(angle)
            fold = 1.0 + drape * (0.08 * math.cos(6 * angle + 0.4) + 0.035 * math.sin(10 * angle))
            x = math.copysign(abs(c) ** 0.83, c) * width
            y = math.copysign(abs(s) ** 0.80, s) * depth * fold
            if pleats:
                gather = 1 + drape*(0.11*math.cos(pleats*angle+0.4) + 0.026*math.cos(2*pleats*angle+0.8))
                x, y = x*gather, y*gather
            verts.append((x, y, z + 0.0035 * drape * math.cos(4 * angle)))
    faces = [tuple(reversed(range(rings)))]
    for row in range(len(sections) - 1):
        for i in range(rings):
            a, b = row * rings + i, row * rings + (i + 1) % rings
            faces.append((a, b, b + rings, a + rings))
    faces.append(tuple(range(len(verts) - rings, len(verts))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(MATERIALS[fabric])
    for face in mesh.polygons:
        face.use_smooth = len(face.vertices) == 4


def _lapel(side):
    a = (0.017, -0.048, 0.390)
    b = (0.082, -0.046, 0.367)
    c = (0.064, -0.060, 0.337)
    d = (0.075, -0.060, 0.333)
    e = (0.012, -0.067, 0.268)
    pts = [(side*x, y, z) for x, y, z in (a, b, c, d, e)]
    mesh = bpy.data.meshes.new("NotchedLapel")
    mesh.from_pydata(pts, [], [tuple(range(5))])
    mesh.update()
    obj = bpy.data.objects.new("Coat_lapel", mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(MATERIALS["tint_light"])
    solid = obj.modifiers.new("FoldedEdge", "SOLIDIFY")
    solid.thickness = 0.004
    solid.offset = 0.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=solid.name)


def _hanger(z_top: float = 0.42, span: float = 0.28) -> None:
    curve_tube(
        "Hanger_hook",
        [(0.0,0.0,z_top), (0.0,0.0,z_top+0.044), (0.0,0.024,z_top+0.060),
         (0.0,0.023,z_top+0.085), (0.0,0.0,z_top+0.094), (0.0,-0.023,z_top+0.084), (0.0,-0.024,z_top+0.065)],
        0.006,
        "gold",
    )
    curve_tube(
        "Hanger_bar",
        [(-span * 0.5, 0.0, z_top - 0.028), (-span * 0.18, 0.0, z_top - 0.004), (0.0, 0.0, z_top + 0.006), (span * 0.18, 0.0, z_top - 0.004), (span * 0.5, 0.0, z_top - 0.028)],
        0.013,
        "wood",
    )


def build_coat() -> None:
    _hanger(0.42, 0.29)
    # Tailored coat torso + subtle A-line flare
    _tailored_body("Coat_body", [(0.020,0.131,0.058,1), (0.025,0.137,0.062,1),
        (0.106,0.123,0.060,0.85), (0.224,0.102,0.054,0.35), (0.310,0.115,0.057,0.15),
        (0.354,0.129,0.047,0.05), (0.379,0.091,0.040,0.0), (0.398,0.050,0.031,0)], "tint")
    curve_tube("Coat_front_seam", [(0.011,-0.064,0.025),(0.011,-0.061,0.12),
        (0.012,-0.055,0.22),(0.012,-0.059,0.273)], 0.0018, "tint_dark")
    for sx in (-1.0, 1.0):
        curve_tube("Coat_sleeve", [(sx*0.097,0,0.349),(sx*0.133,0,0.317),
            (sx*0.146,-0.010,0.234),(sx*0.165,-0.021,0.141)], 0.039,"tint",radii_mult=[0.8,1.03,0.86,0.76])
        rbox("Coat_cuff", (sx*0.166,-0.021,0.140), (0.059,0.062,0.021),"tint_dark",bevel=0.008,rot=(0,-sx*12,0))
        _lapel(sx)
        rbox("Coat_pocket_welt", (sx*0.073,-0.052,0.134), (0.063,0.011,0.013),"tint_light",bevel=0.004,rot=(0,-sx*16,0))
    rbox("Coat_collar_back", (0.0, 0.010, 0.392), (0.135, 0.075, 0.038), "cream", bevel=0.012)
    for bz in (0.10, 0.175, 0.25):
        rcyl("Coat_btn", (0.0, -0.056, bz), 0.013, 0.010, "wood_dark", bevel=0.003, rot=(90.0, 0.0, 0.0))


def build_shirt() -> None:
    _hanger(0.37, 0.27)
    _tailored_body("Shirt_body", [(0.036,0.113,0.045,0.95),(0.044,0.117,0.048,0.95),
        (0.160,0.100,0.044,0.5),(0.249,0.110,0.047,0.14),
        (0.305,0.119,0.041,0.1),(0.335,0.058,0.036,0)],"tint")
    rbox("Shirt_placket", (0.0, -0.046, 0.18), (0.032, 0.012, 0.28), "cream", bevel=0.005)
    for sx in (-1.0, 1.0):
        rbox("Shirt_sleeve", (sx * 0.132, 0.0, 0.255), (0.079, 0.080, 0.145), "tint", bevel=0.024, rot=(0.0, -sx * 26.0, 0.0), subsurf=1)
        rbox("Shirt_cuff", (sx * 0.161, 0.0, 0.198), (0.081, 0.082, 0.022), "cream", bevel=0.008, rot=(0.0, -sx * 26.0, 0.0))
        rbox("Shirt_collar", (sx * 0.044, -0.032, 0.335), (0.068, 0.035, 0.042), "cream", bevel=0.010, rot=(12.0, sx * -22.0, 0.0))
    rbox("Shirt_pocket", (0.062, -0.047, 0.235), (0.052, 0.012, 0.056), "tint_light", bevel=0.006)
    for bz in (0.09, 0.16, 0.23, 0.29):
        rcyl("Shirt_btn", (0.0, -0.053, bz), 0.009, 0.008, "white", bevel=0.002, rot=(90.0, 0.0, 0.0))


def build_dress() -> None:
    _hanger(0.393, 0.21)
    _tailored_body("Dress_bodice", [(0.227,0.078,0.043,0.2),(0.244,0.077,0.042,0.2),
        (0.297,0.085,0.049,0.2),(0.345,0.098,0.047,0.1),(0.372,0.051,0.034,0)], "tint_light")
    # A gathered, continuous skirt hangs flatter in depth than in width.
    _tailored_body("Dress_pleated_skirt", [(0.023,0.163,0.093,1.0),(0.029,0.166,0.096,1.0),
        (0.052,0.160,0.091,0.95),(0.119,0.137,0.079,0.78),
        (0.191,0.105,0.061,0.60),(0.241,0.079,0.044,0.25)], "tint", pleats=10)
    for sx in (-1.0, 1.0):
        ellipsoid("Dress_puff_sleeve", (sx * 0.108, 0.0, 0.335), (0.045, 0.046, 0.048), "cream")
        ellipsoid("Dress_collar_petal", (sx * 0.038, -0.036, 0.365), (0.042, 0.022, 0.018), "white", rot=(0.0, sx * -15.0, 0.0))
    rbox("Dress_waist_sash", (0.0, 0.0, 0.242), (0.186, 0.098, 0.034), "cream", bevel=0.010)
    for sx in (-1.0, 1.0):
        ellipsoid("Dress_bow_loop", (sx * 0.034, -0.054, 0.244), (0.028, 0.014, 0.020), "berry", rot=(0.0, sx * 18.0, 0.0))
    ellipsoid("Dress_bow_knot", (0.0, -0.056, 0.244), (0.014, 0.012, 0.014), "berry")


def build_sweater() -> None:
    # Plump folded cozy cable-knit pullover
    rbox("Sweater_fold_base", (0.0, 0.0, 0.045), (0.29, 0.24, 0.075), "tint", bevel=0.028, subsurf=1)
    rbox("Sweater_fold_top", (0.0, 0.008, 0.095), (0.27, 0.22, 0.052), "tint_light", bevel=0.022, subsurf=1)
    rtorus("Sweater_rib_collar", (0.0, -0.045, 0.122), 0.052, 0.016, "cream", rot=(8.0, 0.0, 0.0))
    for kx in (-0.07, -0.024, 0.024, 0.07):
        curve_tube("Sweater_cable", [(kx, -0.095, 0.120), (kx, 0.01, 0.125), (kx, 0.095, 0.118)], 0.009, "tint_dark")
    for sx in (-1.0, 1.0):
        rbox("Sweater_folded_arm", (sx * 0.085, 0.02, 0.130), (0.085, 0.15, 0.036), "tint", bevel=0.015, rot=(0.0, 0.0, sx * -18.0))
        rbox("Sweater_cuff", (sx * 0.045, -0.045, 0.136), (0.068, 0.032, 0.038), "cream", bevel=0.010, rot=(0.0, 0.0, sx * -18.0))


def build_trousers() -> None:
    # A folded pair of jeans sits flat on a shelf. The back pocket, waistband
    # and staggered hems remain visible from the game's three-quarter camera.
    for i in range(3):
        z = 0.021 + i * 0.030
        rbox("Trousers_fold", (i*0.003, i*0.009, z), (0.185+i*0.007,0.29-i*0.011,0.047),
             "tint" if i != 1 else "tint_dark", bevel=0.018,rot=(0,0,i*1.8))
    rbox("Trousers_waistband", (0.003,0.115,0.104), (0.203,0.041,0.019),"tint_dark",bevel=0.006)
    rbox("Trousers_label", (0.041,0.112,0.114), (0.050,0.028,0.006),"bread",bevel=0.002)
    rbox("Trousers_pocket", (-0.036,0.037,0.104), (0.086,0.075,0.009),"tint_light",bevel=0.004,rot=(0,0,-4))
    curve_tube("Pocket_stitch", [(-0.070,0.057,0.111),(-0.066,0.022,0.111),
        (-0.033,0.009,0.111),(-0.002,0.029,0.111),(0.001,0.059,0.111)],0.0014,"crumb")


def build_scarf() -> None:
    rtorus("Scarf_coil_lower", (0.0, 0.0, 0.040), 0.095, 0.034, "tint")
    rtorus("Scarf_coil_upper", (0.0, 0.005, 0.082), 0.084, 0.030, "tint_light", rot=(6.0, -5.0, 0.0))
    rbox("Scarf_tail_a", (0.048, -0.085, 0.032), (0.068, 0.125, 0.028), "tint", bevel=0.012, rot=(14.0, 0.0, -16.0))
    rbox("Scarf_tail_b", (-0.035, -0.092, 0.024), (0.062, 0.110, 0.025), "tint_light", bevel=0.010, rot=(10.0, 0.0, 12.0))
    for tx in (-0.018, 0.0, 0.018):
        rcyl("Scarf_fringe", (0.058 + tx, -0.152, 0.014), 0.005, 0.030, "cream", bevel=0.002, rot=(82.0, 0.0, -16.0))


def build_socks() -> None:
    for sx, yaw in ((-0.072, -10.0), (0.072, 12.0)):
        rcyl("Sock_ankle", (sx, 0.025, 0.115), 0.040, 0.15, "tint", bevel=0.014, rot=(8.0, 0.0, yaw))
        rcyl("Sock_cuff", (sx, 0.015, 0.192), 0.044, 0.036, "cream", bevel=0.010, rot=(8.0, 0.0, yaw))
        ellipsoid("Sock_foot", (sx, -0.028, 0.038), (0.042, 0.078, 0.036), "tint_light", rot=(0.0, 0.0, yaw))
        ellipsoid("Sock_toe", (sx - math.sin(math.radians(yaw)) * 0.02, -0.085, 0.034), (0.039, 0.032, 0.032), "cream", rot=(0.0, 0.0, yaw))
        ellipsoid("Sock_heel", (sx, 0.036, 0.036), (0.038, 0.028, 0.032), "cream")


def build_shoes() -> None:
    for sx, yaw in ((-0.078, -8.0), (0.078, 8.0)):
        rbox("Shoe_sole", (sx, 0.0, 0.018), (0.094, 0.215, 0.032), "white", bevel=0.014, rot=(0.0, 0.0, yaw), subsurf=1)
        rbox("Shoe_upper", (sx, 0.018, 0.062), (0.086, 0.165, 0.068), "tint", bevel=0.026, rot=(0.0, 0.0, yaw), subsurf=1)
        ellipsoid("Shoe_toecap", (sx, -0.068, 0.042), (0.044, 0.046, 0.030), "white", rot=(0.0, 0.0, yaw))
        for ly in (-0.032, -0.008, 0.016):
            rbox("Shoe_lace", (sx, ly, 0.094), (0.048, 0.010, 0.010), "white", bevel=0.003, rot=(0.0, 0.0, yaw))


def build_gloves() -> None:
    for sx, yaw in ((-0.082, 12.0), (0.082, -12.0)):
        ellipsoid("Mitten_palm", (sx, -0.015, 0.042), (0.056, 0.082, 0.034), "tint", rot=(0.0, 0.0, yaw))
        ellipsoid("Mitten_thumb", (sx - sx * 0.52, -0.010, 0.044), (0.024, 0.044, 0.024), "tint_light", rot=(0.0, 0.0, -sx * 320.0))
        rbox("Mitten_cuff", (sx, 0.072, 0.038), (0.092, 0.048, 0.052), "cream", bevel=0.014, rot=(0.0, 0.0, yaw))


# --- Books, Stationery & Art ---

def build_book() -> None:
    rbox("Book_back_cover", (0.0, 0.0, 0.012), (0.28, 0.34, 0.020), "tint_dark", bevel=0.008)
    rbox("Book_pages", (0.010, 0.0, 0.044), (0.256, 0.318, 0.050), "paper", bevel=0.008)
    rbox("Book_front_cover", (0.0, 0.0, 0.076), (0.28, 0.34, 0.020), "tint", bevel=0.008)
    rbox("Book_spine", (-0.134, 0.0, 0.044), (0.028, 0.34, 0.084), "tint_dark", bevel=0.012)
    rbox("Book_title_plate", (0.012, -0.03, 0.088), (0.14, 0.09, 0.008), "cream", bevel=0.003)
    star_mesh("Book_star_emblem", (0.012, 0.07, 0.089), 0.034, 0.016, 0.008, 5, "gold")
    rbox("Book_ribbon", (0.055, -0.175, 0.022), (0.024, 0.065, 0.006), "berry", bevel=0.002, rot=(14.0, 0.0, 8.0))


def build_notebook() -> None:
    rbox("NB_back", (0.008, 0.0, 0.010), (0.26, 0.33, 0.016), "tint_dark", bevel=0.007)
    rbox("NB_pages", (0.012, 0.0, 0.034), (0.246, 0.316, 0.036), "paper", bevel=0.006)
    rbox("NB_front", (0.008, 0.0, 0.058), (0.26, 0.33, 0.016), "tint", bevel=0.007)
    rbox("NB_label", (0.02, 0.02, 0.068), (0.13, 0.075, 0.006), "cream", bevel=0.002)
    rbox("NB_band", (0.095, 0.0, 0.034), (0.018, 0.334, 0.068), "tint_dark", bevel=0.005)
    for rz in (-0.12, -0.072, -0.024, 0.024, 0.072, 0.12):
        rtorus("NB_ring", (-0.122, rz, 0.036), 0.024, 0.0055, "silver", rot=(90.0, 0.0, 0.0))


def build_newspaper() -> None:
    rbox("News_lower", (0.0, 0.0, 0.022), (0.30, 0.23, 0.032), "paper", bevel=0.012, subsurf=1)
    rbox("News_upper", (-0.006, 0.006, 0.052), (0.285, 0.22, 0.028), "cream", bevel=0.012, rot=(0.0, 3.0, -3.0), subsurf=1)
    rcyl("News_fold_roll", (-0.142, 0.0, 0.038), 0.026, 0.225, "paper", bevel=0.008, rot=(90.0, 0.0, 0.0))
    rbox("News_banner", (0.01, -0.055, 0.068), (0.21, 0.032, 0.006), "tint", bevel=0.002, rot=(0.0, 3.0, -3.0))
    for cx in (-0.045, 0.055):
        rbox("News_col", (cx, 0.025, 0.067), (0.082, 0.095, 0.005), "charcoal", bevel=0.002, rot=(0.0, 3.0, -3.0))


def build_letter() -> None:
    rbox("Letter_stand", (0.0, 0.035, 0.016), (0.18, 0.07, 0.028), "wood", bevel=0.008)
    rbox("Letter_env", (0.0, -0.005, 0.115), (0.29, 0.024, 0.195), "cream", bevel=0.009, rot=(-16.0, 0.0, 0.0))
    rbox("Letter_flap", (0.0, -0.020, 0.155), (0.19, 0.012, 0.19), "paper", bevel=0.005, rot=(-16.0, 45.0, 0.0))
    rcyl("Letter_wax_seal", (0.0, -0.024, 0.105), 0.028, 0.012, "berry", bevel=0.004, rot=(74.0, 0.0, 0.0))
    star_mesh("Letter_seal_star", (0.0, -0.030, 0.104), 0.015, 0.007, 0.006, 5, "gold", rot=(74.0, 0.0, 0.0))


def build_card() -> None:
    rbox("Card_wood_base", (0.0, 0.01, 0.018), (0.22, 0.075, 0.034), "wood", bevel=0.010)
    rbox("Card_board", (0.0, 0.0, 0.135), (0.26, 0.022, 0.215), "tint", bevel=0.012, rot=(-12.0, 0.0, 0.0))
    rbox("Card_inner", (0.0, -0.012, 0.135), (0.224, 0.010, 0.178), "cream", bevel=0.008, rot=(-12.0, 0.0, 0.0))
    star_mesh("Card_star", (0.0, -0.020, 0.140), 0.048, 0.022, 0.012, 5, "gold", rot=(78.0, 0.0, 0.0))


def build_photo() -> None:
    rbox("Photo_easel_leg", (0.0, 0.055, 0.085), (0.045, 0.024, 0.16), "wood_dark", bevel=0.006, rot=(26.0, 0.0, 0.0))
    rbox("Photo_frame", (0.0, -0.01, 0.132), (0.27, 0.028, 0.23), "tint", bevel=0.012, rot=(-14.0, 0.0, 0.0))
    rbox("Photo_mat", (0.0, -0.023, 0.132), (0.225, 0.010, 0.185), "cream", bevel=0.005, rot=(-14.0, 0.0, 0.0))
    rbox("Photo_sky", (0.0, -0.028, 0.136), (0.185, 0.008, 0.145), "sky", bevel=0.003, rot=(-14.0, 0.0, 0.0))
    ellipsoid("Photo_hill", (-0.025, -0.032, 0.095), (0.075, 0.008, 0.038), "leaf", rot=(-14.0, 0.0, 0.0))
    ellipsoid("Photo_sun", (0.048, -0.033, 0.165), (0.022, 0.006, 0.022), "yellow", rot=(-14.0, 0.0, 0.0))


def build_paper() -> None:
    for i, (ang, mkey) in enumerate([(-5.0, "paper"), (2.0, "white"), (7.0, "cream")]):
        rbox(f"Paper_sheet_{i}", (0.0, 0.0, 0.012 + i * 0.014), (0.26, 0.31, 0.012), mkey, bevel=0.004, rot=(0.0, 0.0, ang))
    for cx, mk in ((-0.05, "tint"), (0.01, "yellow"), (0.065, "berry")):
        rcyl("Paper_dot", (cx, -0.03, 0.048), 0.024, 0.006, mk, bevel=0.002)


def _pen_rest() -> None:
    rbox("Pen_rest", (0.035, 0.0, 0.020), (0.085, 0.065, 0.036), "wood", bevel=0.010)


def build_pen() -> None:
    _pen_rest()
    # Sleek fountain pen resting at an inviting angle
    rcyl("Pen_barrel", (-0.01, 0.0, 0.085), 0.020, 0.27, "tint", bevel=0.008, rot=(0.0, 74.0, 14.0))
    rcyl("Pen_gold_ring", (0.055, 0.016, 0.103), 0.022, 0.016, "gold", bevel=0.003, rot=(0.0, 74.0, 14.0))
    rcone("Pen_grip", (-0.135, -0.032, 0.050), 0.019, 0.009, 0.055, "charcoal", bevel=0.003, rot=(0.0, -106.0, 14.0))
    rcone("Pen_nib", (-0.172, -0.042, 0.039), 0.009, 0.002, 0.034, "gold", bevel=0.001, rot=(0.0, -106.0, 14.0))
    rbox("Pen_clip", (0.075, 0.020, 0.128), (0.085, 0.008, 0.010), "silver", bevel=0.003, rot=(0.0, 16.0, 14.0))


def build_pencil() -> None:
    _pen_rest()
    rcyl("Pencil_hex_body", (-0.005, 0.0, 0.084), 0.021, 0.26, "tint", bevel=0.004, verts=6, rot=(0.0, 74.0, 12.0))
    rcyl("Pencil_ferrule", (0.122, 0.027, 0.121), 0.022, 0.028, "gold", bevel=0.003, rot=(0.0, 74.0, 12.0))
    ellipsoid("Pencil_eraser", (0.145, 0.032, 0.128), (0.024, 0.021, 0.021), "pink", rot=(0.0, 74.0, 12.0))
    rcone("Pencil_wood_cone", (-0.138, -0.029, 0.046), 0.020, 0.006, 0.050, "crumb", bevel=0.002, rot=(0.0, -106.0, 12.0))
    rcone("Pencil_lead", (-0.166, -0.035, 0.038), 0.006, 0.0015, 0.020, "charcoal", bevel=0.001, rot=(0.0, -106.0, 12.0))


def build_crayon() -> None:
    rcyl("Crayon_wax", (0.0, 0.0, 0.032), 0.028, 0.25, "tint", bevel=0.006, rot=(0.0, 86.0, 14.0))
    rcyl("Crayon_wrap", (0.01, 0.002, 0.033), 0.030, 0.16, "tint_light", bevel=0.004, rot=(0.0, 86.0, 14.0))
    for ox in (-0.048, 0.062):
        rcyl("Crayon_band", (ox, ox * 0.24, 0.033), 0.031, 0.016, "charcoal", bevel=0.002, rot=(0.0, 86.0, 14.0))
    rcone("Crayon_tip", (-0.138, -0.034, 0.024), 0.026, 0.006, 0.052, "tint", bevel=0.003, rot=(0.0, -94.0, 14.0))


def build_chalk() -> None:
    rbox("Chalk_tray", (0.0, 0.0, 0.018), (0.28, 0.13, 0.032), "wood", bevel=0.010)
    for idx, (cy, matk, yaw) in enumerate([(-0.028, "white", 4.0), (0.0, "yellow", -3.0), (0.028, "tint_light", 6.0)]):
        rcone(f"Chalk_{idx}", (0.0, cy, 0.044), 0.016, 0.014, 0.21, matk, bevel=0.004, rot=(0.0, 90.0, yaw))


def build_brush() -> None:
    _pen_rest()
    rcone("Brush_handle", (0.025, 0.005, 0.092), 0.010, 0.022, 0.24, "wood", bevel=0.004, rot=(0.0, 74.0, 12.0))
    rcyl("Brush_ferrule", (-0.095, -0.020, 0.058), 0.022, 0.038, "silver", bevel=0.003, rot=(0.0, 74.0, 12.0))
    ellipsoid("Brush_bristles", (-0.138, -0.030, 0.046), (0.040, 0.022, 0.020), "wood_dark", rot=(0.0, -16.0, 12.0))
    ellipsoid("Brush_paint_tip", (-0.160, -0.034, 0.040), (0.022, 0.015, 0.014), "tint", rot=(0.0, -16.0, 12.0))


def build_paint_jar() -> None:
    lathe(
        "PaintJar_body",
        [(0.0, 0.0), (0.092, 0.0), (0.104, 0.025), (0.104, 0.125), (0.084, 0.150), (0.084, 0.175), (0.072, 0.175), (0.072, 0.030), (0.0, 0.030)],
        "cream",
        steps=40,
    )
    rbox("PaintJar_label", (0.0, -0.102, 0.078), (0.11, 0.012, 0.068), "tint", bevel=0.004)
    rcyl("PaintJar_paint_fill", (0.0, 0.0, 0.095), 0.076, 0.11, "tint", bevel=0.008)
    ellipsoid("PaintJar_swirl", (0.0, 0.0, 0.152), (0.068, 0.068, 0.022), "tint_light")
    rtorus("PaintJar_collar", (0.0, 0.0, 0.165), 0.084, 0.012, "silver")


def build_ruler() -> None:
    rbox("Ruler_stand", (0.0, 0.025, 0.018), (0.20, 0.055, 0.032), "wood", bevel=0.008)
    rbox("Ruler_blade", (0.0, 0.0, 0.055), (0.35, 0.082, 0.018), "tint", bevel=0.006, rot=(-28.0, 0.0, 0.0))
    for i in range(-6, 7):
        h = 0.026 if i % 2 == 0 else 0.016
        rbox(f"Ruler_tick_{i}", (i * 0.024, -0.022, 0.068), (0.005, h, 0.006), "cream", bevel=0.001, rot=(-28.0, 0.0, 0.0))


def build_eraser() -> None:
    rbox("Eraser_rubber", (-0.025, 0.0, 0.042), (0.21, 0.115, 0.078), "white", bevel=0.018, subsurf=1)
    rbox("Eraser_sleeve", (0.022, 0.0, 0.043), (0.135, 0.124, 0.084), "tint", bevel=0.014)
    rbox("Eraser_stripe", (0.022, 0.0, 0.044), (0.032, 0.127, 0.086), "cream", bevel=0.006)


def build_pencil_box() -> None:
    rbox("PBox_lower", (0.0, 0.0, 0.028), (0.33, 0.145, 0.052), "tint", bevel=0.020, subsurf=1)
    rbox("PBox_lid", (0.0, 0.0, 0.066), (0.334, 0.148, 0.038), "tint_light", bevel=0.018, subsurf=1)
    rbox("PBox_seam", (0.0, 0.0, 0.050), (0.338, 0.152, 0.008), "cream", bevel=0.003)
    rbox("PBox_clasp", (0.0, -0.076, 0.052), (0.054, 0.014, 0.028), "gold", bevel=0.005)
    star_mesh("PBox_badge", (0.0, 0.0, 0.087), 0.032, 0.015, 0.008, 5, "yellow")


def build_scissors() -> None:
    for sign, ang in ((-1.0, 18.0), (1.0, -18.0)):
        rbox("Scissor_blade", (0.035, 0.0, 0.032 + sign * 0.005), (0.21, 0.028, 0.009), "silver", bevel=0.004, rot=(0.0, 0.0, ang))
        rtorus("Scissor_loop", (-0.095, sign * 0.046, 0.034), 0.038, 0.012, "tint")
        rbox("Scissor_shank", (-0.048, sign * 0.022, 0.034), (0.065, 0.022, 0.016), "tint", bevel=0.006, rot=(0.0, 0.0, ang))
    rcyl("Scissor_pivot", (0.0, 0.0, 0.034), 0.012, 0.024, "gold", bevel=0.003)


def build_globe() -> None:
    lathe(
        "Globe_base",
        [(0.0, 0.0), (0.095, 0.0), (0.098, 0.016), (0.062, 0.034), (0.022, 0.048), (0.022, 0.082), (0.0, 0.082)],
        "wood",
        steps=36,
    )
    curve_tube(
        "Globe_meridian",
        [(0.0, 0.0, 0.074), (-0.095, 0.0, 0.115), (-0.135, 0.0, 0.205), (-0.085, 0.0, 0.298), (0.015, 0.0, 0.332)],
        0.009,
        "gold",
    )
    ellipsoid("Globe_ocean", (0.0, 0.0, 0.205), (0.112, 0.112, 0.112), "tint", segs=36, rings=20, rot=(0.0, 23.5, 0.0))
    for loc, rad in [
        ((0.045, -0.088, 0.228), (0.046, 0.026, 0.038)),
        ((-0.055, -0.082, 0.185), (0.038, 0.024, 0.048)),
        ((0.068, 0.072, 0.215), (0.044, 0.028, 0.036)),
    ]:
        ellipsoid("Globe_continent", loc, rad, "leaf")


WARDROBE_STUDY_BUILDERS: list[tuple[str, callable, float]] = [
    ("coat", build_coat, 0.42),
    ("shirt", build_shirt, 0.38),
    ("dress", build_dress, 0.42),
    ("sweater", build_sweater, 0.30),
    ("trousers", build_trousers, 0.36),
    ("scarf", build_scarf, 0.26),
    ("socks", build_socks, 0.25),
    ("shoes", build_shoes, 0.26),
    ("gloves", build_gloves, 0.25),
    ("book", build_book, 0.32),
    ("notebook", build_notebook, 0.31),
    ("newspaper", build_newspaper, 0.30),
    ("letter", build_letter, 0.28),
    ("card", build_card, 0.27),
    ("photo", build_photo, 0.28),
    ("paper", build_paper, 0.29),
    ("pen", build_pen, 0.31),
    ("pencil", build_pencil, 0.31),
    ("crayon", build_crayon, 0.28),
    ("chalk", build_chalk, 0.27),
    ("brush", build_brush, 0.31),
    ("paint_jar", build_paint_jar, 0.22),
    ("ruler", build_ruler, 0.33),
    ("eraser", build_eraser, 0.21),
    ("pencil_box", build_pencil_box, 0.31),
    ("scissors", build_scissors, 0.28),
    ("globe", build_globe, 0.33),
]
