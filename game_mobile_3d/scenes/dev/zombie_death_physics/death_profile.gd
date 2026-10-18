extends Resource
## Experimental art-directed impulses, not firearm ballistics or validated specifications.
@export var display_name := "Pistol — Light"
@export_range(0, 900, 1) var linear_impulse := 180.0 # N s, total across the pattern.
@export_range(0, 20, 0.1) var angular_impulse := 1.0 # N m s, whole-pattern extra torque.
@export_range(0, 360, 1) var upward_impulse := 108.0 # N s, not a continuous force.
@export_range(0.2, 2.0, 0.05) var limit_scale := 0.9
@export_range(0, 5, 0.05) var linear_damping := 0.08
@export_range(0, 8, 0.05) var angular_damping := 0.5
@export_range(0.0, 0.98, 0.01) var transport_fraction := 0.9
@export_range(0.0, 2.5, 0.05) var joint_resistance := 1.0
@export var aggregate_pellets := false
@export_range(0.0, 0.25, 0.005) var pattern_radius := 0.11
@export_range(0.5, 12, 0.1) var full_strength_distance := 1.5
@export_range(2, 25, 0.1) var falloff_distance := 8.0
@export_range(0, 1, 0.01) var far_strength := 0.2

func strength_at(distance: float) -> float:
	if not aggregate_pellets: return 1.0
	return lerpf(1.0, far_strength, clampf((distance - full_strength_distance) / maxf(0.1, falloff_distance - full_strength_distance), 0.0, 1.0))
