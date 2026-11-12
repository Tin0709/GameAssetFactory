extends RefCounted
## Optional projected sunlight from the verified external Forest GPU reference.
const MASK_PATH := "godot_lab/world_map_unified_showcase_v001/forest_dappled_light_v001/projection_source_linear.private.png"
const MASK_SHA256 := "23956b5aab0996a696066516d8796cbf088570bf8e73a3175d8c4b152c329cca"
const MASK_SIZE := Vector2i(512, 512)
const STRENGTH := &"gaf_projected_sun_strength"
const SHIFT := &"gaf_projected_sun_shift"
const MASK := &"gaf_projected_sun_mask"

var _path := ""
var _texture: ImageTexture
var _weight := 0.0
var _shift := Vector2.ZERO

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

func available() -> bool:
	return not _path.is_empty()

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
	RenderingServer.global_shader_parameter_set(MASK, null)
	_weight = 0.
	_shift = Vector2.ZERO
	_texture = null
	_path = ""
