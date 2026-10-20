extends "res://scripts/cuboid_animation.gd"
## Full evaluated Mobs research poses, no generic arm/leg procedural substitute.
const source_library = preload("res://scenes/dev/actions_stuff_research/zombie_combat/source_library.res")
const PROFILE = preload("res://scenes/dev/actions_stuff_research/zombie_combat/profile.json")
const Sampler = preload("res://scenes/dev/actions_stuff_research/source_clip_sampler.gd")
var skeleton: Skeleton3D
var secondary_frozen := false
var idle: RefCounted
var walk: RefCounted
var attack: RefCounted
var life := 0.0
var walk_clock := 0.0
var walk_weight := 0.0
var attack_time := 1.0
var attack_weight := 0.0
var attack_count := 0
var source_frames := 0

func _ready() -> void:
	super._ready()
	skeleton = find_child("Skeleton3D",true,false)
	idle = Sampler.new(source_library.get_animation("Idle"),skeleton)
	walk = Sampler.new(source_library.get_animation("Walk"),skeleton)
	attack = Sampler.new(source_library.get_animation("Attack"),skeleton)
	animation_player.pause()
	# PhysicsZombie evaluates this manually once after the living controller.
	set_process(false)

func play_state(state: StringName,_playback_rate: float=1.0) -> void:
	current_state = state

func attack_lunge(_anticipation: float=.1,_strike: float=.08,_recovery: float=.18) -> void:
	attack_time = 0.0
	attack_count += 1

func hit_impulse(_direction: Vector3) -> void:
	# Source study found hurt tint, no skeletal Hurt clip. Reuse the actor's
	# existing world knockback/flash; do not add the older procedural pose spring.
	pass

func _process(delta: float) -> void:
	super._process(delta) # Existing per-instance hit overlay and material cleanup.
	if secondary_frozen or skeleton == null:return
	life += delta
	var walking := current_state == &"Walk" and attack_time >= .75
	if walking:walk_clock += delta
	walk_weight = move_toward(walk_weight,1.0 if walking else 0.0,delta/.12)
	var attacking := attack_time < .75
	if attacking:attack_time=minf(.75,attack_time+delta)
	attack_weight=move_toward(attack_weight,1.0 if attacking else 0.0,delta/(.06 if attacking else .10))
	var it:=fposmod(life+phase_offset*3.6,3.6)
	var wt:=fposmod(walk_clock+phase_offset*18.0,18.0)
	var at:=clampf(attack_time,0.0,.75)
	for bone in skeleton.get_bone_count():
		var p: Vector3=idle.position(bone,it).lerp(walk.position(bone,wt),walk_weight)
		var q: Quaternion=idle.rotation(bone,it).slerp(walk.rotation(bone,wt),walk_weight)
		var s: Vector3=idle.scale(bone,it).lerp(walk.scale(bone,wt),walk_weight)
		if attack_weight>0.0:
			p=p.lerp(attack.position(bone,at),attack_weight)
			q=q.slerp(attack.rotation(bone,at),attack_weight)
			s=s.lerp(attack.scale(bone,at),attack_weight)
		skeleton.set_bone_pose_position(bone,p)
		skeleton.set_bone_pose_rotation(bone,q)
		skeleton.set_bone_pose_scale(bone,s)
	# Reproduce the library's fixed preview-floor clearance above the real floor;
	# presentation offsets are not added to the capsule or corpse trajectory.
	var clips: Dictionary=PROFILE.data.clips
	var floor_y:=lerpf(float(clips.Idle.preview_floor_y),float(clips.Walk.preview_floor_y),walk_weight)
	model.position.y=-lerpf(floor_y,float(clips.Attack.preview_floor_y),attack_weight)
	source_frames += 1
