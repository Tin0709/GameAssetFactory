extends MultiMeshInstance3D

const SHADER := preload("res://materials/mechanic_lab_damage_numbers.gdshader")
const DIGIT_SIZE := 32
const DIGIT_COUNT := 10
const DIGIT_ADVANCE := 24.5
const NUMBER_PIXEL_SIZE := 0.0144
const NUMBER_DURATION := 0.68
const POP_DURATION := 0.11
const FADE_DURATION := 0.28
const INITIAL_CAPACITY := 64
# A full buffer upload is cheaper for bursts. Sparse hits can write just the live slots.
const BUFFER_UPLOAD_MIN_GLYPHS := 48
const INSTANCE_FLOATS := 16

class DamageNumber:
	var text: String
	var origin: Vector3
	var travel: Vector3
	var age := 0.0
	var centre: Vector3
	var depth: float

var _numbers: Array[DamageNumber] = []
var _instance_buffer := PackedFloat32Array()

func setup(glyphs: Array[Texture2D]) -> void:
	var atlas := Image.create_empty(DIGIT_SIZE * DIGIT_COUNT, DIGIT_SIZE, false, Image.FORMAT_RGBA8)
	for i in DIGIT_COUNT:
		atlas.blit_rect(glyphs[i].get_image(), Rect2i(0, 0, DIGIT_SIZE, DIGIT_SIZE), Vector2i(i * DIGIT_SIZE, 0))
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = 1
	material.set_shader_parameter("digits", ImageTexture.create_from_image(atlas))
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = DIGIT_SIZE * NUMBER_PIXEL_SIZE
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * DIGIT_SIZE * NUMBER_PIXEL_SIZE
	multimesh = MultiMesh.new()
	multimesh.mesh = quad
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.instance_count = INITIAL_CAPACITY
	multimesh.visible_instance_count = 0
	set_process(false)

func add_number(amount: int, origin: Vector3, lateral: Vector3) -> void:
	var number := DamageNumber.new()
	number.text = str(amount)
	number.origin = origin + lateral * 0.12
	number.travel = Vector3.UP * 0.74 + lateral * 0.32
	_numbers.append(number)
	set_process(true)

func _process(delta: float) -> void:
	var glyph_count := 0
	for i in range(_numbers.size() - 1, -1, -1):
		var number := _numbers[i]
		number.age += delta
		if number.age >= NUMBER_DURATION:
			_numbers.remove_at(i)
		else:
			glyph_count += number.text.length()
	if glyph_count == 0:
		multimesh.visible_instance_count = 0
		set_process(false)
		return
	if glyph_count > multimesh.instance_count:
		multimesh.instance_count = nearest_po2(glyph_count)
	var upload_buffer := glyph_count >= BUFFER_UPLOAD_MIN_GLYPHS
	if upload_buffer:
		_instance_buffer.resize(multimesh.instance_count * INSTANCE_FLOATS)
	var camera := get_viewport().get_camera_3d()
	var camera_side := camera.global_basis.x if camera != null else Vector3.RIGHT
	var camera_back := camera.global_basis.z if camera != null else Vector3.BACK
	for number in _numbers:
		var offset: Vector3 = Tween.interpolate_value(Vector3.ZERO, number.travel,
			number.age, NUMBER_DURATION, Tween.TRANS_QUAD, Tween.EASE_OUT)
		number.centre = number.origin + offset
		number.depth = number.centre.dot(camera_back)
	# Draw farther glyphs first, including when two fading numbers overlap.
	_numbers.sort_custom(func(a: DamageNumber, b: DamageNumber) -> bool: return a.depth < b.depth)
	var slot := 0
	for number in _numbers:
		var scale: float = Tween.interpolate_value(0.85, 0.28, minf(number.age, POP_DURATION),
			POP_DURATION, Tween.TRANS_BACK, Tween.EASE_OUT)
		var alpha := minf(1.0, (NUMBER_DURATION - number.age) / FADE_DURATION)
		var spacing := camera_side * (DIGIT_ADVANCE * NUMBER_PIXEL_SIZE * scale)
		var length := number.text.length()
		for i in length:
			var origin := number.centre + spacing * (i - (length - 1) * 0.5)
			var point := to_local(origin)
			var digit := number.text.unicode_at(i) - 48
			if upload_buffer:
				# MultiMesh stores three row-major transform rows, then four custom floats.
				var offset := slot * INSTANCE_FLOATS
				_instance_buffer[offset] = scale
				_instance_buffer[offset + 3] = point.x
				_instance_buffer[offset + 5] = scale
				_instance_buffer[offset + 7] = point.y
				_instance_buffer[offset + 10] = scale
				_instance_buffer[offset + 11] = point.z
				_instance_buffer[offset + 12] = digit
				_instance_buffer[offset + 13] = alpha
			else:
				multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), point))
				multimesh.set_instance_custom_data(slot, Color(digit, alpha, 0.0, 0.0))
			slot += 1
	if upload_buffer:
		multimesh.buffer = _instance_buffer
	multimesh.visible_instance_count = glyph_count
