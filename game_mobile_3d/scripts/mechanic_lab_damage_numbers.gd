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

class DamageNumber:
	var text: String
	var origin: Vector3
	var travel: Vector3
	var age := 0.0

var _numbers: Array[DamageNumber] = []

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
	multimesh.visible_instance_count = mini(glyph_count, multimesh.instance_count)
	if glyph_count == 0:
		set_process(false)
		return
	if glyph_count > multimesh.instance_count:
		multimesh.instance_count = nearest_po2(glyph_count)
		multimesh.visible_instance_count = glyph_count
	var camera := get_viewport().get_camera_3d()
	var camera_side := camera.global_basis.x if camera != null else Vector3.RIGHT
	var slot := 0
	for number in _numbers:
		var centre := number.origin + Tween.interpolate_value(Vector3.ZERO, number.travel,
			number.age, NUMBER_DURATION, Tween.TRANS_QUAD, Tween.EASE_OUT) as Vector3
		var scale: float = Tween.interpolate_value(0.85, 0.28, minf(number.age, POP_DURATION),
			POP_DURATION, Tween.TRANS_BACK, Tween.EASE_OUT)
		var alpha := minf(1.0, (NUMBER_DURATION - number.age) / FADE_DURATION)
		var spacing := camera_side * (DIGIT_ADVANCE * NUMBER_PIXEL_SIZE * scale)
		var length := number.text.length()
		for i in length:
			var origin := centre + spacing * (i - (length - 1) * 0.5)
			multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), to_local(origin)))
			multimesh.set_instance_custom_data(slot, Color(number.text.unicode_at(i) - 48, alpha, 0.0, 0.0))
			slot += 1
