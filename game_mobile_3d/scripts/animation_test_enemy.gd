extends "res://scripts/cuboid_zombie.gd"
## Gameplay-test target: awareness works, while movement, attacks and damage stop.

func _ready() -> void:
	super._ready()
	visual.play_state(&"Idle")

func _physics_process(_delta: float) -> void:
	velocity = Vector3.ZERO

func take_damage(_amount: int, _direction: Vector3 = Vector3.ZERO) -> bool:
	return false
