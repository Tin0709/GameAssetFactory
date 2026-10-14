extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path:="res://scenes/dev/actions_stuff_research/source_run_sampler.gd"
	check(ResourceLoader.exists(path),"Exact source sampler with independent lifetime and leg scale is missing")
	if not ResourceLoader.exists(path):quit(1);return
	var actor=load("res://scenes/dev/ExpressiveLocomotionPlayer.tscn").instantiate()
	root.add_child(actor);actor.set_physics_process(false);actor.get_node("Visual").set_process(false)
	var rig: Skeleton3D=actor.visual.skeleton
	var sampler=load(path).new(rig)
	var stage:="res://scenes/dev/actions_stuff_research/tests/fixtures/"
	var max_p:=0.;var max_q:=0.;var max_s:=0.;var count:=0;var imported_p:=0.;var imported_q:=0.;var imported_s:=0.
	for kind in ["run","walk"]:
		var fixture=JSON.parse_string(FileAccess.get_file_as_string(stage+kind+"_fixtures.json"))
		var library=load("res://scenes/dev/actions_stuff_research/source_library.res")
		var walk=load("res://scenes/dev/actions_stuff_research/source_clip_sampler.gd").new(library.get_animation("Walk_ActionsStuff_Source_Test_v001"),rig)
		var imported_run=load("res://scenes/dev/actions_stuff_research/source_clip_sampler.gd").new(library.get_animation("Run_ActionsStuff_Source_Test_v001"),rig)
		for row in fixture:
			if kind=="run":sampler.set_clocks(fposmod(row.t*1.6,1.),row.t)
			for name in row.poses:
				var bone:=rig.find_bone(name);check(bone>=0,"Native bone "+name)
				var value: Array=row.poses[name]
				var p: Vector3=sampler.position(bone) if kind=="run" else walk.position(bone,row.t)
				var q: Quaternion=sampler.rotation(bone) if kind=="run" else walk.rotation(bone,row.t)
				var s: Vector3=sampler.scale(bone) if kind=="run" else walk.scale(bone,row.t)
				max_p=maxf(max_p,p.distance_to(Vector3(value[0][0],value[0][1],value[0][2])))
				max_q=maxf(max_q,1-absf(q.dot(Quaternion(value[1][0],value[1][1],value[1][2],value[1][3]))))
				max_s=maxf(max_s,s.distance_to(Vector3(value[2][0],value[2][1],value[2][2])))
				if kind=="run" and row.t<=6.:
					imported_p=maxf(imported_p,imported_run.position(bone,row.t).distance_to(Vector3(value[0][0],value[0][1],value[0][2])))
					imported_q=maxf(imported_q,1-absf(imported_run.rotation(bone,row.t).dot(Quaternion(value[1][0],value[1][1],value[1][2],value[1][3]))))
					imported_s=maxf(imported_s,imported_run.scale(bone,row.t).distance_to(Vector3(value[2][0],value[2][1],value[2][2])))
			count+=1
	check(max_p<.00002,"Exact evaluated source positions "+str(max_p))
	check(max_q<.000002,"Exact evaluated source rotations "+str(max_q))
	check(max_s<.000002,"Exact evaluated source scale "+str(max_s))
	# Dense sampled quaternion/PRS interpolation differs slightly from Blender
	# Euler FCurve evaluation between keys: bound to25um /10ppm, separately
	# from the stricter literal-source runtime evaluator checks above.
	check(imported_p<.000025 and imported_q<.000002 and imported_s<.00001,"Complete evaluated Run PRS import agrees within sampled-track precision")
	var waist:=rig.find_bone("Hips");var leg:=rig.find_bone("Leg.L")
	sampler.set_clocks(.4,6.);var before: Vector3=sampler.position(waist)
	sampler.set_clocks(.4,6.625);check(sampler.position(waist).distance_to(before)>.001,"Lifetime bob remains independent of repeated core phase")
	sampler.set_clocks(.7083,0.);check(absf(sampler.scale(leg).y-1.07)<.000002,"Run 7 percent leg scale pulse retained")
	var report:={"failures":failures,"poses":count,"max_p":max_p,"max_q":max_q,"max_s":max_s,"imported_run_position_error":imported_p,"imported_run_quaternion_error":imported_q,"imported_run_scale_error":imported_s}
	FileAccess.open("user://actions_stuff_source_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SOURCE_TEST ",JSON.stringify(report))
	actor.queue_free();quit(0 if failures.is_empty() else 1)
