extends Node3D
const Profiles = preload("res://scripts/weapon_fire_profiles.gd")
var duration := 0.04
var age := 0.0
var size := 1.0
var twist := 0.0
func configure(weapon: int, shot: int) -> void:
	duration = Profiles.PROFILES[weapon].flash_duration
	size = Profiles.PROFILES[weapon].flash_scale * (0.94 + 0.06 * (shot % 3))
	twist = (shot % 4) * PI / 8.0
func _ready() -> void:
	$Visual.rotation.z = twist
	scale = Vector3.ONE * size
func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	scale = Vector3.ONE * size * (1.0 - 0.45 * age / duration)
