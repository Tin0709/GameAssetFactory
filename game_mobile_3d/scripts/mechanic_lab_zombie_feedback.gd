extends Node3D
## The digit silhouettes come from the external MD2 cue atlas. Timing and colors are lab settings.

const HealthBars := preload("res://scripts/mechanic_lab_health_bars.gd")
const DamageNumbers := preload("res://scripts/mechanic_lab_damage_numbers.gd")
const FILL_HOLD_SECONDS := 0.12
const FILL_DRAIN_PER_SECOND := 1.9

var digits: Array[Texture2D]
var effects: Node3D
var bar: MeshInstance3D
var health_bars: HealthBars
var damage_numbers: DamageNumbers
var bar_slot := -1
var _health_ratio := 1.0
var _delayed_ratio := 1.0
var _delay := 0.0
var _fill_pending := false
var _serial := 0
static var _bar_mesh: QuadMesh
static var _bar_material: ShaderMaterial

func _ready() -> void:
	if health_bars != null:
		bar_slot = health_bars.add_bar(self)
	else:
		_create_individual_bar()
	set_process(false)

func _create_individual_bar() -> void:
	if _bar_mesh == null:
		_bar_mesh = HealthBars.make_quad()
		_bar_material = ShaderMaterial.new()
		_bar_material.shader = HealthBars.HEALTH_SHADER
	bar = MeshInstance3D.new()
	bar.name = "OverheadHealth"
	bar.mesh = _bar_mesh
	bar.material_override = _bar_material
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar)
	bar.position.y = HealthBars.BAR_HEIGHT

func show_hit(amount: int, remaining: int, maximum: int) -> void:
	_health_ratio = float(remaining) / maximum
	if remaining <= 0:
		_remove_batched_bar()
		if bar != null:
			bar.hide()
	else:
		_update_bar_fill()
	_delay = FILL_HOLD_SECONDS
	_fill_pending = remaining > 0 and bar_slot >= 0
	set_process(remaining > 0)
	_spawn_number(amount)

func _process(delta: float) -> void:
	if _fill_pending:
		# The first displayed hit already has the new red fill. Do not
		# charge time before the hit to the yellow fill's hold.
		_fill_pending = false
		return
	var drain_time := maxf(0.0, delta - _delay) if bar_slot >= 0 else delta
	_delay = maxf(0.0, _delay - delta)
	if _delay > 0.0:
		return
	_delayed_ratio = move_toward(_delayed_ratio, _health_ratio, drain_time * FILL_DRAIN_PER_SECOND)
	_update_bar_fill()
	if is_equal_approx(_delayed_ratio, _health_ratio):
		set_process(false)

func _update_bar_fill() -> void:
	if bar_slot >= 0:
		health_bars.set_bar_health(bar_slot, _health_ratio, _delayed_ratio)
	elif bar != null:
		bar.set_instance_shader_parameter("health_ratio", _health_ratio)
		bar.set_instance_shader_parameter("delayed_ratio", _delayed_ratio)

func _exit_tree() -> void:
	_remove_batched_bar()

func _remove_batched_bar() -> void:
	if bar_slot >= 0 and is_instance_valid(health_bars):
		health_bars.remove_bar(bar_slot)
		bar_slot = -1

func _spawn_number(amount: int) -> void:
	var camera := get_viewport().get_camera_3d()
	var side := camera.global_basis.x if camera != null else Vector3.RIGHT
	var lateral := side * (1.0 if _serial % 2 == 0 else -1.0)
	_serial += 1
	var origin := global_position + Vector3.UP * 2.40
	if damage_numbers != null:
		damage_numbers.add_number(amount, origin, lateral)
	else:
		spawn_number(amount, digits, effects, origin, lateral)

static func spawn_number(amount: int, glyphs: Array[Texture2D], parent: Node3D,
		origin: Vector3, lateral: Vector3, tint: Color = Color.WHITE) -> void:
	if glyphs.size() != DamageNumbers.DIGIT_COUNT:
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
		sprite.pixel_size = DamageNumbers.NUMBER_PIXEL_SIZE
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.render_priority = 1
		sprite.offset.x = (i - (text.length() - 1) * 0.5) * DamageNumbers.DIGIT_ADVANCE
		number.add_child(sprite)
		sprites.append(sprite)
	parent.add_child(number, true)
	number.global_position = origin + lateral * 0.12
	number.scale = Vector3.ONE * 0.85
	var tween := number.create_tween().set_parallel()
	tween.tween_property(number, "global_position", number.global_position + Vector3.UP * 0.74 + lateral * 0.32,
		DamageNumbers.NUMBER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "scale", Vector3.ONE * 1.13,
		DamageNumbers.POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for sprite in sprites:
		tween.tween_property(sprite, "modulate:a", 0.0, DamageNumbers.FADE_DURATION).set_delay(
			DamageNumbers.NUMBER_DURATION - DamageNumbers.FADE_DURATION)
	tween.chain().tween_callback(number.queue_free)

static func load_digits(path: String) -> Array[Texture2D]:
	const DIGIT_SIZE := DamageNumbers.DIGIT_SIZE
	var textures: Array[Texture2D] = []
	var atlas := Image.load_from_file(path)
	if atlas == null or atlas.get_size() != Vector2i(DamageNumbers.DIGIT_COUNT * DIGIT_SIZE, DIGIT_SIZE):
		return textures
	for digit in DamageNumbers.DIGIT_COUNT:
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
