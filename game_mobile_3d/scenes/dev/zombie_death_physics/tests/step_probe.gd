extends Node
## Test-only observer: sample EVERY physics tick, independent of display frame rate.
var target: Node3D
var peak_anchor := 0.0
var minimum_y := INF
var scale_error := 0.0
var finite := true
var samples := 0
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target) or not target.dead: return
	samples += 1
	peak_anchor = maxf(peak_anchor, target.ragdoll.max_anchor_error())
	minimum_y = minf(minimum_y, target.ragdoll.minimum_corner_y())
	for body in target.ragdoll.bodies.values():
		finite = finite and body.global_position.is_finite()
		scale_error = maxf(scale_error, body.global_basis.get_scale().distance_to(Vector3.ONE))
