extends Node3D
## A single emissive box, not a particle system or dynamic light.

@export var duration: float = 0.14

func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.02, duration)
	tween.tween_callback(queue_free)
