"""Author the three specialist classrooms without changing the shared manifest.

Run in a hidden, separate Blender background process:
  blender --background --factory-startup --python build_specialist_rooms.py -- --all

The editable .blend is the source of truth. Rebuilding an existing source requires
--overwrite. Each room writes its own manifest-entry.json for the integrator.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import os
import sys
import time

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import modeling as m
import pipeline as p
import validate_interiors as validator


NAMES = {"music_room": "音乐教室", "art_room": "美术教室", "science_room": "科学教室"}
ROOM_SIZES = {"music_room": (18, 16), "art_room": (16, 14), "science_room": (18, 16)}


def plan_for(room_id):
    plan = json.loads((p.ROOT / "game/data/landmark_interiors.json").read_text(encoding="utf-8"))
    school = next(entry for entry in plan["landmarks"] if entry["room_id"] == "school")
    return next(area for area in school["areas"] if area["room_id"] == room_id)


def locus(room_id, index, xy, associated):
    authored = plan_for(room_id)["anchors"][index - 1]
    anchor = m.anchor(authored["node_name"], xy, authored["label"], associated)
    anchor["memory_id"] = authored["id"]
    anchor["activity"] = authored["activity"]
    return anchor


def common(room_id, title, accent, host):
    width, depth = ROOM_SIZES[room_id]
    m.setup(room_id)
    m.room_shell(width, depth, wall="ivory", floor_mat="lightwood" if room_id != "science_room" else "cream")
    # Open front and camera-side walls, no roof, a continuous centre-to-rear aisle.
    m.title_banner(title, "A place to explore together", accent, y=depth / 2 - .22)
    m.anchor("SG_SPAWN", (0, -depth / 2 + 2.1), "进入点")
    m.anchor("SG_EXIT", (0, -depth / 2 + 1.05), "返回完整校园")
    m.anchor("SG_NPC_HOST", host, NAMES[room_id] + "老师")
    m.group("01_Architecture_Details")
    for x in [-width / 2 + 2.1, width / 2 - 2.1]:
        m.window("Room_Window", x, depth / 2 - .19, 2.1, 2.3, 1.45)
    # Horizontal low trim reinforces the dollhouse scale without covering props.
    m.box("Rear_Accent_Skirting", (0, depth / 2 - .23, .48), (width - .35, .11, .42), accent, .025)
    m.box("Entry_Mat", (0, -depth / 2 + 1.1, .012), (2.35, 1.0, .024), accent, .09)
    m.text("Entry_Welcome", "WELCOME", (0, -depth / 2 + 1.1, .03), .22, "ivory", facing="up")


def extruded_polygon(name, outline, z, height, mat):
    outline = list(outline)
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(outline, outline[1:] + outline[:1]))
    if area < 0:
        outline.reverse()
    n = len(outline)
    vertices = [(x, y, z) for x, y in outline] + [(x, y, z + height) for x, y in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return m.soften(m.mesh(name, vertices, faces, mat), .035)


def note(name, x, y, z, s=.28, color="gold"):
    m.ball(name + "_Head", (x, y, z), (s * .7, .055, s * .5), color)
    m.beam(name + "_Stem", (x + s * .58, y, z), (x + s * .58, y, z + s * 2.8), .035, color)
    m.beam(name + "_Flag", (x + s * .58, y, z + s * 2.8), (x + s * 1.35, y, z + s * 2.25), .05, color)


def music_sheet(name, x, y, z, width=.72, vertical=False):
    if vertical:
        m.box(name + "_Paper", (x, y, z), (width, .025, width * 1.15), "paper", .012)
        for row in range(5):
            m.box(name + "_Staff", (x, y - .02, z + (row - 2) * width * .13), (width * .8, .012, .012), "darkwood", 0)
        for k in range(3):
            note(name + "_Note", x - width * .25 + k * width * .25, y - .035, z + ((k % 2) - .5) * width * .14, width * .08, "black")
    else:
        m.box(name + "_Paper", (x, y, z), (width, width * 1.15, .025), "paper", .012)
        for row in range(5):
            m.box(name + "_Staff", (x, y + (row - 2) * width * .13, z + .018), (width * .8, .012, .01), "darkwood", 0)
        for k in range(3):
            m.ball(name + "_Note", (x - width * .24 + k * width * .24, y + (k % 2) * width * .12, z + .03), (width * .045, width * .035, .01), "black", 12, 8)


def guitar(name, x, y, z=0, color="oak", scale=1):
    outline = [(-.22, 0), (-.47, .1), (-.53, .38), (-.33, .62), (-.38, .82), (-.23, .98), (.23, .98), (.38, .82), (.33, .62), (.53, .38), (.47, .1), (.22, 0)]
    body = extruded_polygon(name + "_Body", [(a * scale, b * scale) for a, b in outline], -.12 * scale, .24 * scale, color)
    body.rotation_euler.x = math.pi / 2
    body.location = (x, y, z + .16 * scale)
    m.box(name + "_Neck", (x, y, z + 1.57 * scale), (.17 * scale, .12 * scale, 1.10 * scale), "darkwood", .02)
    m.box(name + "_Headstock", (x, y, z + 2.18 * scale), (.26 * scale, .15 * scale, .38 * scale), color, .035)
    hole = m.cyl(name + "_SoundHole", (x, y - .136 * scale, z + .81 * scale), .16 * scale, .018 * scale, "darkwood", 32)
    hole.rotation_euler.x = math.pi / 2
    for i in range(4):
        xx = x + (i - 1.5) * .034 * scale
        m.beam(name + "_String", (xx, y - .16 * scale, z + .45 * scale), (xx, y - .16 * scale, z + 2.25 * scale), .006 * scale, "cream")
    for h in [1.13, 1.32, 1.51, 1.70, 1.88]:
        m.box(name + "_Fret", (x, y - .082 * scale, z + h * scale), (.19 * scale, .014 * scale, .017 * scale), "gold", 0)
    for dx in [-.19, .19]:
        for h in [2.08, 2.24]:
            m.ball(name + "_TuningPeg", (x + dx * scale, y, z + h * scale), (.06 * scale, .065 * scale, .045 * scale), "gold", 12, 8)


def grand_piano(x, y):
    name = "Music_Piano"
    outline = [(-1.8, -1.0), (1.8, -1.0), (1.8, .1), (1.5, .75), (.95, 1.35), (.2, 1.65), (-.9, 1.3), (-1.8, .65)]
    points = [(x + a, y + b) for a, b in outline]
    extruded_polygon(name + "_CurvedCase", points, 1.0, .38, "navy")
    extruded_polygon(name + "_Rim", [(x + a * .97, y + b * .97) for a, b in outline], 1.39, .07, "darkwood")
    # Lid is raised slightly and held with a visible prop, not an opaque room-sized slab.
    lid = extruded_polygon(name + "_RaisedLid", [(a * .94, b * .94) for a, b in outline], 0, .085, "teal")
    lid.location = (x, y, 1.72)
    lid.rotation_euler.y = -.13
    m.beam(name + "_LidProp", (x + 1.25, y + .3, 1.4), (x + 1.25, y + .3, 1.95), .045, "gold")
    for dx, dy in [(-1.42, -.6), (1.42, -.6), (-.35, 1.0)]:
        m.cyl(name + "_Leg", (x + dx, y + dy, .52), .14, 1.04, "navy", 16, top=.10)
        m.ball(name + "_Caster", (x + dx, y + dy, .10), (.16, .16, .09), "gold", 12, 8)
    m.box(name + "_KeyboardBed", (x, y - 1.28, 1.10), (3.7, .72, .20), "navy")
    for i in range(28):
        xx = x - 1.68 + i * .124
        m.box(name + "_WhiteKey", (xx, y - 1.3, 1.22), (.116, .62, .045), "ivory", .008)
        if i % 7 not in [2, 6] and i < 27:
            m.box(name + "_BlackKey", (xx + .062, y - 1.13, 1.28), (.07, .35, .07), "black", .008)
    m.box(name + "_MusicRest", (x, y - .74, 1.68), (1.35, .11, .64), "navy", .025)
    music_sheet(name + "_Score", x, y - .81, 1.72, .75, True)
    m.bench(name + "_Bench", x, y - 2.05, 2.0, "teal", back=False)
    m.collider(name, (x, y + .15, .72), (3.7, 3.25, 1.44))
    m.text(name + "_Label", "PIANO", (x, y - 1.69, .96), .18, "gold")


def music_room():
    common("music_room", "MUSIC ROOM", "teal", (-1.25, -2.1))
    m.group("10_Score_Cabinet")
    m.shelf("Music_ScoreCabinet", -6.35, -2.8, 3.1, 3, "books", 2.5)
    m.box("Music_ScoreCabinet_TopLabel", (-6.35, -3.22, 2.68), (3.0, .10, .42), "teal")
    m.text("Music_ScoreCabinet_Label", "SHEET MUSIC", (-6.35, -3.29, 2.68), .23, "ivory")
    music_sheet("Music_ScoreCabinet_OpenScore", -6.35, -3.25, 1.55, .68, True)
    locus("music_room", 1, (-6.35, -4.4), "Music_ScoreCabinet")

    m.group("20_Grand_Piano")
    grand_piano(-5.0, 3.3)
    locus("music_room", 2, (-5.0, -.1), "Music_Piano_CurvedCase")

    m.group("30_Rhythm_Ensemble")
    cx, cy = 2.0, 1.2
    m.rug("Music_Rhythm_Rug", (cx, cy), (4.8, 3.4), "rose")
    for i, (dx, dy, radius, height, color) in enumerate([(-1.2, .1, .48, .83, "yellow"), (0, .45, .68, 1.0, "teal"), (1.2, .1, .48, .74, "rose")]):
        m.drum("Music_Rhythm_Drum_%02d" % i, cx + dx, cy + dy, 0, radius, height, color)
        m.beam("Music_Rhythm_Stick", (cx + dx - .30, cy + dy - .20, height + .09), (cx + dx + .24, cy + dy + .18, height + .13), .022, "oak")
    for dx in [-1.75, 1.75]:
        m.beam("Music_Rhythm_CymbalStand", (cx + dx, cy + .72, .06), (cx + dx, cy + .72, 1.65), .045, "metal")
        m.cyl("Music_Rhythm_Cymbal", (cx + dx, cy + .72, 1.65), .48, .045, "gold", 40, top=.19)
        for a in [0, 2.1, 4.2]:
            m.beam("Music_Rhythm_StandFoot", (cx + dx, cy + .72, .4), (cx + dx + .4 * math.cos(a), cy + .72 + .4 * math.sin(a), .06), .027, "metal")
    m.collider("Music_Rhythm_Drums", (cx, cy + .22, .85), (4.35, 2.4, 1.7))
    locus("music_room", 3, (2.0, -1.25), "Music_Rhythm_Drum_01_Shell")

    m.group("40_String_Instruments")
    m.box("Music_StringRack_Platform", (6.0, -3.05, .12), (3.3, 1.05, .24), "oak")
    for dx in [-1.55, 1.55]:
        m.box("Music_StringRack_Post", (6 + dx, -2.82, 1.28), (.12, .15, 2.55), "wood")
    m.box("Music_StringRack_TopRail", (6, -2.82, 2.5), (3.35, .17, .15), "wood")
    for i, (x, s, color) in enumerate([(4.95, .85, "lightwood"), (6.0, 1.0, "rose"), (7.05, .72, "oak")]):
        guitar("Music_String_%02d" % i, x, -3.1, .15, color, s)
    m.collider("Music_StringRack", (6.0, -3.0, 1.35), (3.5, 1.1, 2.7))
    locus("music_room", 4, (6.0, -5.0), "Music_StringRack_Platform")

    m.group("50_Little_Stage")
    m.box("Music_Stage_Platform", (0, 6.35, .19), (5.3, 2.1, .38), "oak", .16)
    m.box("Music_Stage_FrontFascia", (0, 5.27, .24), (5.1, .12, .28), "teal")
    m.collider("Music_Stage", (0, 6.35, .20), (5.3, 2.1, .40))
    for x in [-2.8, 2.8]:
        m.box("Music_Stage_CurtainPost", (x, 6.9, 1.7), (.16, .2, 3.4), "oak")
        for i in range(4):
            m.cyl("Music_Stage_CurtainFold", (x + (i - 1.5) * .16, 7.1, 1.95), .14, 2.65, "rose", 16)
    m.box("Music_Stage_CurtainRail", (0, 7.15, 3.35), (6.2, .22, .2), "oak")
    m.cyl("Music_Stage_MicrophoneBase", (0, 6.0, .45), .3, .10, "navy")
    m.beam("Music_Stage_MicStand", (0, 6, .48), (0, 6, 1.95), .035, "metal")
    m.beam("Music_Stage_Microphone", (0, 6, 1.95), (.30, 6, 2.08), .075, "navy")
    for x, z in [(-1.4, 2.3), (1.3, 2.45)]:
        note("Music_Stage_WallNote", x, 7.35, z, .28, "gold")
    locus("music_room", 5, (0, 4.1), "Music_Stage_Platform")

    m.group("60_Acoustic_Details")
    for x in [-8.15, 8.15]:
        for i in range(4):
            m.box("Music_AcousticPanel", (x, 4.7 - i * 1.1, 1.8), (.28, .7, 1.7), "sage" if i % 2 else "mint", .12)
    m.plant("Music_EntryFern", -8.0, -5.7, s=.75)


def painting(name, x, y, z, width=1.5, height=1.25, theme="flower"):
    m.box(name + "_Frame", (x, y, z), (width + .15, .13, height + .15), "oak", .045)
    m.box(name + "_Canvas", (x, y - .09, z), (width, .035, height), "paper", .012)
    front = y - .115
    if theme == "flower":
        m.beam(name + "_Stem", (x, front, z - height * .35), (x, front, z + height * .13), .035, "leaf")
        for i in range(6):
            a = i * math.tau / 6
            m.ball(name + "_Petal", (x + width * .18 * math.cos(a), front - .015, z + height * .15 + width * .18 * math.sin(a)), (width * .15, .03, height * .12), "rose", 12, 8)
        m.ball(name + "_FlowerCentre", (x, front - .045, z + height * .15), (width * .1, .035, height * .1), "yellow", 12, 8)
        m.ball(name + "_Leaf", (x + width * .12, front, z - height * .15), (width * .16, .025, height * .07), "leaflight", 12, 8)
    elif theme == "landscape":
        m.box(name + "_Sky", (x, front, z + height * .12), (width * .91, .02, height * .64), "glass", .01)
        m.ball(name + "_Sun", (x + width * .24, front - .02, z + height * .28), (width * .10, .02, width * .10), "yellow", 16, 8)
        for j, color in enumerate(["sage", "mint", "leaf"]):
            m.ball(name + "_Hill", (x + (j - 1) * width * .3, front - .03 - j * .005, z - height * .25), (width * .38, .025, height * (.24 + .035 * j)), color, 16, 8)
    else:
        for i, color in enumerate(["rose", "yellow", "teal", "blue"]):
            xx = x + (i % 2 - .5) * width * .42
            zz = z + (i // 2 - .5) * height * .42
            m.ball(name + "_ColourShape", (xx, front - .02, zz), (width * .16, .025, height * .18), color, 16, 8)


def paint_palette(name, x, y, z, scale=1):
    palette = m.ball(name + "_Board", (x, y, z), (.65 * scale, .47 * scale, .055), "lightwood", 24, 12)
    m.cyl(name + "_ThumbInset", (x + .30 * scale, y - .12 * scale, z + .045), .09 * scale, .014, "darkwood", 24)
    for i, color in enumerate(["red", "yellow", "blue", "white", "mint"]):
        a = .4 + i * .65
        m.ball(name + "_PaintBlob", (x + .44 * scale * math.cos(a), y + .3 * scale * math.sin(a), z + .065), (.095 * scale, .085 * scale, .025), color, 12, 8)
    return palette


def brush_cup(name, x, y, z, color="teal"):
    m.cyl(name + "_Cup", (x, y, z + .18), .19, .36, color, 24)
    m.cyl(name + "_DarkInterior", (x, y, z + .365), .155, .012, "darkwood", 24)
    for i in range(5):
        dx = (i - 2) * .055
        dy = .05 * (-1 if i % 2 else 1)
        m.beam(name + "_Handle", (x + dx, y + dy, z + .25), (x + dx * 1.9, y + dy * 2, z + .85 + (i % 2) * .1), .018, "oak")
        m.beam(name + "_Bristles", (x + dx * 1.9, y + dy * 2, z + .83 + (i % 2) * .1), (x + dx * 2.2, y + dy * 2.2, z + .98 + (i % 2) * .1), .035, "darkwood")


def pot(name, x, y, z, scale=1, color="clay"):
    # Lathed hollow profile retains a real rim and visible inner bowl.
    profile = [(.19, 0), (.31, .10), (.36, .36), (.30, .61), (.28, .66), (.23, .65), (.25, .58), (.29, .35), (.23, .14), (.12, .10)]
    vertices = []
    steps = 40
    for r, h in profile:
        vertices.extend((x + r * scale * math.cos(i * math.tau / steps), y + r * scale * math.sin(i * math.tau / steps), z + h * scale) for i in range(steps))
    faces = []
    for j in range(len(profile) - 1):
        for i in range(steps):
            faces.append((j * steps + i, j * steps + (i + 1) % steps, (j + 1) * steps + (i + 1) % steps, (j + 1) * steps + i))
    faces.append(tuple(reversed(range(steps))))
    ob = m.mesh(name, vertices, faces, color)
    for face in ob.data.polygons:
        face.use_smooth = True
    return ob


def art_room():
    common("art_room", "ART STUDIO", "rose", (-2.0, -3.1))
    m.group("10_Aprons_And_Preparation")
    x, y = -5.8, -2.75
    m.box("Art_ApronCabinet_Back", (x, y + .32, 1.4), (3.2, .14, 2.8), "mint")
    for dx in [-1.6, 1.6]:
        m.box("Art_ApronCabinet_Side", (x + dx, y, 1.4), (.12, .8, 2.8), "oak")
    for h in [.12, 2.75]:
        m.box("Art_ApronCabinet_Shelf", (x, y, h), (3.3, .85, .14), "lightwood")
    for i, color in enumerate(["yellow", "rose", "teal"]):
        xx = x + (i - 1) * .92
        m.ring("Art_Apron_Hook", (xx, y - .04, 2.45), .085, .022, "gold", (math.pi / 2, 0, 0), .7)
        apron = extruded_polygon("Art_Apron_Cloth", [(-.34, 0), (.34, 0), (.36, .85), (.22, 1.05), (.20, 1.27), (-.20, 1.27), (-.22, 1.05), (-.36, .85)], -.02, .04, color)
        apron.rotation_euler.x = math.pi / 2
        apron.location = (xx, y - .11, .72)
        m.ring("Art_Apron_NeckLoop", (xx, y - .10, 2.13), .20, .025, "cream", (math.pi / 2, 0, 0), .72)
        m.box("Art_Apron_Pocket", (xx, y - .16, 1.15), (.40, .025, .28), "cream", .025)
        for j in range(3):
            m.ball("Art_Apron_PaintMark", (xx + (j - 1) * .14, y - .15, 1.56 + (j % 2) * .13), (.055, .015, .07), ["blue", "yellow", "rose"][(j + i) % 3], 12, 8)
    m.collider("Art_ApronCabinet", (x, y, 1.4), (3.4, .9, 2.8))
    locus("art_room", 1, (x, -4.4), "Art_ApronCabinet_Back")

    m.group("20_Colour_Mixing")
    x, y = -5.0, 2.25
    top = m.table("Art_PaintTable", x, y, 3.4, 1.8, 1.04, "lightwood", solid=True)
    paint_palette("Art_MainPalette", x - .45, y - .12, top + .04)
    brush_cup("Art_Brushes", x + 1.0, y + .3, top)
    for i, color in enumerate(["red", "yellow", "blue", "white"]):
        m.jar("Art_PaintJar_%02d" % i, x - 1.15 + i * .48, y + .55, top, .17, color)
    m.text("Art_PaintTable_Label", "MIX COLOURS", (x, y - .95, .82), .22, "teal")
    locus("art_room", 2, (x, .15), "Art_PaintTable_Top")

    m.group("30_Central_Easels")
    m.rug("Art_Easel_WorkMat", (.7, 1.55), (3.4, 3.0), "mint")
    for i, (x, y, scale, theme) in enumerate([(.35, 1.5, 1.0, "flower"), (1.95, 2.1, .72, "landscape")]):
        name = "Art_Easel_%02d" % i
        for dx in [-.64, .64]:
            m.beam(name + "_FrontLeg", (x + dx * scale, y - .4, .05), (x + dx * .3 * scale, y + .1, 2.7 * scale), .075, "oak")
        m.beam(name + "_RearLeg", (x, y + .75, .05), (x, y + .1, 2.45 * scale), .065, "wood")
        m.box(name + "_CanvasShelf", (x, y - .28, .94 * scale), (1.65 * scale, .36, .12), "oak")
        painting(name + "_Painting", x, y - .12, 1.78 * scale, 1.35 * scale, 1.45 * scale, theme)
    m.collider("Art_EaselIsland", (.9, 1.6, 1.0), (3.4, 2.35, 2.0))
    locus("art_room", 3, (.9, -.9), "Art_Easel_00_CanvasShelf")

    m.group("40_Clay_Workshop")
    x, y = 5.0, -2.85
    top = m.table("Art_ClayTable", x, y, 3.1, 1.75, 1.03, "oak")
    m.box("Art_Clay_WorkingBoard", (x - .65, y, top + .035), (1.45, 1.1, .07), "lightwood")
    pot("Art_Clay_OpenVase", x - .8, y, top + .09, .9)
    pot("Art_Clay_BluePot", x + .4, y + .22, top + .03, .62, "teal")
    # A little hand-modelled rabbit makes this visibly a clay workshop.
    m.ball("Art_Clay_RabbitBody", (x + 1.05, y - .22, top + .22), (.22, .23, .23), "clay")
    m.ball("Art_Clay_RabbitHead", (x + 1.05, y - .22, top + .48), (.18, .18, .18), "clay")
    for dx in [-.08, .08]:
        m.ball("Art_Clay_RabbitEar", (x + 1.05 + dx, y - .22, top + .70), (.055, .065, .19), "clay")
    for i in range(3):
        m.beam("Art_Clay_SculptingTool", (x + .0 + i * .15, y - .65, top + .04), (x + .3 + i * .15, y - .2, top + .06), .025, "wood")
    m.stool("Art_Clay_Stool", 6.2, -1.2, .6, "rose")
    locus("art_room", 4, (5.0, -4.95), "Art_ClayTable_Top")

    m.group("50_Gallery_Wall")
    for i, (x, theme) in enumerate([(-3.4, "landscape"), (-1.65, "flower"), (0, "abstract"), (1.65, "landscape"), (3.4, "flower")]):
        painting("Art_Gallery_%02d" % i, x, 6.73, 1.72 + (i % 2) * .12, 1.32, 1.42, theme)
    m.box("Art_Gallery_LowerRail", (0, 6.57, .65), (8.8, .16, .11), "oak")
    locus("art_room", 5, (0, 4.7), "Art_Gallery_02_Frame")
    m.group("60_Studio_Details")
    m.sink("Art_RinseSink", -6.15, 5.35)
    m.plant("Art_WindowPlant", 6.6, 5.7, s=.8, flower=True)
    m.box("Art_DryingRack_Back", (6.65, 3.1, .96), (.1, 2.0, 1.9), "oak")
    for h in [.32, .68, 1.04, 1.4]:
        m.box("Art_DryingRack_Tray", (6.25, 3.1, h), (.9, 2.0, .065), "lightwood")
        m.box("Art_DryingRack_Paper", (6.17, 3.1, h + .05), (.65, 1.6, .025), "paper", .012)
    m.collider("Art_DryingRack", (6.3, 3.1, .9), (1.1, 2.1, 1.8))


def microscope(name, x, y, z, color="teal"):
    m.box(name + "_Base", (x, y, z + .08), (.72, .9, .16), color, .12)
    m.beam(name + "_ArmLower", (x + .22, y + .27, z + .13), (x + .22, y + .27, z + .85), .11, color)
    m.beam(name + "_ArmUpper", (x + .22, y + .27, z + .85), (x - .12, y -.02, z + 1.21), .11, color)
    m.box(name + "_Stage", (x - .03, y - .07, z + .50), (.62, .52, .07), "navy", .035)
    m.box(name + "_Slide", (x - .03, y - .07, z + .55), (.38, .16, .018), "glass", .006)
    m.beam(name + "_EyepieceTube", (x - .12, y - .02, z + 1.14), (x - .12, y - .24, z + 1.43), .09, "navy")
    m.beam(name + "_EyepieceRim", (x - .12, y - .23, z + 1.41), (x - .12, y - .29, z + 1.49), .12, "black")
    m.cyl(name + "_ObjectiveHub", (x - .12, y - .02, z + .98), .17, .13, "metal", 20)
    for i in range(3):
        a = i * math.tau / 3
        m.beam(name + "_Objective", (x - .12 + .12 * math.cos(a), y - .02 + .12 * math.sin(a), z + .95), (x - .12 + .12 * math.cos(a), y - .02 + .12 * math.sin(a), z + .72), .045, "gold")
    for dx in [-.37, .37]:
        knob = m.cyl(name + "_FocusKnob", (x + dx, y + .15, z + .75), .11, .08, "gold", 24)
        knob.rotation_euler.y = math.pi / 2
    m.cyl(name + "_Illuminator", (x - .03, y - .09, z + .22), .15, .11, "ivory", 24)


def magnifier(name, x, y, z, radius=.32):
    m.ring(name + "_Rim", (x, y, z), radius, .045, "gold", (math.pi / 2, 0, 0))
    m.beam(name + "_Handle", (x + radius * .7, y, z - radius * .7), (x + radius * 1.65, y, z - radius * 1.65), .055, "teal")


def magnet(name, x, y, z):
    outline = [(-.6, -.5), (.6, -.5), (.6, .65), (.25, .65), (.25, -.16), (-.25, -.16), (-.25, .65), (-.6, .65)]
    extruded_polygon(name + "_U", [(x + a, y + b) for a, b in outline], z, .18, "red")
    m.box(name + "_BluePole", (x + .425, y + .27, z + .10), (.35, .78, .20), "blue", .025)
    for dx in [-.425, .425]:
        m.box(name + "_PoleCap", (x + dx, y + .63, z + .10), (.35, .14, .21), "metal", .025)
    m.text(name + "_N", "N", (x - .425, y + .3, z + .205), .22, "ivory", facing="up")
    m.text(name + "_S", "S", (x + .425, y + .3, z + .215), .22, "ivory", facing="up")


def science_room():
    common("science_room", "SCIENCE LAB", "mint", (-1.5, -2.9))
    m.group("02_Laboratory_Floor")
    # Floor graphics remain flat visual geometry; the SG_FLOOR provides all support.
    for x in [-2.7, 2.7]:
        m.box("Science_AisleStripe", (x, 0, .005), (.065, 12.5, .01), "mint", 0)
    m.group("10_Preparation_Station")
    x, y = -6.0, -3.15
    top = m.table("Science_Preparation", x, y, 3.6, 1.55, 1.03, "mint", solid=True)
    m.box("Science_Preparation_Pegboard", (x, y + .65, 1.98), (3.4, .13, 1.6), "cream")
    for ix in range(11):
        for iz in range(4):
            m.ball("Science_Preparation_Peg", (x - 1.4 + ix * .28, y + .565, 1.45 + iz * .32), (.022, .012, .022), "oak", 8, 6)
    for gx in [x - .85, x + .65]:
        for dx in [-.18, .18]:
            m.ring("Science_SafetyGoggles_Lens", (gx + dx, y + .48, 2.03), .16, .035, "teal", (math.pi / 2, 0, 0))
        m.beam("Science_SafetyGoggles_Bridge", (gx - .03, y + .48, 2.03), (gx + .03, y + .48, 2.03), .025, "teal")
        m.beam("Science_SafetyGoggles_Strap", (gx - .35, y + .48, 2.03), (gx + .35, y + .48, 2.23), .022, "oak")
    m.box("Science_Preparation_FirstAidBox", (x - .9, y -.14, top + .24), (.75, .52, .48), "ivory")
    m.box("Science_Preparation_Cross1", (x - .9, y -.41, top + .26), (.13, .025, .32), "mint")
    m.box("Science_Preparation_Cross2", (x - .9, y -.425, top + .26), (.32, .025, .13), "mint")
    m.jar("Science_Preparation_Handwash", x + .5, y -.12, top, .19, "glass")
    m.beam("Science_Preparation_Pump", (x + .5, y -.12, top + .43), (x + .72, y -.12, top + .43), .035, "teal")
    m.text("Science_Preparation_Label", "LOOK  /  LISTEN  /  CARE", (x, y - .80, .81), .19, "teal")
    locus("science_room", 1, (x, -5.25), "Science_Preparation_Top")

    m.group("20_Microscope_Bench")
    x, y = -5.4, 3.8
    top = m.table("Science_MicroscopeBench", x, y, 3.7, 1.8, 1.03, "lightwood")
    microscope("Science_Microscope_01", x - .95, y, top, "teal")
    microscope("Science_Microscope_02", x + .85, y, top, "rose")
    m.box("Science_Microscope_SampleTray", (x, y - .4, top + .04), (.5, .45, .08), "cream")
    for i in range(3):
        m.box("Science_Microscope_SlideSample", (x, y - .55 + i * .14, top + .09), (.36, .10, .018), "glass", .005)
    m.text("Science_MicroscopeBench_Label", "LOOK CLOSELY", (x, y - .95, .82), .22, "teal")
    locus("science_room", 2, (x, 1.65), "Science_MicroscopeBench_Top")

    m.group("30_Central_Plant_Observation")
    x, y = 1.05, 1.45
    top = m.table("Science_PlantTable", x, y, 3.5, 2.15, 1.0, "mint", solid=True)
    for i, (dx, scale) in enumerate([(-1.05, .40), (0, .62), (1.05, .85)]):
        m.plant("Science_PlantStage_%02d" % i, x + dx, y + .20, top, False, scale)
        m.box("Science_PlantStage_Label", (x + dx, y - .9, 1.0), (.55, .04, .32), "cream")
        m.text("Science_PlantStage_Number", str(i + 1), (x + dx, y - .94, 1.0), .22, "teal")
    m.box("Science_Plant_ObservationBook", (x -.65, y -.55, top + .035), (.85, .45, .07), "paper")
    for i in range(4):
        m.box("Science_Plant_RecordLine", (x -.65, y -.68 + i * .085, top + .075), (.65, .009, .01), "mint", 0)
    magnifier("Science_Plant_Magnifier", x + 1.4, y + .5, top + 1.05, .28)
    m.beam("Science_Plant_MagnifierStand", (x + 1.65, y + .5, top), (x + 1.65, y + .5, top + .85), .035, "teal")
    locus("science_room", 3, (x, -.90), "Science_PlantTable_Top")

    m.group("40_Magnet_Experiments")
    x, y = 5.35, -3.55
    top = m.table("Science_MagnetTable", x, y, 3.6, 1.8, 1.03, "lightwood")
    m.box("Science_Magnet_Tray", (x -.65, y, top + .035), (1.9, 1.5, .07), "cream", .08)
    magnet("Science_Magnet_Horseshoe", x -.65, y, top + .08)
    for i in range(24):
        a = -.15 + i * math.tau / 24
        m.ball("Science_Magnet_IronFilings", (x -.65 + .82 * math.cos(a), y + .68 * math.sin(a), top + .09), (.025, .04, .018), "black", 8, 6)
    m.box("Science_Magnet_BarNorth", (x + .80, y -.17, top + .15), (.28, .65, .20), "red")
    m.box("Science_Magnet_BarSouth", (x + .80, y + .45, top + .15), (.28, .65, .20), "blue")
    m.cyl("Science_Magnet_CompassCase", (x + 1.25, y -.5, top + .08), .25, .12, "gold", 32)
    m.cyl("Science_Magnet_CompassFace", (x + 1.25, y -.5, top + .15), .21, .02, "ivory", 32)
    m.beam("Science_Magnet_CompassNeedle", (x + 1.12, y -.62, top + .18), (x + 1.38, y -.38, top + .18), .025, "red")
    locus("science_room", 4, (x, -5.65), "Science_MagnetTable_Top")

    m.group("50_Models_And_Display")
    x, y = 0, 6.65
    m.box("Science_ModelDisplay_Back", (x, y + .42, 1.25), (4.8, .14, 2.5), "teal")
    for dx in [-2.4, 2.4]:
        m.box("Science_ModelDisplay_Side", (x + dx, y, 1.25), (.14, 1.25, 2.5), "oak")
    for h in [.18, 1.23, 2.48]:
        m.box("Science_ModelDisplay_Shelf", (x, y, h), (4.9, 1.35, .12), "lightwood")
    # A desk-scale solar system, a crystal group and a molecular model are all geometry.
    m.cyl("Science_ModelSolar_Base", (-1.2, y, 1.34), .75, .12, "navy", 40)
    m.ball("Science_ModelSolar_Sun", (-1.2, y, 1.8), (.24, .24, .24), "yellow")
    for i, (radius, angle, color, size) in enumerate([(.38, .3, "blue", .10), (.59, 2.1, "rose", .13), (.78, 4.0, "mint", .16)]):
        m.ring("Science_ModelSolar_Orbit", (-1.2, y, 1.8), radius, .015, "gold", segments=40)
        m.ball("Science_ModelSolar_Planet_%02d" % i, (-1.2 + radius * math.cos(angle), y + radius * math.sin(angle), 1.8), (size, size, size), color, 16, 10)
    for i, (dx, dy, height) in enumerate([(-.3, 0, .58), (.1, -.15, .77), (.3, .15, .46)]):
        m.cyl("Science_ModelCrystal", (1.25 + dx, y + dy, 1.31 + height / 2), .16, height, "lavender", 6, top=.04)
    atoms = [(-1.6, -.1, .55), (-.65, .1, .64), (.2, -.2, .50), (1.15, .15, .68)]
    for i, (xx, yy, zz) in enumerate(atoms):
        m.ball("Science_ModelMolecule_Atom", (xx, y + yy, zz), (.18, .18, .18), ["rose", "teal", "ivory", "yellow"][i], 16, 10)
        if i:
            prev = atoms[i - 1]
            m.beam("Science_ModelMolecule_Bond", (prev[0], y + prev[1], prev[2]), (xx, y + yy, zz), .05, "oak")
    m.collider("Science_ModelDisplay", (0, y, 1.25), (5.0, 1.45, 2.5))
    locus("science_room", 5, (0, 4.6), "Science_ModelDisplay_Back")
    m.group("60_Observation_Details")
    m.board("Science_ObservationRules", 6.45, 4.75, "I NOTICE...", "Look / Wonder / Share", "teal", 1.8, 2.55)
    m.clock_face("Science_WallClock", -3.2, 7.75, 2.5)


def verify_room(source, stats, entry, output_glb):
    # Read the exported GLB itself. This checks the geometry the engine will import.
    glb_data, binary = validator.glb(output_glb)
    nodes, world = validator.world_nodes(glb_data)
    named = {node.get("name"): i for i, node in enumerate(nodes)}
    points = {name: validator.transform(world[named[name]], [0, 0, 0]) for name in source["required_nodes"]}
    blockers = [validator.mesh_bounds(glb_data, node, world[i]) for i, node in enumerate(nodes) if node.get("name", "").startswith("SG_COLLIDER_")]
    floor = validator.check_star_floor(glb_data, binary, nodes, world, points)
    ordinary_walk = validator.walkability(entry["bounds"], blockers, points, radius=.32, step=.20)
    wide_walk = validator.walkability(entry["bounds"], blockers, points, radius=.75, step=.15)
    errors = []
    if not floor["passed"]:
        errors.extend(floor["errors"])
    for mode, result in [("player", ordinary_walk), ("1.5m_clearance", wide_walk)]:
        for name, check in result["anchors"].items():
            if check["inside_obstacle"] or not check["reachable"]:
                errors.append(mode + ": blocked or unreachable " + name)
    for i, node in enumerate(nodes):
        if not node.get("name", "").startswith("SG_COLLIDER_"):
            continue
        for primitive in glb_data["meshes"][node["mesh"]]["primitives"]:
            material = glb_data["materials"][primitive["material"]]
            if material["pbrMetallicRoughness"]["baseColorFactor"][3] != 0:
                errors.append("Opaque collision mesh: " + node["name"])
    memory_points = {name: pos for name, pos in points.items() if name.startswith("SG_MEMORY_")}
    for name, pos in memory_points.items():
        for other in ["SG_EXIT", "SG_NPC_HOST"]:
            if math.dist((pos[0], pos[2]), (points[other][0], points[other][2])) < 2.5:
                errors.append("Memory anchor too close to host/exit: " + name + " / " + other)
    authored = {item["node_name"]: item for item in plan_for(source["room_id"])["anchors"]}
    for anchor in source["anchors"]:
        if anchor["name"] in authored and anchor["label"] != authored[anchor["name"]]["label"]:
            errors.append("Plan label mismatch: " + anchor["name"])
    if errors:
        raise ValueError(json.dumps(errors, ensure_ascii=False))
    return {**source, **stats, "passed": True, "rendered": True, "floor_orientation": floor,
            "walkability": ordinary_walk, "clearance_1_5m": wide_walk,
            "asset_validation_scope": "Exported GLB anchors, transparent collider meshes, floor winding/front-face support and 1.5m-wide raster connectivity; Godot runtime checks are separate.",
            "shared_manifest_modified": False, "errors": []}


def write_room(room_id, resolution):
    folder = p.OUT / room_id
    folder.mkdir(parents=True, exist_ok=True)
    blend = folder / (room_id + "_v01.blend")
    glb = folder / (room_id + "_v01.glb")
    preview = folder / "preview.png"
    p.preview_setup(resolution)
    bpy.context.scene.camera.data.ortho_scale = 26.5 if room_id != "art_room" else 24.2
    bpy.context.scene["room_display_name"] = NAMES[room_id]
    bpy.context.scene["scene_level"] = 3
    bpy.context.scene["parent_room"] = "school"
    bpy.context.scene["editable_source"] = True
    source = p.collect_source(room_id)
    if source["missing_external_textures"]:
        raise ValueError(source["missing_external_textures"])
    # Keep collisions present in the GLB but hidden in editable/rendered views.
    for ob in bpy.context.scene.objects:
        if ob.name.startswith("SG_COLLIDER_"):
            ob.hide_render = True
            ob.hide_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    p.render_preview(preview)
    pending = folder / ("." + room_id + ".pending.glb")
    p.export_glb(pending)
    stats = p.confirm_export(pending, source)
    os.replace(pending, glb)
    entry = p.manifest_entry(room_id, NAMES[room_id], source, stats)
    entry.update({"scene_level": 3, "parent_room": "school", "model_version": "v01", "dimensions_m": list(ROOM_SIZES[room_id]), "specialist_room": True})
    report = verify_room(source, stats, entry, glb)
    report["source_blend"] = blend.relative_to(p.ROOT).as_posix()
    report["source_blend_sha256"] = hashlib.sha256(blend.read_bytes()).hexdigest()
    report["preview_sha256"] = hashlib.sha256(preview.read_bytes()).hexdigest()
    report["authoring_script"] = Path(__file__).relative_to(p.ROOT).as_posix()
    p.write_json(folder / "validation.json", report)
    p.write_json(folder / "manifest-entry.json", entry)
    print("SPECIALIST_ROOM_COMPLETED " + room_id + " " + json.dumps({"triangles": stats["triangles_instanced"], "glb_bytes": stats["glb_bytes"], "anchors": len(source["anchors"]), "wide_route_check": True}), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--room", choices=list(NAMES), action="append")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--resolution", type=int, default=1400)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    keys = list(NAMES) if args.all else args.room or []
    if not keys:
        parser.error("Use --all or --room music_room/art_room/science_room")
    builders = {"music_room": music_room, "art_room": art_room, "science_room": science_room}
    for room_id in keys:
        target = p.OUT / room_id / (room_id + "_v01.blend")
        if target.exists() and not args.overwrite:
            raise FileExistsError("Editable source exists; pass --overwrite only for an intended rebuild: " + str(target))
        started = time.monotonic()
        print("SPECIALIST_ROOM_STARTED " + room_id, flush=True)
        builders[room_id]()
        write_room(room_id, max(1000, args.resolution))
        print("SPECIALIST_ROOM_SECONDS " + room_id + " " + str(round(time.monotonic() - started, 1)), flush=True)


if __name__ == "__main__":
    main()
