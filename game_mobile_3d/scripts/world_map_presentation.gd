extends Node
## Render-only interpolation. Physics, input and authored local poses are untouched.
var level: Node3D
var enabled := false
var _scene_tree: SceneTree
var _previous_tree_interpolation := false
var _previous_modes: Array[Array] = []

func setup(world: Node3D) -> void:
	level = world
	_scene_tree = get_tree()
	_previous_tree_interpolation = _scene_tree.physics_interpolation
	for node: Node in [level, level.player, level.player.visual]:
		_previous_modes.append([node, node.physics_interpolation_mode])
	set_enabled(true)

func set_enabled(value: bool) -> void:
	if value == enabled: return
	enabled = value
	if enabled:
		# Only the physical root is interpolated. The existing pose writer runs
		# per rendered frame, so its local transforms must remain direct.
		level.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		level.player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		level.player.visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_scene_tree.physics_interpolation = true
	else:
		for item: Array in _previous_modes:
			if is_instance_valid(item[0]): item[0].physics_interpolation_mode = item[1]
		_scene_tree.physics_interpolation = _previous_tree_interpolation
	if is_instance_valid(level.player): level.player.reset_physics_interpolation()

func player_position() -> Vector3:
	return level.player.get_global_transform_interpolated().origin if enabled else level.player.global_position

func wind_time(physics_time: float) -> float:
	return physics_time - (1.0 - Engine.get_physics_interpolation_fraction()) / Engine.physics_ticks_per_second

func _exit_tree() -> void:
	if enabled: set_enabled(false)
