extends SceneTree
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
var max_clock := 0.0
var max_channel := 0.0
var max_native := 0.0
var max_active_native := 0.0
func matrix(rows: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(rows[0][3],rows[1][3],rows[2][3]))
func vector_channels(raw: Dictionary) -> Dictionary:
	var out := {}
	for bone in raw:
		out[bone] = {}
		for key in raw[bone]:
			var v: Array = raw[bone][key]
			out[bone][key] = Vector3(v[0],v[1],v[2])
	return out
func compare_channels(actual: Dictionary, expected: Dictionary) -> void:
	var want := vector_channels(expected)
	for bone in want:
		for key in want[bone]: max_channel = maxf(max_channel,Vector3(actual[bone][key]).distance_to(want[bone][key]))
func run() -> void:
	var controller_path := "res://scenes/dev/actions_stuff_research/source_idle_controller.gd"
	var sampler_path := "res://scenes/dev/actions_stuff_research/source_idle_sampler.gd"
	check(ResourceLoader.exists(controller_path),"Approved Idle controller is missing")
	check(ResourceLoader.exists(sampler_path),"Approved Idle composite sampler is missing")
	if not failures.is_empty():
		print("IDLE_SOURCE_TEST ",JSON.stringify({"failures":failures}))
		quit(1)
		return
	var actor = load("res://scenes/dev/ExpressiveLocomotionPlayer.tscn").instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("Visual").set_process(false)
	var rig: Skeleton3D = actor.visual.skeleton
	var sampler = load(sampler_path).new(rig)
	var ground_sampler = load("res://scenes/dev/actions_stuff_research/source_direction_sampler.gd").new(rig)
	ground_sampler.set_item_holding(0,0)
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_bytes("res://scenes/dev/actions_stuff_research/tests/fixtures/idle_fixtures.json.gz").decompress_dynamic(128*1024*1024,FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
	var samples := 0
	var poses := 0
	var rendered30 := 0
	var rendered60 := 0
	var seen := {}
	for case in fixtures.cases:
		var controller = load(controller_path).new(12.0)
		var index := 0
		for row in case.samples:
			var input_before: Dictionary = row.base.duplicate(true)
			var snapshot: Dictionary = controller.step(row.base,row.requested,row.eligible,1.0/240.0)
			check(row.base == input_before,"Ground snapshot must remain untouched")
			seen[snapshot.state] = true
			var a: Dictionary = snapshot.controllers.bjmscc
			var e: Dictionary = row.expected
			check(a.state == e.state and a.outgoing == e.outgoing,"Source state parity " + case.name + " " + str(index))
			for key in ["state_time","fade_elapsed","fade_duration"]: max_clock = maxf(max_clock,absf(float(a[key])-float(e[key])))
			for key in e.clocks: max_clock = maxf(max_clock,absf(float(a.clocks.get(key,0.0))-float(e.clocks[key])))
			check(snapshot.layers.size() == row.layers.size(),"Source positive approved layers " + case.name + " " + str(index))
			for i in mini(snapshot.layers.size(),row.layers.size()):
				check(snapshot.layers[i].alias == "tculwn","No unapproved gestures")
				for key in ["clock","controller_weight"]: max_clock = maxf(max_clock,absf(float(snapshot.layers[i][key])-float(row.layers[i][key])))
			if row.has("channels"):
				ground_sampler.set_snapshot(row.base)
				compare_channels(ground_sampler.channels,row.base_channels)
				var bc: Dictionary = ground_sampler.channels.duplicate(true)
				var before: Dictionary = bc.duplicate(true)
				sampler.set_composite(bc,row.base,snapshot)
				check(bc == before,"Composite does not mutate accepted channels")
				compare_channels(sampler.channels,row.channels)
				if row.has("local"):
					for name in row.local:
						var actual: Transform3D = sampler.poses[rig.find_bone(name)]
						var expected := matrix(row.local[name])
						max_active_native = maxf(max_active_native,actual.origin.distance_to(expected.origin))
						for axis in 3: max_active_native = maxf(max_active_native,actual.basis[axis].distance_to(expected.basis[axis]))
				# Independent baseline native retarget, inactive overlay never changes a bone.
				if snapshot.layers.is_empty():
					ground_sampler.set_snapshot(row.base)
					sampler.set_composite(ground_sampler.channels,row.base,snapshot)
					for j in rig.get_bone_count():
						max_native = maxf(max_native,sampler.position(j).distance_to(ground_sampler.position(j)))
						for axis in 3: max_native = maxf(max_native,sampler.poses[j].basis[axis].distance_to(ground_sampler.poses[j].basis[axis]))
				var frozen: Dictionary = snapshot.duplicate(true)
				var future: Dictionary = sampler.future_snapshot(snapshot,.01)
				check(snapshot == frozen,"Future probe does not mutate live snapshot")
				check(future.vars == snapshot.vars and future.life == snapshot.life,"Future freezes source vars and root historical life")
				check(future.timeline_events.is_empty(),"Future probe fires no events")
				for layer in future.layers:
					check(layer.clock <= 4.2083,"Future finite clip is clamped")
				poses += 1
				if index%8==0: rendered30 += 1
				if index%4==0: rendered60 += 1
			samples += 1
			index += 1
		var age: float = controller.life
		controller.reset()
		check(controller.life == age and controller.state == "uwpoku","Reset clears controller but preserves age")
	for row in fixtures.clips: compare_channels(sampler.sample_clip("tculwn",float(row.clock),{}),row.channels)
	# Input/airborne intent gates must prevent activation even without displacement.
	for mode in ["blocked_input","airborne"]:
		var controller = load(controller_path).new(12.0)
		var base: Dictionary = fixtures.cases[0].samples[0].base.duplicate(true)
		for i in 1200:
			base.life = 12.0+float(i+1)/240.0
			var result: Dictionary = controller.step(base,mode=="blocked_input",mode!="airborne",1.0/240.0)
			check(result.layers.is_empty(),"No gesture while requested or ineligible")
	check(seen.has("tculwn") and seen.has("bhsawv") and seen.has("wkbbnc"),"Gesture, outgoing fade and rearm covered")
	# Outgoing derivative probes advance the source fade without firing rearm.
	var fade := {"life":19.0,"vars":{"v.eqhdel":5.0},"layers":[{"alias":"tculwn","state":"tculwn","clock":4.2,"controller_weight":1.0,"state_weight":1.0}],"controllers":{"bjmscc":{"state":"bhsawv","state_time":0.0,"clocks":{},"outgoing":"tculwn","fade_elapsed":0.0,"fade_duration":.2}},"timeline_events":[{}]}
	var halfway: Dictionary = sampler.future_snapshot(fade,.1)
	check(absf(float(halfway.layers[0].controller_weight)-.5)<1e-10 and halfway.layers[0].clock==4.2083,"Future derivative has source .2s fade and finite clip clamp")
	check(sampler.future_snapshot(fade,.21).layers.is_empty(),"Future derivative expires outgoing layer without rearm")
	check(fade.controllers.bjmscc.fade_elapsed==0.0 and fade.layers[0].clock==4.2,"Future fade probe preserves live controller")
	check(max_active_native < .000004,"Independent full graph active native retarget " + str(max_active_native))
	check(sampler.data.clips.keys() == ["tculwn"],"Only approved compiled clip ships")
	check(max_clock < 1e-8,"Source state clocks/fades/weights " + str(max_clock))
	check(max_channel < .00008,"Full source graph normal-body channel parity " + str(max_channel))
	check(max_native < .000004,"Inactive overlay native baseline parity " + str(max_native))
	var report := {"failures":failures,"samples":samples,"poses":poses,"rendered30":rendered30,"rendered60":rendered60,"clip_samples":fixtures.clips.size(),"states":seen.keys(),"max_clock":max_clock,"max_channel":max_channel,"max_native":max_native,"max_active_native":max_active_native}
	print("IDLE_SOURCE_TEST ",JSON.stringify(report))
	FileAccess.open("/Users/tin/Documents/ChatGPT/New project/experiments/actions_stuff_idle_gameplay_v001/source_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	actor.queue_free()
	quit(0 if failures.is_empty() else 1)
