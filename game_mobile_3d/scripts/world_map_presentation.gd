extends Node
## Render-only interpolation. Physics, input and authored local poses are untouched.
var level: Node3D
var enabled := false
var _scene_tree: SceneTree
var _previous_tree_interpolation := false
var _previous_jitter_fix := 0.5
var _previous_modes: Array[Array] = []
var _owns_service := false

func begin(world: Node3D) -> void:
	level = world
	_scene_tree = get_tree()
	_previous_tree_interpolation = _scene_tree.physics_interpolation
	_previous_jitter_fix = Engine.physics_jitter_fix
	_previous_modes.append([level, level.physics_interpolation_mode])
	level.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Activate before static render instances are built. Switching this global
	# representation after construction leaves existing static RIDs stale.
	_scene_tree.physics_interpolation = true
	# Match Godot's startup interpolation path: timer jitter correction would
	# otherwise compete with the render interpolation fraction.
	Engine.physics_jitter_fix = 0.0
	_owns_service = true

func setup() -> void:
	for node: Node in [level.player, level.player.visual]:
		_previous_modes.append([node, node.physics_interpolation_mode])
	set_enabled(true)

func set_enabled(value: bool) -> void:
	if value == enabled: return
	enabled = value
	# Keep static RIDs in one representation for the map's entire lifetime.
	# Only the physical root is interpolated; per-frame local poses stay direct.
	level.player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON if enabled else Node.PHYSICS_INTERPOLATION_MODE_OFF
	level.player.visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if is_instance_valid(level.player): level.player.reset_physics_interpolation()

func player_position() -> Vector3:
	return level.player.get_global_transform_interpolated().origin if enabled else level.player.global_position

func wind_time(physics_time: float) -> float:
	return physics_time - (1.0 - Engine.get_physics_interpolation_fraction()) / Engine.physics_ticks_per_second

func _exit_tree() -> void:
	if not _owns_service: return
	for item: Array in _previous_modes:
		if is_instance_valid(item[0]): item[0].physics_interpolation_mode = item[1]
	_scene_tree.physics_interpolation = _previous_tree_interpolation
	Engine.physics_jitter_fix = _previous_jitter_fix
	_owns_service = false
