extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab=load("res://scenes/dev/LocomotionTurningLab.tscn").instantiate();root.add_child(lab);lab.set_physics_process(false)
	var p=lab.actor
	var results:={}
	var conversion:=Transform3D(Basis(Vector3(1,0,0),Vector3(0,0,-1),Vector3(0,1,0)),Vector3.ZERO)
	var passed:=true
	for mode in [1,2]:
		p.set_review_mode(mode)
		var source_path:=ProjectSettings.globalize_path("res://").path_join("../blender/characters/player/cuboid/export/%s/source_samples.json"%("locomotion_r4g" if mode==1 else "locomotion_r5"))
		var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_path))
		var position_error:=0.0;var rotation_error:=0.0;var samples:=0
		for name in source:
			p.sprint_weight=1.0 if name.begins_with("Sprint") else 0.0
			p.turn_amount=-1.0 if name.ends_with("Left") else (1.0 if name.ends_with("Right") else 0.0)
			p.candidate_turn_amount=p.turn_amount
			for rec in source[name].samples:
				p.phase=float(rec.time)/float(source[name].duration);p.evaluate_pose()
				for bone in rec.bones:
					var rows:Array=rec.bones[bone]
					var expected:=conversion*Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(rows[0][3],rows[1][3],rows[2][3]))
					var actual:Transform3D=p.skeleton.get_bone_global_pose(p.skeleton.find_bone(bone))
					position_error=maxf(position_error,actual.origin.distance_to(expected.origin))
					rotation_error=maxf(rotation_error,actual.basis.get_rotation_quaternion().angle_to(expected.basis.get_rotation_quaternion()))
					samples+=1
		results[str(mode)]={"bone_samples":samples,"max_position_error_m":position_error,"max_rotation_error_rad":rotation_error}
		passed=passed and position_error<0.0001 and rotation_error<0.002
	results.passed=passed
	FileAccess.open("res://.validation/locomotion_r5/import_validation.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print(JSON.stringify(results));lab.queue_free();await process_frame;quit(0 if passed else 1)
