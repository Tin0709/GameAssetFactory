extends Resource
## Original tuning. Inspector-editable scene Resource; all times are seconds.
@export_range(.5,1.5,.05) var attack_speed:=1.15
@export var damage:=Vector3i(17,20,32)
@export var poise_damage:=Vector3(14,18,38)
@export_range(1,24,1) var targets_per_swing:=8
@export var broadphase_reach:=2.25
@export var blade_radius:=.20
@export var buffer_seconds:=.22
@export var hit_stop:=.035
@export var finisher_hit_stop:=.065
@export var camera_impulse:=.035
@export var finisher_camera_impulse:=.095
@export var roll_speed:=6.8
@export var roll_cost:=24.
@export var guard_cost:=18.
@export var stamina_regen:=28.
@export var parry_window:=.18
@export_range(0,2,1) var effects_quality:=1
@export_range(0,2,.1) var effects_intensity:=1.
