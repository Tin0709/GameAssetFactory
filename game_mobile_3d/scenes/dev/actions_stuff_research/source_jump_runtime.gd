extends "res://scenes/dev/actions_stuff_research/source_direction_controller.gd"
## Literal approved source, alive/local/normal/dry profile. Caller owns physics.
## Order: pre27 ->29 ->30 -> locomotion -> sprint -> landing -> jump -> fall.
## Declared adapters match frozen Python: positive-only unnormalized PRS mixing,
## outgoing local clocks continue, one transition/controller/step, linear fade.
const JUMP_PROGRAM_PATH := "res://scenes/dev/actions_stuff_research/jump_program.json"
const ORDER := ["veywgp","psowex","pyhwuc","ngeixo","muiqdc"]
var controllers: Dictionary = {}
var timeline_events: Array = []
var holding_right := 0.0
var holding_left := 0.0

func _init(initial_life: float = 12.0) -> void:
	super(initial_life)
	_program = VM.prepare(JSON.parse_string(FileAccess.get_file_as_string(JUMP_PROGRAM_PATH)))
	env.clear()
	for variable in _program.variable_names: env[variable.to_lower()] = 0.0
	env.merge({"v.tnlxsa":2.0,"v.wtlyok":1.0,"v.qlczor":initial_life,"v.abjhra":initial_life,"v.jcvgdh":initial_life,"v.bueybx":initial_life},true)
	for alias in ORDER:
		controllers[alias] = {"state":_program.controllers[alias].initial_state,"time":0.0,"clocks":{},"fired":{},"old":null,"fade":0.0,"duration":0.0,"initialized":false}

func set_item_holding(right: float, left: float) -> void:
	assert(is_finite(right) and is_finite(left) and right >= 0 and right <= 1 and left >= 0 and left <= 1)
	holding_right = right
	holding_left = left

func _record(alias: String, c: Dictionary) -> Dictionary:
	return _program.controllers[alias].states[c.state]

func _scripts(record: Dictionary, key: String) -> void:
	for program in record.get(key,[]): VM.execute(program,env)

func _initialize_clips(alias: String, c: Dictionary) -> void:
	c.clocks = {}
	c.fired = {}
	for item in _record(alias,c).animations:
		if _program.clips.has(item[0]):
			c.clocks[item[0]] = 0.0
			c.fired[item[0]] = {}

func _timeline(controller: String, alias: String, clock: float, fired: Dictionary) -> void:
	for event in _program.clips[alias].timeline:
		if float(event[0]) <= clock + 1e-10 and not fired.has(event[2]):
			VM.execute(event[1],env)
			fired[event[2]] = true
			timeline_events.append({"controller":controller,"alias":alias,"timestamp":event[0],"clock":clock,"script":event[3]})

func _advance(controller: String, clocks: Dictionary, fired: Dictionary, dt: float) -> void:
	for alias in clocks:
		var clip: Dictionary = _program.clips[alias]
		env["q.anim_time"] = clocks[alias]
		clocks[alias] = float(VM.execute(clip.anim_time_update,env)) if clip.anim_time_update != null else float(clocks[alias])+dt
		_timeline(controller,alias,clocks[alias],fired[alias])

func _layers_for(alias: String, source_state: String, clocks: Dictionary, weight: float) -> Array:
	var out: Array = []
	for item in _program.controllers[alias].states[source_state].animations:
		var animation: String = item[0]
		if not clocks.has(animation): continue
		var clock: float = clocks[animation]
		var clip: Dictionary = _program.clips[animation]
		if clip.loop is bool and clip.loop and clip.animation_length:
			clock = fposmod(clock,float(clip.animation_length))
		elif clip.animation_length:
			clock = minf(clock,float(clip.animation_length))
		env["q.anim_time"] = clock
		var cw := float(VM.execute(item[1],env))*weight
		out.append({"alias":animation,"controller":alias,"state":source_state,"clock":clock,"controller_weight":cw,"state_weight":weight})
	return out

func _controller_layers(alias: String, c: Dictionary) -> Array:
	var alpha: float = minf(1.0,c.fade/c.duration) if c.old != null else 1.0
	var out: Array = _layers_for(alias,c.old.state,c.old.clocks,1.0-alpha) if c.old != null else []
	out.append_array(_layers_for(alias,c.state,c.clocks,alpha))
	return out

func _step_controller(alias: String, dt: float) -> Array:
	var c: Dictionary = controllers[alias]
	if not c.initialized:
		_scripts(_record(alias,c),"on_entry")
		_initialize_clips(alias,c)
		c.initialized = true
		for animation in c.clocks: _timeline(alias,animation,c.clocks[animation],c.fired[animation])
	c.time = round((c.time+dt)*1e14)/1e14
	_advance(alias,c.clocks,c.fired,dt)
	if c.old != null:
		c.fade += dt
		_advance(alias,c.old.clocks,c.old.fired,dt)
		if c.fade >= c.duration: c.old = null
	env["q.state_time"] = c.time
	var any_finished := false
	var all_finished := true
	var finish_count := 0
	for animation in c.clocks:
		var clip: Dictionary = _program.clips[animation]
		if not ((clip.loop is bool and clip.loop) or (clip.loop is String and clip.loop == "hold_on_last_frame")):
			var finished: bool = clip.animation_length != 0 and c.clocks[animation] >= float(clip.animation_length)
			any_finished = any_finished or finished
			all_finished = all_finished and finished
			finish_count += 1
	env["q.any_animation_finished"] = float(any_finished)
	env["q.all_animations_finished"] = float(finish_count > 0 and all_finished)
	for transition in _record(alias,c).transitions:
		if not VM.execute(transition[1],env): continue
		var previous := _record(alias,c)
		_scripts(previous,"on_exit")
		if previous.blend_transition is Dictionary:
			push_error("Special source blend curve outside ordinary profile")
			return []
		c.duration = float(previous.blend_transition)
		c.fade = 0.0
		c.old = {"state":c.state,"clocks":c.clocks.duplicate(),"fired":c.fired.duplicate(true)} if c.duration else null
		c.state = transition[0]
		c.time = 0.0
		env["q.state_time"] = 0.0
		_scripts(_record(alias,c),"on_entry")
		_initialize_clips(alias,c)
		for animation in c.clocks: _timeline(alias,animation,c.clocks[animation],c.fired[animation])
		break
	return _controller_layers(alias,c)

func _controller_snapshot(c: Dictionary) -> Dictionary:
	return {"state":c.state,"state_time":c.time,"clocks":c.clocks.duplicate(),"outgoing":null if c.old == null else c.old.state,"fade_elapsed":c.fade,"fade_duration":c.duration}

func step(query: Dictionary, dt: float) -> Dictionary:
	if not is_finite(dt) or dt <= 0.0 or dt > 1.0/6.0:
		push_error("dt must be finite in (0,1/6]")
		return {}
	var q := _queries(query,dt)
	if q.is_empty(): return {}
	if not is_finite(q["q.life_time"]) or q["q.life_time"] < life:
		push_error("Query life_time must be finite and nondecreasing")
		return {}
	for key in ["is_in_water","is_jumping","body_y_rotation","target_x_rotation","modified_distance_moved"]:
		if not q.has("q."+key): q["q."+key] = 0.0
	q["q.any"] = func(x: Variant, a: Variant, b: Variant) -> float: return float(x == a or x == b)
	q["q.in_range"] = func(x: float, a: float, b: float) -> float: return float(a <= x and x <= b)
	for key in ["relative_block_has_any_tag","is_item_name_any","equipped_item_any_tag"]:
		if not q.has("q."+key): q["q."+key] = func(_a: Variant = null,_b: Variant = null,_c: Variant = null,_d: Variant = null) -> float: return 0.0
	for key in ["is_in_ui","is_paperdoll","is_first_person","has_cape","is_riding","is_sneaking","is_swimming","is_crawling","is_gliding","blocking","main_hand_item_use_duration","item_is_charged"]:
		if q.get("q."+key):
			push_error("Excluded Jump source profile query " + key)
			return {}
	if not q["q.is_alive"] or not q["q.is_local_player"] or q["q.is_in_water"]:
		push_error("Jump source requires alive local normal dry player")
		return {}
	timeline_events = []
	for key in env.keys():
		if key.begins_with("q.") or key.begins_with("t."): env.erase(key)
	env.merge(q,true)
	life = q["q.life_time"]
	env["v.qlczor"] += dt
	for program in _program.programs: VM.execute(program,env)
	env["v.vbcdda"] = holding_right
	env["v.wfyvyl"] = holding_left
	var layers: Array = [{"alias":"xfltzh","controller":"rzkmtm","state":"default","clock":life,"controller_weight":1.0}]
	for alias in ORDER: layers.append_array(_step_controller(alias,dt))
	for alias in ["bob","holding","look_at_target"]:
		layers.append({"alias":alias,"controller":"hsfnbp" if alias == "look_at_target" else "kcexxa","state":"default","clock":life,"controller_weight":1.0})
	var variables := {}
	for key in env:
		if key.begins_with("v."): variables[key] = env[key]
	var control := {}
	for alias in ORDER: control[alias] = _controller_snapshot(controllers[alias])
	state = controllers.veywgp.state
	state_time = controllers.veywgp.time
	run_weight = 0.0
	for layer in _controller_layers("veywgp",controllers.veywgp):
		if layer.alias == "move": run_weight += float(layer.state_weight)
	return {"vars":variables,"phase":variables["v.eqhdel"],"phase01":variables["v.ifcvde"],"life":life,"controllers":control,"layers":layers,"state":state,"controllerstate":state,"state_time":state_time,"run_weight":run_weight,"cadence":1.6*sqrt(maxf(0.0,variables["v.njrdop"])),"query":q.duplicate(),"timeline_events":timeline_events.duplicate(true),"profile":"local_alive_tnlxsa2_thirdperson_dry_no_specials"}
