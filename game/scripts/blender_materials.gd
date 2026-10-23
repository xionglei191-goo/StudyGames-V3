extends RefCounted
## Some imported glTF materials keep COLOR_0 data but disable its albedo flag.
## Restore the exported vertex color; keep the artist's textures and PBR values.
const WorldArt = preload("res://scripts/world_art.gd")

static func restore_vertex_colors(root: Node3D) -> Dictionary:
	var cached: Dictionary = {}
	var surfaces := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var mesh := instance.mesh as ArrayMesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			if mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR == 0:
				continue
			var material := instance.get_active_material(surface) as BaseMaterial3D
			if material == null:
				continue
			var key := material.get_instance_id()
			if not cached.has(key):
				var restored := material.duplicate() as BaseMaterial3D
				restored.vertex_color_use_as_albedo = true
				restored.vertex_color_is_srgb = false
				cached[key] = restored
			instance.set_surface_override_material(surface, cached[key])
			surfaces += 1
	var art_stats := WorldArt.apply_to_scene(root)
	return {"vertex_color_surfaces":surfaces,"restored_materials":cached.size(),"world_art":art_stats}
