extends SceneTree
var checks: Array=[]
var failures: Array=[]
var cases: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func equip(actor: Node, kind: int) -> void:
	actor.set_review_weapon(true)
	var v=actor.visual;var behavior=v.weapon_behavior;v.weapon_behavior=null
	v.equip_weapon(kind);v.switch_weight=1;v.weapon_behavior=behavior;v.socket.attach_equipped(&"hand")
func run() -> void:
	var scene=load("res://scenes/dev/ExpressiveLocomotionTest.tscn").instantiate()
	root.add_child(scene);current_scene=scene;scene.actor.scripted_input=true;await scene.tick(5)
	var actor=scene.actor;var v=actor.visual
	for pace in [1.5,2.25]:
		actor.review_pace=pace
		for kind in 3:
			actor.requested_direction=Vector2.ZERO;actor.requested_run=false;scene.reset_actor();actor.position.x=-12
			actor.set_review_weapon(false);await scene.tick(50)
			actor.requested_direction=Vector2(0,1);actor.requested_run=true;await scene.tick(40)
			actor.review_drop(6)
			var previous: Array=[]
			for bone in v.r13_mask:previous.append(v.skeleton.get_bone_pose_rotation(bone))
			var previous_target: Array=previous.duplicate()
			var peak:=0.0;var worst: Dictionary={};var landed:=false;var waving:=false;var scale_error:=0.0;var support_while_air:=false
			var events: Array=[];var contact_faded:=false;var contact_seen:=false
			var end_tick:=Engine.get_physics_frames()+170
			while Engine.get_physics_frames()<end_tick:
				# State/physics-time events match at30/60 renderFPS.
				if events.size()==0 and actor.jump_state=="AIR" and v.falling_time>.28:
					equip(actor,kind);events.append("equip in fall")
				if events.size()==1 and actor.jump_state=="AIR" and actor.time_to_contact<.22:
					actor.set_review_weapon(false);events.append("release before contact")
				if events.size()==2 and actor.jump_state=="LAND" and actor.jump_age>.20:
					equip(actor,kind);events.append("equip during recovery")
				if events.size()==3 and actor.jump_state=="LAND" and actor.jump_age>.30:
					actor.set_review_weapon(false);events.append("interrupt recovery equip")
				if events.size()==4 and actor.jump_state=="LAND" and actor.jump_age>.42:
					equip(actor,kind);events.append("re-equip during release")
				if events.size()==5 and actor.jump_state=="LAND" and actor.jump_age>.52:
					actor.set_review_weapon(false);events.append("release interrupted re-equip")
				await scene.tick(1,"Weapon / falling compatibility")
				for index in v.r13_mask.size():
					var bone: int=v.r13_mask[index];var q: Quaternion=v.skeleton.get_bone_pose_rotation(bone)
					var angle:=rad_to_deg(previous[index].angle_to(q))
					var native_q: Quaternion=(v._from_rotvec(v.weapon_rotation_offsets[index])*v.weapon_base_q[index]).normalized()
					if v.skeleton.get_bone_name(bone) not in ["WeaponSocket","WeaponCarrier"] and angle>peak:
						peak=angle;worst={"bone":v.skeleton.get_bone_name(bone),"state":actor.jump_state,"age":actor.jump_age,"weight":v.review_weapon_weight,"events":events.duplicate(),"offset":v.weapon_rotation_offsets[index],"native_step":rad_to_deg(previous_target[index].angle_to(native_q)),"entry_age":v.layer_entry_age}
					previous[index]=q
					previous_target[index]=native_q
				for bone in [v.leg_left,v.leg_right]:scale_error=maxf(scale_error,(v.skeleton.get_bone_pose_scale(bone)-Vector3.ONE).length())
				landed=landed or actor.jump_state=="LAND"
				if actor.jump_state=="LAND" and not contact_seen:
					contact_seen=true;contact_faded=v.fall_wave_weight<.001
				waving=waving or (v.fall_wave_weight>.99 and v.review_weapon_weight<.01)
				support_while_air=support_while_air or (actor.jump_state=="AIR" and (v.foot_support[0] or v.foot_support[1]))
			check(peak<60,"Weapon%d fall/equip/release/recovery stays below strict60deg guard at%.2fx"%[kind,pace])
			check(landed and actor.jump_state=="GROUND" and actor.current_speed>3,"Weapon fall returns to responsive running by actual contact")
			check(waving and not support_while_air,"Unarmed fall gesture survives weapon release without false support")
			check(v.fall_wave_weight==0 and scale_error<.00001,"Gesture releases before landing; rigid legs preserved")
			check(events.size()==6 and contact_seen and contact_faded,"All six weapon events occur in matched physical phases; falling gesture faded at first contact")
			cases.append({"pace":pace,"weapon":kind,"maximum_upper_step_degrees":peak,"worst":worst,"scale_error":scale_error,"events":events,"contact_faded":contact_faded})
	actor.requested_direction=Vector2.ZERO;await scene.tick(60)
	v.move_requested=true;v.jump_state="GROUND";v.travel_bias=0;v.turn_lean=0;v.turn_twist=0;v.gait_run_weight=1
	var bone: int=v.hips;var before_x: Array=[];var after_x: Array=[]
	for sample in 64:
		v.gait_phase=sample/64.0;v.polish_enabled=false;var before: Transform3D=v._target_pose(bone)
		v.polish_enabled=true;var after: Transform3D=v._target_pose(bone)
		before_x.append(before.origin.x);after_x.append(after.origin.x)
		check(is_equal_approx(before.origin.y,after.origin.y) and is_equal_approx(before.origin.z,after.origin.z),"Quieter Run retains vertical and sagittal weight transfer")
	check(is_equal_approx((after_x.max()-after_x.min())/(before_x.max()-before_x.min()),.8),"Run lateral excursion is reduced20percent")
	var out:="res://.validation/expressive_polish_v2";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/layers.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"))
	print("EXPRESSIVE_POLISH_LAYER_CHECKS ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)
