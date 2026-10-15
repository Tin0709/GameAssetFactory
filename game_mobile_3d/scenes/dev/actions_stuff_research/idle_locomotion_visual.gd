extends "res://scenes/dev/actions_stuff_research/jump_locomotion_visual.gd"
## Approved source Idle overlay, restricted to this research scene. The accepted
## ground/jump bridge remains authoritative for physics, phase, bob and contacts.
const IdleController=preload("res://scenes/dev/actions_stuff_research/source_idle_controller.gd")
const IdleSampler=preload("res://scenes/dev/actions_stuff_research/source_idle_sampler.gd")
var idle_controller: RefCounted
var idle_sampler: RefCounted
var idle_future_sampler: RefCounted
var idle_snapshot: Dictionary={}
var idle_active:=false
var _idle_driving:=false
var presentation: Node

func _ready() -> void:
	super._ready()
	idle_controller=IdleController.new(entity_lifetime)
	idle_sampler=IdleSampler.new(skeleton);idle_future_sampler=IdleSampler.new(skeleton)

func drive_jump_motion(world_velocity: Vector3,requested: bool,physics: Dictionary,delta: float) -> void:
	var previous_life:=entity_lifetime
	var was_active:=idle_active
	# Delay contact eligibility until the final composed pose; advance the
	# existing locomotion/Jump runtimes and pending physics delta exactly once.
	_idle_driving=true
	super.drive_jump_motion(world_velocity,requested,physics,delta)
	_idle_driving=false
	var count:=maxi(1,ceili(delta*240.-.000001));var step:=delta/count
	for i in count:
		var base:=direction_snapshot.duplicate(true)
		base.life=lerpf(previous_life,entity_lifetime,float(i+1)/count)
		idle_snapshot=idle_controller.step(base,requested,jump_grounded and not jump_active,step)
	idle_active=not jump_active and not idle_snapshot.layers.is_empty()
	if idle_active:
		idle_sampler.set_composite(direction_sampler.channels,direction_snapshot,idle_snapshot)
		direction_poses=idle_sampler.poses.duplicate()
		var future:=direction_snapshot.duplicate(true)
		future.phase+=.004*float(future.cadence);future.life+=.004
		direction_future_sampler.set_snapshot(future)
		idle_future_sampler.set_composite(direction_future_sampler.channels,future,idle_sampler.future_snapshot(idle_snapshot,.004))
		direction_future_poses=idle_future_sampler.poses.duplicate()
	elif was_active and not jump_active:
		# Ground future cache can still hold the overlay from the preceding tick.
		pose_dirty=true;_cache_direction_poses()
	# Source clip starts neutral; no arbitrary filtering of authored keys. Exit
	# uses its literal .2s fade, plus inherited movement handoff inertialization.
	if jump_grounded: _update_direction_support(delta)
	support_left=_support(0);support_right=_support(1)
	# Resolve every physics pose once, including multiple ticks between renders.
	# Render presentation consumes these final poses without feeding back into IK.
	_evaluate(delta)
	if presentation!=null: presentation.capture()

func _update_direction_support(delta: float) -> void:
	if not _idle_driving: super._update_direction_support(delta)

func reset_contacts() -> void:
	super.reset_contacts()
	if idle_controller!=null: idle_controller.reset()
	idle_active=false;idle_snapshot={}
