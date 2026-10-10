extends SceneTree
var failures: Array[String]=[]
var results: Array=[]
func _initialize() -> void:call_deferred("run")
func tick() -> void:
	await physics_frame;await process_frame
	# process_frame is emitted before Node._process; measure the finished pose.
	await create_timer(0.0).timeout
func check(ok: bool, text: String) -> void:
	if not ok:failures.append(text);push_error(text)
func run() -> void:
	var level:Node=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(level);current_scene=level
	var p=level.player
	for i in 8:await tick()
	p.get_node("WeaponBehavior").enabled=false
	for armed in [false,true]:
		p.visual.set_weapon_equipped(armed)
		if armed:p.equip_test_weapon(1)
		for kind in ["walk","run"]:
			level.reset_player();Input.action_press("move_right")
			if kind=="run":Input.action_press("sprint")
			for i in 12:await tick()
			p.request_jump()
			var lo:=INF;var hi:=-INF;var min_floor:=INF;var maximum_pose_step:=0.0
			var previous:Quaternion=p.visual.skeleton.get_bone_pose_rotation(p.visual.leg_right)
			var maximum_source_error:=0.0
			var history:Array=[]
			for i in 60:
				await tick()
				var s:Skeleton3D=p.visual.skeleton
				var l:Vector3=s.get_bone_global_pose(p.visual.leg_left)*Vector3(0,.675,0)
				var r:Vector3=s.get_bone_global_pose(p.visual.leg_right)*Vector3(0,.675,0)
				var pose:Quaternion=s.get_bone_pose_rotation(p.visual.leg_right)
				if p.visual.jump_active and p.visual.jump_blend>.999:
					for bone in [p.visual.leg_left,p.visual.leg_right]:
						maximum_source_error=maxf(maximum_source_error,s.get_bone_pose_rotation(bone).angle_to(p.visual.jump_pose.rotation(bone,p.visual.jump_time)))
				maximum_pose_step=maxf(maximum_pose_step,previous.angle_to(pose));previous=pose
				# Include the entire airborne interval: the authored walk crosses
				# its feet near takeoff/contact, outside the old V002 middle window.
				if p.jump_active and not p.is_on_floor():
					lo=minf(lo,r.z-l.z);hi=maxf(hi,r.z-l.z)
				if p.is_on_floor():
					for bone in [p.visual.leg_left,p.visual.leg_right]:
						for x in [-.1125,.1125]:
							for z in [-.1125,.1125]:
								var corner:Vector3=s.global_transform*s.get_bone_global_pose(bone)*Vector3(x,.675,z)
								min_floor=minf(min_floor,corner.y-p.global_position.y)
				history.append({"t":p.jump_time,"floor":p.is_on_floor(),"feet_delta_z":r.z-l.z})
			var tag:String=kind+(" armed" if armed else " unarmed")
			check(lo<-.04 and hi>.04,tag+": legs exchange stride during flight")
			check(min_floor>=-.015,tag+": supported sole penetration below 1.5cm")
			check(maximum_source_error<.001,tag+": full-weight legs follow the authored V003 clip")
			results.append({"case":tag,"air_stride_min":lo,"air_stride_max":hi,"ground_sole_min":min_floor,"maximum_pose_step_deg":rad_to_deg(maximum_pose_step),"history":history})
			Input.action_release("move_right");Input.action_release("sprint")
	FileAccess.open("res://.validation/jump_loop_v003/moving_footwork.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":results,"failures":failures},"\t"))
	print("MOVING_JUMP_FOOTWORK failures=",failures)
	level.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
