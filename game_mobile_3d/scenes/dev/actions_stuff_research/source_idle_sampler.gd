extends "res://scenes/dev/actions_stuff_research/source_jump_sampler.gd"
## Add only the approved gesture to the already evaluated accepted ground body.
## Baseline bob/holding/look/root layers are never evaluated twice.
const IDLE_DATA_PATH := "res://scenes/dev/actions_stuff_research/idle_program.json"

func _init(rig: Skeleton3D) -> void:
	super(rig)
	data = JSON.parse_string(FileAccess.get_file_as_string(IDLE_DATA_PATH))
	holding_right = 0.0
	holding_left = 0.0

func set_composite(base_channels: Dictionary, _base_snapshot: Dictionary, idle_snapshot: Dictionary) -> void:
	channels = base_channels.duplicate(true)
	var env := _environment(idle_snapshot,0.0)
	env["v.vbcdda"] = 0.0
	env["v.wfyvyl"] = 0.0
	for layer in idle_snapshot.get("layers",[]):
		assert(layer.alias == "tculwn","Only approved source Idle is authorized")
		_add_clip(channels,layer.alias,env,float(layer.clock),float(layer.controller_weight))
	_retarget()

func future_snapshot(snapshot: Dictionary, ahead: float) -> Dictionary:
	## Pose derivative only: freeze variables, historical root age and controller
	## state; advance the gesture's own clocks/fade with no transitions/events.
	assert(is_finite(ahead) and ahead >= 0.0)
	var future: Dictionary = snapshot.duplicate(true)
	future.timeline_events = []
	var controller: Dictionary = future.get("controllers",{}).get("bjmscc",{})
	if not controller.is_empty():
		controller.state_time = float(controller.state_time)+ahead
		for alias in controller.clocks: controller.clocks[alias] = float(controller.clocks[alias])+ahead
		if controller.outgoing != null: controller.fade_elapsed = minf(float(controller.fade_duration),float(controller.fade_elapsed)+ahead)
	var layers: Array = []
	for layer in future.get("layers",[]):
		layer.clock = minf(float(data.clips.tculwn.animation_length),float(layer.clock)+ahead)
		if not controller.is_empty() and controller.outgoing != null and layer.state == controller.outgoing:
			layer.state_weight = maxf(0.0,1.0-float(controller.fade_elapsed)/float(controller.fade_duration))
			layer.controller_weight = layer.state_weight
		if float(layer.controller_weight) > 0.0: layers.append(layer)
	future.layers = layers
	return future
