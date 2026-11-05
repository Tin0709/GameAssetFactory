extends RefCounted
## Day-only attenuation for the two environment shaders with engine ambient disabled.

const SIZE := 256
const PARAMETERS := ["gaf_cloud_pattern", "gaf_cloud_phase", "gaf_cloud_strength"]

var active := false
var materials: Array[ShaderMaterial] = []
var _saved: Array[Array] = []
var _pattern: ImageTexture
var _phase := Vector4.ZERO

func _noise(seed_value: int, frequency: float) -> PackedByteArray:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 3
	return noise.get_seamless_image(SIZE, SIZE).get_data()

func _make_pattern() -> ImageTexture:
	# Original seeded tiles. The two linear channels share an uncompressed texture.
	var broad := _noise(57, 0.012)
	var detail := _noise(829, 0.024)
	var packed := PackedByteArray()
	packed.resize(SIZE * SIZE * 2)
	for i in SIZE * SIZE:
		var coarse_value := clampf(0.37 + (float(broad[i]) / 255.0 - 0.5) * 1.10, 0.0, 1.0)
		var fine_value := clampf(0.23 + (float(detail[i]) / 255.0 - 0.5) * 0.89, 0.0, 1.0)
		packed[2 * i] = roundi(255.0 * coarse_value)
		packed[2 * i + 1] = roundi(255.0 * fine_value)
	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RG8, packed)
	return ImageTexture.create_from_image(image)

func apply(graphics: Node, enabled: bool) -> void:
	if active == enabled:
		return
	if not enabled:
		for i in materials.size():
			for j in PARAMETERS.size():
				materials[i].set_shader_parameter(PARAMETERS[j], _saved[i][j])
		materials.clear()
		_saved.clear()
		active = false
		return
	for row: Dictionary in graphics.pairs:
		if not materials.has(row.candidate):
			materials.append(row.candidate)
	for material: ShaderMaterial in graphics.strict_match.trees.materials:
		if not materials.has(material):
			materials.append(material)
	if materials.is_empty():
		return
	if _pattern == null:
		_pattern = _make_pattern()
	for material: ShaderMaterial in materials:
		var old_values := []
		for parameter: String in PARAMETERS:
			old_values.append(material.get_shader_parameter(parameter))
		_saved.append(old_values)
		material.set_shader_parameter("gaf_cloud_pattern", _pattern)
		material.set_shader_parameter("gaf_cloud_phase", _phase)
		material.set_shader_parameter("gaf_cloud_strength", 1.0)
	active = true

func advance(delta: float) -> void:
	if not active:
		return
	_phase.y = fposmod(_phase.y + delta * 0.02, 1.0)
	_phase.w = fposmod(_phase.w - delta * 0.04, 1.0)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("gaf_cloud_phase", _phase)
