"""Blender 5.2+ builders for Bathroom, Bedroom, Household, Fruit, Dishware, and Food props (42 models)."""
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
)


# --- Bathroom, Bedroom & Household ---

def build_pillow() -> None:
    ellipsoid("Pillow_puff", (0.0, 0.0, 0.062), (0.155, 0.115, 0.056), "tint", segs=36, rings=20)
    rtorus("Pillow_piping", (0.0, 0.0, 0.058), 0.128, 0.009, "cream")
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            ellipsoid("Pillow_ear", (sx * 0.128, sy * 0.092, 0.056), (0.026, 0.022, 0.018), "tint_light", rot=(0.0, 0.0, sx * sy * 28.0))


def build_quilt() -> None:
    rbox("Quilt_layer1", (0.0, 0.0, 0.026), (0.31, 0.25, 0.048), "tint", bevel=0.020, subsurf=1)
    rbox("Quilt_layer2", (0.0, 0.008, 0.068), (0.29, 0.23, 0.046), "tint_light", bevel=0.020, subsurf=1)
    rbox("Quilt_cuff", (0.0, -0.068, 0.098), (0.285, 0.085, 0.026), "cream", bevel=0.012, subsurf=1)
    for gx in (-0.075, 0.0, 0.075):
        ellipsoid("Quilt_puff", (gx, 0.042, 0.090), (0.042, 0.058, 0.014), "tint")


def build_towel() -> None:
    rbox("Towel_bottom", (0.0, 0.0, 0.022), (0.28, 0.21, 0.040), "tint", bevel=0.018, subsurf=1)
    rbox("Towel_stripe", (0.0, -0.072, 0.024), (0.282, 0.022, 0.042), "cream", bevel=0.006)
    rcyl("Towel_roll", (0.0, 0.015, 0.074), 0.038, 0.24, "tint_light", bevel=0.014, rot=(0.0, 90.0, 0.0))
    rcyl("Towel_roll_core", (0.0, 0.015, 0.074), 0.016, 0.244, "cream", bevel=0.004, rot=(0.0, 90.0, 0.0))


def build_toothbrush() -> None:
    lathe(
        "TB_tumbler",
        [(0.0, 0.0), (0.056, 0.0), (0.068, 0.145), (0.060, 0.148), (0.050, 0.016), (0.0, 0.016)],
        "cream",
        steps=36,
    )
    rtorus("TB_band", (0.0, 0.0, 0.115), 0.063, 0.006, "tint_light")
    curve_tube(
        "TB_handle",
        [(-0.015, 0.0, 0.035), (0.008, 0.0, 0.125), (0.032, 0.0, 0.205), (0.046, 0.0, 0.265)],
        0.011,
        "tint",
    )
    rbox("TB_head", (0.048, 0.0, 0.272), (0.020, 0.018, 0.046), "tint_light", bevel=0.006, rot=(0.0, 14.0, 0.0))
    rbox("TB_bristles", (0.034, 0.0, 0.275), (0.018, 0.015, 0.038), "white", bevel=0.004, rot=(0.0, 14.0, 0.0))
    ellipsoid("TB_paste", (0.025, 0.0, 0.278), (0.009, 0.009, 0.018), "sky", rot=(0.0, 14.0, 0.0))


def build_comb() -> None:
    rbox("Comb_stand", (0.0, 0.018, 0.012), (0.16, 0.055, 0.022), "cream", bevel=0.008)
    rbox("Comb_spine", (0.0, 0.0, 0.095), (0.27, 0.022, 0.038), "tint", bevel=0.012, rot=(-16.0, 0.0, 0.0), subsurf=1)
    for i in range(-7, 8):
        rcone(f"Comb_tooth_{i}", (i * 0.0155, 0.012, 0.052), 0.0055, 0.003, 0.065, "tint_light", bevel=0.001, rot=(164.0, 0.0, 0.0))


def build_soap() -> None:
    ellipsoid("Soap_dish_outer", (0.0, 0.0, 0.022), (0.135, 0.096, 0.022), "cream", segs=36, rings=16)
    ellipsoid("Soap_dish_rim", (0.0, 0.0, 0.032), (0.122, 0.084, 0.010), "white", segs=36, rings=12)
    rbox("Soap_bar", (0.0, 0.0, 0.058), (0.165, 0.105, 0.056), "tint", bevel=0.024, rot=(0.0, 0.0, 8.0), subsurf=1)
    for bx, by, bz, br in [(0.052, -0.025, 0.092, 0.020), (0.026, -0.038, 0.102, 0.014), (-0.048, 0.028, 0.088, 0.016), (-0.025, 0.035, 0.098, 0.011)]:
        ellipsoid("Soap_bubble", (bx, by, bz), (br, br, br), "white")


def build_water() -> None:
    ellipsoid("Water_pool", (0.0, 0.0, 0.014), (0.155, 0.145, 0.014), "water", segs=36, rings=14)
    rtorus("Water_ripple_1", (0.0, 0.0, 0.024), 0.068, 0.009, "sky")
    rtorus("Water_ripple_2", (0.0, 0.0, 0.022), 0.118, 0.007, "water")
    curve_tube("Water_stream", [(0.02, 0.03, 0.22), (0.008, 0.01, 0.13), (0.0, 0.0, 0.025)], 0.018, "water")
    for dx, dy, dz, dr in [(-0.048, -0.032, 0.078, 0.018), (0.052, -0.025, 0.108, 0.015), (-0.018, -0.045, 0.145, 0.013)]:
        ellipsoid("Water_drop", (dx, dy, dz), (dr, dr, dr * 1.35), "sky")


def build_bucket() -> None:
    lathe(
        "Bucket_body",
        [(0.0, 0.0), (0.088, 0.0), (0.122, 0.195), (0.128, 0.205), (0.114, 0.205), (0.080, 0.016), (0.0, 0.016)],
        "tint",
        steps=40,
    )
    rtorus("Bucket_rim", (0.0, 0.0, 0.202), 0.122, 0.009, "tint_light")
    curve_tube(
        "Bucket_bail",
        [(-0.122, 0.0, 0.198), (-0.105, 0.0, 0.268), (0.0, 0.0, 0.305), (0.105, 0.0, 0.268), (0.122, 0.0, 0.198)],
        0.006,
        "silver",
    )
    rcyl("Bucket_grip", (0.0, 0.0, 0.302), 0.014, 0.068, "wood", bevel=0.004, rot=(0.0, 90.0, 0.0))


def build_umbrella() -> None:
    lathe(
        "Umb_canopy",
        [(0.0, 0.285), (0.055, 0.278), (0.125, 0.245), (0.175, 0.185), (0.168, 0.182), (0.118, 0.238), (0.0, 0.272)],
        "tint",
        steps=8,
        subsurf=1,
    )
    rcone("Umb_ferrule", (0.0, 0.0, 0.305), 0.012, 0.003, 0.038, "gold", bevel=0.001)
    rcyl("Umb_shaft", (0.0, 0.0, 0.155), 0.008, 0.24, "wood", bevel=0.002)
    curve_tube(
        "Umb_j_handle",
        [(0.0, 0.0, 0.042), (0.0, 0.0, 0.016), (0.022, 0.0, 0.008), (0.042, 0.0, 0.022), (0.040, 0.0, 0.045)],
        0.010,
        "wood_dark",
    )


def build_glasses() -> None:
    for sx in (-1.0, 1.0):
        rtorus("Glass_rim", (sx * 0.072, -0.025, 0.055), 0.046, 0.009, "tint", rot=(82.0, 0.0, sx * -6.0))
        rcyl("Glass_lens", (sx * 0.072, -0.025, 0.055), 0.041, 0.006, "water", bevel=0.001, rot=(82.0, 0.0, sx * -6.0))
        curve_tube(
            "Glass_arm",
            [(sx * 0.118, -0.022, 0.062), (sx * 0.122, 0.065, 0.058), (sx * 0.112, 0.115, 0.032)],
            0.006,
            "tint_dark",
        )
    curve_tube("Glass_bridge", [(-0.026, -0.028, 0.062), (0.0, -0.032, 0.068), (0.026, -0.028, 0.062)], 0.007, "tint")


def build_clock() -> None:
    for sx in (-1.0, 1.0):
        ellipsoid("Clock_foot", (sx * 0.062, 0.0, 0.018), (0.016, 0.020, 0.018), "gold")
        lathe(
            "Clock_bell",
            [(0.0, 0.032), (0.034, 0.028), (0.038, 0.006), (0.032, 0.006), (0.028, 0.024), (0.0, 0.028)],
            "gold",
            steps=28,
            loc=(sx * 0.075, 0.0, 0.215),
            rot=(0.0, sx * 28.0, 0.0),
        )
    rcyl("Clock_case", (0.0, 0.0, 0.125), 0.105, 0.062, "tint", bevel=0.012, rot=(90.0, 0.0, 0.0))
    rcyl("Clock_dial", (0.0, -0.028, 0.125), 0.088, 0.012, "cream", bevel=0.003, rot=(90.0, 0.0, 0.0))
    rbox("Clock_hour", (-0.018, -0.036, 0.138), (0.044, 0.006, 0.010), "charcoal", bevel=0.002, rot=(0.0, -35.0, 0.0))
    rbox("Clock_min", (0.016, -0.037, 0.150), (0.010, 0.006, 0.058), "berry", bevel=0.002, rot=(0.0, 18.0, 0.0))
    rtorus("Clock_top_ring", (0.0, 0.0, 0.248), 0.022, 0.005, "gold", rot=(90.0, 0.0, 0.0))


def build_watch() -> None:
    ellipsoid("Watch_pillow", (0.0, 0.0, 0.045), (0.068, 0.082, 0.042), "cream")
    rtorus("Watch_strap", (0.0, 0.0, 0.052), 0.058, 0.016, "tint_dark", rot=(0.0, 90.0, 0.0))
    rcyl("Watch_bezel", (0.0, -0.022, 0.098), 0.046, 0.018, "gold", bevel=0.004, rot=(28.0, 0.0, 0.0))
    rcyl("Watch_dial", (0.0, -0.026, 0.104), 0.038, 0.008, "white", bevel=0.002, rot=(28.0, 0.0, 0.0))
    rbox("Watch_hand1", (0.008, -0.030, 0.108), (0.024, 0.005, 0.005), "charcoal", bevel=0.001, rot=(28.0, 25.0, 0.0))


def build_lamp() -> None:
    lathe(
        "Lamp_base",
        [(0.0, 0.0), (0.088, 0.0), (0.092, 0.018), (0.055, 0.042), (0.020, 0.065), (0.018, 0.165), (0.0, 0.165)],
        "wood",
        steps=36,
    )
    ellipsoid("Lamp_bulb", (0.0, 0.0, 0.195), (0.032, 0.032, 0.038), "yellow")
    lathe(
        "Lamp_shade",
        [(0.058, 0.285), (0.065, 0.285), (0.132, 0.155), (0.124, 0.155)],
        "tint",
        steps=36,
    )
    rtorus("Lamp_trim_bot", (0.0, 0.0, 0.156), 0.128, 0.006, "cream")
    rcyl("Lamp_pull", (0.048, -0.02, 0.132), 0.005, 0.048, "gold", bevel=0.002)


def build_key() -> None:
    rtorus("Key_bow", (-0.088, 0.0, 0.028), 0.048, 0.014, "gold")
    for ang in (0.0, 120.0, 240.0):
        rad = math.radians(ang)
        rtorus("Key_trefoil", (-0.088 + 0.024 * math.cos(rad), 0.024 * math.sin(rad), 0.028), 0.020, 0.009, "gold")
    rcyl("Key_collar", (-0.032, 0.0, 0.028), 0.018, 0.018, "gold", bevel=0.004, rot=(0.0, 90.0, 0.0))
    rcyl("Key_shaft", (0.048, 0.0, 0.028), 0.011, 0.165, "gold", bevel=0.004, rot=(0.0, 90.0, 0.0))
    rbox("Key_bit_1", (0.088, -0.024, 0.024), (0.024, 0.038, 0.016), "gold", bevel=0.004)
    rbox("Key_bit_2", (0.114, -0.020, 0.024), (0.018, 0.030, 0.016), "gold", bevel=0.004)


def build_stool() -> None:
    rcyl("Stool_seat", (0.0, 0.0, 0.205), 0.125, 0.038, "tint", bevel=0.014)
    rcyl("Stool_cushion", (0.0, 0.0, 0.222), 0.105, 0.016, "tint_light", bevel=0.006)
    rtorus("Stool_ring", (0.0, 0.0, 0.085), 0.088, 0.010, "wood")
    for ang_d in (45.0, 135.0, 225.0, 315.0):
        ang = math.radians(ang_d)
        lx, ly = 0.078 * math.cos(ang), 0.078 * math.sin(ang)
        rcone("Stool_leg", (lx, ly, 0.102), 0.012, 0.018, 0.205, "wood", bevel=0.003, rot=(-8.0 * math.sin(ang), 8.0 * math.cos(ang), 0.0))


# --- Fruits, Produce, Dishes & Meals ---

def build_apple() -> None:
    body = ellipsoid("Apple_body", (0.0, 0.0, 0.105), (0.108, 0.108, 0.098), "tint", segs=40, rings=22)
    for v in body.data.vertices:
        x, y, z = v.co.x, v.co.y, v.co.z
        r2 = x * x + y * y
        theta = math.atan2(y, x)
        lobe = 1.0 + 0.035 * math.cos(5.0 * theta)
        v.co.x = x * lobe * (1.0 + 0.18 * (z / 0.10))
        v.co.y = y * lobe * (1.0 + 0.18 * (z / 0.10))
        v.co.z = z - 0.024 * math.exp(-r2 * 260.0) * (1.0 if z > 0 else -0.6)
    body.data.update()
    curve_tube("Apple_stem", [(0.0, 0.0, 0.182), (0.006, 0.0, 0.215), (0.022, 0.005, 0.242)], 0.008, "wood_dark")
    botanical_leaf("Apple_leaf", (0.008, 0.0, 0.212), (0.088, -0.025, 0.238), 0.026, 0.012, "leaf")


def build_tomato() -> None:
    body = ellipsoid("Tomato_body", (0.0, 0.0, 0.085), (0.115, 0.115, 0.086), "berry", segs=40, rings=20)
    for v in body.data.vertices:
        theta = math.atan2(v.co.y, v.co.x)
        rib = 1.0 + 0.045 * math.cos(6.0 * theta)
        v.co.x *= rib
        v.co.y *= rib
    body.data.update()
    for i in range(5):
        ang = i * math.tau / 5.0
        botanical_leaf(f"Tomato_sepal_{i}", (0.0, 0.0, 0.165), (0.068 * math.cos(ang), 0.068 * math.sin(ang), 0.158), 0.016, 0.008, "leaf")
    curve_tube("Tomato_stem", [(0.0, 0.0, 0.162), (0.006, 0.0, 0.198)], 0.008, "leaf")


def build_orange() -> None:
    ellipsoid("Orange_body", (0.0, 0.0, 0.102), (0.106, 0.106, 0.100), "orange", segs=36, rings=20)
    rcyl("Orange_calyx", (0.0, 0.0, 0.200), 0.016, 0.010, "leaf", bevel=0.003)
    botanical_leaf("Orange_leaf", (0.006, 0.0, 0.205), (0.082, -0.02, 0.228), 0.024, 0.010, "leaf")


def build_pear() -> None:
    lathe(
        "Pear_body",
        [(0.0, 0.0), (0.048, 0.004), (0.096, 0.048), (0.102, 0.092), (0.072, 0.148), (0.046, 0.198), (0.022, 0.228), (0.0, 0.234)],
        "tint",
        steps=38,
    )
    curve_tube("Pear_stem", [(0.0, 0.0, 0.228), (0.010, 0.0, 0.268), (0.024, 0.0, 0.285)], 0.007, "wood_dark")
    botanical_leaf("Pear_leaf", (0.010, 0.0, 0.258), (0.078, -0.02, 0.275), 0.022, 0.010, "leaf")


def build_banana() -> None:
    for idx, (oy, yaw) in enumerate([(-0.036, -14.0), (0.0, 0.0), (0.036, 14.0)]):
        curve_tube(
            f"Banana_{idx}",
            [(-0.115, -0.01, 0.095), (-0.055, oy, 0.038), (0.035, oy * 1.15, 0.034), (0.115, oy * 0.6, 0.088)],
            0.026,
            "yellow",
            radii_mult=[0.55, 1.0, 1.05, 0.45],
        )
    rbox("Banana_crown", (-0.122, -0.01, 0.105), (0.032, 0.045, 0.032), "wood_dark", bevel=0.008, rot=(0.0, -25.0, 0.0))


def build_egg() -> None:
    lathe(
        "Egg_dish",
        [(0.0, 0.0), (0.075, 0.0), (0.092, 0.028), (0.084, 0.032), (0.066, 0.012), (0.0, 0.012)],
        "cream",
        steps=36,
    )
    lathe(
        "Egg_shell",
        [(0.0, 0.014), (0.048, 0.024), (0.068, 0.068), (0.062, 0.118), (0.038, 0.158), (0.0, 0.172)],
        "tint",
        steps=36,
    )


def build_potato() -> None:
    p = ellipsoid("Potato_body", (0.0, 0.0, 0.068), (0.125, 0.086, 0.068), "bread", segs=32, rings=18)
    for v in p.data.vertices:
        v.co.x += 0.008 * math.sin(v.co.y * 22.0 + v.co.z * 15.0)
        v.co.z += 0.005 * math.cos(v.co.x * 19.0)
    p.data.update()
    for ex, ey, ez in [(-0.045, -0.068, 0.088), (0.052, -0.062, 0.072), (0.012, 0.065, 0.095)]:
        ellipsoid("Potato_eye", (ex, ey, ez), (0.009, 0.006, 0.006), "wood_dark")


def build_vegetable() -> None:
    # Plump fresh bok choy / leafy green bundle
    ellipsoid("Veg_base_bulb", (0.0, 0.0, 0.045), (0.058, 0.058, 0.045), "leaf_light")
    for i in range(6):
        ang = i * math.tau / 6.0
        sx, sy = 0.032 * math.cos(ang), 0.032 * math.sin(ang)
        ex, ey = 0.105 * math.cos(ang), 0.105 * math.sin(ang)
        curve_tube(f"Veg_stem_{i}", [(sx, sy, 0.035), (sx * 1.4, sy * 1.4, 0.105), (ex * 0.72, ey * 0.72, 0.155)], 0.016, "cream")
        botanical_leaf(f"Veg_leaf_{i}", (sx * 1.3, sy * 1.3, 0.095), (ex, ey, 0.215), 0.044, 0.016, "leaf")


def build_fish() -> None:
    ellipsoid("Fish_platter", (0.0, 0.0, 0.014), (0.175, 0.115, 0.014), "cream", segs=36, rings=14)
    ellipsoid("Fish_platter_rim", (0.0, 0.0, 0.022), (0.165, 0.106, 0.008), "white", segs=36, rings=12)
    ellipsoid("Fish_body", (-0.018, 0.0, 0.052), (0.112, 0.052, 0.032), "tint", segs=32, rings=16)
    rcone("Fish_tail", (0.108, 0.0, 0.052), 0.046, 0.008, 0.058, "tint_dark", bevel=0.003, rot=(0.0, -90.0, 0.0))
    ellipsoid("Fish_dorsal", (-0.015, 0.038, 0.062), (0.045, 0.018, 0.012), "tint_light")
    ellipsoid("Fish_eye", (-0.088, -0.022, 0.068), (0.010, 0.010, 0.008), "charcoal")
    rcyl("Fish_lemon", (0.045, -0.048, 0.034), 0.026, 0.010, "yellow", bevel=0.003, rot=(18.0, 0.0, 0.0))


def build_chicken() -> None:
    lathe(
        "Chick_plate",
        [(0.0, 0.0), (0.135, 0.0), (0.162, 0.026), (0.152, 0.030), (0.122, 0.012), (0.0, 0.012)],
        "cream",
        steps=40,
    )
    ellipsoid("Chick_drumstick", (-0.025, 0.0, 0.068), (0.095, 0.064, 0.054), "bread", rot=(0.0, -14.0, 12.0))
    rcyl("Chick_bone", (0.078, 0.022, 0.088), 0.016, 0.075, "cream", bevel=0.004, rot=(0.0, 76.0, 12.0))
    rtorus("Chick_frill", (0.095, 0.026, 0.092), 0.022, 0.009, "white", rot=(0.0, 76.0, 12.0))
    for gx, gy in [(-0.075, -0.065), (0.035, -0.075), (-0.055, 0.072)]:
        ellipsoid("Chick_pea", (gx, gy, 0.026), (0.014, 0.014, 0.012), "leaf")


def build_dumplings() -> None:
    lathe(
        "Dump_steamer",
        [(0,0), (0.128,0), (0.140,0.004), (0.146,0.009), (0.149,0.037),
         (0.148,0.048), (0.141,0.048), (0.138,0.043), (0.135,0.019), (0.128,0.014), (0,0.014)],
        "wood",
        steps=52, subsurf=0,
    )
    for z,radius in [(0.009,0.146), (0.036,0.149), (0.047,0.147)]:
        rtorus("Bamboo_binding", (0,0,z), radius, 0.0028, "wood_dark", major_seg=52, minor_seg=8)
    rcyl("Dump_leaf_mat", (0.0, 0.0, 0.018), 0.132, 0.006, "leaf", bevel=0.002)
    for ang_d in (30.0, 150.0, 270.0):
        ang = math.radians(ang_d)
        _pleated_dumpling(0.067*math.cos(ang), 0.067*math.sin(ang), ang + math.pi/2)


def _pleated_dumpling(cx, cy, rotation):
    # Sections run from one upturned corner to the other. Only the front
    # wrapper is gathered; its ridges lean into the narrower pinched seam.
    section = [(0,0),(-0.72,0.05),(-1,0.32),(-0.83,0.60),(-0.41,0.82),
               (-0.17,0.95),(0,1),(0.11,0.96),(0.35,0.79),(0.92,0.46),(0.85,0.15),(0.55,0.03)]
    width = len(section)
    mesh_points, seam, faces = [], [], []
    for i in range(33):
        t = i/16-1
        belly = math.sqrt(max(0.003, 1-t*t))
        x = 0.064*t
        for j, (side, h) in enumerate(section):
            fold = math.cos(i*math.tau*7/32 - h*2.8)
            y = 0.024*t*t + side*0.033*belly
            if side < 0:
                y -= 0.0045*fold*belly*math.sin(h*math.pi)
            z = 0.0215 + 0.006*t*t + h*(0.008+0.052*belly)
            z += 0.0024*fold*belly*h**3
            point = (cx+x*math.cos(rotation)-y*math.sin(rotation),
                     cy+x*math.sin(rotation)+y*math.cos(rotation), z)
            mesh_points.append(point)
            if j == 6:
                seam.append(point)
            if i:
                a = (i-1)*width+j
                b = (i-1)*width+(j+1)%width
                faces.append((a,b,b+width,a+width))
    faces.extend([tuple(reversed(range(width))), tuple(range(len(mesh_points)-width,len(mesh_points)))])
    mesh = bpy.data.meshes.new("Pinched_wrapper")
    mesh.from_pydata(mesh_points, [], faces)
    mesh.update()
    bpy.context.collection.objects.link(bpy.data.objects.new("Dumpling_wrapper",mesh))
    mesh.materials.append(MATERIALS["cream"])
    for face in mesh.polygons:
        face.use_smooth = len(face.vertices) == 4
    curve_tube("Dumpling_seam", seam, 0.0022, "cream", bevel_res=1, smooth_spline=False)


def build_sandwich() -> None:
    lathe(
        "Sand_plate",
        [(0.0, 0.0), (0.135, 0.0), (0.158, 0.022), (0.148, 0.026), (0.120, 0.010), (0.0, 0.010)],
        "white",
        steps=38,
    )
    rbox("Sand_bread_bot", (0.0, 0.0, 0.026), (0.19, 0.18, 0.028), "bread", bevel=0.010)
    rbox("Sand_crumb_bot", (0.0, 0.0, 0.032), (0.172, 0.162, 0.020), "crumb", bevel=0.006)
    for lx, ly in [(-0.04, -0.04), (0.04, -0.04), (-0.04, 0.04), (0.04, 0.04)]:
        ellipsoid("Sand_lettuce", (lx, ly, 0.048), (0.062, 0.058, 0.010), "leaf_light")
    rcyl("Sand_tomato", (-0.02, -0.01, 0.060), 0.058, 0.014, "berry", bevel=0.004)
    rbox("Sand_cheese", (0.0, 0.0, 0.072), (0.175, 0.175, 0.010), "yellow", bevel=0.003, rot=(0.0, 0.0, 12.0))
    rbox("Sand_bread_top", (0.0, 0.0, 0.092), (0.19, 0.18, 0.028), "bread", bevel=0.010)


def build_hamburger() -> None:
    lathe(
        "Burg_plate",
        [(0.0, 0.0), (0.132, 0.0), (0.155, 0.022), (0.146, 0.025), (0.118, 0.010), (0.0, 0.010)],
        "white",
        steps=38,
    )
    rcyl("Burg_bun_bot", (0.0, 0.0, 0.028), 0.098, 0.032, "bread", bevel=0.012)
    for i in range(9):
        ang = i * math.tau / 9.0
        tip = (0.108 * math.cos(ang), 0.106 * math.sin(ang), 0.053+0.005*math.sin(3.2*i))
        botanical_leaf("Burg_lettuce", (0.022*math.cos(ang),0.022*math.sin(ang),0.048),
                       tip,0.038,0.012,"leaf_light" if i%3 else "leaf","leaf_light")
    rcyl("Burg_patty", (0.0, 0.0, 0.066), 0.096, 0.028, "wood_dark", bevel=0.010)
    rbox("Burg_cheese", (0.0, 0.0, 0.082), (0.155, 0.155, 0.009), "orange", bevel=0.003, rot=(0.0, 0.0, 45.0))
    rcyl("Burg_tomato", (0.0, 0.0, 0.092), 0.082, 0.014, "berry", bevel=0.004)
    bun = lathe("Burg_bun_top",[(0,0.097),(0.086,0.097),(0.102,0.106),(0.099,0.119),
        (0.092,0.135),(0.078,0.147),(0.055,0.157),(0.028,0.163),(0,0.165)],"bread",steps=44)
    # A baked crust grades from pale at the split to amber at the crown.
    from primitives import MATERIALS
    bun.data.materials.append(MATERIALS["crumb"])
    for face in bun.data.polygons:
        if face.center.z < 0.107 + 0.002*math.sin(face.center.x*85):
            face.material_index = 1
    for i in range(19):
        ang = i*2.39996
        r = 0.083*math.sqrt((i+0.42)/19)
        top = 0.099 + 0.066*math.sqrt(1-(r/0.102)**2)
        ellipsoid("Burg_sesame", (r*math.cos(ang),r*math.sin(ang),top),
                  (0.0055,0.0026,0.0020), "cream", segs=12,rings=8,
                  rot=(0,math.degrees(r*5),math.degrees(ang)+26))


def build_cake() -> None:
    lathe(
        "Cake_plate",
        [(0.0, 0.0), (0.145, 0.0), (0.162, 0.020), (0.152, 0.024), (0.130, 0.010), (0.0, 0.010)],
        "white",
        steps=40,
    )
    rcyl("Cake_sponge_1", (0.0, 0.0, 0.048), 0.118, 0.068, "tint", bevel=0.012)
    rcyl("Cake_filling", (0.0, 0.0, 0.086), 0.120, 0.016, "cream", bevel=0.005)
    rcyl("Cake_sponge_2", (0.0, 0.0, 0.122), 0.118, 0.062, "tint", bevel=0.012)
    rcyl("Cake_icing", (0.0, 0.0, 0.156), 0.122, 0.020, "cream", bevel=0.008)
    for i in range(8):
        ang = i * math.tau / 8.0
        ellipsoid("Cake_rosette", (0.092 * math.cos(ang), 0.092 * math.sin(ang), 0.172), (0.018, 0.018, 0.014), "white")
    rcone("Cake_strawberry", (0.0, 0.0, 0.192), 0.028, 0.006, 0.048, "berry", bevel=0.004)


def build_candy() -> None:
    ellipsoid("Candy_center", (0.0, 0.0, 0.056), (0.072, 0.056, 0.052), "tint", segs=32, rings=18)
    rtorus("Candy_swirl", (0.0, 0.0, 0.056), 0.054, 0.009, "cream", rot=(0.0, 90.0, 0.0))
    for sx in (-1.0, 1.0):
        rcone("Candy_tail", (sx * 0.105, 0.0, 0.056), 0.048, 0.012, 0.072, "tint_light", bevel=0.004, rot=(0.0, sx * -90.0, 0.0))


def build_milk() -> None:
    rbox("Milk_body", (0.0, 0.0, 0.098), (0.128, 0.128, 0.192), "white", bevel=0.012)
    rbox("Milk_band", (0.0, 0.0, 0.088), (0.131, 0.131, 0.078), "sky", bevel=0.008)
    rbox("Milk_gable", (0.0, 0.0, 0.215), (0.092, 0.128, 0.092), "cream", bevel=0.008, rot=(0.0, 45.0, 0.0))
    rbox("Milk_fin", (0.0, 0.0, 0.258), (0.018, 0.128, 0.028), "white", bevel=0.004)
    rcyl("Milk_cap", (0.0, -0.036, 0.232), 0.018, 0.016, "sky", bevel=0.003, rot=(45.0, 0.0, 0.0))


def build_cup() -> None:
    lathe(
        "Cup_mug",
        [(0.0, 0.0), (0.074, 0.0), (0.086, 0.022), (0.088, 0.168), (0.076, 0.172), (0.074, 0.022), (0.0, 0.022)],
        "tint",
        steps=40,
    )
    rcyl("Cup_tea_surface", (0.0, 0.0, 0.138), 0.074, 0.010, "cream", bevel=0.002)
    curve_tube(
        "Cup_handle",
        [(0.084, 0.0, 0.140), (0.128, 0.0, 0.132), (0.134, 0.0, 0.085), (0.122, 0.0, 0.045), (0.082, 0.0, 0.042)],
        0.013,
        "tint_light",
    )


def build_juice_glass() -> None:
    lathe(
        "Juice_tumbler",
        [(0.0, 0.0), (0.064, 0.0), (0.082, 0.185), (0.074, 0.185), (0.058, 0.018), (0.0, 0.018)],
        "glass",
        steps=38,
    )
    rcone("Juice_fill", (0.0, 0.0, 0.088), 0.056, 0.072, 0.135, "orange", bevel=0.006)
    rtorus("Juice_meniscus",(0.0,0.0,0.154),0.069,0.0025,"yellow",minor_seg=8)
    rtorus("Juice_glass_lip",(0.0,0.0,0.185),0.078,0.003,"glass",minor_seg=8)
    rcyl("Juice_slice", (0.076, 0.0, 0.185), 0.036, 0.010, "yellow", bevel=0.003, rot=(90.0, 0.0, 0.0))
    curve_tube("Juice_straw", [(-0.018, 0.0, 0.065), (-0.035, 0.0, 0.215), (-0.072, 0.0, 0.238)], 0.007, "berry")


def build_teapot() -> None:
    lathe(
        "Teapot_belly",
        [(0.0, 0.0), (0.072, 0.0), (0.118, 0.065), (0.115, 0.125), (0.076, 0.168), (0.0, 0.168)],
        "tint",
        steps=42,
    )
    lathe(
        "Teapot_lid",
        [(0.0, 0.198), (0.048, 0.188), (0.074, 0.168), (0.0, 0.168)],
        "tint_light",
        steps=36,
    )
    ellipsoid("Teapot_knob", (0.0, 0.0, 0.208), (0.018, 0.018, 0.016), "cream")
    curve_tube(
        "Teapot_spout",
        [(-0.098, 0.0, 0.078), (-0.148, 0.0, 0.115), (-0.168, 0.0, 0.168)],
        0.018,
        "tint",
        radii_mult=[1.15, 0.85, 0.65],
    )
    curve_tube(
        "Teapot_handle",
        [(0.095, 0.0, 0.145), (0.148, 0.0, 0.138), (0.152, 0.0, 0.082), (0.102, 0.0, 0.052)],
        0.013,
        "tint_light",
    )


def build_plate() -> None:
    lathe(
        "Plate_ceramic",
        [(0.0, 0.0), (0.105, 0.0), (0.115, 0.008), (0.162, 0.028), (0.165, 0.034), (0.148, 0.034), (0.102, 0.014), (0.0, 0.014)],
        "tint",
        steps=44,
    )
    rtorus("Plate_gold_band", (0.0, 0.0, 0.032), 0.154, 0.0035, "gold")


def _base_ceramic_bowl(mat: str = "tint") -> None:
    lathe(
        "Bowl_vessel",
        [(0.0, 0.0), (0.062, 0.0), (0.066, 0.014), (0.118, 0.068), (0.132, 0.118), (0.122, 0.120), (0.106, 0.070), (0.056, 0.022), (0.0, 0.022)],
        mat,
        steps=42,
    )
    rtorus("Bowl_rim_accent", (0.0, 0.0, 0.118), 0.127, 0.0045, "cream")


def build_bowl() -> None:
    _base_ceramic_bowl("tint")


def build_rice_bowl() -> None:
    _base_ceramic_bowl("sky")
    ellipsoid("Rice_mound", (0,0,0.108), (0.118,0.116,0.048), "cream", segs=32, rings=16)
    grain_count = 224
    for i in range(grain_count):
        angle = i*2.39996
        r = math.sqrt((i+0.5)/grain_count)*0.974
        slope = math.sqrt(1-r*r)
        yaw = i*1.731 + 0.45*math.sin(2*i)
        tilt = math.atan(0.41*r/slope*math.cos(yaw-angle))
        center = (0.118*r*math.cos(angle), 0.116*r*math.sin(angle), 0.108+0.048*slope)
        sesame = i in (13, 19, 64)
        size = (0.0060,0.0026,0.0020) if sesame else (0.0115,0.0043,0.0035)
        ellipsoid("Rice_sesame" if sesame else "Rice_grain", center, size,
                  "charcoal" if sesame else ("cream" if i%5==0 else "white"),
                  segs=8, rings=4, rot=(0,math.degrees(tilt),math.degrees(yaw)))


def build_noodle_bowl() -> None:
    _base_ceramic_bowl("berry")
    rcyl("Noodle_broth", (0.0, 0.0, 0.095), 0.115, 0.014, "bread", bevel=0.003)
    for strand in range(5):
        points = []
        for i in range(48):
            t = i/47
            angle = t*(6.4+strand*0.55)+strand*1.38
            radius = 0.028+0.010*strand+0.013*math.sin(2*angle+strand)+0.011*t
            points.append((-0.012+radius*math.cos(angle),0.010+0.88*radius*math.sin(angle),
                           0.105+0.007*math.sin(2.6*angle+strand)))
        curve_tube("Noodle_strand",points,0.0038,"crumb",bevel_res=1,smooth_spline=False)
    ellipsoid("Noodle_egg_white", (0.048, -0.035, 0.116), (0.036, 0.028, 0.014), "white", rot=(12.0, -10.0, 20.0))
    ellipsoid("Noodle_egg_yolk", (0.048, -0.036, 0.122), (0.018, 0.016, 0.010), "orange", rot=(12.0, -10.0, 20.0))
    botanical_leaf("Noodle_greens", (-0.045, -0.025, 0.108), (-0.095, -0.055, 0.132), 0.028, 0.010, "leaf")
    for x,y,angle in [(0.011,0.066,18), (0.037,0.052,-14), (0.027,0.075,-8)]:
        rtorus("Noodle_scallion",(x,y,0.109),0.006,0.002,"leaf",major_seg=12,minor_seg=5,rot=(angle,12,0))


def build_soup_bowl() -> None:
    _base_ceramic_bowl("cream")
    rcyl("Soup_broth", (0.0, 0.0, 0.096), 0.116, 0.016, "orange", bevel=0.004)
    for cx, cy, mk in [(-0.038, -0.025, "leaf"), (0.032, 0.028, "leaf"), (-0.015, 0.042, "cream"), (0.042, -0.028, "yellow")]:
        rcyl("Soup_garnish", (cx, cy, 0.104), 0.016, 0.008, mk, bevel=0.003)


def build_pot() -> None:
    lathe(
        "Pot_body",
        [(0.0, 0.0), (0.115, 0.0), (0.132, 0.032), (0.132, 0.138), (0.120, 0.138), (0.120, 0.020), (0.0, 0.020)],
        "tint",
        steps=40,
    )
    lathe(
        "Pot_lid",
        [(0.0, 0.172), (0.082, 0.162), (0.135, 0.138), (0.0, 0.138)],
        "tint_dark",
        steps=40,
    )
    rtorus("Pot_knob", (0.0, 0.0, 0.178), 0.024, 0.007, "charcoal", rot=(90.0, 0.0, 0.0))
    for sx in (-1.0, 1.0):
        rtorus("Pot_ear", (sx * 0.138, 0.0, 0.115), 0.026, 0.008, "charcoal", rot=(90.0, 0.0, 0.0))


def build_chopsticks() -> None:
    rbox("Chop_rest", (-0.045, 0.0, 0.014), (0.028, 0.088, 0.024), "cream", bevel=0.008, subsurf=1)
    for sy, ang in ((-0.020, 2.5), (0.020, -2.5)):
        rcone("Chopstick", (0.0, sy, 0.032), 0.005, 0.009, 0.31, "wood", bevel=0.002, rot=(0.0, 87.0, ang))


def build_spoon() -> None:
    rbox("Spoon_rest", (-0.045, 0.0, 0.010), (0.045, 0.055, 0.016), "cream", bevel=0.006)
    ellipsoid("Spoon_bowl", (0.078, 0.0, 0.028), (0.054, 0.038, 0.018), "silver", rot=(0.0, -8.0, 0.0))
    ellipsoid("Spoon_hollow", (0.078, 0.0, 0.036), (0.042, 0.028, 0.009), "white", rot=(0.0, -8.0, 0.0))
    curve_tube("Spoon_handle", [(0.032, 0.0, 0.028), (-0.035, 0.0, 0.034), (-0.115, 0.0, 0.026)], 0.009, "tint")


HOME_FOOD_BUILDERS: list[tuple[str, callable, float]] = [
    ("pillow", build_pillow, 0.30),
    ("quilt", build_quilt, 0.31),
    ("towel", build_towel, 0.28),
    ("toothbrush", build_toothbrush, 0.27),
    ("comb", build_comb, 0.27),
    ("soap", build_soap, 0.25),
    ("water", build_water, 0.29),
    ("bucket", build_bucket, 0.29),
    ("umbrella", build_umbrella, 0.32),
    ("glasses", build_glasses, 0.25),
    ("clock", build_clock, 0.26),
    ("watch", build_watch, 0.22),
    ("lamp", build_lamp, 0.31),
    ("key", build_key, 0.26),
    ("stool", build_stool, 0.28),
    ("apple", build_apple, 0.24),
    ("tomato", build_tomato, 0.23),
    ("orange", build_orange, 0.23),
    ("pear", build_pear, 0.26),
    ("banana", build_banana, 0.27),
    ("egg", build_egg, 0.21),
    ("potato", build_potato, 0.23),
    ("vegetable", build_vegetable, 0.26),
    ("fish", build_fish, 0.31),
    ("chicken", build_chicken, 0.29),
    ("dumplings", build_dumplings, 0.29),
    ("sandwich", build_sandwich, 0.28),
    ("hamburger", build_hamburger, 0.27),
    ("cake", build_cake, 0.29),
    ("candy", build_candy, 0.25),
    ("milk", build_milk, 0.26),
    ("cup", build_cup, 0.22),
    ("juice_glass", build_juice_glass, 0.25),
    ("teapot", build_teapot, 0.29),
    ("plate", build_plate, 0.29),
    ("bowl", build_bowl, 0.25),
    ("rice_bowl", build_rice_bowl, 0.25),
    ("noodle_bowl", build_noodle_bowl, 0.26),
    ("soup_bowl", build_soup_bowl, 0.25),
    ("pot", build_pot, 0.29),
    ("chopsticks", build_chopsticks, 0.31),
    ("spoon", build_spoon, 0.26),
]
