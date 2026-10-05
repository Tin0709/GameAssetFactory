extends Resource
## Shared defaults in radians, metres and velocity impulses; lab overrides are local.
@export_group("Common")
@export var bounce_strength := 1.0
@export var bounce_frequency := 3.6
@export var bounce_damping := 0.48
@export var max_body_drop := 0.024
@export var max_body_angle := 0.045
@export var max_velocity := 1.2
@export var integration_hz := 120.0
@export var max_substeps := 8
@export var contact_phase := 0.0
@export_group("Player")
@export var player_frequency := 3.5
@export var player_damping := 0.36
@export var player_max_drop := 0.075
@export var player_max_angle := 0.065
@export var player_max_velocity := 3.0
@export var walk_contact_impulse := 1.1
@export var run_contact_impulse := 2.4
@export var walk_pitch_impulse := 0.08
@export var run_pitch_impulse := 0.16
@export var combat_body_response := 0.60
@export var landing_impulse := 0.45
@export var acceleration_strength := 0.0009
@export var turn_spring_strength := 0.004
@export var chest_frequency := 3.8
@export var chest_vertical_follow := 0.45
@export var head_frequency := 4.2
@export var head_follow_strength := 0.40
@export var head_vertical_follow := 0.30
@export var idle_follow_strength := 0.12
@export var arm_frequency := 3.6
@export var weapon_follow_strength := 0.90
@export var weapon_frequencies := Vector3(4.6, 3.8, 3.3)
@export var weapon_mass := Vector3(1.0, 1.05, 1.16)
@export var aim_stabilization := 0.40
@export var max_weapon_shift := 0.014
@export var max_weapon_angle := 0.030
@export var recoil_follow_impulses := Vector3(0.055, 0.070, 0.110)
@export var hit_impulse := 0.34
@export_group("Zombie")
@export var zombie_contact_impulse := 0.24
@export var zombie_hit_impulse := 0.60
@export var zombie_frequency := 3.1
@export var zombie_damping := 0.55
@export var zombie_max_drop := 0.014
@export var zombie_max_angle := 0.075
@export var zombie_shoulder_follow := 0.45
@export var zombie_head_follow := 0.20
@export_group("Death")
@export var death_ground_fraction := 0.66
@export var death_launch := 0.25
@export var death_lift := 0.09
@export var ground_rebound := 0.032
@export var corpse_hold := 0.45
@export var ground_clearance := 0.004
