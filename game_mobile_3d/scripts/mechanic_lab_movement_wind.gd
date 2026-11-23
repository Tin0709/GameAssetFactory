extends Node3D

const EffectSource := preload("res://scripts/mechanic_lab_effect_source.gd")
const SOURCE := "extracted/2026-10-25 19-26-25/Game/Spicewood/FX/Materials/Wind/T_WhirlWind.png"
const SOURCE_SHA256 := "b0db34beb364606e0c335593c69dfefcf41fd4f374b51c26d8ce1b134574a0e7"
const CAPACITY := 4
const QUAD_SIZE := Vector2(1.02, 0.36)
const DRIFT_DISTANCE := 0.16
const RUN_SPEED_FRACTION := 0.85
const LIFETIME := 0.19
const TINT := Color(0.87, 0.94, 0.92, 0.34)

class Wake:
	var mesh: MeshInstance3D
	var material: StandardMaterial3D
	var origin: Vector3
	var trailing: Vector3
	var age := 0.0
	var contact_tick := -1

var _actor: CharacterBody3D
var _terrain_contact: Callable
var _wakes: Array[Wake] = []
var _next := 0
var _physics_clock := false
var _visible_footprint: Rect2

func setup(actor: CharacterBody3D, terrain_contact := Callable(), physics_clock := false,
		cull_mode: BaseMaterial3D.CullMode = BaseMaterial3D.CULL_BACK) -> bool:
	var image := EffectSource.load_image(SOURCE, SOURCE_SHA256, Vector2i(64, 64))
	if image == null:
		return false
	_actor = actor
	_terrain_contact = terrain_contact
	_physics_clock = physics_clock
	# Account for the transparent part of the source image, including a texel for filtering.
	var footprint := image.get_used_rect().grow(1).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var pixels := Vector2(image.get_size())
	_visible_footprint = Rect2((Vector2(footprint.position) / pixels - Vector2.ONE * 0.5) * QUAD_SIZE,
		Vector2(footprint.size) / pixels * QUAD_SIZE)
	var texture := ImageTexture.create_from_image(image)
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = QUAD_SIZE
	for i in CAPACITY:
		var wake := Wake.new()
		wake.material = StandardMaterial3D.new()
		wake.material.albedo_texture = texture
		wake.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wake.material.cull_mode = cull_mode
		wake.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wake.mesh = MeshInstance3D.new()
		wake.mesh.mesh = quad
		wake.mesh.material_override = wake.material
		wake.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wake.mesh.hide()
		add_child(wake.mesh)
		_wakes.append(wake)
	actor.surface_contact.connect(_on_surface_contact)
	actor.presentation_reset.connect(clear)
	set_process(false)
	return true

func _on_surface_contact(point: Vector3, landed: bool) -> void:
	if landed or not _actor._run_requested or _actor.current_speed < _actor.run_speed * RUN_SPEED_FRACTION:
		return
	var foot_height := _actor.global_position.y
	if _terrain_contact.is_valid():
		var contact: Dictionary = _terrain_contact.call(point)
		if contact.is_empty():
			return
		point = contact.position
		foot_height = point.y
	var motion := _actor.get_real_velocity()
	motion.y = 0.0
	var trailing := -motion.normalized()
	var lateral := trailing.cross(Vector3.UP)
	var side := signf(lateral.dot(point - _actor.global_position))
	var wake := _wakes[_next]
	_next = (_next + 1) % _wakes.size()
	wake.trailing = trailing
	wake.origin = Vector3(point.x, foot_height + 0.38, point.z) + trailing * 0.50 + lateral * side * 0.18
	wake.age = 0.0
	wake.contact_tick = Engine.get_physics_frames()
	wake.mesh.global_transform = Transform3D(Basis(trailing, Vector3.UP, lateral), wake.origin)
	wake.material.albedo_color = TINT
	wake.mesh.layers = 0 if _physics_clock else 1
	wake.mesh.show()
	set_process(true)

func _process(delta: float) -> void:
	var active := false
	var render_tick := 0.0
	var step := 0.0
	if _physics_clock:
		# Match the player's interpolated pose and the dust from the same step.
		render_tick = float(Engine.get_physics_frames())
		if not Engine.is_in_physics_frame():
			render_tick += Engine.get_physics_interpolation_fraction() - 1.0
		step = get_physics_process_delta_time()
	for wake in _wakes:
		if not wake.mesh.visible:
			continue
		if _physics_clock:
			var layers := int(render_tick >= wake.contact_tick)
			if wake.mesh.layers != layers:
				wake.mesh.layers = layers
			wake.age = maxf(render_tick - wake.contact_tick, 0.0) * step
		else:
			wake.age += delta
		if wake.age >= LIFETIME:
			wake.mesh.hide()
			continue
		var progress := wake.age / LIFETIME
		wake.mesh.global_position = wake.origin + wake.trailing * progress * DRIFT_DISTANCE
		wake.material.albedo_color.a = TINT.a * (1.0 - smoothstep(0.12, 1.0, progress))
		active = true
	set_process(active)

func overlaps_smoke(camera: Camera3D, point: Vector3, size: float) -> bool:
	if not is_processing() or not is_visible_in_tree():
		return false
	var camera_basis := camera.global_basis
	for wake in _wakes:
		if not wake.mesh.visible:
			continue
		if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
			return true
		# Project the whole drifting wake onto the camera's screen axes.
		# A smoke sprite overlapping it needs its original depth sort.
		var trailing := wake.trailing
		var lateral := trailing.cross(Vector3.UP)
		var drift := trailing * (DRIFT_DISTANCE * 0.5)
		var footprint_center := _visible_footprint.get_center()
		var offset := point - wake.origin - trailing * footprint_center.x - lateral * footprint_center.y - drift
		var half := _visible_footprint.size * 0.5
		var half_width := absf(camera_basis.x.dot(trailing)) * half.x \
			+ absf(camera_basis.x.dot(lateral)) * half.y + absf(camera_basis.x.dot(drift))
		var half_height := absf(camera_basis.y.dot(trailing)) * half.x \
			+ absf(camera_basis.y.dot(lateral)) * half.y + absf(camera_basis.y.dot(drift))
		if absf(camera_basis.x.dot(offset)) < half_width + size * 0.5 \
				and absf(camera_basis.y.dot(offset)) < half_height + size * 0.5:
			return true
	return false

func clear() -> void:
	for wake in _wakes:
		wake.mesh.hide()
	set_process(false)
