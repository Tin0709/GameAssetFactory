extends SceneTree
## Independent Python source-channel/native-matrix fixtures catch wrong axes,
## discarded scale, normalized direction weights, and entity-relative head loss.
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func matrix(rows: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(rows[0][3],rows[1][3],rows[2][3]))
func run() -> void:
	var path := "res://scenes/dev/actions_stuff_research/source_direction_sampler.gd"
	check(ResourceLoader.exists(path), "Directional source sampler is missing")
	if not ResourceLoader.exists(path):
		quit(1)
		return
	var actor = load("res://scenes/dev/ExpressiveLocomotionPlayer.tscn").instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("Visual").set_process(false)
	var rig: Skeleton3D = actor.visual.skeleton
	var sampler = load(path).new(rig)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/dev/actions_stuff_research/tests/fixtures/direction_pose_fixtures.json"))
	var max_channel := 0.0
	var max_position := 0.0
	var max_basis := 0.0
	var max_height := 0.0
	var count := 0
	for row in fixture.samples:
		sampler.set_snapshot(row.snapshot)
		for bone in row.channels:
			for key in row.channels[bone]:
				var expected: Array = row.channels[bone][key]
				var actual: Vector3 = sampler.channels[bone][key]
				max_channel = maxf(max_channel,actual.distance_to(Vector3(expected[0],expected[1],expected[2])))
		for name in row.local:
			var index := rig.find_bone(name)
			check(index >= 0,"Native bone " + name)
			var expected := matrix(row.local[name])
			var actual := Transform3D(Basis(sampler.rotation(index))*Basis.from_scale(sampler.scale(index)),sampler.position(index))
			max_position = maxf(max_position,actual.origin.distance_to(expected.origin))
			for axis in 3:
				max_basis = maxf(max_basis,actual.basis[axis].distance_to(expected.basis[axis]))
		max_height = maxf(max_height,absf(sampler.height_offset(row.snapshot)-float(row.height)))
		var different_phase: Dictionary = row.snapshot.duplicate(true)
		different_phase.phase += .371
		check(absf(sampler.height_offset(different_phase)-sampler.height_offset(row.snapshot)) < .0000001,"Height must be independent of phase")
		count += 1
	check(max_channel < .00004,"Literal source channels " + str(max_channel))
	check(max_position < .000003,"Native local positions " + str(max_position))
	check(max_basis < .000003,"Native XYZ hierarchy/scale matrices " + str(max_basis))
	check(max_height < .0000001,"Approved height envelope " + str(max_height))
	# Keep the established forward Run profile as a second independent oracle.
	var old = load("res://scenes/dev/actions_stuff_research/source_run_sampler.gd").new(rig)
	var parity: float = 0.0
	for phase in [0.0,.2083,.4,.7083,.999999,1.0]:
		var snapshot := {"phase":phase,"life":6.625,"run_weight":1.0,"vars":{"v.esnrkj":1.0,"v.cknrcn":1.0,"v.mrmeib":0.0},"query":{}}
		sampler.set_snapshot(snapshot)
		old.set_clocks(phase,6.625)
		for i in rig.get_bone_count():
			parity = maxf(parity,sampler.position(i).distance_to(old.position(i)))
			parity = maxf(parity,1.0-absf(sampler.rotation(i).dot(old.rotation(i))))
			parity = maxf(parity,sampler.scale(i).distance_to(old.scale(i)))
	check(parity < .000003,"Established forward Run parity " + str(parity))
	var report := {"failures":failures,"samples":count,"max_channel":max_channel,"max_position":max_position,"max_basis":max_basis,"max_height":max_height,"run_parity":parity}
	print("DIRECTION_SAMPLER_TEST ",JSON.stringify(report))
	FileAccess.open("user://actions_stuff_direction_sampler_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	actor.queue_free()
	quit(0 if failures.is_empty() else 1)
