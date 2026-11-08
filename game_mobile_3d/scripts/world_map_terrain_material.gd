extends RefCounted
## Opaque unit-UV terrain contract. Existing atlas/grade/sampling stays owned by Look.
const PARAMETERS=["terrain_pbr_enabled","terrain_has_metal","terrain_has_rough","terrain_metal_map","terrain_rough_map","terrain_metal_channel","terrain_rough_channel","terrain_glow_map","terrain_glow_enabled","terrain_glow_add","terrain_glow_tint","terrain_glow_energy"]
static func supported(s:BaseMaterial3D)->bool:
	if not s is StandardMaterial3D or s.next_pass!=null or s.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:return false
	if s.uv1_scale!=Vector3.ONE or s.uv1_offset!=Vector3.ZERO or s.uv1_triplanar or s.emission_on_uv2:return false
	if s.shading_mode!=BaseMaterial3D.SHADING_MODE_PER_PIXEL or s.diffuse_mode!=BaseMaterial3D.DIFFUSE_BURLEY or s.specular_mode!=BaseMaterial3D.SPECULAR_SCHLICK_GGX:return false
	if s.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED or s.grow or s.proximity_fade_enabled or s.distance_fade_mode!=BaseMaterial3D.DISTANCE_FADE_DISABLED:return false
	if s.depth_draw_mode!=BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY:return false
	for flag in BaseMaterial3D.FLAG_MAX:
		if s.get_flag(flag) and not flag in [BaseMaterial3D.FLAG_ALBEDO_FROM_VERTEX_COLOR,BaseMaterial3D.FLAG_SRGB_VERTEX_COLOR,BaseMaterial3D.FLAG_INVERT_HEIGHTMAP,BaseMaterial3D.FLAG_USE_TEXTURE_REPEAT]:return false
	if (s.metallic_texture!=null or s.roughness_texture!=null or (s.emission_enabled and s.emission_texture!=null)) and (s.texture_repeat or s.texture_filter!=BaseMaterial3D.TEXTURE_FILTER_NEAREST):return false
	for feature in BaseMaterial3D.FEATURE_MAX:
		if feature!=BaseMaterial3D.FEATURE_EMISSION and s.get_feature(feature):return false
	return true
static func channel(value:int)->Vector4:
	if value==BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE:return Vector4(1./3.,1./3.,1./3.,0)
	var result:=Vector4.ZERO;result[value]=1.;return result
static func bind(m:ShaderMaterial,s:BaseMaterial3D,enabled:bool)->void:
	enabled=enabled and supported(s)
	m.set_shader_parameter("native_roughness",s.roughness if enabled else 1.)
	m.set_shader_parameter("native_metallic",s.metallic if enabled else 0.)
	m.set_shader_parameter("native_specular",s.metallic_specular if enabled else 0.)
	m.set_shader_parameter("terrain_pbr_enabled",enabled)
	if not enabled:return
	for pair in [["terrain_has_metal",s.metallic_texture!=null],["terrain_has_rough",s.roughness_texture!=null],
		["terrain_metal_map",s.metallic_texture],["terrain_rough_map",s.roughness_texture],
		["terrain_metal_channel",channel(s.metallic_texture_channel)],["terrain_rough_channel",channel(s.roughness_texture_channel)],
		["terrain_glow_map",s.emission_texture],["terrain_glow_enabled",s.emission_enabled],["terrain_glow_add",s.emission_operator==BaseMaterial3D.EMISSION_OP_ADD],
		["terrain_glow_tint",s.emission],["terrain_glow_energy",s.emission_energy_multiplier]]:m.set_shader_parameter(pair[0],pair[1])
