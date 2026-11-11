extends RefCounted
## Transient private texture array. Layer order is shared with the terrain shader.
const MANIFEST := "godot_lab/world_map_unified_showcase_v001/terrain_source_atlas_v001/sources.private.json"
const TILE_KEYS := ["grass_top", "grass_side", "dirt", "path", "stone"]
const TILE_SIZE := 16

static func load_tiles() -> Texture2DArray:
	if not OS.has_feature("editor"):
		return null
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.simplify_path().replace("\\", "/").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/").to_lower()
	if not root.is_absolute_path() or root.begins_with("res://") or root.begins_with("user://") \
		or root.to_lower() == project or root.to_lower().begins_with(project + "/"):
		return null
	var path := root.path_join(MANIFEST)
	if not FileAccess.file_exists(path):
		return null
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary or manifest.get("schema") != "private_world_map_terrain_atlas_v1" \
		or not manifest.get("atlas") is String or not manifest.get("sha256") is String or not manifest.get("tiles") is Dictionary:
		return null
	var relative: String = manifest.atlas
	if relative.is_absolute_path() or relative.get_extension().to_lower() != "png":
		return null
	var atlas_path := root.path_join(relative.replace("\\", "/")).simplify_path()
	if not atlas_path.begins_with(root + "/extracted/") or not FileAccess.file_exists(atlas_path) \
		or FileAccess.get_sha256(atlas_path) != manifest.sha256:
		return null
	var atlas := Image.load_from_file(atlas_path)
	if atlas == null or atlas.is_empty():
		return null
	var images: Array[Image] = []
	for key in TILE_KEYS:
		var offset: Variant = manifest.tiles.get(key)
		if not offset is Array or offset.size() != 2 or not (offset[0] is float or offset[0] is int) \
			or not (offset[1] is float or offset[1] is int):
			return null
		var tile := Rect2i(int(offset[0]), int(offset[1]), TILE_SIZE, TILE_SIZE)
		if not Rect2i(Vector2i.ZERO, atlas.get_size()).encloses(tile):
			return null
		var image := atlas.get_region(tile)
		image.generate_mipmaps()
		images.append(image)
	var texture := Texture2DArray.new()
	return texture if texture.create_from_images(images) == OK else null
