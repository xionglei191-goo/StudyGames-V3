"""One-time initial v06 playability correction, never touches v05 or later artist edits."""
from pathlib import Path
import runpy
import bpy
from mathutils import Vector

root = Path(__file__).resolve().parents[1]
working = root / "assets/blender/alphabet_island/alphabet_island_layout_v06_game.blend"
assert Path(bpy.data.filepath).resolve() == working.resolve()
scene = bpy.context.scene
if not scene.get("sg_initial_spawn_reviewed", False):
    spawn = bpy.data.objects["SG_SPAWN"]
    door = bpy.data.objects["SG_DOOR_HOME"]
    point = door.matrix_world.translation + Vector((-3.2, -3.0, 0))
    point.z = spawn.matrix_world.translation.z
    matrix = spawn.matrix_world.copy()
    matrix.translation = point
    spawn.matrix_world = matrix
    bpy.data.objects["ALPHA_Home_Fountain_Base"]["sg_collision"] = "fountain"
    scene["sg_initial_spawn_reviewed"] = True
    bpy.context.view_layer.update()
runpy.run_path(str(root / "assets/blender/alphabet_island/export_game_map.py"), run_name="__main__")
