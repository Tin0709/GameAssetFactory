extends RefCounted

const CROWN_WIND_PROFILE := "godot_lab/oak_raster_registration_v001/review_wind.private.json"
const CROWN_WIND_PROFILE_SHA := "14a1cd2b17fdb74140ba56df8511a6a9466408ab61fc3dc70bbf0f279b4c0349"
const CROWN_WIND_PATTERN := "oak_wind.private.rgba8"
const MAX_GAIN := .50
const CULL_MARGIN := .65

static func load_pattern(root: String) -> Dictionary:
	var path := root.path_join(CROWN_WIND_PROFILE)
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != CROWN_WIND_PROFILE_SHA:
		return {}
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var pattern := path.get_base_dir().path_join(CROWN_WIND_PATTERN)
	var bytes := FileAccess.get_file_as_bytes(pattern)
	const SIZE := 512
	if bytes.size() != SIZE * SIZE * 4:
		return {}
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	if digest.finish().hex_encode() != profile.texture_sha256:
		return {}
	return {"time_offset": float(profile.time_offset), "texture": ImageTexture.create_from_image(Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, bytes))}

static func foliage_weights(source: ArrayMesh) -> PackedByteArray:
	if source == null or source.get_surface_count() != 1 or source.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return PackedByteArray()
	var arrays := source.surface_get_arrays(0)
	# These source atlases put foliage on the left and bark on the right.
	# Both regions share the U = 0.5 edge, so classify whole triangles.
	var format := source.surface_get_format(0)
	var required := Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_INDEX
	if (format & required) != required:
		return PackedByteArray()
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if uv.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return PackedByteArray()
	var weights := PackedByteArray()
	weights.resize(uv.size())
	const UNASSIGNED := 2
	# GLTF's compressed UV can land one UNORM16 step from the atlas edge.
	const LEFT_EDGE := 0.5 - 1.0 / 65535.0
	const RIGHT_EDGE := 0.5 + 1.0 / 65535.0
	weights.fill(UNASSIGNED)
	for index in range(0, indices.size(), 3):
		var u0 := uv[indices[index]].x
		var u1 := uv[indices[index + 1]].x
		var u2 := uv[indices[index + 2]].x
		var low := minf(u0, minf(u1, u2))
		var high := maxf(u0, maxf(u1, u2))
		var has_leaf_uv := low < LEFT_EDGE
		var has_bark_uv := high > RIGHT_EDGE
		if has_leaf_uv == has_bark_uv:
			return PackedByteArray()
		var weight := int(has_leaf_uv)
		for corner in 3:
			var vertex := indices[index + corner]
			if weights[vertex] != UNASSIGNED and weights[vertex] != weight:
				return PackedByteArray()
			weights[vertex] = weight
	for vertex in weights.size():
		weights[vertex] = 255 if weights[vertex] == 1 else 0
	return weights

static func sample_state(time: float, time_offset: float, strength: float) -> Vector2:
	# Both scroll vectors wrap after 20 seconds.
	return Vector2(fposmod(time + time_offset, 20.0), MAX_GAIN * strength) if strength > 0.0 else Vector2.ZERO