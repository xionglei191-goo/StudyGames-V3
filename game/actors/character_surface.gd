extends RefCounted
## Apply during the character bake. Albedo, tangents, and packed material channels
## keep their source data at level zero; distant hair and weave use a prefiltered level.

static func bake_mipmaps(material: StandardMaterial3D) -> void:
	var converted: Dictionary = {}
	for slot in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_NORMAL,
			BaseMaterial3D.TEXTURE_ROUGHNESS, BaseMaterial3D.TEXTURE_METALLIC, BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION]:
		var texture := material.get_texture(slot)
		if texture == null:
			continue
		if not converted.has(texture):
			var pixels := texture.get_image()
			if pixels == null or pixels.is_empty() or pixels.has_mipmaps():
				continue
			if pixels.is_compressed() and pixels.decompress() != OK:
				continue
			if pixels.generate_mipmaps(slot == BaseMaterial3D.TEXTURE_NORMAL) != OK:
				continue
			var filtered := ImageTexture.create_from_image(pixels)
			filtered.resource_name = texture.resource_name
			converted[texture] = filtered
		material.set_texture(slot,converted[texture])
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
