extends RefCounted
## Applies secondary shaders to WorldMap-owned materials while terrain shadow tiles can be used.

const SOURCE := &"gaf_far_shadow_source"
const MIST_BASE := &"gaf_mist_base"
const COMPILE_SWITCH := "#define GAF_FAR_TERRAIN_SHADOWS"
const RECEIVER_INCLUDES := [
	"world_map_direct_cloud.gdshaderinc",
	"world_map_foliage_light.gdshaderinc",
	"world_map_grass_light.gdshaderinc",
	"world_map_player_light.gdshaderinc",
]

var mist_variant: Callable
var _variants := {}
var _generated := {}
var _bound := {}
var bound_count: int:
	get:
		return _bound.size()


static func authored_shader(shader: Shader) -> Shader:
	if shader == null:
		return null
	var base: Shader = shader.get_meta(MIST_BASE, shader)
	return base.get_meta(SOURCE, base)


func prepare(materials: Array, other_shaders: Array[Shader]) -> void:
	var sources := {}
	for material: ShaderMaterial in materials:
		if material != null and material.shader != null:
			sources[material.shader.get_meta(MIST_BASE, material.shader)] = true
	for shader in other_shaders:
		sources[shader] = true
	for source: Shader in sources:
		var variant := _variant_for(source)
		if variant == null:
			continue
		variant.get_shader_uniform_list()
		if mist_variant.is_valid() and source.code.contains("GAF_SHARED_MIST"):
			var wrapped: Shader = mist_variant.call(variant)
			wrapped.get_shader_uniform_list()


func bind(materials: Array) -> bool:
	var visible := {}
	var changed := false
	for material: ShaderMaterial in materials:
		if material == null:
			continue
		var key := material.get_instance_id()
		if visible.has(key):
			continue
		visible[key] = true
		var current := material.shader
		if _owns(current):
			continue
		var variant := _variant_for(current)
		if variant == null:
			_bound.erase(key)
			continue
		_bound[key] = {"material": weakref(material), "original": current}
		material.shader = variant
		changed = true
	for key: int in _bound.keys():
		if not visible.has(key):
			changed = _restore(key) or changed
	return changed


func release() -> bool:
	var changed := false
	for key: int in _bound.keys():
		changed = _restore(key) or changed
	return changed


func _restore(key: int) -> bool:
	var record: Dictionary = _bound[key]
	_bound.erase(key)
	var material: ShaderMaterial = record.material.get_ref()
	if material == null or not _owns(material.shader):
		return false
	material.shader = record.original
	return true


func _owns(shader: Shader) -> bool:
	if shader == null:
		return false
	var base: Shader = shader.get_meta(MIST_BASE, shader)
	return _generated.has(base)


func _variant_for(source: Shader) -> Shader:
	if source == null:
		return null
	if _variants.has(source):
		return _variants[source]
	if not _supports(source.code):
		_variants[source] = null
		return null
	var base: Shader = source.get_meta(MIST_BASE, source)
	var variant_base: Shader
	if base != source:
		variant_base = _variant_for(base)
		if variant_base == null:
			_variants[source] = null
			return null
	var variant: Shader
	if variant_base != null and mist_variant.is_valid():
		variant = mist_variant.call(variant_base)
	else:
		variant = Shader.new()
		variant.code = source.code.replace("shader_type spatial;", "shader_type spatial;\n" + COMPILE_SWITCH)
	variant.set_meta(SOURCE, source)
	if variant_base != null:
		variant.set_meta(MIST_BASE, variant_base)
	else:
		_generated[variant] = true
	_variants[source] = variant
	return variant


func _supports(code: String) -> bool:
	if not code.contains("shader_type spatial;") or code.contains(COMPILE_SWITCH):
		return false
	if code.contains("#ifdef GAF_FAR_TERRAIN_SHADOWS"):
		return true
	for include: String in RECEIVER_INCLUDES:
		if code.contains(include):
			return true
	return false
