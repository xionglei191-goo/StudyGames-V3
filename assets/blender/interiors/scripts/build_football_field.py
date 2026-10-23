"""Create the standalone football_field Blender source and local export evidence.

This generator only writes assets/blender/interiors/football_field/. It never
updates the shared interiors manifest, gameplay scripts or an existing room.
Rebuilding this authored source requires the explicit --overwrite switch.
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
import build_specialist_rooms as specialist


ROOM = "football_field"
ROOM_NAME = "校园足球场"
GROUND_SIZE = (34.0, 28.0)
PITCH_SIZE = (26.0, 18.0)
SOURCE_ROOT = p.OUT / ROOM
POSITIONS = {
    "SG_SPAWN": (0.0, -11.5),
    "SG_EXIT": (0.0, -12.9),
    "SG_NPC_HOST": (-3.7, -10.8),
    "SG_MEMORY_01": (-10.6, -12.6),
    "SG_MEMORY_02": (0.0, 0.0),
    "SG_MEMORY_03": (10.6, 0.0),
    "SG_MEMORY_04": (-6.0, 4.5),
    "SG_MEMORY_05": (10.2, 10.2),
}


def flat_line(name, a, b, width=.085, z=.026, material="ivory"):
    a, b = Vector(a), Vector(b)
    mid = (a + b) / 2
    ob = m.box(name, (mid.x, mid.y, z), (width, (b - a).length, .008), material, 0)
    ob.rotation_euler.z = -math.atan2(b.x - a.x, b.y - a.y)
    return ob


def flat_arc(name, centre, radius, start=0.0, end=math.tau, width=.085, z=.032, material="ivory", segments=96):
    vertices, faces = [], []
    count = max(8, round(segments * abs(end - start) / math.tau))
    for i in range(count + 1):
        angle = start + (end - start) * i / count
        for r in [radius - width / 2, radius + width / 2]:
            vertices.append((centre[0] + r * math.cos(angle), centre[1] + r * math.sin(angle), z))
    for i in range(count):
        faces.append((i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2))
    return m.mesh(name, vertices, faces, material)


def line_mesh(name, segments, radius=.018, material="ivory", sides=6):
    """Many small round net strands in one mesh/material, rather than one node each."""
    vertices, faces = [], []
    for a, b in segments:
        a, b = Vector(a), Vector(b)
        axis = (b - a).normalized()
        helper = Vector((0, 0, 1)) if abs(axis.z) < .9 else Vector((0, 1, 0))
        u = axis.cross(helper).normalized()
        v = axis.cross(u).normalized()
        start = len(vertices)
        for centre in [a, b]:
            for i in range(sides):
                offset = radius * (u * math.cos(i * math.tau / sides) + v * math.sin(i * math.tau / sides))
                vertices.append(tuple(centre + offset))
        faces.append(tuple(start + i for i in reversed(range(sides))))
        faces.append(tuple(start + sides + i for i in range(sides)))
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((start + i, start + j, start + sides + j, start + sides + i))
    return m.mesh(name, vertices, faces, material)


def football(name, x, y, z, radius=.24):
    # A low-poly ball with geometric pentagonal patches; no external texture or ball physics.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=(x, y, z))
    body = bpy.context.object
    body.name = name + "_WhiteBall"
    m.link(body)
    body.data.materials.append(m.M["ivory"])
    for face in body.data.polygons:
        face.use_smooth = True
    phi = (1 + math.sqrt(5)) / 2
    normals = [(0, a, b * phi) for a in [-1, 1] for b in [-1, 1]]
    normals += [(a, b * phi, 0) for a in [-1, 1] for b in [-1, 1]]
    normals += [(a * phi, 0, b) for a in [-1, 1] for b in [-1, 1]]
    vertices, faces = [], []
    centre = Vector((x, y, z))
    for raw in normals:
        normal = Vector(raw).normalized()
        helper = Vector((0, 0, 1)) if abs(normal.z) < .9 else Vector((0, 1, 0))
        tangent = normal.cross(helper).normalized()
        bitangent = normal.cross(tangent).normalized()
        index = len(vertices)
        vertices.append(tuple(centre + normal * radius * 1.005))
        for i in range(5):
            angle = i * math.tau / 5 + .2
            point = normal + .30 * (tangent * math.cos(angle) + bitangent * math.sin(angle))
            vertices.append(tuple(centre + point.normalized() * radius * 1.012))
        for i in range(5):
            faces.append((index, index + 1 + i, index + 1 + (i + 1) % 5))
    m.mesh(name + "_PentagonalPanels", vertices, faces, "navy")


def cone(name, x, y, size=.32, color="orange"):
    m.box(name + "_Base", (x, y, .055), (size * 1.6, size * 1.6, .11), color, .045)
    m.cyl(name + "_Cone", (x, y, size + .05), size * .60, size * 1.8, color, 16, top=size * .10)
    m.cyl(name + "_ReflectiveBand", (x, y, size * 1.12 + .05), size * .32, .07, "ivory", 16, top=size * .26)
    m.collider(name, (x, y, size * .7), (size * 1.45, size * 1.45, size * 1.4))


def goal(name, side):
    x, rear = side * 13.0, side * 14.65
    half_width, height = 2.1, 2.35
    frame = [
        ((x, -half_width, .08), (x, -half_width, height)),
        ((x, half_width, .08), (x, half_width, height)),
        ((x, -half_width, height), (x, half_width, height)),
        ((x, -half_width, .06), (rear, -half_width, .06)),
        ((x, half_width, .06), (rear, half_width, .06)),
        ((rear, -half_width, .06), (rear, half_width, .06)),
        ((rear, -half_width, .06), (rear, -half_width, height * .82)),
        ((rear, half_width, .06), (rear, half_width, height * .82)),
        ((rear, -half_width, height * .82), (rear, half_width, height * .82)),
        ((x, -half_width, height), (rear, -half_width, height * .82)),
        ((x, half_width, height), (rear, half_width, height * .82)),
    ]
    line_mesh(name + "_GoalFrame", frame, .08, "ivory", 12)
    strands = []
    # Rear panel: vertical and horizontal mesh cells.
    for i in range(15):
        yy = -half_width + i * half_width * 2 / 14
        strands.append(((rear, yy, .12), (rear, yy, height * .82)))
    for i in range(8):
        zz = .12 + i * (height * .82 - .12) / 7
        strands.append(((rear, -half_width, zz), (rear, half_width, zz)))
    # Two sloping side panels and roof.
    for sign in [-1, 1]:
        yy = sign * half_width
        for i in range(7):
            t = i / 6
            xx = x + (rear - x) * t
            hh = height * (1 - .18 * t)
            strands.append(((xx, yy, .12), (xx, yy, hh)))
        for i in range(8):
            t = i / 7
            strands.append(((x, yy, .12 + (height - .12) * t), (rear, yy, .12 + (height * .82 - .12) * t)))
    for i in range(15):
        yy = -half_width + i * half_width * 2 / 14
        strands.append(((x, yy, height), (rear, yy, height * .82)))
    for i in range(7):
        t = i / 6
        xx = x + (rear - x) * t
        hh = height * (1 - .18 * t)
        strands.append(((xx, -half_width, hh), (xx, half_width, hh)))
    line_mesh(name + "_WovenNet", strands, .015, "cream", 6)
    # Physical back and sides stop walking through the net; the goal mouth is open.
    m.collider(name + "_NetBack", (rear, 0, 1.0), (.12, 4.3, 2.0))
    for yy in [-half_width, half_width]:
        m.collider(name + "_NetSide", ((x + rear) / 2, yy, 1.1), (abs(rear - x) + .1, .12, 2.2))
        m.collider(name + "_Post", (x, yy, 1.2), (.18, .18, 2.4))


def flags():
    for i, (x, y) in enumerate([(-13.3, -9.3), (13.3, -9.3), (-13.3, 9.3), (13.3, 9.3)]):
        m.cyl("Football_CornerFlag_Post", (x, y, .85), .04, 1.7, "ivory", 12)
        m.ball("Football_CornerFlag_Cap", (x, y, 1.72), (.065, .065, .065), "gold", 12, 8)
        vertices = [(x, y, 1.62), (x + .75, y + .06, 1.50), (x, y, 1.12)]
        flag = m.mesh("Football_CornerFlag_Cloth_%02d" % i, vertices, [(0, 1, 2), (2, 1, 0)], "yellow" if i % 2 else "teal")
        flag["double_sided_cloth"] = True
        m.collider("Football_CornerFlag_%02d" % i, (x, y, .8), (.15, .15, 1.6))


def perimeter_fence():
    m.group("01_Perimeter_And_Campus_Access")
    for name, a, b in [
        ("Back", (-16.75, 13.72), (16.75, 13.72)),
        ("Left", (-16.75, -13.7), (-16.75, 13.72)),
        ("Right", (16.75, -13.7), (16.75, 13.72)),
        ("FrontLeft", (-16.75, -13.7), (-1.85, -13.7)),
        ("FrontRight", (1.85, -13.7), (16.75, -13.7)),
    ]:
        a, b = Vector(a), Vector(b)
        length = (b - a).length
        count = math.ceil(length / 2.2)
        for i in range(count + 1):
            q = a.lerp(b, i / count)
            m.cyl("Football_Fence_" + name + "_Post", (q.x, q.y, .48), .075, .96, "oak", 12)
            m.ball("Football_Fence_" + name + "_Cap", (q.x, q.y, .99), (.10, .10, .07), "lightwood", 12, 8)
        for z in [.35, .72]:
            m.beam("Football_Fence_" + name + "_Rail", (a.x, a.y, z), (b.x, b.y, z), .045, "lightwood")
        centre = (a + b) / 2
        size = (length + .1, .18, 1.2) if abs(a.y - b.y) < .1 else (.18, length + .1, 1.2)
        m.collider("Football_Fence_" + name, (centre.x, centre.y, .6), size)
    m.box("Football_Entrance_Mat", (0, -12.95, .018), (3.15, 1.05, .036), "teal", .10)
    m.text("Football_Entrance_Text", "FOOTBALL", (0, -12.95, .039), .28, "ivory", facing="up")


def pitch():
    m.group("00_Floor_And_Field_Markings")
    m.floor(*GROUND_SIZE, mat="grass", planks=False)
    # All visual paint/grass layers stay below 0.05 m; the SG floor is the support surface.
    for i in range(8):
        x = -13 + (i + .5) * 3.25
        m.box("Football_GrassStripe_%02d" % i, (x, 0, .009), (3.25, 18.0, .018), "leaflight" if i % 2 else "grass", 0)
    for y in [-11.5, 11.5]:
        m.box("Football_SidelineWalk", (0, y, .009), (34.0, 5.0, .018), "sand", 0)
    for x in [-15, 15]:
        m.box("Football_GoalEndWalk", (x, 0, .009), (4.0, 18.0, .018), "sand", 0)
    for y in [-9, 9]:
        flat_line("Football_Touchline", (-13, y), (13, y))
    for x in [-13, 13]:
        flat_line("Football_GoalLine", (x, -9), (x, 9))
    flat_line("Football_HalfwayLine", (0, -9), (0, 9))
    flat_arc("Football_CenterCircle", (0, 0), 2.8)
    m.cyl("Football_CenterSpot", (0, 0, .030), .14, .008, "ivory", 24)
    for side in [-1, 1]:
        goal_x, box_x, small_x = side * 13, side * 8.6, side * 11.2
        flat_line("Football_PenaltyArea_Front", (box_x, -4.6), (box_x, 4.6))
        flat_line("Football_GoalArea_Front", (small_x, -2.8), (small_x, 2.8))
        for y in [-4.6, 4.6]:
            flat_line("Football_PenaltyArea_Side", (goal_x, y), (box_x, y))
        for y in [-2.8, 2.8]:
            flat_line("Football_GoalArea_Side", (goal_x, y), (small_x, y))
        m.cyl("Football_PenaltySpot", (side * 9.8, 0, .030), .11, .008, "ivory", 24)
        start = math.pi - .96 if side == 1 else -.96
        end = math.pi + .96 if side == 1 else .96
        flat_arc("Football_PenaltyArc", (side * 9.8, 0), 2.1, start, end)
    # Quarter-circle corner marks lie inside the field, distinct from the flags outside it.
    for x, y, a in [(-13, -9, 0), (13, -9, math.pi / 2), (13, 9, math.pi), (-13, 9, math.pi * 1.5)]:
        flat_arc("Football_CornerArc", (x, y), .65, a, a + math.pi / 2, .065)


def equipment():
    m.group("10_Equipment_Zone")
    x, y = -10.6, -10.8
    m.box("Football_EquipmentRack_Back", (x, y + .32, 1.2), (4.0, .13, 2.4), "teal")
    for dx in [-2.0, 2.0]:
        m.box("Football_EquipmentRack_Side", (x + dx, y, 1.2), (.12, .8, 2.4), "oak")
    for z in [.18, .8, 2.42]:
        m.box("Football_EquipmentRack_Shelf", (x, y, z), (4.1, .86, .13), "lightwood")
    for i in range(4):
        football("Football_EquipmentBall_%02d" % i, x - 1.45 + i * .95, y - .03, .48, .23)
    for i, color in enumerate(["yellow", "rose", "blue"]):
        xx = x - 1.25 + i * 1.20
        outline = [(-.36, 0), (.36, 0), (.36, .53), (.55, .64), (.33, .92), (.18, .84), (.15, .72), (-.15, .72), (-.18, .84), (-.33, .92), (-.55, .64), (-.36, .53)]
        bib = specialist.extruded_polygon("Football_TrainingBib", outline, -.02, .04, color)
        bib.rotation_euler.x = math.pi / 2
        bib.location = (xx, y - .12, 1.08)
        m.text("Football_Bib_Number", str(i + 1), (xx, y - .16, 1.52), .28, "ivory")
        m.beam("Football_Equipment_Hanger", (xx - .3, y, 2.10), (xx + .3, y, 2.10), .027, "oak")
    m.text("Football_Equipment_Label", "TEAM KIT", (x, y - .49, 2.42), .28, "teal")
    m.collider("Football_EquipmentRack", (x, y, 1.25), (4.25, .95, 2.5))
    m.bench("Football_TeamBench", 6.2, -11.65, 4.4, "teal")
    for i in range(3):
        m.jar("Football_WaterBottle", 5.0 + i * .45, -11.7, .72, .11, ["yellow", "blue", "rose"][i])


def practice_zone():
    m.group("40_Passing_Practice")
    for i, (x, y) in enumerate([(-9.0, 2.7), (-3.0, 2.7), (-9.0, 6.3), (-3.0, 6.3)]):
        cone("Football_PracticeCone_%02d" % i, x, y, .28, "orange" if i % 2 else "yellow")
    for i in range(8):
        x = -8.65 + i * .76
        m.box("Football_PassingRoute_Dash", (x, 4.5, .030), (.38, .07, .008), "ivory", .012)
    flat_line("Football_PassArrow1", (-3.2, 4.5), (-3.8, 4.85), .06)
    flat_line("Football_PassArrow2", (-3.2, 4.5), (-3.8, 4.15), .06)
    football("Football_PracticeBall", -7.65, 5.4, .27, .25)
    football("Football_KickoffBall", 1.0, -.85, .27, .25)
    # A labelled tray is outside the active passing lane, leaving its centre walkable.
    m.box("Football_PracticeMarker", (-6.0, 6.7, .024), (2.5, .65, .035), "teal", .06)
    m.text("Football_Practice_Label", "PASS & SHARE", (-6.0, 6.7, .047), .20, "ivory", facing="up")


def stand_and_scoreboard():
    m.group("50_Spectator_Stand_And_Scoreboard")
    # Two low tiers with benches, access reserved to the perimeter walkway.
    m.box("Football_Stand_LowerPlatform", (6.1, 11.55, .16), (5.6, 1.15, .32), "oak", .10)
    m.box("Football_Stand_UpperPlatform", (6.1, 12.55, .40), (5.6, .95, .8), "oak", .10)
    for yy, height in [(11.50, .61), (12.50, 1.05)]:
        m.box("Football_Stand_Seat", (6.1, yy, height), (5.25, .52, .13), "teal", .07)
        for xx in [3.9, 6.1, 8.3]:
            m.box("Football_Stand_SeatSupport", (xx, yy, height - .2), (.12, .32, .35), "wood")
    m.collider("Football_Stand", (6.1, 12.05, .55), (5.8, 2.3, 1.1))
    for xx in [3.2, 9.0]:
        m.beam("Football_Stand_BackPost", (xx, 13.1, .10), (xx, 13.1, 1.55), .065, "oak")
    m.beam("Football_Stand_BackRail", (3.2, 13.1, 1.55), (9.0, 13.1, 1.55), .065, "oak")
    x, y = 12.3, 12.65
    for xx in [x - 1.35, x + 1.35]:
        m.box("Football_Scoreboard_Post", (xx, y, 1.35), (.14, .20, 2.7), "oak")
    m.box("Football_Scoreboard_Frame", (x, y, 2.65), (3.6, .23, 2.2), "oak", .10)
    m.box("Football_Scoreboard_Face", (x, y - .15, 2.65), (3.35, .07, 1.95), "teal", .04)
    m.text("Football_Scoreboard_Title", "PRACTICE", (x, y - .21, 3.31), .25, "ivory")
    m.text("Football_Scoreboard_Teams", "HOME       GUEST", (x, y - .21, 2.88), .19, "cream")
    m.text("Football_Scoreboard_ExampleScore", "0 : 0", (x, y - .22, 2.28), .64, "ivory")
    m.collider("Football_Scoreboard", (x, y, 1.75), (3.7, .35, 3.5))


def build():
    m.setup(ROOM)
    pitch()
    perimeter_fence()
    equipment()
    m.group("30_Goals_And_CornerFlags")
    goal("Football_WestGoal", -1)
    goal("Football_EastGoal", 1)
    flags()
    practice_zone()
    stand_and_scoreboard()
    m.group("60_Campus_Garden_Context")
    m.board("Football_FieldSign", -6.5, 12.5, "FOOTBALL FIELD", "Move / Explore / Play together", "teal", z=2.2, w=6.2)
    m.plant("Football_EntryFlowers", -2.4, -12.8, flower=True, s=.65)
    m.plant("Football_EntryFlowers", 2.4, -12.8, flower=True, s=.65)
    m.plant("Football_CornerPlanter", -15.5, 11.9, flower=False, s=1.0)
    m.group("80_Gameplay_Anchors")
    m.anchor("SG_SPAWN", POSITIONS["SG_SPAWN"], "进入足球场")
    m.anchor("SG_EXIT", POSITIONS["SG_EXIT"], "返回完整校园")
    m.anchor("SG_NPC_HOST", POSITIONS["SG_NPC_HOST"], "足球教练")
    props = ["Football_EquipmentRack_Back", "Football_CenterCircle", "Football_EastGoal_GoalFrame", "Football_PracticeMarker", "Football_Scoreboard_Face"]
    for i, associated in enumerate(props, 1):
        specialist.locus(ROOM, i, POSITIONS["SG_MEMORY_%02d" % i], associated)


def export_room(resolution):
    SOURCE_ROOT.mkdir(parents=True, exist_ok=True)
    blend = SOURCE_ROOT / (ROOM + "_v01.blend")
    glb = SOURCE_ROOT / (ROOM + "_v01.glb")
    preview = SOURCE_ROOT / "preview.png"
    p.preview_setup(resolution)
    scene = bpy.context.scene
    scene.camera.location = (29, -36, 36)
    scene.camera.data.ortho_scale = 45.3
    p.point_camera(scene.camera, (0, 0, .3))
    scene.render.resolution_y = round(resolution * .79)
    scene["room_display_name"] = ROOM_NAME
    scene["scene_level"] = 3
    scene["parent_room"] = "school"
    scene["gameplay_scope"] = "Static field exploration. No match simulation, ball physics or score updates."
    scene["dimensions_note"] = "34x28m park, 26x18m miniature school pitch; not regulation match dimensions."
    scene["source_generator"] = Path(__file__).relative_to(p.ROOT).as_posix()
    source = p.collect_source(ROOM)
    for ob in scene.objects:
        if ob.name.startswith("SG_COLLIDER_"):
            ob.hide_render = True
            ob.hide_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    p.render_preview(preview)
    pending = SOURCE_ROOT / ".football_field.pending.glb"
    p.export_glb(pending)
    stats = p.confirm_export(pending, source)
    os.replace(pending, glb)
    entry = p.manifest_entry(ROOM, ROOM_NAME, source, stats)
    entry.update({
        "scene_level": 3, "parent_room": "school", "model_version": "v01", "dimensions_m": list(GROUND_SIZE), "pitch_dimensions_m": list(PITCH_SIZE),
        "return_to": {"room_id": "school", "interaction_id": "football_field_gate", "door_node": "SG_DOOR_FOOTBALL_FIELD"},
        "technical_frame": {
            "engine": "Godot 4.7.2", "renderer": "GL Compatibility", "target": "Windows desktop with optional Web preview", "world_units": "metres",
            "source_up": "Blender Z", "runtime_up": "glTF/Godot Y", "front": "Blender -Y", "pivot": "pitch centre at ground height 0",
            "camera": "orthographic 2.5D following camera", "runtime_camera_size_suggestion": 34,
            "floor_physics": "SG_FLOOR_Main closed mesh, top at zero with upward normals", "grass_and_line_max_height_m": .047,
            "texture_count": 0, "materials": "shared warm matte PBR palette", "collision": "hidden simple proxy meshes; open goal mouths; goal nets block at sides/back",
            "animation": "none; balls and example scoreboard are static props", "lod": "single authored LOD for this separately loaded field; no performance claim",
        },
        "design": {
            "shape_language": "soft low-poly campus park, simple readable goals and field markings, warm wooden equipment and benches",
            "palette_roles": "sage/leaf green turf, ivory painted markings, teal furniture and signs, light oak frames, yellow/orange training accents",
            "style_references": ["assets/blender/interiors/school/preview_v02.png", "assets/blender/interiors/playground/preview.png", "assets/blender/interiors/science_room/preview.png"],
            "gameplay_scope": "five fixed exploration sites on a complete miniature football field; no implemented football match or scorekeeping",
            "visual_target_selection": "Use the existing warm toy-campus direction already accepted for neighbouring school scenes",
        },
        "provenance": {
            "kind": "original procedural Blender mesh authoring", "creator": "Codex for this project", "tool": "Blender " + bpy.app.version_string,
            "source_script": Path(__file__).relative_to(p.ROOT).as_posix(), "created_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "external_downloads": [], "external_textures": [], "license_note": "New geometry and in-project primitive helpers; no third-party model or texture added. Existing project licensing remains applicable.",
            "preservation": "All pre-existing room files and shared manifests remain untouched by this generator.",
        },
        "verification": {"technical_checks_passed": True, "rendered_preview": True, "native_scale_reviewed": False, "in_engine_reviewed": False, "approval_status": "awaiting_render_review_and_runtime_integration"},
    })
    report = specialist.verify_room(source, stats, entry, glb)
    report.update({
        "source_blend": blend.relative_to(p.ROOT).as_posix(), "source_blend_sha256": hashlib.sha256(blend.read_bytes()).hexdigest(),
        "preview_sha256": hashlib.sha256(preview.read_bytes()).hexdigest(), "authored_pitch_dimensions_m": list(PITCH_SIZE),
        "line_and_grass_height_limit_m": .05, "floor_at_all_anchors_y_zero": True,
        "not_verified": ["Godot runtime routes and transitions", "target-device frame rate", "match or moving-ball behaviour (not implemented)"],
    })
    p.write_json(SOURCE_ROOT / "validation.json", report)
    p.write_json(SOURCE_ROOT / "manifest-entry.json", entry)
    print("FOOTBALL_FIELD_COMPLETED " + json.dumps({"triangles": stats["triangles_instanced"], "glb_bytes": stats["glb_bytes"], "anchors": len(source["anchors"]), "bounds": entry["bounds"], "glb_sha256": stats["sha256"]}), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--resolution", type=int, default=1700)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    target = SOURCE_ROOT / (ROOM + "_v01.blend")
    if target.exists() and not args.overwrite:
        raise FileExistsError("Refusing to overwrite editable source without --overwrite: " + str(target))
    build()
    export_room(max(1200, args.resolution))


if __name__ == "__main__":
    main()
