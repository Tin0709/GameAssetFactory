extends PhysicalBone3D
## Numerical guardrails, not pose tracking: physics still owns every corpse transform.
@export var maximum_linear_speed := 24.0
@export var maximum_angular_speed := 8.0
var peak_linear_speed := 0.0
var peak_angular_speed := 0.0
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	peak_linear_speed = maxf(peak_linear_speed, state.linear_velocity.length())
	peak_angular_speed = maxf(peak_angular_speed, state.angular_velocity.length())
	state.linear_velocity = state.linear_velocity.limit_length(maximum_linear_speed)
	state.angular_velocity = state.angular_velocity.limit_length(maximum_angular_speed)
