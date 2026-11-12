extends RefCounted
## Optional projected sunlight from the verified external Forest GPU reference.
const MASK_PATH := "godot_lab/world_map_unified_showcase_v001/forest_dappled_light_v001/projection_source_linear.private.png"
const MASK_SHA256 := "23956b5aab0996a696066516d8796cbf088570bf8e73a3175d8c4b152c329cca"
const SOFT_MASK_PATH := "godot_lab/world_map_unified_showcase_v001/cliff_light_transition_v001/projection_penumbra.private.png"
const SOFT_MASK_SHA256 := "4e0055e4b615efb5ba3993b4b2e953ff1999b2dcac19e336944ab94605472582"
const MASK_SIZE := Vector2i(512, 512)
const STRENGTH := &"gaf_projected_sun_strength"
const SHIFT := &"gaf_projected_sun_shift"
const SOFTNESS := &"gaf_projected_sun_softness"
const MASK := &"gaf_projected_sun_mask"

var _path := ""
var _texture: ImageTexture
var _weight := 0.0
var _shift := Vector2.ZERO
var _soft_path := ""
var _softness := 0.0
var _softness_loaded := false

func setup() -> void:
	release()
	if not OS.has_feature("editor") or RenderingServer.get_current_rendering_method() != "mobile" \
			or RenderingServer.get_rendering_device() == null \
			or ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_vertex_shading"):
		return
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.replace("\\", "/").simplify_path().trim_suffix("/")
	var checkout := ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path().trim_suffix("/").get_base_dir().to_lower()
	if not root.is_absolute_path() or root.begins_with("res://") or root.begins_with("user://") \
			or root.to_lower() == checkout or root.to_lower().begins_with(checkout + "/"):
		return
	var path := root.path_join(MASK_PATH)
	if FileAccess.file_exists(path):
		_path = path
		var soft := root.path_join(SOFT_MASK_PATH)
		if FileAccess.file_exists(soft):
			_soft_path = soft

func available() -> bool:
	return not _path.is_empty()

func softness_available() -> bool:
	return available() and not _soft_path.is_empty()

func set_softness(value: float) -> void:
	var applied := clampf(value, 0.0, 1.0) if _weight > 0.0 and is_finite(value) and softness_available() else 0.0
	if applied == _softness:
		return
	if applied > 0.0 and not _softness_loaded:
		var image := Image.new()
		if FileAccess.get_sha256(_soft_path) != SOFT_MASK_SHA256 or image.load(_soft_path) != OK or image.get_size() != MASK_SIZE:
			_soft_path = ""
			return
		image.generate_mipmaps()
		# The private derivative preserves red/green and stores filtered red in blue.
		_texture = ImageTexture.create_from_image(image)
		RenderingServer.global_shader_parameter_set(MASK, _texture)
		_softness_loaded = true
	_softness = applied
	RenderingServer.global_shader_parameter_set(SOFTNESS, applied)

func set_weight(weight: float) -> void:
	if weight == _weight:
		return
	if weight > 0.0 and _texture == null:
		if not available():
			return
		var image := Image.new()
		if FileAccess.get_sha256(_path) != MASK_SHA256 or image.load(_path) != OK or image.get_size() != MASK_SIZE:
			_path = ""
			return
		image.generate_mipmaps()
		_texture = ImageTexture.create_from_image(image)
		RenderingServer.global_shader_parameter_set(MASK, _texture)
	_weight = weight
	RenderingServer.global_shader_parameter_set(STRENGTH, weight)

func set_shift(shift: Vector2) -> void:
	var applied := shift if _weight > 0.0 and shift.is_finite() else Vector2.ZERO
	if applied == _shift:
		return
	_shift = applied
	RenderingServer.global_shader_parameter_set(SHIFT, _shift)

func release() -> void:
	RenderingServer.global_shader_parameter_set(STRENGTH, 0.)
	RenderingServer.global_shader_parameter_set(SHIFT, Vector2.ZERO)
	RenderingServer.global_shader_parameter_set(SOFTNESS, 0.)
	RenderingServer.global_shader_parameter_set(MASK, null)
	_weight = 0.
	_shift = Vector2.ZERO
	_softness = 0.
	_softness_loaded = false
	_soft_path = ""
	_texture = null
	_path = ""
