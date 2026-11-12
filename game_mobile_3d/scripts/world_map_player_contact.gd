extends Node
## Small indirect-light occluders driven by the displayed sole geometry.
const Phase := preload("res://scripts/world_map_phase_finish.gd")
const STRENGTH := .24
static var _owner: WeakRef

var feet: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO]
var _level: Node3D
var _camera: Camera3D
var _presenter: Node
var _soles: Array[Array] = [[], []]
var _published_camera := Vector3.INF

func setup(level: Node3D) -> void:
	set_process(false)
	var actor: CharacterBody3D = level.player
	if not OS.has_feature("editor") or RenderingServer.get_current_rendering_method() != "mobile" \
		or actor.get("primary_ready") != true:
		return
	var source: RefCounted = actor.direction_adapter
	if source == null or not is_instance_valid(actor.render_presenter):
		return
	for side in 2:
		for entry: Dictionary in source._sole_points[side]:
			_soles[side].append([entry.bone, Transform3D(entry.bind) * Vector3(entry.point)])
		if _soles[side].is_empty():
			return
	_level = level
	_camera = level.get_node("Camera3D")
	_presenter = actor.render_presenter
	_owner = weakref(self)
	RenderingServer.global_shader_parameter_set("gaf_player_sole_left", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("gaf_player_sole_right", Vector4.ZERO)
	process_priority = 92 # After camera and interpolated actor pose.
	set_process(true)

func available() -> bool:
	return _level != null

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if _owner == null or _owner.get_ref() != self:
		return
	var review: Node = _level.showcase
	var gain := 0.
	if review.forest_active() and review.atmosphere_review == "combined" \
		and is_instance_valid(_presenter) and _camera.is_current():
		gain = STRENGTH * Phase.phase_weight(review.hour) * review._lighting_scale(&"foot_contact")
	var left := Vector4.ZERO
	var right := Vector4.ZERO
	if gain > 0. and not _presenter.display_world.is_empty():
		left = _foot(0, gain)
		right = _foot(1, gain)
	if left != feet[0]:
		feet[0] = left
		RenderingServer.global_shader_parameter_set("gaf_player_sole_left", left)
	if right != feet[1]:
		feet[1] = right
		RenderingServer.global_shader_parameter_set("gaf_player_sole_right", right)
	if (left.w > 0. or right.w > 0.) and _published_camera != _camera.global_position:
		_published_camera = _camera.global_position
		RenderingServer.global_shader_parameter_set("gaf_player_sole_camera", _published_camera)

func _foot(side: int, gain: float) -> Vector4:
	var center := Vector2.ZERO
	var bottom := INF
	for entry: Array in _soles[side]:
		var point := Transform3D(_presenter.display_world[entry[0]]) * Vector3(entry[1])
		center += Vector2(point.x, point.z)
		bottom = minf(bottom, point.y)
	center /= _soles[side].size()
	var floor_y: float = _level.surface_height(center.x, center.y)
	if not is_finite(floor_y):
		return Vector4.ZERO
	var clearance := bottom - floor_y
	# A sole next to a higher step must not darken its top above the shoe.
	var support := smoothstep(-.21, -.08, clearance) * (1. - smoothstep(.045, .31, clearance))
	if support <= 0.:
		return Vector4.ZERO
	return Vector4(center.x, floor_y, center.y, gain * support)

func _exit_tree() -> void:
	if _owner != null and _owner.get_ref() == self:
		RenderingServer.global_shader_parameter_set("gaf_player_sole_left", Vector4.ZERO)
		RenderingServer.global_shader_parameter_set("gaf_player_sole_right", Vector4.ZERO)
		_owner = null
