extends Node
## Original diffuse fill, not spatial GI. Owns only this map's sky bindings.
const FIELD = preload("res://materials/world_map_ambient.gdshader")
const OWNED := ["sky", "ambient_light_source", "ambient_light_sky_contribution", "reflected_light_source"]
var level: Node3D
var enabled := true
var _environment: Environment
var _previous: Dictionary = {}
var _applied: Dictionary = {}
var _sky: Sky
var _material: ShaderMaterial
var _color := Color(-1, -1, -1)
var _energy := -1.0

func setup(world: Node3D) -> void:
	level = world
	refresh()

func available() -> bool:
	return RenderingServer.get_current_rendering_method() == "mobile" and RenderingServer.get_rendering_device() != null

func is_active() -> bool:
	return _environment != null

func set_enabled(value: bool) -> void:
	enabled = value
	refresh()

func _eligible(environment: Environment) -> bool:
	# A visible/foreign sky or ambient reflections need their own lighting model.
	return environment != null and environment.sky == null \
		and environment.background_mode in [Environment.BG_COLOR, Environment.BG_CLEAR_COLOR] \
		and environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR \
		and environment.reflected_light_source in [Environment.REFLECTION_SOURCE_SKY, Environment.REFLECTION_SOURCE_DISABLED]

func _update_field() -> void:
	var color := _environment.ambient_light_color
	var energy := _environment.ambient_light_energy
	if color == _color and energy == _energy: return
	_color = color
	_energy = energy
	# Full sky contribution bypasses Environment ambient energy in Mobile.
	# Bake that energy into the original linear radiance, not into display RGB.
	var linear := color.srgb_to_linear()
	var mean := Vector3(linear.r, linear.g, linear.b) * energy
	_material.set_shader_parameter("center", mean)
	_material.set_shader_parameter("vertical", mean * Vector3(0.15, 0.25, 0.45))
	_material.set_shader_parameter("horizontal", mean * 0.18)

func refresh() -> void:
	var candidate: Environment
	if enabled and available() and is_instance_valid(level) and level.look != null and level.look.stage == 2:
		candidate = level.get_node("WorldEnvironment").environment
	if candidate != _environment: _restore()
	if candidate == null: return
	if _environment != null:
		# Another owner can replace bindings without being overwritten on teardown.
		for field: String in OWNED:
			if _environment.get(field) != _applied[field]:
				_restore()
				return
		if not candidate.background_mode in [Environment.BG_COLOR, Environment.BG_CLEAR_COLOR]:
			_restore()
			return
	else:
		if not _eligible(candidate): return
		if _sky == null:
			_material = ShaderMaterial.new()
			_material.shader = FIELD
			_sky = Sky.new()
			_sky.sky_material = _material
			_sky.radiance_size = Sky.RADIANCE_SIZE_32
			_sky.process_mode = Sky.PROCESS_MODE_QUALITY
		_environment = candidate
		for field: String in OWNED: _previous[field] = candidate.get(field)
		_applied = {
			"sky": _sky,
			"ambient_light_source": Environment.AMBIENT_SOURCE_SKY,
			"ambient_light_sky_contribution": 1.0,
			"reflected_light_source": Environment.REFLECTION_SOURCE_DISABLED,
		}
		for field: String in OWNED: candidate.set(field, _applied[field])
	_update_field()

func _restore() -> void:
	if _environment == null: return
	for field: String in OWNED:
		if _environment.get(field) == _applied[field]:
			_environment.set(field, _previous[field])
	_environment = null
	_previous.clear()
	_applied.clear()

func _process(_delta: float) -> void:
	refresh()

func _exit_tree() -> void:
	_restore()
