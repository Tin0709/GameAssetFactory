extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func difference(a:Transform3D,b:Transform3D)->float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func _initialize()->void:call_deferred("run")
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.grass_field_blocks=30;root.add_child(lab);await physics_frame;await process_frame
	var a=lab.player;var p=lab.sabre_mode.render_presenter;var rig:Skeleton3D=a.skeleton;var head:=rig.find_bone("J_Head")
	lab.set_process(false);a.set_physics_process(false);lab.sabre_mode.set_physics_process(false);a.reset_actor();a._grounded=true;a._move_requested=true;a._run_requested=true;a.current_speed=7.;a._animate(.12);p.reset_history()
	var worst:=0.
	for key:String in ["Attack1","Run","Attack3","Run"]:
		if key=="Run":a.combo.cancel()
		else:a.combo._start_attack(0 if key=="Attack1" else 2)
		a._animate(.10);p.capture()
		for alpha:float in [.25,.5,.75]:
			p.prepare(alpha)
			for face:int in a.body_stability.face_roots:
				var previous:Transform3D=Transform3D(p.previous.world[head]).affine_inverse()*Transform3D(p.previous.world[face])
				var current:Transform3D=Transform3D(p.current.world[head]).affine_inverse()*Transform3D(p.current.world[face])
				var expected:Transform3D=previous.interpolate_with(current,alpha)
				var shown:Transform3D=Transform3D(p.display_world[head]).affine_inverse()*Transform3D(p.display_world[face])
				worst=maxf(worst,difference(shown,expected))
				check(difference(shown,expected)<.00001,"Fractional facial root follows displayed head through "+key+" alpha"+str(alpha))
	check(a.face.material_override==null,"Facial correction does not replace the original material")
	var report:={"checks":checks,"failures":failures,"maximum_head_relative_error":worst}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation/md2_sabre_movement"));FileAccess.open("res://.validation/md2_sabre_movement/face-presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_FACE_PRESENTATION ",JSON.stringify(report));lab.free();quit(0 if failures.is_empty() else 1)
