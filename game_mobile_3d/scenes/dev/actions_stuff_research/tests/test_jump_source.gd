extends SceneTree
## Frozen Python full-runtime oracle. Run 30/60 rendered frames at 60-Hz source
## substeps, compare every variable, local clock, fade, layer and PRS channel.
const FIXTURES := "/Users/tin/Documents/ChatGPT/New project/experiments/actions_stuff_jump_gameplay_v001/jump_fixtures.json"
var failures: Array[String] = []
var max_variable := 0.0
var max_channel := 0.0
var max_clock := 0.0
var max_position := 0.0
var max_basis := 0.0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func matrix(rows: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(rows[0][3],rows[1][3],rows[2][3]))
func compare_channels(actual: Dictionary, expected: Dictionary) -> void:
	for bone in expected:
		for key in expected[bone]:
			var v: Array = expected[bone][key]
			max_channel = maxf(max_channel,Vector3(actual[bone][key]).distance_to(Vector3(v[0],v[1],v[2])))
func run() -> void:
	var runtime_path := "res://scenes/dev/actions_stuff_research/source_jump_runtime.gd"
	var sampler_path := "res://scenes/dev/actions_stuff_research/source_jump_sampler.gd"
	check(ResourceLoader.exists(runtime_path),"Jump runtime missing")
	check(ResourceLoader.exists(sampler_path),"Jump sampler missing")
	if not failures.is_empty():
		quit(1)
		return
	var actor = load("res://scenes/dev/ExpressiveLocomotionPlayer.tscn").instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("Visual").set_process(false)
	var rig: Skeleton3D = actor.visual.skeleton
	var sampler = load(sampler_path).new(rig)
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES))
	var samples := 0
	for case in fixtures.cases:
		var runtime = load(runtime_path).new(float(case.initial_life))
		runtime.seed_context(false)
		for row in case.samples:
			var snapshot: Dictionary
			for query in row.queries: snapshot = runtime.step(query,1.0/60.0)
			check(not snapshot.is_empty(),"Runtime sample " + case.name)
			if snapshot.is_empty():
				quit(1)
				return
			for key in row.expected.vars:
				max_variable = maxf(max_variable,absf(float(snapshot.vars.get(key,0.0))-float(row.expected.vars[key])))
			for alias in row.expected.controllers:
				var a: Dictionary = snapshot.controllers[alias]
				var e: Dictionary = row.expected.controllers[alias]
				check(a.state == e.state and a.outgoing == e.outgoing,"Controller states " + case.name + " " + alias + " frame " + str(samples))
				for key in ["state_time","fade_elapsed","fade_duration"]: max_clock = maxf(max_clock,absf(float(a[key])-float(e[key])))
				check(a.clocks.keys() == e.clocks.keys(),"Clock aliases " + alias)
				for key in e.clocks: max_clock = maxf(max_clock,absf(float(a.clocks.get(key,0.0))-float(e.clocks[key])))
			check(snapshot.layers.size() == row.expected.layers.size(),"Layer count")
			for i in mini(snapshot.layers.size(),row.expected.layers.size()):
				var a: Dictionary = snapshot.layers[i]
				var e: Dictionary = row.expected.layers[i]
				check(a.alias == e.alias and a.controller == e.controller and a.state == e.state,"Ordered layers")
				for key in ["clock","controller_weight"]: max_clock = maxf(max_clock,absf(float(a[key])-float(e[key])))
			check(snapshot.timeline_events.size() == row.expected.timeline_events.size(),"Timeline events")
			sampler.set_snapshot(snapshot)
			compare_channels(sampler.channels,row.expected.channels)
			if row.has("local"):
				for name in row.local:
					var index := rig.find_bone(name)
					var expected := matrix(row.local[name])
					var actual: Transform3D = sampler.poses[index]
					max_position = maxf(max_position,actual.origin.distance_to(expected.origin))
					for axis in 3: max_basis = maxf(max_basis,actual.basis[axis].distance_to(expected.basis[axis]))
			samples += 1
	for row in fixtures.clips:
		compare_channels(sampler.sample_clip(row.alias,float(row.clock),row.snapshot),row.channels)
	check(max_variable < .00000001,"All source variable parity " + str(max_variable))
	check(max_clock < .00000001,"Source clocks/fades/weights " + str(max_clock))
	check(max_channel < .00008,"Full source PRS including Catmull " + str(max_channel))
	check(max_position < .000004,"JumpRetarget local translations " + str(max_position))
	check(max_basis < .000004,"JumpRetarget inherited root/leg scale and head basis " + str(max_basis))
	var report := {"failures":failures,"samples":samples,"clip_samples":fixtures.clips.size(),"max_variable":max_variable,"max_clock":max_clock,"max_channel":max_channel,"max_position":max_position,"max_basis":max_basis}
	print("JUMP_SOURCE_TEST ",JSON.stringify(report))
	FileAccess.open("/Users/tin/Documents/ChatGPT/New project/experiments/actions_stuff_jump_gameplay_v001/source_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	actor.queue_free()
	quit(0 if failures.is_empty() else 1)
