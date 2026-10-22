extends "res://scripts/cuboid_animation.gd"
## Full evaluated Mobs research poses, no generic arm/leg procedural substitute.
var source_library: AnimationLibrary = preload("res://scenes/dev/actions_stuff_research/zombie_combat/source_library.res")
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
## Original dev hit layer; the pack supplies hurt color, not a skeletal Hurt clip.
## World-space critically damped offsets are reapplied over the sampled pose,
## never integrated back into the source pose or restarted by another bullet.
const HIT_FREQUENCY := 28.0
const HIT_KICK := 6.3
const HIT_LIMIT := deg_to_rad(7.0)
const HIT_VELOCITY_LIMIT := 9.0
var hit_rotation := Vector3.ZERO
var hit_velocity := Vector3.ZERO
var hit_offset := Vector3.ZERO
var hit_offset_velocity := Vector3.ZERO
var hit_count := 0
var spine_bone := -1
var chest_bone := -1
var head_bone := -1

func _ready() -> void:
	super._ready()
	skeleton = find_child("Skeleton3D",true,false)
	spine_bone = skeleton.find_bone("Spine")
	chest_bone = skeleton.find_bone("Chest")
	head_bone = skeleton.find_bone("Head")
	idle = Sampler.new(source_library.get_animation("Idle"),skeleton)
	walk = Sampler.new(source_library.get_animation("Walk"),skeleton)
	attack = Sampler.new(source_library.get_animation("Attack"),skeleton)
	# Keep the inherited actor's startup seek API valid; this paused legacy player
	# never advances or drives the living/dead pose after the source sampler starts.
	animation_player.play("Zombie_Idle")
	animation_player.pause()
	# PhysicsZombie evaluates this manually once after the living controller.
	set_process(false)

func play_state(state: StringName,_playback_rate: float=1.0) -> void:
	current_state = state

func attack_lunge(_anticipation: float=.1,_strike: float=.08,_recovery: float=.18) -> void:
	attack_time = 0.0
	attack_count += 1

func flash_hit(duration: float=.065) -> void:
	super.flash_hit(duration)

func hit_impulse(direction: Vector3) -> void:
	# Lethal hits hand the last displayed pose directly to the existing ragdoll.
	if secondary_frozen or get_parent().current_hp <= 0:return
	direction.y = 0.0
	if direction.is_zero_approx():direction = -global_basis.z
	direction = direction.normalized()
	hit_velocity = (hit_velocity + Vector3.UP.cross(direction)*HIT_KICK).limit_length(HIT_VELOCITY_LIMIT)
	hit_offset_velocity = (hit_offset_velocity + direction*.65).limit_length(.9)
	hit_count += 1

func _hit_layer(delta: float) -> void:
	# Exact critically damped solution: stable at 30/60 FPS and no tween allocation.
	var decay := exp(-HIT_FREQUENCY*delta)
	var c := hit_velocity + hit_rotation*HIT_FREQUENCY
	hit_rotation = ((hit_rotation+c*delta)*decay).limit_length(HIT_LIMIT)
	hit_velocity = ((hit_velocity-c*HIT_FREQUENCY*delta)*decay).limit_length(HIT_VELOCITY_LIMIT)
	c = hit_offset_velocity + hit_offset*HIT_FREQUENCY
	hit_offset = ((hit_offset+c*delta)*decay).limit_length(.012)
	hit_offset_velocity = ((hit_offset_velocity-c*HIT_FREQUENCY*delta)*decay).limit_length(.9)
	if hit_rotation.length_squared()<1e-12 and hit_velocity.length_squared()<1e-10:
		hit_rotation=Vector3.ZERO;hit_velocity=Vector3.ZERO
	if hit_offset.length_squared()<1e-12 and hit_offset_velocity.length_squared()<1e-10:
		hit_offset=Vector3.ZERO;hit_offset_velocity=Vector3.ZERO
	# Chest carries both rigid arms; feet, hips and their gait clocks are untouched.
	_rotate_hit(spine_bone,.25)
	_rotate_hit(chest_bone,.75)
	_rotate_hit(head_bone,-.18)
	if not hit_offset.is_zero_approx():
		var parent := skeleton.get_bone_parent(spine_bone)
		var frame := skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis
		skeleton.set_bone_pose_position(spine_bone,skeleton.get_bone_pose_position(spine_bone)+frame.inverse()*hit_offset)

func _rotate_hit(bone: int,weight: float) -> void:
	if hit_rotation.is_zero_approx():return
	var parent := skeleton.get_bone_parent(bone)
	var frame := skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis
	var local := frame.inverse()*hit_rotation
	var q := Quaternion(local.normalized(),local.length()*weight)
	skeleton.set_bone_pose_rotation(bone,(q*skeleton.get_bone_pose_rotation(bone)).normalized())

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
		# The same source PRS result: never evaluate a zero-weight clip. Crowds
		# spend most time fully Idle/Walk/Attack, so two-thirds of attack sampling
		# and half of steady gait sampling previously produced discarded values.
		var p:Vector3
		var q:Quaternion
		var s:Vector3
		if attack_weight>=1.0:
			p=attack.position(bone,at);q=attack.rotation(bone,at);s=attack.scale(bone,at)
		else:
			if walk_weight<=0.0:
				p=idle.position(bone,it);q=idle.rotation(bone,it);s=idle.scale(bone,it)
			elif walk_weight>=1.0:
				p=walk.position(bone,wt);q=walk.rotation(bone,wt);s=walk.scale(bone,wt)
			else:
				p=idle.position(bone,it).lerp(walk.position(bone,wt),walk_weight)
				q=idle.rotation(bone,it).slerp(walk.rotation(bone,wt),walk_weight)
				s=idle.scale(bone,it).lerp(walk.scale(bone,wt),walk_weight)
			if attack_weight>0.0:
				p=p.lerp(attack.position(bone,at),attack_weight)
				q=q.slerp(attack.rotation(bone,at),attack_weight)
				s=s.lerp(attack.scale(bone,at),attack_weight)
		# Upload the same complete PRS once instead of three native setters.
		skeleton.set_bone_pose(bone,Transform3D(Basis(q).scaled(s),p))
	# Reproduce the library's fixed preview-floor clearance above the real floor;
	# presentation offsets are not added to the capsule or corpse trajectory.
	var clips: Dictionary=PROFILE.data.clips
	var floor_y:=lerpf(float(clips.Idle.preview_floor_y),float(clips.Walk.preview_floor_y),walk_weight)
	model.position.y=-lerpf(floor_y,float(clips.Attack.preview_floor_y),attack_weight)
	_hit_layer(delta)
	source_frames += 1
