extends Node3D

const EffectSource := preload("res://scripts/mechanic_lab_effect_source.gd")
const SOURCE := "extracted/2026-10-25 19-26-25/Game/Spicewood/FX/Materials/Wind/T_WhirlWind.png"
const SOURCE_SHA256 := "b0db34beb364606e0c335593c69dfefcf41fd4f374b51c26d8ce1b134574a0e7"
const CAPACITY := 4
const RUN_SPEED_FRACTION := 0.85
const LIFETIME := 0.19
const TINT := Color(0.87, 0.94, 0.92, 0.34)

class Wake:
	var mesh: MeshInstance3D
	var material: StandardMaterial3D
	var origin: Vector3
	var trailing: Vector3
	var age := 0.0

var _actor: CharacterBody3D
var _terrain_contact: Callable
var _wakes: Array[Wake] = []
var _next := 0

func setup(actor: CharacterBody3D, terrain_contact := Callable()) -> bool:
	var image := EffectSource.load_image(SOURCE, SOURCE_SHA256, Vector2i(64, 64))
	if image == null:
		return false
	_actor = actor
	_terrain_contact = terrain_contact
	var texture := ImageTexture.create_from_image(image)
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2(1.02, 0.36)
	for i in CAPACITY:
		var wake := Wake.new()
		wake.material = StandardMaterial3D.new()
		wake.material.albedo_texture = texture
		wake.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	wake.mesh.global_transform = Transform3D(Basis(trailing, Vector3.UP, lateral), wake.origin)
	wake.material.albedo_color = TINT
	wake.mesh.show()
	set_process(true)

func _process(delta: float) -> void:
	var active := false
	for wake in _wakes:
		if not wake.mesh.visible:
			continue
		wake.age += delta
		if wake.age >= LIFETIME:
			wake.mesh.hide()
			continue
		var progress := wake.age / LIFETIME
		wake.mesh.global_position = wake.origin + wake.trailing * progress * 0.16
		wake.material.albedo_color.a = TINT.a * (1.0 - smoothstep(0.12, 1.0, progress))
		active = true
	set_process(active)

func clear() -> void:
	for wake in _wakes:
		wake.mesh.hide()
	set_process(false)
