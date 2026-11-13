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
@export var sun_bounce_path: String
@export var sun_bounce_sha256: String
@export var sun_bounce_hours: PackedFloat32Array
@export var sun_bounce_directions: PackedVector3Array
@export var sun_bounce_slices: PackedInt32Array
@export var sun_bounce_layer_count := 0
@export var stone_diffuse_path: String
@export var stone_diffuse_sha256: String
@export var stone_twilight_sky_path: String
@export var stone_twilight_sky_sha256: String

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
	if not has_day_field() and not has_night_field() and not has_sun_bounce_field() and not has_stone_diffuse_field() and not has_stone_twilight_sky():
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

func has_stone_diffuse_field() -> bool:
	return OS.has_feature("editor") and stone_diffuse_sha256.length() == 64 \
		and FileAccess.file_exists(_private_path(stone_diffuse_path))

func has_stone_twilight_sky() -> bool:
	return OS.has_feature("editor") and stone_twilight_sky_sha256.length() == 64 \
		and FileAccess.file_exists(_private_path(stone_twilight_sky_path))

func load_stone_twilight_sky() -> ImageTexture:
	var bytes := _read_verified(stone_twilight_sky_path, stone_twilight_sky_sha256, extent.x * extent.y)
	if bytes.is_empty():
		return null
	return ImageTexture.create_from_image(Image.create_from_data(extent.x, extent.y, false, Image.FORMAT_R8, bytes))

func load_stone_diffuse_texture() -> ImageTexture:
	var bytes := _read_verified(stone_diffuse_path, stone_diffuse_sha256, extent.x * extent.y)
	if bytes.is_empty():
		return null
	return ImageTexture.create_from_image(Image.create_from_data(extent.x, extent.y, false, Image.FORMAT_R8, bytes))

func has_sun_bounce_field() -> bool:
	var size := sun_bounce_hours.size()
	if not OS.has_feature("editor") or sun_bounce_sha256.length() != 64 or size < 2 \
			or sun_bounce_layer_count <= 0 or sun_bounce_layer_count > size \
			or sun_bounce_directions.size() != size or sun_bounce_slices.size() != size \
			or not FileAccess.file_exists(_private_path(sun_bounce_path)):
		return false
	for index in size:
		if not is_finite(sun_bounce_hours[index]) or sun_bounce_hours[index] < 0.0 or sun_bounce_hours[index] > 24.0 \
				or not sun_bounce_directions[index].is_finite() or not sun_bounce_directions[index].is_normalized() \
				or sun_bounce_slices[index] < 0 or sun_bounce_slices[index] >= sun_bounce_layer_count:
			return false
		if index > 0 and sun_bounce_hours[index] <= sun_bounce_hours[index - 1]:
			return false
	return true

func sun_bounce_sample(hour: float, direction: Vector3) -> Vector2:
	var first_hour := sun_bounce_hours[0]
	var last_hour := sun_bounce_hours[-1]
	var fade := smoothstep(first_hour - 1.0, first_hour, hour) * (1.0 - smoothstep(last_hour, last_hour + 1.5, hour))
	if fade <= 0.0:
		return Vector2.ZERO
	var index := 0
	while index < sun_bounce_hours.size() - 2 and hour >= sun_bounce_hours[index + 1]:
		index += 1
	var a := sun_bounce_directions[index]
	var b := sun_bounce_directions[index + 1]
	var segment := b - a
	var weight := clampf((direction - a).dot(segment) / maxf(segment.length_squared(), 1e-8), 0.0, 1.0)
	var expected := a.lerp(b, weight).normalized()
	var confidence := smoothstep(cos(deg_to_rad(4.0)), cos(deg_to_rad(0.5)), direction.dot(expected))
	var slice := lerpf(sun_bounce_slices[index], sun_bounce_slices[index + 1], weight)
	return Vector2((slice + 0.5) / float(sun_bounce_layer_count), fade * confidence)

func load_sun_bounce_texture() -> ImageTexture3D:
	return _load_volume(sun_bounce_path, sun_bounce_sha256, sun_bounce_layer_count)

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
	return _load_volume(field_path, field_sha256, extent.z)

func _load_volume(path: String, sha: String, depth: int) -> ImageTexture3D:
	if not _supports_packed_texture():
		return null
	var slice_bytes := extent.x * extent.y * 4
	var bytes := _read_verified(path, sha, slice_bytes * depth)
	if bytes.is_empty():
		return null
	var layers: Array[Image] = []
	for i in depth:
		layers.append(Image.create_from_data(extent.x, extent.y, false, Image.FORMAT_RGBE9995,
			bytes.slice(i * slice_bytes, (i + 1) * slice_bytes)))
	var texture := ImageTexture3D.new()
	if texture.create(Image.FORMAT_RGBE9995, extent.x, extent.y, depth, false, layers) != OK:
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
