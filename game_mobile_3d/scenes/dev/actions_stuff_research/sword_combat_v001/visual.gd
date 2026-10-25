extends "res://scenes/dev/actions_stuff_research/rifle_ready_v001/rifle_visual.gd"
## Original Sword poses enter the existing target/contact/inertialization writer.
const SWORD_LIBRARY=preload("res://scenes/dev/actions_stuff_research/sword_combat_v001/original_library.res")
const PoseSampler=preload("res://scenes/dev/actions_stuff_research/source_clip_sampler.gd")
var sword_equipped:=false
var melee:Node
var sword_model:Node3D
var sword_profile:Dictionary
var sword_clips:Dictionary={}
var sword_attachment:=Transform3D.IDENTITY
var sword_mount:=Transform3D.IDENTITY
var sword_base_local:=Vector3.ZERO
var sword_tip_local:=Vector3.ZERO
var sword_upper:Array[int]=[]
var sword_lower:Array[int]=[]
var _sword_turn_lock:=false
var _roll_gait_cursor:=NAN
var private_fiery_requested:=false
var using_private_fiery:=false
var private_fiery_profile:Dictionary={}
var _dynamic_clips:Dictionary={}
var sword_current_attachment:=Transform3D.IDENTITY
func _retime_locomotion_phase(step:float)->void:
	if sword_equipped and melee!=null and melee.state.state==&"roll" and is_finite(_roll_gait_cursor):
		var phase:float=_roll_gait_cursor;var phase01:=fposmod(phase,1.)
		direction_snapshot.phase=phase;direction_snapshot.phase01=phase01;direction_snapshot.cadence=0.;direction_snapshot.run_weight=_gameplay_run_weight
		direction_snapshot.vars["v.eqhdel"]=phase;direction_snapshot.vars["v.ifcvde"]=phase01
		direction_controller.env["v.eqhdel"]=phase;direction_controller.env["v.ifcvde"]=phase01
		_distance_phase=phase
		return
	super._retime_locomotion_phase(step)
func _ready()->void:
	super._ready()
	sword_profile=JSON.parse_string(FileAccess.get_file_as_string("res://scenes/dev/actions_stuff_research/sword_combat_v001/profile.json"))
	sword_attachment=_rows(sword_profile.carrier_in_right_arm);sword_mount=_rows(sword_profile.weapon_mount)
	sword_base_local=Vector3(sword_profile.sword_base_local[0],sword_profile.sword_base_local[1],sword_profile.sword_base_local[2])
	sword_tip_local=Vector3(sword_profile.sword_tip_local[0],sword_profile.sword_tip_local[1],sword_profile.sword_tip_local[2])
	for key in SWORD_LIBRARY.get_animation_list():sword_clips[key]=PoseSampler.new(SWORD_LIBRARY.get_animation(key),skeleton)
	sword_current_attachment=sword_attachment
	if private_fiery_requested:
		# Deliberately OUTSIDE res:// and Git. The release-excluded dev lab may
		# inspect user-owned source motion without shipping any reference tracks.
		var base:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().get_base_dir().path_join("private_research/fiery_combat_20261025/godot_lab")
		var external:=base.path_join("fiery_retarget_library.res")
		if FileAccess.file_exists(external) and FileAccess.file_exists(base.path_join("profile.json")):
			var library:=load(external) as AnimationLibrary
			if library!=null:
				private_fiery_profile=JSON.parse_string(FileAccess.get_file_as_string(base.path_join("profile.json")))
				for key in library.get_animation_list():
					sword_clips[key]=PoseSampler.new(library.get_animation(key),skeleton);_dynamic_clips[key]=true
				using_private_fiery=true
		else:push_warning("Private Fiery reference unavailable; original Sword candidate remains active.")
	for name in ["Spine","Chest","Neck","Head","Arm.L","Arm.R","ForeArm.L","ForeArm.R"]:sword_upper.append(skeleton.find_bone(name))
	for name in ["Root","Hips","Leg.L","Leg.R"]:sword_lower.append(skeleton.find_bone(name))
	sword_model=load(sword_profile.sword_asset).instantiate();sword_model.name="SwordSandBlockV1";add_child(sword_model);sword_model.hide()
	for instance:MeshInstance3D in sword_model.find_children("*","MeshInstance3D",true,false):
		for surface in instance.mesh.get_surface_count():
			var material:=instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material:material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
func sword_clip()->String:
	if melee==null:return "Ready"
	match melee.state.state:
		&"attack":return "Attack%d"%(melee.state.attack_index+1)
		&"guard":return "Guard"
		&"parry":return "Parry"
		&"roll":return "Roll"
		&"hurt":return "Hurt"
	return "Ready"
func _sample_set(ahead:float=0.)->Array:
	var poses:Array=super._sample_set(ahead)
	if not sword_equipped or sword_clips.is_empty() or melee==null:return poses
	var key:=sword_clip();var sampler:RefCounted=sword_clips[key]
	var time:float=melee.state.time+ahead*(melee.config.attack_speed if key.begins_with("Attack") else 1.)
	if key in ["Ready","Guard"]:time=fposmod(time,sampler.clip.length)
	else:time=minf(time,sampler.clip.length)
	for bone in sword_upper:
		poses[bone]=Transform3D(Basis(sampler.rotation(bone,time)),sampler.position(bone,time))
	var lower:=0.
	if key=="Roll":lower=1.
	elif key.begins_with("Attack") and jump_grounded and not jump_active:lower=1.-rifle_move_weight
	elif key in ["Guard","Parry","Hurt"] and jump_grounded and not jump_active:lower=1.-rifle_move_weight
	if lower>0.:
		for bone in sword_lower:poses[bone]=Transform3D(poses[bone]).interpolate_with(Transform3D(Basis(sampler.rotation(bone,time)),sampler.position(bone,time)),lower)
	# One invariant grip; never use the two-handed Rifle constraint on Sword.
	var attachment:=sword_attachment
	if _dynamic_clips.has(key):
		attachment=Transform3D(poses[arm_right]).affine_inverse()*Transform3D(Basis(sampler.rotation(carrier_bone,time)),sampler.position(carrier_bone,time))
	if ahead==0.:sword_current_attachment=attachment
	poses[carrier_bone]=Transform3D(poses[arm_right])*attachment
	return poses
func _advance_facing(target_yaw:float,delta:float)->void:
	if sword_equipped and _sword_turn_lock:return # Combat heading already advanced once this tick.
	super._advance_facing(target_yaw,delta)
func drive_jump_motion(world_velocity:Vector3,requested:bool,physics:Dictionary,delta:float)->void:
	if not sword_equipped:
		_sword_turn_lock=false;_roll_gait_cursor=NAN
		super.drive_jump_motion(world_velocity,requested,physics,delta);return
	rifle_aim_requested=false;rifle_aim_weight=0.;combat_turn_requested=false;auto_aim_target=null
	_sword_turn_lock=melee!=null and melee.state.state in [&"attack",&"guard",&"parry",&"roll"]
	if _sword_turn_lock:
		rotation.y+=clampf(wrapf(melee.facing-rotation.y,-PI,PI),-16.*delta,16.*delta)
		# Reuse the already-compiled runtime. reset() constructs/parses/prepares
		# an entire source controller and must never run in a per-tick hot path.
		stationary_turn.runtime.seed_heading(-rad_to_deg(rotation.y))
		stationary_turn.look_yaw=rotation.y;stationary_turn.requested_yaw=rotation.y;stationary_turn.body_yaw=rotation.y
		stationary_turn.gaze=0.;stationary_turn.weight=0.;stationary_turn.axis=0.;stationary_turn.active=false;stationary_turn.stepping=false
	if melee!=null and melee.state.state==&"roll":
		if not is_finite(_roll_gait_cursor):_roll_gait_cursor=float(direction_snapshot.phase)
		# Physical contact has been established; Roll supersedes the old landing
		# pose, without resetting either the shared gait or physical jump state.
		jump_active=false
	else:_roll_gait_cursor=NAN
	var moving:=requested
	# Physics travel during a lunge/roll is not a walking gait request.
	if melee!=null and melee.state.state==&"roll":moving=false;settling=false
	super.drive_jump_motion(world_velocity,moving,physics,delta)
	sword_model.global_transform=sword_world()
func _constrain_rifle_contacts()->void:
	if not sword_equipped:super._constrain_rifle_contacts();return
	if sword_clips.is_empty():return
	var carrier:=skeleton.get_bone_pose(arm_right)*sword_current_attachment
	skeleton.set_bone_pose(carrier_bone,carrier);skeleton.set_bone_pose(socket_bone,carrier)
	skeleton.force_update_all_bone_transforms()
func _support(side:int)->bool:
	if sword_equipped and melee!=null and melee.state.state==&"roll":return false
	return super._support(side)
func _update_direction_support(delta:float)->void:
	if sword_equipped and melee!=null and melee.state.state==&"roll":
		settling=false
		for side in 2:_source_support[side]=false;released[side]=true;support_aim[side]=Quaternion.IDENTITY
		return
	super._update_direction_support(delta)
func sword_world()->Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(arm_right)*sword_current_attachment*sword_mount
