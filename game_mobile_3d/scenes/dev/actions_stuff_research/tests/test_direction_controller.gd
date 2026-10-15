extends SceneTree
# Python-generated full time histories catch source ordering, degree math,
# context/yaw, hysteresis, dwell, phase reset and crossfade regressions.
var failures: Array[String] = []
var comparisons := 0
var max_error := 0.0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		if failures.size() < 20: push_error(label)
func _initialize() -> void:
	call_deferred("run")
func compare_value(actual: Variant, expected: Variant, label: String) -> void:
	comparisons += 1
	if expected is Dictionary:
		check(actual is Dictionary, label + " is dictionary")
		if not actual is Dictionary: return
		for key in expected:
			check(actual.has(key), label + " missing " + key)
			if actual.has(key): compare_value(actual[key], expected[key], label + "." + key)
	elif expected is float or expected is int:
		check(actual is float or actual is int, label + " numeric value")
		if not (actual is float or actual is int): return
		var error := absf(float(actual) - float(expected))
		max_error = maxf(max_error, error)
		check(error <= 2e-9 * maxf(1.0, absf(float(expected))), label + " got " + str(actual) + " expected " + str(expected))
	else:
		check(actual == expected, label + " exact value")
func restore_ieee(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("ieee64"): return value.ieee64.hex_decode().decode_double(0)
		var restored := {}
		for key in value: restored[key] = restore_ieee(value[key])
		return restored
	if value is Array:
		var restored := []
		for item in value: restored.append(restore_ieee(item))
		return restored
	return value
func run() -> void:
	var path := "res://scenes/dev/actions_stuff_research/source_direction_controller.gd"
	check(ResourceLoader.exists(path), "Literal directional source controller is missing")
	if not ResourceLoader.exists(path): quit(1); return
	var controller_script = load(path)
	var vm = load("res://scenes/dev/actions_stuff_research/molang_vm.gd")
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/dev/actions_stuff_research/tests/fixtures/controller_direction_fixtures.json"))
	for test in fixtures.vm:
		var environment := {}
		compare_value(vm.execute(test.node, environment), test.expected, "VM " + test.expression)
		compare_value(environment, test.env, "VM env " + test.expression)
		check(environment.size() == test.env.size(), "VM assignment/return environment keys: " + test.expression)
	var steps := 0
	for trace in fixtures.traces:
		var controller = controller_script.new(trace.initial_life)
		controller.env.merge(trace.get("seed", {}), true)
		var index := 0
		for row in trace.rows:
			var exact_input: Dictionary = restore_ieee(row.input_ieee64)
			var out: Dictionary = controller.step(exact_input.query, exact_input.dt)
			var expected: Dictionary = row.expected.duplicate(true)
			var variable_count := int(expected.variable_count)
			expected.erase("variable_count")
			compare_value(out, expected, str(trace.name) + ":" + str(index))
			check(out.vars.size() == variable_count, "Complete source variable environment")
			check(out.controllerstate == out.state, "Python-compatible state alias")
			compare_value(out.query["q.position"].call(0), row.query.position[0], "Query position callable")
			compare_value(out.query["q.head_y_rotation"].call(0), row.query.head_y_rotation, "Query head callable")
			index += 1; steps += 1
	var dense_max_error := max_error
	# Seeding engine heading must prevent a one-time spawn turn without changing clocks.
	var seeded = controller_script.new(12.0)
	check(seeded.has_method("seed_heading"), "Heading seed API exists")
	if seeded.has_method("seed_heading"):
		seeded.seed_heading(-180.0)
		var seeded_out: Dictionary = seeded.step({"position": [0.0,0.0,0.0], "movement_direction": [0.0,0.0,0.0], "head_y_rotation": -180.0}, 1.0/60.0)
		compare_value(seeded_out.phase, 0.0, "Heading seed preserves phase")
		compare_value(seeded_out.life, 12.0+1.0/60.0, "Heading seed preserves lifetime")
		for variable in ["v.hgztwc", "v.jrptkt", "v.vyjyhz", "v.ufojdf", "v.nthjcy"]:
			compare_value(seeded_out.vars[variable], -180.0, "Heading seed " + variable)
	# Native Vector3 input must produce the same source-coordinate queries.
	var vector_controller = controller_script.new()
	var vector_out: Dictionary = vector_controller.step({"position": Vector3(0,0,.1), "movement_direction": Vector3(0,0,1), "head_y_rotation": 0.0}, 1.0/60.0)
	compare_value(vector_out.query["q.position"].call(2), .1, "Vector3 source position")
	var report := {"failures": failures, "steps": steps, "comparisons": comparisons, "max_absolute_error": max_error, "dense_source_max_absolute_error": dense_max_error, "traces": fixtures.traces.size()}
	FileAccess.open("user://actions_stuff_direction_controller_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("DIRECTION_CONTROLLER_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
