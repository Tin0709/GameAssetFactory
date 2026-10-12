extends SceneTree
var checks: Array=[]
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var scene=load("res://scenes/dev/ExpressiveLocomotionTest.tscn").instantiate()
	root.add_child(scene);current_scene=scene;await scene.tick(3)
	var v=scene.actor.visual
	check(v.get("run_stride_scale")!=null,"Run exposes an independent longer-stride comparison")
	if v.get("run_stride_scale")==null:quit(1);return
	check(scene.actor.review_pace==2.25,"Latest pace is2.25x original; Idle unchanged")
	v.directional_enabled=false;v.move_requested=true;v.jump_state="GROUND"
	for run_weight in [0.0,1.0]:
		v.gait_run_weight=run_weight
		for phase in [0.0,.25,.5,.75]:
			v.gait_phase=phase
			for bone in [v.leg_left,v.leg_right,v.hips,v.chest]:
				v.run_stride_scale=1.0;var old: Transform3D=v._target_pose(bone)
				v.run_stride_scale=1.2;var revised: Transform3D=v._target_pose(bone)
				if run_weight==0 or bone in [v.hips,v.chest]:check(old.is_equal_approx(revised),"Longer Run leaves Walk and body pose targets unchanged")
				else:
					var rest: Basis=v.skeleton.get_bone_rest(bone).basis
					var pitch: float=(old.basis*rest.inverse()).get_euler().x
					var expected: Basis=Basis(Vector3.RIGHT,pitch*.2)*old.basis
					check(expected.is_equal_approx(revised.basis),"Run whole-leg sagittal articulation increases20percent")
					check(old.origin.is_equal_approx(revised.origin),"Longer stride does not widen leg tracks or translate the limb")
	v.gait_run_weight=1.0;v.run_stride_scale=1.2
	check(absf(v._stride_distance()-1.848)<.00001,"Distance cadence uses1.848m Run stride instead of merely speeding steps")
	v.gait_run_weight=0.0
	check(absf(v._stride_distance()-1.08)<.00001,"Walk stride stays1.08m")
	var out:="res://.validation/expressive_directional_v1";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/run_stride.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("EXPRESSIVE_RUN_STRIDE_CHECKS ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)
