extends RefCounted
## Optional projected sunlight from the verified external Forest GPU reference.
const MASK_PATH := "godot_lab/world_map_unified_showcase_v001/forest_dappled_light_v001/projection_source_linear.private.png"
const MASK_SHA256 := "23956b5aab0996a696066516d8796cbf088570bf8e73a3175d8c4b152c329cca"
const SOFT_MASK_PATH := "godot_lab/world_map_unified_showcase_v001/cliff_light_transition_v001/projection_penumbra.private.png"
const SOFT_MASK_SHA256 := "4e0055e4b615efb5ba3993b4b2e953ff1999b2dcac19e336944ab94605472582"
const MASK_SIZE := Vector2i(512, 512)
const STRENGTH := &"gaf_projected_sun_strength"
const SHIFT := &"gaf_projected_sun_shift"
const LOCAL_REGION := &"gaf_projected_sun_local_region"
const LOCAL_SHIFT := &"gaf_projected_sun_local_shift"
const SOFTNESS := &"gaf_projected_sun_softness"
const MASK := &"gaf_projected_sun_mask"
const OPENINGS := &"gaf_projected_sun_openings"
const CONTRAST := &"gaf_projected_sun_contrast"
const RECOVERY_REGION := &"gaf_projected_path_recovery_region"
const RECOVERY_AMOUNT := &"gaf_projected_path_recovery_amount"

var _path := ""
var _texture: ImageTexture
var _weight := 0.0
var _shift := Vector2.ZERO
var _local_region := Vector4.ZERO
var _local_shift := Vector2.ZERO
var _soft_path := ""
var _softness := 0.0
var _softness_loaded := false
var _opening_recovery := 0.
var _contrast := Vector4.ZERO
var _recovery_region := Vector4.ZERO
var _recovery_amount := 0.

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
	if _weight <= 0.0:
		set_local_alignment(Vector4.ZERO, Vector2.ZERO)
		set_path_recovery(Vector4.ZERO, 0.)

func set_opening_recovery(amount: float, phase_response: float = 0.) -> void:
	var projection_weight := clampf(_weight / .40, 0., 1.)
	var full_recovery := clampf(_weight / .20, 0., 1.)
	var factor := lerpf(projection_weight, full_recovery, clampf(phase_response, 0., 1.))
	var applied := clampf(amount, 0., 1.) * factor if is_finite(amount) else 0.
	if applied == _opening_recovery:
		return
	_opening_recovery = applied
	RenderingServer.global_shader_parameter_set(OPENINGS, applied)

func set_contrast(direction: Vector3, amount: float) -> void:
	var applied := Vector4.ZERO
	if _weight > .05 and direction.is_finite() and not direction.is_zero_approx() and is_finite(amount) and amount > 0.:
		var key := direction.normalized()
		applied = Vector4(key.x, key.y, key.z, minf(amount, 1.))
	if applied != _contrast:
		_contrast = applied
		RenderingServer.global_shader_parameter_set(CONTRAST, applied)


func set_shift(shift: Vector2) -> void:
	var applied := shift if _weight > 0.0 and shift.is_finite() else Vector2.ZERO
	if applied == _shift:
		return
	_shift = applied
	RenderingServer.global_shader_parameter_set(SHIFT, _shift)

static func valid_local_region(region: Vector4) -> bool:
	return region.is_finite() and region.z >= 0.0 and region.w > region.z and is_finite(region.w * region.w)

static func valid_local_alignment(region: Vector4, offset: Vector2) -> bool:
	return valid_local_region(region) and offset.is_finite() and offset != Vector2.ZERO

func set_local_alignment(region: Vector4, offset: Vector2) -> void:
	var radii := Vector4.ZERO
	var shift := Vector2.ZERO
	if _weight > 0.0 and valid_local_alignment(region, offset):
		radii = Vector4(region.x, region.y, region.z * region.z, region.w * region.w)
		shift = offset
	if radii != _local_region:
		_local_region = radii
		RenderingServer.global_shader_parameter_set(LOCAL_REGION, radii)
	if shift != _local_shift:
		_local_shift = shift
		RenderingServer.global_shader_parameter_set(LOCAL_SHIFT, shift)

func set_path_recovery(region: Vector4, amount: float) -> void:
	var radii := Vector4.ZERO
	var applied := 0.
	if _weight > 0. and is_finite(amount) and amount > 0. and valid_local_region(region):
		radii = Vector4(region.x, region.y, region.z * region.z, region.w * region.w)
		applied = clampf(amount, 0., 1.)
	if radii != _recovery_region:
		_recovery_region = radii
		RenderingServer.global_shader_parameter_set(RECOVERY_REGION, radii)
	if applied != _recovery_amount:
		_recovery_amount = applied
		RenderingServer.global_shader_parameter_set(RECOVERY_AMOUNT, applied)

func release() -> void:
	set_path_recovery(Vector4.ZERO, 0.)
	RenderingServer.global_shader_parameter_set(STRENGTH, 0.)
	RenderingServer.global_shader_parameter_set(SHIFT, Vector2.ZERO)
	RenderingServer.global_shader_parameter_set(LOCAL_REGION, Vector4.ZERO)
	RenderingServer.global_shader_parameter_set(LOCAL_SHIFT, Vector2.ZERO)
	RenderingServer.global_shader_parameter_set(SOFTNESS, 0.)
	RenderingServer.global_shader_parameter_set(OPENINGS, 0.)
	RenderingServer.global_shader_parameter_set(CONTRAST, Vector4.ZERO)
	RenderingServer.global_shader_parameter_set(MASK, null)
	_weight = 0.
	_opening_recovery = 0.
	_contrast = Vector4.ZERO
	_shift = Vector2.ZERO
	_local_region = Vector4.ZERO
	_local_shift = Vector2.ZERO
	_softness = 0.
	_softness_loaded = false
	_soft_path = ""
	_texture = null
	_path = ""
