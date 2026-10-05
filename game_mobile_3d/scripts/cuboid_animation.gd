extends Node3D
## Shared presentation helper. Models face +Z after Blender's Y-up GLB conversion.

@export var animation_prefix: String = "Player"
var animation_player: AnimationPlayer
var current_state: StringName = &""
const HIT_MATERIAL = preload("res://materials/HitFlash.tres")
var meshes: Array[MeshInstance3D] = []
var flash_remaining: float = 0.0
var lunge_tween: Tween
@onready var model: Node3D = $Model

func _ready() -> void:
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(animation_player != null, "Cuboid model must contain its AnimationPlayer")
	for animation_name in animation_player.get_animation_list():
		if animation_name in [animation_prefix + "_Idle", animation_prefix + "_Walk", animation_prefix + "_Run"]:
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	for instance in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := instance as MeshInstance3D
		meshes.append(mesh_instance)
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	play_state(&"Idle")

func _process(delta: float) -> void:
	if flash_remaining > 0.0:
		flash_remaining = maxf(0.0, flash_remaining - delta)
		if flash_remaining == 0.0:
			for instance in meshes: instance.material_overlay = null

func flash_hit(duration: float = 0.09) -> void:
	flash_remaining = duration
	# Instance overlays avoid flashing other actors that share the atlas material.
	for instance in meshes: instance.material_overlay = HIT_MATERIAL

func has_state(state: StringName) -> bool:
	return animation_player.has_animation(animation_prefix + "_" + String(state))

func attack_lunge() -> void:
	if has_state(&"Attack"):
		play_state(&"Attack")
		return
	play_state(&"Idle")
	if lunge_tween and lunge_tween.is_valid(): lunge_tween.kill()
	model.position = Vector3.ZERO
	lunge_tween = create_tween()
	lunge_tween.tween_property(model, "position:z", 0.13, 0.10).set_trans(Tween.TRANS_SINE)
	lunge_tween.tween_property(model, "position:z", 0.0, 0.18).set_trans(Tween.TRANS_SINE)

func freeze_animation() -> void:
	animation_player.pause()
	if lunge_tween and lunge_tween.is_valid(): lunge_tween.kill()
	model.position = Vector3.ZERO

func play_state(state: StringName, playback_rate: float = 1.0) -> void:
	var clip := StringName(animation_prefix + "_" + String(state))
	assert(animation_player.has_animation(clip), "Missing animation: " + String(clip))
	animation_player.speed_scale = playback_rate
	if current_state != state:
		animation_player.play(clip, 0.10)
		current_state = state

func face_direction(direction: Vector3, delta: float, turn_speed: float) -> void:
	if direction.length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-turn_speed * delta))
