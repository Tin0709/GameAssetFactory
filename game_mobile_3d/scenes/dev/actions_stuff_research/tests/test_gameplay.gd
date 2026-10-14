extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path:="res://scenes/dev/ActionsStuffWalkRunTest.tscn"
	check(ResourceLoader.exists(path),"Requested playable Actions & Stuff scene is missing")
	if not ResourceLoader.exists(path):quit(1);return
	var scene=load(path).instantiate();root.add_child(scene)
	await physics_frame;await process_frame
	var actor=scene.player;var v=actor.visual
	actor.scripted_input=true
	check(v.active_walk_action=="Walk_ActionsStuff_Source_Test_v001","Exact source Walk selected")
	check(v.active_run_action=="Run_ActionsStuff_Source_Test_v001","Exact source Run selected")
	var dt:=1./30.;var args:=OS.get_cmdline_user_args()
	if args.has("60"):dt=1./60.
	actor.set_physics_process(false);v.set_process(false)
	var max_step:=0.;var minimum:=INF;var max_scale:=1.;var max_contact_speed:=0.;var contacts:=0
	var last_q: Array[Quaternion]=[];var previous_points: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO];var previous_ids: Array[int]=[-1,-1]
	for i in int(16./dt):
		var t:=i*dt
		actor.requested_direction=Vector2(0,1) if t<12. else Vector2.ZERO
		actor.requested_run=t>3. and t<9.
		var desired:=Vector2(0,actor.run_speed if actor.requested_run else actor.walk_speed) if t<12. else Vector2.ZERO
		var planar:=Vector2(actor.velocity.x,actor.velocity.z).move_toward(desired,(actor.acceleration if t<12. else actor.deceleration)*dt)
		actor.velocity=Vector3(planar.x,0,planar.y);actor.position+=actor.velocity*dt
		v.drive_locomotion(actor.velocity,t<12.,dt);v._evaluate(dt)
		check(is_finite(actor.position.length()),"Finite character movement")
		if i>int(1./dt):
			for side in 2:
				var bone: int=[v.leg_left,v.leg_right][side]
				var q: Quaternion=v.skeleton.get_bone_pose_rotation(bone)
				if last_q.size()==2:max_step=maxf(max_step,rad_to_deg(last_q[side].angle_to(q)))
				minimum=minf(minimum,v._sole_world(bone).y)
				max_scale=maxf(max_scale,v.skeleton.get_bone_pose_scale(bone).y)
				var point: Vector3=v.contact_point(side)
				if t>5. and t<8.5 and v.foot_support[side] and previous_ids[side]==v.contact_ids[side] and v.rolling_used[side]:
					max_contact_speed=maxf(max_contact_speed,point.distance_to(previous_points[side])/dt);contacts+=1
				previous_points[side]=point;previous_ids[side]=v.contact_ids[side]
		last_q=[v.skeleton.get_bone_pose_rotation(v.leg_left),v.skeleton.get_bone_pose_rotation(v.leg_right)]
	check(minimum>-.003,"Feet stay above ground "+str(minimum))
	check(max_step<65.,"No frozen-leg reset or extreme discontinuity "+str(max_step))
	check(max_scale>1.065,"Source leg stretch appears in gameplay")
	check(contacts>2 and max_contact_speed<.04,"Run support corner remains planted "+str(max_contact_speed))
	check(not v.move_requested and not v.settling,"Release movement settles to Idle")
	check(absf(v.skeleton.get_bone_pose_scale(v.leg_left).y-1.)<.0001,"Stop returns leg scale smoothly to one")
	var life: float=v.entity_lifetime;scene.reset_player()
	check(v.entity_lifetime==life,"Position reset does not restart source entity lifetime")
	check(actor.position.length()<.001,"R resets position")
	var report={"fps":1./dt,"failures":failures,"minimum_foot_y":minimum,"max_leg_step_degrees":max_step,"max_scale_y":max_scale,"run_contact_speed":max_contact_speed,"contact_samples":contacts,"maximum_correction":v.maximum_correction,"correction_clamps":v.correction_clamps}
	var output:="/Users/tin/Documents/ChatGPT/New project/experiments/actions_stuff_walk_run_scene_v001/gameplay"+str(int(1./dt))+".json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GAMEPLAY_TEST ",JSON.stringify(report));scene.queue_free();quit(0 if failures.is_empty() else 1)
