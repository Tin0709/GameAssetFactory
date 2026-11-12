extends Node3D
## The digit silhouettes come from the external MD2 cue atlas. Timing and colors are lab settings.

const HEALTH_SHADER := preload("res://materials/mechanic_lab_zombie_health.gdshader")
const DIGIT_SIZE := 32
const DIGIT_ADVANCE := 24.5
const NUMBER_DURATION := 0.68
const NUMBER_PIXEL_SIZE := 0.0144

var digits: Array[Texture2D]
var effects: Node3D
var bar: MeshInstance3D
var _health_ratio := 1.0
var _delayed_ratio := 1.0
var _delay := 0.0
var _serial := 0
static var _bar_mesh: QuadMesh
static var _bar_material: ShaderMaterial

func _ready() -> void:
	if _bar_mesh == null:
		_bar_mesh = QuadMesh.new()
		_bar_mesh.size = Vector2(0.86, 0.165)
		_bar_material = ShaderMaterial.new()
		_bar_material.shader = HEALTH_SHADER
	bar = MeshInstance3D.new()
	bar.name = "OverheadHealth"
	bar.mesh = _bar_mesh
	bar.material_override = _bar_material
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar)
	bar.position.y = 2.16
	set_process(false)

func show_hit(amount: int, remaining: int, maximum: int) -> void:
	_health_ratio = float(remaining) / maximum
	bar.set_instance_shader_parameter("health_ratio", _health_ratio)
	bar.visible = remaining > 0
	_delay = 0.12
	set_process(remaining > 0)
	_spawn_number(amount)

func _process(delta: float) -> void:
	_delay = maxf(0.0, _delay - delta)
	if _delay > 0.0:
		return
	_delayed_ratio = move_toward(_delayed_ratio, _health_ratio, delta * 1.9)
	bar.set_instance_shader_parameter("delayed_ratio", _delayed_ratio)
	if is_equal_approx(_delayed_ratio, _health_ratio):
		set_process(false)

func _spawn_number(amount: int) -> void:
	var camera := get_viewport().get_camera_3d()
	var side := camera.global_basis.x if camera != null else Vector3.RIGHT
	var lateral := side * (1.0 if _serial % 2 == 0 else -1.0)
	_serial += 1
	spawn_number(amount, digits, effects, global_position + Vector3.UP * 2.40, lateral)

static func spawn_number(amount: int, glyphs: Array[Texture2D], parent: Node3D,
		origin: Vector3, lateral: Vector3, tint: Color = Color.WHITE) -> void:
	if glyphs.size() != 10:
		return
	var number := Node3D.new()
	number.name = "DamageNumber"
	number.set_meta("amount", amount)
	var text := str(amount)
	var sprites: Array[Sprite3D] = []
	for i in text.length():
		var sprite := Sprite3D.new()
		sprite.texture = glyphs[text.unicode_at(i) - 48]
		sprite.modulate = tint
		sprite.pixel_size = NUMBER_PIXEL_SIZE
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.render_priority = 1
		sprite.offset.x = (i - (text.length() - 1) * 0.5) * DIGIT_ADVANCE
		number.add_child(sprite)
		sprites.append(sprite)
	parent.add_child(number, true)
	number.global_position = origin + lateral * 0.12
	number.scale = Vector3.ONE * 0.85
	var tween := number.create_tween().set_parallel()
	tween.tween_property(number, "global_position", number.global_position + Vector3.UP * 0.74 + lateral * 0.32, NUMBER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "scale", Vector3.ONE * 1.13, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for sprite in sprites:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.28).set_delay(NUMBER_DURATION - 0.28)
	tween.chain().tween_callback(number.queue_free)

static func load_digits(path: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var atlas := Image.load_from_file(path)
	if atlas == null or atlas.get_size() != Vector2i(10 * DIGIT_SIZE, DIGIT_SIZE):
		return textures
	for digit in 10:
		var image := atlas.get_region(Rect2i(digit * DIGIT_SIZE, 0, DIGIT_SIZE, DIGIT_SIZE))
		for y in DIGIT_SIZE:
			for x in DIGIT_SIZE:
				var masks := image.get_pixel(x, y)
				if masks.a < 0.5:
					image.set_pixel(x, y, Color.TRANSPARENT)
				elif masks.r > masks.g:
					image.set_pixel(x, y, Color(1.0, 0.97, 0.80))
				else:
					image.set_pixel(x, y, Color(0.10, 0.038, 0.023))
		textures.append(ImageTexture.create_from_image(image))
	return textures
