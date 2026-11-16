extends RefCounted

const SourceFilePath := preload("res://scripts/source_file_path.gd")

static func load_image(relative: String, checksum: String, expected_size: Vector2i) -> Image:
	if not OS.has_feature("editor"):
		return null
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	var path := SourceFilePath.resolve_private_file(root, relative)
	if path.is_empty() or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != checksum:
		return null
	var image := Image.load_from_file(path)
	return image if image != null and image.get_size() == expected_size else null
