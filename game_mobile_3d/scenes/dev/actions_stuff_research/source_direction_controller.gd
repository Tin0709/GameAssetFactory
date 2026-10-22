extends RefCounted
## Research-only ordinary grounded, alive, local, third-person normal player.
## Literal source order: pre_animation 27 -> 29 -> 30, then controller.
## Inputs use SOURCE coordinates and degrees. Constructor seeds relaxed
## attackless context (v.txtwqb>=12); initial age does not advance gait phase.
const VM = preload("res://scenes/dev/actions_stuff_research/molang_vm.gd")
const PROGRAM_PATH := "res://scenes/dev/actions_stuff_research/controller_program.json"
const EXCLUDED_FLAGS := ["v.rvwafl", "v.hirjne", "v.hhsumy", "v.fxllpr", "v.gddzeg", "v.gtgvhp", "v.yyjpfg", "v.cthrgf", "v.is_first_person", "v.is_paperdoll"]
const QUERY_ZERO := ["q.is_in_ui", "q.is_paperdoll", "q.is_first_person", "q.has_cape", "q.is_riding", "q.is_sprinting", "q.is_sneaking", "q.is_swimming", "q.is_crawling", "q.is_gliding", "q.blocking", "q.main_hand_item_use_duration", "q.item_is_charged", "q.vertical_speed", "q.yaw_speed"]
var env: Dictionary = {}
var life := 0.0
var state := "onccai"
var state_time := 0.0
var run_weight := 0.0
var _blend_elapsed := 0.0
var _blend_duration := 0.0
var _blend_from := 0.0
var _blend_to := 0.0
var _program: Dictionary

func _init(initial_life: float = 12.0) -> void:
	_program = JSON.parse_string(FileAccess.get_file_as_string(PROGRAM_PATH))
	for variable in _program.variable_names: env[variable] = 0.0
	life = initial_life
	env.merge({"v.tnlxsa": 2.0, "v.wtlyok": 1.0, "v.qlczor": initial_life, "v.abjhra": initial_life, "v.jcvgdh": initial_life, "v.bueybx": initial_life, "v.txtwqb": maxf(initial_life, 12.0)}, true)

## Explicitly choose authored recent-interaction/head-facing or relaxed context.
func seed_context(recent: bool) -> void:
	env["v.txtwqb"] = 0.0 if recent else 12.0

## Initialize source head unwrap/body history to actual engine facing at spawn.
## v.jrptkt is the authored previous head query; no phase/age/speed changes.
func seed_heading(source_degrees: float) -> void:
	for variable in ["v.hgztwc", "v.jrptkt", "v.vyjyhz", "v.ufojdf", "v.nthjcy"]:
		env[variable] = source_degrees

func _queries(query: Dictionary, dt: float) -> Dictionary:
	var normalized := {}
	for key in query:
		var name: String = str(key)
		normalized[name if name.begins_with("q.") else "q." + name] = query[key]
	for key in QUERY_ZERO:
		if not normalized.has(key): normalized[key] = 0.0
	for key in ["q.is_alive", "q.is_on_ground", "q.is_local_player"]:
		if not normalized.has(key): normalized[key] = 1.0
	for key in ["q.is_riding_any_entity_of_type", "q.is_pack_setting_selected"]:
		if not normalized.has(key): normalized[key] = func(_arg: Variant = null, _arg2: Variant = null) -> float: return 0.0
	for key in ["q.position", "q.movement_direction"]:
		if not normalized.has(key):
			push_error("Harness must supply " + key)
			return {}
		var vector = normalized[key]
		if not vector is Callable:
			if not vector is Vector3 and (not vector is Array or vector.size() != 3):
				push_error(key + " requires source xyz length 3")
				return {}
			normalized[key] = func(axis: Variant) -> float: return float(vector[int(axis)])
	if not normalized.has("q.head_y_rotation"):
		push_error("Harness must supply q.head_y_rotation")
		return {}
	var head = normalized["q.head_y_rotation"]
	if not head is Callable:
		var head_value := float(head)
		normalized["q.head_y_rotation"] = func(_axis: Variant = 0) -> float: return head_value
	normalized["q.life_time"] = float(normalized.get("q.life_time", life + dt))
	normalized["q.delta_time"] = dt
	return normalized

func _validate_profile(q: Dictionary) -> bool:
	if not q["q.is_alive"] or not q["q.is_on_ground"] or not q["q.is_local_player"]:
		push_error("Directional source supports only alive local ordinary ground")
		return false
	for key in ["q.is_in_ui", "q.is_paperdoll", "q.is_first_person", "q.has_cape", "q.is_riding", "q.is_sneaking", "q.is_swimming", "q.is_crawling", "q.is_gliding", "q.blocking", "q.main_hand_item_use_duration", "q.item_is_charged", "q.vertical_speed"]:
		if q[key]:
			push_error("Excluded directional source profile query " + key)
			return false
	for key in EXCLUDED_FLAGS:
		if env.get(key, 0.0):
			push_error("Excluded directional source profile flag " + key)
			return false
	if env.get("v.tnlxsa") != 2.0:
		push_error("Only normal player tnlxsa=2 is supported")
		return false
	return true

var diagnostic_control_usec:=0
func step(query: Dictionary, dt: float) -> Dictionary:
	var started:=Time.get_ticks_usec()
	var result=_diagnostic_step(query,dt)
	diagnostic_control_usec+=Time.get_ticks_usec()-started
	return result
func _diagnostic_step(query: Dictionary, dt: float) -> Dictionary:
	if not is_finite(dt) or dt <= 0.0 or dt > 1.0/6.0:
		push_error("dt must be finite in (0,1/6] for audited Euler smoothing")
		return {}
	var q := _queries(query, dt)
	if q.is_empty(): return {}
	if not is_finite(q["q.life_time"]) or q["q.life_time"] < life:
		push_error("Query life_time must be finite and nondecreasing")
		return {}
	if not _validate_profile(q): return {}
	# pre_animation22 alive timer and caller-owned interaction context precede trio.
	env["v.qlczor"] += dt
	if q.has("q.attack_time"): env["v.attack_time"] = float(q["q.attack_time"])
	for key in env.keys():
		if key.begins_with("q.") or key.begins_with("t."): env.erase(key)
	env.merge(q, true)
	life = q["q.life_time"]
	for program in _program.programs: VM.execute(program, env)
	if not _validate_profile(q): return {}
	if _blend_duration:
		_blend_elapsed = minf(_blend_duration, _blend_elapsed + dt)
		run_weight = _blend_from + (_blend_to - _blend_from) * (_blend_elapsed / _blend_duration)
	# Python rounds state age to 14 decimal places before strict authored dwell.
	state_time = round((state_time + dt) * 1e14) / 1e14
	env["q.state_time"] = state_time
	var record: Dictionary = _program.states[state]
	for transition in record.transitions:
		if VM.execute(transition[1], env):
			var destination: String = transition[0]
			if destination not in ["onccai", "run"]:
				push_error("Ground profile attempted excluded source state " + destination)
				return {}
			_blend_from = run_weight
			_blend_to = float(destination == "run")
			_blend_duration = float(record.blend_transition)
			_blend_elapsed = 0.0
			if not _blend_duration: run_weight = _blend_to
			state = destination
			state_time = 0.0
			env["q.state_time"] = 0.0
			break
	var weights := {}
	for animation in _program.states[state].animations:
		weights[animation[0]] = VM.execute(animation[1], env)
	var variables := {}
	for key in env:
		if key.begins_with("v."): variables[key] = env[key]
	return {"vars": variables, "phase": variables["v.eqhdel"], "phase01": variables.get("v.ifcvde", fposmod(variables["v.eqhdel"], 1.0)), "life": life, "run_weight": run_weight, "controllerstate": state, "state": state, "state_time": state_time, "cadence": 1.6 * sqrt(maxf(0.0, variables["v.njrdop"])), "raw_weights": weights, "query": q.duplicate(), "profile": "ordinary_ground_local_third_person_tnlxsa2"}
