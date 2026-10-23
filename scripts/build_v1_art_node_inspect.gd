extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var packed: PackedScene = load("res://assets/world/island.glb") as PackedScene
	var model: Node3D = packed.instantiate() as Node3D
	root.add_child(model)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		if "North_Bridge_Deck" in str(node.name) or "Z_Rear_Garden_Fence_Rail" in str(node.name):
			var props: Dictionary = {}
			for key: StringName in node.get_meta_list():
				props[str(key)] = node.get_meta(key)
			print(str(node.name), " ", JSON.stringify(props))
	quit(0)
