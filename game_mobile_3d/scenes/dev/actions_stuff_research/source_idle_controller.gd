extends RefCounted
## Source bjmscc/fotixv overlay. Only the approved tculwn/jcyjaa chooser branch
## is available. Source0 applies inside this private environment only; accepted
## source2 locomotion environment is copied and never modified or recomputed.
const VM = preload("res://scenes/dev/actions_stuff_research/molang_vm.gd")
const IDLE_PROGRAM_PATH := "res://scenes/dev/actions_stuff_research/idle_program.json"
const OWNED := ["v.yfuzcx","v.ngjrwv","v.xrtrow"]
var _program: Dictionary
var controllers: Dictionary = {}
var env: Dictionary = {}
var timeline_events: Array = []
var life := 12.0
var state := "uwpoku"
var state_time := 0.0

func _init(initial_life: float = 12.0) -> void:
	_program = JSON.parse_string(FileAccess.get_file_as_string(IDLE_PROGRAM_PATH))
	life = initial_life
	reset()

func reset() -> void:
	## Reset local dwell/gesture state while source lifetime remains continuous.
	env = {"v.yfuzcx":0.0,"v.ngjrwv":0.0,"v.xrtrow":0.0}
	controllers = {"bjmscc":{"state":_program.controllers.bjmscc.initial_state,"time":0.0,"clocks":{},"fired":{},"old":null,"fade":0.0,"duration":0.0,"initialized":false}}
	timeline_events = []
	state = "uwpoku"
	state_time = 0.0

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

func step(base_ground_snapshot: Dictionary, requested: bool, eligible: bool, delta: float) -> Dictionary:
	assert(is_finite(delta) and delta > 0.0 and delta <= 1.0/6.0)
	var owned := {}
	for key in OWNED: owned[key] = env.get(key,0.0)
	env = base_ground_snapshot.get("vars",{}).duplicate(true)
	env.merge(owned,true)
	env["v.tnlxsa"] = 0.0
	env["v.vbcdda"] = 0.0
	env["v.wfyvyl"] = 0.0
	env["v.is_holding_right"] = 0.0
	env["v.is_holding_left"] = 0.0
	var query: Dictionary = base_ground_snapshot.get("query",{}).duplicate(true)
	life = float(base_ground_snapshot.get("life",life+delta))
	query["q.life_time"] = life
	query["q.delta_time"] = delta
	query["q.approved_idle_choice"] = 1.0
	# Explicit study context: prior movement1, attack-free12. Actual source
	# interaction flags from the ground snapshot supersede these missing defaults.
	query["q.modified_distance_moved"] = 1.0
	if not env.has("v.txtwqb"): env["v.txtwqb"] = 12.0
	for key in ["q.is_emoting","q.main_hand_item_use_duration","q.is_sneaking","q.ground_speed"]:
		if not query.has(key): query[key] = 0.0
	if not query.has("q.is_on_ground"): query["q.is_on_ground"] = 1.0
	for key in ["q.equipped_item_any_tag","q.is_item_name_any"]:
		query[key] = func(_a: Variant=null,_b: Variant=null,_c: Variant=null,_d: Variant=null) -> float: return 0.0
	# Intent is required for blocked WASD and stationary jump: displacement alone
	# cannot interrupt. q.ground_speed exits the source clip; nwocdu resets waiting.
	if requested or not eligible:
		query["q.ground_speed"] = maxf(1.0,float(query.get("q.ground_speed",0.0)))
		env["v.nwocdu"] = 1.0
	env.merge(query,true)
	timeline_events = []
	var layers: Array = _step_controller("bjmscc",delta)
	var positive: Array = []
	for layer in layers:
		assert(layer.alias == "tculwn","Only the artistically approved Idle can play")
		if float(layer.controller_weight) > 0.0: positive.append(layer)
	state = controllers.bjmscc.state
	state_time = controllers.bjmscc.time
	var variables := {}
	for key in env:
		if key.begins_with("v."): variables[key] = env[key]
	return {"vars":variables,"query":query,"life":life,"phase":base_ground_snapshot.get("phase",0.0),"phase01":base_ground_snapshot.get("phase01",0.0),"cadence":base_ground_snapshot.get("cadence",0.0),"state":state,"state_time":state_time,"layers":positive,"controllers":{"bjmscc":_controller_snapshot(controllers.bjmscc)},"timeline_events":timeline_events.duplicate(true),"eligible":eligible,"requested":requested,"approved_idle_choice":1,"profile":"approved_source0_idle_overlay_on_accepted_ground"}
