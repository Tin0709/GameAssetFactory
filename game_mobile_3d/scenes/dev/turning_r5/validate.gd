extends SceneTree
var failures:=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok: failures.append(message)
func run() -> void:
	var lab=load("res://scenes/dev/LocomotionTurningLab.tscn").instantiate();root.add_child(lab);lab.set_physics_process(false)
	var p=lab.actor
	# Co-located actors see the same physics tick and floor state. Disable their
	# mutual collision layer in this test only; the ground mask stays unchanged.
	var actors:=[p]
	p.collision_layer=0
	for mode in [1,2]:
		var copy=p.duplicate();copy.collision_layer=0;lab.add_child(copy);actors.append(copy)
	var phase_error:=0.0
	var max_position_error:=0.0
	var max_yaw_error:=0.0
	var position_error_vector:=Vector3.ZERO
	var root_id:int=p.skeleton.find_bone("Root")
	var root_rest:Transform3D=p.skeleton.get_bone_rest(root_id)
	for mode in 3: actors[mode].set_review_mode(mode)
	for i in 1200:
		await physics_frame
		for mode in 3:
			p=actors[mode]
			var angle:float=PI+0.01*i+sin(i*0.02)
			var before:float=p.phase
			p.step(1.0/60,Vector3(sin(angle),0,cos(angle)),i%360>=180)
			var expected:=fposmod(before+(1.0/60)*lerpf(1.0/(16.0/24),1.0/(13.0/24),p.sprint_weight),1.0)
			phase_error=maxf(phase_error,absf(wrapf(p.phase-expected,-0.5,0.5)))
			check(p.skeleton.get_bone_pose_position(root_id).distance_to(root_rest.origin)<0.00001,"Root fixed")
			for bone in p.skeleton.get_bone_count(): check(p.skeleton.get_bone_pose_scale(bone).distance_to(Vector3.ONE)<0.00001,"No pose scale")
			if mode>0:
				if p.position.distance_to(actors[0].position)>max_position_error: position_error_vector=p.position-actors[0].position
				max_position_error=maxf(max_position_error,p.position.distance_to(actors[0].position))
				max_yaw_error=maxf(max_yaw_error,absf(wrapf(p.visual.rotation.y-actors[0].visual.rotation.y,-PI,PI)))
				check(absf(wrapf(p.phase-actors[0].phase,-0.5,0.5))<0.00001,"A/B/C phase identical")
	check(phase_error<0.00001,"Phase continuous during gait transitions")
	check(max_position_error<0.00001 and max_yaw_error<0.00001,"A/B/C movement and facing identical")
	for direction in [-1,1]:
		p.visual.rotation.y=2.9;p.turn_amount=0;p.candidate_turn_amount=0;p.set_review_mode(2)
		for i in 900:
			await physics_frame
			var angle:float=2.9+direction*i*0.025
			p.step(1.0/60,Vector3(sin(angle),0,cos(angle)),true)
			if i>90: check(signf(p.final_turn_value)==-direction,"Character-relative sign through full circles")
	var old_phase:float=p.phase;var old_position:Vector3=p.position;var old_yaw:float=p.visual.rotation.y
	for mode in [0,1,2,0,2,1,2]:
		p.set_review_mode(mode)
		check(p.phase==old_phase and p.position==old_position and p.visual.rotation.y==old_yaw,"Live mode switch preserves path/facing/phase")
	p.visual.rotation.y=0;p.candidate_turn_amount=0
	for i in 180:
		await physics_frame
		p.step(1.0/60,Vector3(sin(i/600.0),0,cos(i/600.0)),false)
	check(absf(p.final_turn_value)<0.04,"Tiny 0.1rad/s steering stays quiet")
	for name in p.clips:
		var clip:Animation=p.clips[name].animation
		for track in clip.get_track_count():check(clip.track_get_type(track)!=Animation.TYPE_SCALE_3D,"No animation scale tracks")
	var result:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"phase_error":phase_error,"A_B_C_max_position_error_m":max_position_error,"position_error_vector":str(position_error_vector),"A_B_C_max_yaw_error_rad":max_yaw_error,"tiny_steering_final":p.final_turn_value}
	FileAccess.open("res://.validation/locomotion_r5/runtime_validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));lab.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
