"""Material finish and physically scaled UVs shared by the prop GLBs and Blender library."""
from pathlib import Path

import bpy
import numpy as np


TEXTILES = {"coat", "shirt", "dress", "sweater", "trousers", "scarf", "socks", "gloves",
            "shoes", "teddy", "pillow", "quilt", "towel", "umbrella", "kite", "rope"}
PAPER = {"book", "notebook", "newspaper", "letter", "card", "photo", "paper", "milk", "gift_box"}
CERAMICS = {"cup", "plate", "bowl", "soup_bowl", "noodle_bowl", "rice_bowl", "teapot"}
FOOD = {"hamburger", "cake", "chicken", "dumplings", "potato", "sandwich"}
PLANTS = {"leaf", "plant", "flower", "vegetable", "apple", "tomato", "orange", "pear", "banana"}

# Visual grain runs along U. One tile covers this many Blender metres before prop normalization.
# The game binds its existing neutral detail maps by the same material suffix.
FINISHES = {
    "Woodgrain": ("wood", 0.28, 0.49, 0.15),
    "Linen": ("cloth", 0.12, 0.89, 0.22),
    "Papergrain": ("paper", 0.14, 0.84, 0.13),
    "Porous": ("plaster", 0.11, 0.76, 0.21),
    "Leafskin": ("foliage", 0.19, 0.54, 0.10),
    "Glaze": (None, 0.20, 0.25, 0.0),
    "Rubber": ("plaster", 0.075, 0.77, 0.10),
    "Felt": ("cloth", 0.075, 0.92, 0.15),
    "Enamel": (None, 0.20, 0.33, 0.0),
    "Wax": (None, 0.20, 0.43, 0.0),
    "Steamed": (None, 0.10, 0.58, 0.0),
}


def finish_for(asset, part, material):
    if part.startswith(("rice_", "dumpling_", "noodle_strand", "noodle_egg")):
        return "Steamed"
    if part.startswith("timber_"):
        return "Woodgrain"
    if part.startswith("linen_"):
        return "Linen"
    if part.startswith("glazed_"):
        return "Glaze"
    if material in {"L2_Gold", "L2_Silver", "L2_GlassWater", "L2_ClearGlass"}:
        return None
    if asset in {"crayon","eraser"} and any(key in part for key in ("wrap","band","sleeve")):
        return "Papergrain"
    if asset in {"basketball","football","ball","eraser"}:
        return "Rubber"
    if asset in {"cat","dog","cloud"} and not any(key in part for key in ("eye","nose","stand","collar")):
        return "Felt"
    if asset in {"star","sun"} or (asset == "clock" and "case" in part):
        return "Woodgrain"
    if asset in {"egg","chalk"} and ("egg" in part or "chalk" in part):
        return "Porous"
    if asset == "bee" and material in {"L2_Leaf","L2_LeafLight"}:
        return "Leafskin"
    if asset in {"juice_glass","fish","duck","bee","water"} or "dish" in part or "bubble" in part:
        return "Glaze"
    if asset in {"soap","crayon","candy"}:
        return "Wax"
    if asset in {"paint_jar","pencil_box","scissors","toothbrush","comb","glasses","clock","watch","pot","spoon"}:
        return "Enamel"
    if asset in FOOD and any(s in part for s in ("bread", "bun", "patty", "sponge", "skin", "potato", "crust")):
        return "Porous"
    if material in {"L2_Wood", "L2_WoodDark"} and not any(s in part for s in ("belt", "nose", "eye", "stem", "seed", "tail", "hair")):
        return "Woodgrain"
    if asset in TEXTILES and "button" not in part and "_btn" not in part and "buckle" not in part and "eye" not in part and "nose" not in part:
        return "Linen"
    if material == "L2_Paper" or (asset in PAPER and material in {"L2_Cream", "L2_White", "L2_TintPrimary", "L2_TintDark"}):
        return "Papergrain"
    if material in {"L2_Bread", "L2_Crumb", "L2_Soil", "L2_Terracotta"}:
        return "Porous"
    if asset in PLANTS and (material in {"L2_Leaf", "L2_LeafLight"} or "fruit" in part):
        return "Leafskin"
    if asset in CERAMICS or "ceramic" in part or "plate" in part or "saucer" in part:
        return "Glaze"
    return None


def prepare_part(asset, obj):
    mesh = obj.data
    finish = finish_for(asset, obj.name.lower(), mesh.materials[0].name)
    if not finish:
        return
    source = mesh.materials[0]
    name = f"{source.name}_{finish}"
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = source.copy()
        mat.name = name
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = FINISHES[finish][2]
        if finish == "Glaze":
            bsdf.inputs["Coat Weight"].default_value = 0.26
            bsdf.inputs["Coat Roughness"].default_value = 0.20
    mesh.materials[0] = mat
    if not FINISHES[finish][0]:
        return
    # Choose a stable projection for each face in the part's own frame. A turned
    # sleeve or a sloping wooden leg keeps its fibres when it is joined for export.
    coords = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", coords)
    coords = coords.reshape(-1, 3)
    extent = np.ptp(coords, axis=0)
    uv = mesh.uv_layers.active or mesh.uv_layers.new(name="UVMap")
    uv.name = "UVMap"
    loop_vertices = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", loop_vertices)
    normals = np.empty(len(mesh.polygons) * 3, dtype=np.float32)
    mesh.polygons.foreach_get("normal", normals)
    axis = np.abs(normals.reshape(-1, 3)).argmax(axis=1)
    counts = np.empty(len(mesh.polygons), dtype=np.int32)
    mesh.polygons.foreach_get("loop_total", counts)
    loop_axis = np.repeat(axis, counts)
    texcoords = np.empty((len(mesh.loops), 2), dtype=np.float32)
    for side in range(3):
        a, b = (i for i in range(3) if i != side)
        if finish == "Woodgrain" and extent[b] > extent[a]:
            a, b = b, a
        select = loop_axis == side
        texcoords[select] = coords[loop_vertices[select]][:, [a, b]] / FINISHES[finish][1]
    uv.data.foreach_set("uv", texcoords.ravel())


def finish_blend_materials(root: Path):
    """Bind the game's shared texture tiles and pack them into the editable Blender file."""
    tiles = root / "game/assets/world_refresh_v3"
    for mat in bpy.data.materials:
        suffix = mat.name.rsplit("_", 1)[-1]
        if suffix not in FINISHES or not FINISHES[suffix][0]:
            continue
        family, _, _, depth = FINISHES[suffix]
        tree = mat.node_tree
        bsdf = tree.nodes.get("Principled BSDF")
        albedo = tree.nodes.new("ShaderNodeTexImage")
        albedo.image = bpy.data.images.load(str(tiles / f"{family}_detail.png"), check_existing=True)
        mult = tree.nodes.new("ShaderNodeMixRGB")
        mult.blend_type = "MULTIPLY"
        mult.inputs[0].default_value = 1.0
        mult.inputs[1].default_value = mat.diffuse_color
        tree.links.new(albedo.outputs["Color"], mult.inputs[2])
        tree.links.new(mult.outputs[0], bsdf.inputs["Base Color"])
        tile = tree.nodes.new("ShaderNodeTexImage")
        tile.image = bpy.data.images.load(str(tiles / f"{family}_normal.png"), check_existing=True)
        tile.image.colorspace_settings.name = "Non-Color"
        normal = tree.nodes.new("ShaderNodeNormalMap")
        normal.inputs["Strength"].default_value = depth
        tree.links.new(tile.outputs["Color"], normal.inputs["Color"])
        tree.links.new(normal.outputs[0], bsdf.inputs["Normal"])
        if not albedo.image.packed_file:
            albedo.image.pack()
        if not tile.image.packed_file:
            tile.image.pack()
