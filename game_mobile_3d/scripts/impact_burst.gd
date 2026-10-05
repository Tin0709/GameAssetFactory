extends Node3D
## A single emissive box, not a particle system or dynamic light.

func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.02, 0.14)
	tween.tween_callback(queue_free)
