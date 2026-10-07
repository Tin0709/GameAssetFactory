extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	var scene = load("res://scenes/dev/LocomotionTurningLab.tscn")
	check(scene != null, "Isolated lab scene exists")
	if scene == null: quit(1); return
	var a = scene.instantiate(); root.add_child(a); a.set_physics_process(false)
	var b = scene.instantiate(); root.add_child(b); b.set_physics_process(false)
	a.actor.set_physics_process(false); b.actor.set_physics_process(false)
	a.actor.turning_enabled = false; b.actor.turning_enabled = true
	var p = b.actor
	# Independent Blender world-matrix fixture catches sampling/application/import errors.
	var source: Dictionary
	var source_path := ProjectSettings.globalize_path("res://").path_join("../blender/characters/player/cuboid/export/locomotion_r4g/source_samples.json")
	source=JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var pose_position_error := 0.0
	var pose_rotation_error := 0.0
	var conversion := Transform3D(Basis(Vector3(1,0,0),Vector3(0,0,-1),Vector3(0,1,0)),Vector3.ZERO)
	for name in source:
		p.sprint_weight=1.0 if name.begins_with("Sprint") else 0.0
		p.turn_amount=-1.0 if name.ends_with("Left") else (1.0 if name.ends_with("Right") else 0.0)
		for rec in source[name].samples:
			p.phase=float(rec.time)/float(source[name].duration)
			p.evaluate_pose()
			for bone in rec.bones:
				var rows: Array = rec.bones[bone]
				var expected := conversion*Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(rows[0][3],rows[1][3],rows[2][3]))
				var actual: Transform3D = p.skeleton.get_bone_global_pose(p.skeleton.find_bone(bone))
				pose_position_error=maxf(pose_position_error,actual.origin.distance_to(expected.origin))
				pose_rotation_error=maxf(pose_rotation_error,actual.basis.get_rotation_quaternion().angle_to(expected.basis.get_rotation_quaternion()))
	check(pose_position_error<0.0001 and pose_rotation_error<0.002,"Native runtime matches independent Blender world poses")
	p.phase=0; p.sprint_weight=0; p.turn_amount=0
	for name in ["Walk","WalkTurnLeft","WalkTurnRight","Sprint","SprintTurnLeft","SprintTurnRight"]:
		check(p.animation_player.has_animation(name), "Imported clip " + name)
		var clip: Animation = p.animation_player.get_animation(name)
		check(absf(clip.length - (16.0/24 if name.begins_with("Walk") else 13.0/24)) < 0.00001, "Authored duration " + name)
		for t in clip.get_track_count(): check(clip.track_get_type(t) != Animation.TYPE_SCALE_3D, "No scale track")
	var phase_error := 0.0
	var trajectory_error := 0.0
	var yaw_error := 0.0
	var root_id: int = p.skeleton.find_bone("Root")
	var root_rest: Transform3D = p.skeleton.get_bone_rest(root_id)
	for i in 2400:
		var dt := 1.0/120 if i%3 else 1.0/75
		var heading := sin(float(i)*0.007)*2.6 + float(i)*0.013
		var dir := Vector3(sin(heading),0,cos(heading))
		var sprint := i%600 >= 280
		var before: float = p.phase
		a.actor.step(dt,dir,sprint); p.step(dt,dir,sprint)
		var expected := fposmod(before + dt*lerpf(1.0/(16.0/24),1.0/(13.0/24),p.sprint_weight),1.0)
		phase_error = maxf(phase_error,absf(wrapf(p.phase-expected,-0.5,0.5)))
		trajectory_error = maxf(trajectory_error,a.actor.position.distance_to(p.position))
		yaw_error = maxf(yaw_error,absf(a.actor.visual.rotation.y-p.visual.rotation.y))
		check(p.skeleton.get_bone_pose_position(root_id).distance_to(root_rest.origin)<0.00001,"Root remains static")
	check(phase_error<0.00001,"One normalized clock survives changing direction and Shift")
	check(trajectory_error<0.000001 and yaw_error<0.000001,"A/B has identical actual path and facing")
	# A local left turn is positive Y yaw at every world heading, including +/-PI.
	var circle_signs := {}
	for sign_value in [-1,1]:
		for gait in [false,true]:
			p.phase=0.37; p.visual.rotation.y=2.9; p.turn_amount=0
			for i in 900:
				var angle: float = 2.9+sign_value*float(i)*0.012
				p.step(1.0/120,Vector3(sin(angle),0,cos(angle)),gait)
				if i>120: check(signf(p.turn_amount)==-sign_value,"Circle keeps character-relative sign")
			circle_signs["%d_%s"%[sign_value,str(gait)]] = p.turn_amount
			var previous: float = p.phase
			var heading: float = p.visual.rotation.y
			for i in 120: p.step(1.0/120,Vector3(sin(heading),0,cos(heading)),gait)
			check(absf(p.turn_amount)<0.001,"Straight recovery returns to neutral")
	# Rapid opposite direction crosses the neutral blend without discontinuous reset.
	p.visual.rotation.y=0; p.turn_amount=-0.8
	for i in 36: p.step(1.0/120,Vector3(-1,0,0),true)
	check(p.turn_amount>0.05,"Opposite turn responds within 0.3 seconds")
	var frozen: float = p.phase
	for i in 20: p.step(1.0/60,Vector3.ZERO,false)
	check(p.phase==frozen,"Stationary freezes existing gait without adding a stop action")
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"phase_error":phase_error,"A_B_position_error_m":trajectory_error,"A_B_yaw_error_rad":yaw_error,"circle_signs":circle_signs,"source_position_error_m":pose_position_error,"source_rotation_error_rad":pose_rotation_error}
	DirAccess.make_dir_recursive_absolute("res://.validation/locomotion_r4g")
	FileAccess.open("res://.validation/locomotion_r4g/runtime_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report)); a.queue_free(); b.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
