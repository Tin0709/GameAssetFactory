extends SceneTree

const VisibilityField := preload("res://scripts/terrain_mist_visibility.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("Pass the bake metadata JSON and destination .res after --.")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		printerr("Use a rendering window so Godot can serialize the 3D texture.")
		quit(1)
		return
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var raw_path := args[0].get_basename() + ".r8"
	if not metadata is Dictionary or not FileAccess.file_exists(raw_path):
		quit(2)
		return
	var dims := Vector3i(vector(metadata.dimensions))
	var plane := dims.x * dims.y
	var payload := FileAccess.get_file_as_bytes(raw_path)
	if dims[dims.min_axis_index()] < 2 or payload.size() != plane * dims.z \
			or FileAccess.get_sha256(raw_path) != metadata.payload_sha256:
		quit(3)
		return
	var slices: Array[Image] = []
	for index in dims.z:
		slices.append(Image.create_from_data(dims.x, dims.y, false, Image.FORMAT_R8,
			payload.slice(plane * index, plane * (index + 1))))
	var texture := ImageTexture3D.new()
	if texture.create(Image.FORMAT_R8, dims.x, dims.y, dims.z, false, slices) != OK:
		quit(4)
		return
	if texture.get_data().size() != dims.z:
		quit(4)
		return
	var field := VisibilityField.new()
	field.texture = texture
	field.origin = vector(metadata.origin)
	field.spacing = vector(metadata.spacing)
	field.layout_sha256 = metadata.layout_sha256
	quit(ResourceSaver.save(field, args[1], ResourceSaver.FLAG_COMPRESS))

func vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
