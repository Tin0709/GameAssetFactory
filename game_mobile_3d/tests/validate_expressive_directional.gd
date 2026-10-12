extends SceneTree
var checks: Array=[]
var failures: Array=[]
var versions: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)

func observe(scene: Node, ticks: int, record: Dictionary) -> void:
	var v=scene.actor.visual
	var previous_feet: Array=v.last_sole.duplicate()
	var previous_ids: Array=v.contact_ids.duplicate()
	var previous_support: Array=v.foot_support.duplicate()
	var previous_q: Array=[]
	for bone in [v.leg_left,v.leg_right]:previous_q.append(v._leg_world_rotation(bone))
	var phase: float=v.gait_phase;var yaw: float=v.rotation.y
	var end_tick:=Engine.get_physics_frames()+ticks
	while Engine.get_physics_frames()<end_tick:
		await scene.tick(1)
		record.frames+=1
		if v.foot_support[0] or v.foot_support[1]:record.support_frames+=1
		for side in 2:
			var p: Vector3=v.last_sole[side]
			var world_q: Quaternion=v._leg_world_rotation([v.leg_left,v.leg_right][side])
			if rad_to_deg(world_q.angle_to(previous_q[side]))>record.leg_step_degrees:
				record.worst_leg={"side":side,"support":v.foot_support[side],"previous_support":previous_support[side],"phase":v.gait_phase,"jump":v.jump_state,"age":v.jump_age,"aim_degrees":rad_to_deg(v.support_aim[side].angle_to(Quaternion.IDENTITY))}
			record.leg_step_degrees=maxf(record.leg_step_degrees,rad_to_deg(world_q.angle_to(previous_q[side])))
			record.leg_rate_per_pace=maxf(record.get("leg_rate_per_pace",0.0),rad_to_deg(world_q.angle_to(previous_q[side]))/maxf(v.pose_delta*v.review_pace,.00001))
			if v.foot_support[side] and previous_support[side] and previous_ids[side]==v.contact_ids[side] and not v.settling:
				var distance:=p.distance_to(previous_feet[side])
				record.slip_m+=distance;record.peak_slip_m=maxf(record.peak_slip_m,distance)
				var q: Quaternion=v._leg_world_rotation([v.leg_left,v.leg_right][side])
				record.plant_rotation_degrees=maxf(record.plant_rotation_degrees,rad_to_deg(q.angle_to(previous_q[side])))
			previous_feet[side]=p;previous_ids[side]=v.contact_ids[side];previous_support[side]=v.foot_support[side]
			previous_q[side]=v._leg_world_rotation([v.leg_left,v.leg_right][side])
			record.penetration_m=maxf(record.penetration_m,-p.y)
		record.phase_error=maxf(record.phase_error,absf(wrapf(v.gait_phase-phase-v.gait_frequency*v.pose_delta,-.5,.5)))
		record.yaw_step_degrees=maxf(record.yaw_step_degrees,rad_to_deg(absf(wrapf(v.rotation.y-yaw,-PI,PI))))
		phase=v.gait_phase;yaw=v.rotation.y

func run() -> void:
	for enabled in [false,true]:
		var scene=load("res://scenes/dev/ExpressiveLocomotionTest.tscn").instantiate()
		root.add_child(scene);current_scene=scene
		var actor=scene.actor;var v=actor.visual
		actor.scripted_input=true
		if v.get("directional_enabled")!=null:v.directional_enabled=enabled
		var cases: Array=[]
		for sprint in [false,true]:
			for degrees in [45,90,180]:
				for lead in [.15,.65]:
					actor.requested_direction=Vector2.ZERO;actor.requested_run=false;scene.reset_actor();actor.position.x=-12;await scene.tick(40)
					actor.requested_direction=Vector2(0,1);actor.requested_run=sprint;await scene.tick(45)
					v.gait_phase=lead;v.foot_support[0]=false;v.foot_support[1]=false;v.pose_dirty=true;await scene.tick(3)
					var record:={"run":sprint,"degrees":degrees,"lead":lead,"slip_m":0.0,"peak_slip_m":0.0,"plant_rotation_degrees":0.0,"leg_step_degrees":0.0,"penetration_m":0.0,"phase_error":0.0,"yaw_step_degrees":0.0,"frames":0,"support_frames":0}
					var clamps: int=v.correction_clamps;var before: Vector3=actor.velocity
					var angle:=deg_to_rad(degrees)*(1 if lead<.5 else -1)
					actor.requested_direction=Vector2(sin(angle),cos(angle))
					await observe(scene,2,record)
					check((actor.velocity-before).length()>.05,"Input immediately changes velocity: %s %d lead%.2f"%["Run" if sprint else "Walk",degrees,lead])
					await observe(scene,34,record)
					record.clamps=v.correction_clamps-clamps
					record.final_position=actor.position;record.final_phase=v.gait_phase;cases.append(record)
					check(record.phase_error<.06,"Turn preserves shared stride phase")
					check(record.penetration_m<.008,"Turn maintains sole clearance")
					check(record.yaw_step_degrees<20,"Turn does not snap body heading")
					check(record.leg_rate_per_pace<900,"Support-to-swing rotation stays within the same elapsed-time and pace-normalized guard")
					check(float(record.support_frames)/record.frames>(.65 if sprint else .80),"Turn retains authored support rather than hiding slip in flight")
		actor.requested_direction=Vector2.ZERO;await scene.tick(55)
		check(not v.move_requested and not v.settling,"Directional stop returns to planted Idle")
		var jumps: Array=[]
		for sprint in [false,true]:
			for degrees in [45,90,180]:
				actor.requested_direction=Vector2(0,1);actor.requested_run=sprint;await scene.tick(35)
				actor.request_jump();check(await scene._wait_state("AIR",35),"Turning jump launches")
				await scene.tick(8)
				var velocity_before: Vector3=actor.velocity;var angle:=deg_to_rad(degrees)
				actor.requested_direction=Vector2(sin(angle),cos(angle))
				await scene.tick(2)
				check((actor.velocity-velocity_before).length()>.05,"Airborne turn input remains immediate")
				check(await scene._wait_state("LAND",90),"Turning jump lands by physics")
				var record:={"run":sprint,"degrees":degrees,"slip_m":0.0,"peak_slip_m":0.0,"plant_rotation_degrees":0.0,"leg_step_degrees":0.0,"penetration_m":0.0,"phase_error":0.0,"yaw_step_degrees":0.0,"frames":0,"support_frames":0}
				await observe(scene,50,record);jumps.append(record)
				check(actor.current_speed>(3.4 if sprint else 1.3) and not v.settling,"Turning jump rejoins responsive gait")
				check(record.leg_rate_per_pace<900,"Landing handoff stays within the same elapsed-time and pace-normalized rotation guard")
				check(record.penetration_m<.008,"Turning landing maintains sole clearance")
		var total:=0.0;var peak:=0.0;var clamps:=0
		for record in cases:total+=record.slip_m;peak=maxf(peak,record.peak_slip_m);clamps+=record.clamps
		versions.append({"directional":enabled,"pace":v.review_pace,"cases":cases,"jumps":jumps,"total_planted_slip_m":total,"peak_slip_m":peak,"clamps":clamps})
		scene.queue_free();await process_frame
	check(versions[1].total_planted_slip_m<versions[0].total_planted_slip_m*.70,"Refinement reduces matched turn planted sliding by at least30percent")
	for i in versions[0].cases.size():
		check(versions[0].cases[i].final_position.distance_to(versions[1].cases[i].final_position)<.00001,"Refined capsule follows exactly the original responsive turn path")
		check(absf(versions[0].cases[i].final_phase-versions[1].cases[i].final_phase)<.00001,"Refinement preserves the original gait progression")
	var out:="res://.validation/expressive_directional_v1";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/runtime_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"versions":versions},"\t"))
	print("EXPRESSIVE_DIRECTIONAL_CHECKS ",checks.size()," failures ",failures.size())
	quit(0 if failures.is_empty() else 1)
