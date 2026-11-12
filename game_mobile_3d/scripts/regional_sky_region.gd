extends Resource
## Scene-authored bounds and references to an external, verified sky field.

@export var center_xz: Vector2
@export var inner_radius_m := 0.0
@export var outer_radius_m := 0.0
@export var extent: Vector3i
@export var terrain_receivers := 0
@export var grass_origin: Vector2
@export var grass_extent: Vector2i
@export var transport_sha256: String
@export var indices_path: String
@export var indices_sha256: String
@export var field_path: String
@export var field_sha256: String
@export var night_field_path: String
@export var night_field_sha256: String

func read_ids(transport_path: String, vertex_count: int) -> PackedFloat32Array:
	if not OS.has_feature("editor") or not center_xz.is_finite() or not grass_origin.is_finite():
		return PackedFloat32Array()
	if not is_finite(inner_radius_m) or not is_finite(outer_radius_m) or inner_radius_m < 0.0 or outer_radius_m <= inner_radius_m:
		return PackedFloat32Array()
	if extent.x <= 0 or extent.y <= 0 or extent.z != 8 or terrain_receivers <= 0 or grass_extent.x <= 0 or grass_extent.y <= 0:
		return PackedFloat32Array()
	if terrain_receivers + grass_extent.x * grass_extent.y > extent.x * extent.y:
		return PackedFloat32Array()
	if transport_sha256.length() != 64 or FileAccess.get_sha256(transport_path) != transport_sha256:
		return PackedFloat32Array()
	if not has_day_field() and not has_night_field():
		return PackedFloat32Array()
	var ids := _read_verified(indices_path, indices_sha256, vertex_count * 4).to_float32_array()
	for id in ids:
		if not is_finite(id) or id < 0.0 or id >= terrain_receivers or id != floorf(id):
			return PackedFloat32Array()
	return ids

func has_day_field() -> bool:
	return OS.has_feature("editor") and FileAccess.file_exists(_private_path(field_path))

func has_night_field() -> bool:
	return OS.has_feature("editor") and night_field_sha256.length() == 64 and FileAccess.file_exists(_private_path(night_field_path))

func load_night_texture() -> ImageTexture:
	if extent.x <= 0 or extent.y <= 0 or not _supports_packed_texture():
		return null
	var bytes := _read_verified(night_field_path, night_field_sha256, extent.x * extent.y * 4)
	if bytes.is_empty():
		return null
	return ImageTexture.create_from_image(Image.create_from_data(extent.x, extent.y, false, Image.FORMAT_RGBE9995, bytes))

func _supports_packed_texture() -> bool:
	var rd := RenderingServer.get_rendering_device()
	return rd != null and rd.texture_is_format_supported_for_usage(
		RenderingDevice.DATA_FORMAT_E5B9G9R9_UFLOAT_PACK32, RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT)

func load_texture() -> ImageTexture3D:
	if not _supports_packed_texture():
		return null
	var slice_bytes := extent.x * extent.y * 4
	var bytes := _read_verified(field_path, field_sha256, slice_bytes * extent.z)
	if bytes.is_empty():
		return null
	var layers: Array[Image] = []
	for i in extent.z:
		layers.append(Image.create_from_data(extent.x, extent.y, false, Image.FORMAT_RGBE9995,
			bytes.slice(i * slice_bytes, (i + 1) * slice_bytes)))
	var texture := ImageTexture3D.new()
	if texture.create(Image.FORMAT_RGBE9995, extent.x, extent.y, extent.z, false, layers) != OK:
		return null
	return texture

func bounds() -> Vector4:
	return Vector4(center_xz.x, center_xz.y, inner_radius_m, outer_radius_m)

func _private_path(relative: String) -> String:
	var normalized := relative.simplify_path()
	if normalized.is_empty() or normalized.is_absolute_path() or normalized == ".." or normalized.begins_with("../"):
		return ""
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	return root.path_join(normalized)

func _read_verified(relative: String, sha: String, size_bytes: int) -> PackedByteArray:
	if not OS.has_feature("editor") or sha.length() != 64 or size_bytes <= 0:
		return PackedByteArray()
	var file := FileAccess.open(_private_path(relative), FileAccess.READ)
	if file == null or file.get_length() != size_bytes:
		return PackedByteArray()
	var bytes := file.get_buffer(size_bytes)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return bytes if hash.finish().hex_encode() == sha else PackedByteArray()
