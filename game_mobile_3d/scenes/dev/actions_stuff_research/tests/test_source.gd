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
	var stage:="/Users/tin/Documents/ChatGPT/New project/experiments/actions_stuff_walk_run_scene_v001/"
	var max_p:=0.;var max_q:=0.;var max_s:=0.;var count:=0
	for kind in ["run","walk"]:
		var fixture=JSON.parse_string(FileAccess.get_file_as_string(stage+kind+"_fixtures.json"))
		var library=load("res://scenes/dev/actions_stuff_research/source_library.res")
		var walk=load("res://scenes/dev/actions_stuff_research/source_clip_sampler.gd").new(library.get_animation("Walk_ActionsStuff_Source_Test_v001"),rig)
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
			count+=1
	check(max_p<.00002,"Exact evaluated source positions "+str(max_p))
	check(max_q<.000002,"Exact evaluated source rotations "+str(max_q))
	check(max_s<.000002,"Exact evaluated source scale "+str(max_s))
	var head:=rig.find_bone("Head");var leg:=rig.find_bone("Leg.L")
	sampler.set_clocks(.4,6.);var before: Vector3=sampler.position(head)
	sampler.set_clocks(.4,6.625);check(sampler.position(head).distance_to(before)>.001,"Lifetime bob remains independent of repeated core phase")
	sampler.set_clocks(.5,0.);check(absf(sampler.scale(leg).y-1.07)<.000002,"Run 7 percent leg scale pulse retained")
	print("SOURCE_TEST ",JSON.stringify({"failures":failures,"poses":count,"max_p":max_p,"max_q":max_q,"max_s":max_s}))
	actor.queue_free();quit(0 if failures.is_empty() else 1)
