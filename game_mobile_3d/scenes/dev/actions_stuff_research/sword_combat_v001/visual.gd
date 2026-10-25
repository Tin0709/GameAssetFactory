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
func _ready()->void:
	super._ready()
	sword_profile=JSON.parse_string(FileAccess.get_file_as_string("res://scenes/dev/actions_stuff_research/sword_combat_v001/profile.json"))
	sword_attachment=_rows(sword_profile.carrier_in_right_arm);sword_mount=_rows(sword_profile.weapon_mount)
	sword_base_local=Vector3(sword_profile.sword_base_local[0],sword_profile.sword_base_local[1],sword_profile.sword_base_local[2])
	sword_tip_local=Vector3(sword_profile.sword_tip_local[0],sword_profile.sword_tip_local[1],sword_profile.sword_tip_local[2])
	for key in SWORD_LIBRARY.get_animation_list():sword_clips[key]=PoseSampler.new(SWORD_LIBRARY.get_animation(key),skeleton)
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
	poses[carrier_bone]=Transform3D(poses[arm_right])*sword_attachment
	return poses
func _advance_facing(target_yaw:float,delta:float)->void:
	if sword_equipped and melee!=null and melee.state.state in [&"attack",&"guard",&"parry",&"roll"]:
		rotation.y+=clampf(wrapf(melee.facing-rotation.y,-PI,PI),-16.*delta,16.*delta);return
	super._advance_facing(target_yaw,delta)
func drive_jump_motion(world_velocity:Vector3,requested:bool,physics:Dictionary,delta:float)->void:
	if not sword_equipped:super.drive_jump_motion(world_velocity,requested,physics,delta);return
	rifle_aim_requested=false;rifle_aim_weight=0.;combat_turn_requested=false;auto_aim_target=null
	if melee!=null and melee.state.state in [&"attack",&"guard",&"parry",&"roll"]:
		rotation.y+=clampf(wrapf(melee.facing-rotation.y,-PI,PI),-16.*delta,16.*delta)
		stationary_turn.reset(rotation.y)
	var moving:=requested
	# Physics travel during a lunge/roll is not a walking gait request.
	if melee!=null and melee.state.state==&"roll":moving=false;settling=false
	super.drive_jump_motion(world_velocity,moving,physics,delta)
	sword_model.global_transform=sword_world()
func _constrain_rifle_contacts()->void:
	if not sword_equipped:super._constrain_rifle_contacts();return
	if sword_clips.is_empty():return
	var carrier:=skeleton.get_bone_pose(arm_right)*sword_attachment
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
	return skeleton.global_transform*skeleton.get_bone_global_pose(arm_right)*sword_attachment*sword_mount
