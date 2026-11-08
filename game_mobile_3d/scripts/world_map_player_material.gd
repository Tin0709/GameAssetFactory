extends RefCounted
## Strict PBR adapter. No source assets or native bytecode are embedded here.
const SHADER=preload("res://materials/world_map_player_pbr.gdshader")
const CB_PATH="godot_lab/world_map_unified_showcase_v001/player_light_audit_v001/hero_draws/event856_PIX_GENERIC_PIPELINE_STAGE_PS_r3.bin"
const CB_SHA="e364754a2009f38b96e60362eb9a6b8fcd6315a3f6d816570333ff1dc46e3d71"
const SKIN_RGBA_SHA="a08cb0963081657956181ca610a383b1384b101ee3129f95d5166226c7ec2025"
const ORM_RGBA_SHA="99d8ff9d3c111806dbdd7c85cda9ba3def9620aa56cae793fd9cd8a2572b0c9b"
var variants:Dictionary={}
var profile:Dictionary={}
var skin_mask:Texture2D

func _init()->void:
	if not OS.has_feature("editor"):return
	var research:=OS.get_environment("MD2_RESEARCH_ROOT")
	if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
	var path:=research.path_join(CB_PATH)
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CB_SHA:return
	var values:=FileAccess.get_file_as_bytes(path).to_float32_array()
	if values.size()<40:return
	profile={"roughness":Vector3(values[35],values[36],values[37]),"self_light":values[28]}
	var mask_path:=research.path_join("extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Characters/Player/Skins/Valorie/T_Valorie_MRES.png")
	if FileAccess.file_exists(mask_path):
		var image:=Image.load_from_file(mask_path)
		if image!=null and image.get_size()==Vector2i(64,64):
			image.convert(Image.FORMAT_RGBA8)
			var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data())
			if digest.finish().hex_encode()=="26e10dc3da0acbb9e319b5e0e2fc7a476fcdfe51dace0c0dc10eb0ed69938abc":
				var alpha:=PackedByteArray();var bytes:=image.get_data()
				for i in 4096:alpha.append(bytes[i*4+3])
				skin_mask=ImageTexture.create_from_image(Image.create_from_data(64,64,false,Image.FORMAT_R8,alpha))

func available()->bool:
	return RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null \
		and not ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_vertex_shading") \
		and not ProjectSettings.get_setting("rendering/lights_and_shadows/use_physical_light_units",false)

func source_skin(node:MeshInstance3D,source:BaseMaterial3D)->bool:
	if profile.is_empty() or not str(node.name) in ["SabrePrototypeBody","SabrePrototypeFace"]:return false
	return texture_matches(source.albedo_texture,SKIN_RGBA_SHA) and texture_matches(source.roughness_texture,ORM_RGBA_SHA) \
		and source.roughness_texture==source.metallic_texture and source.roughness_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_GREEN \
		and source.metallic_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_BLUE and source.roughness==1.0

func texture_matches(texture:Texture2D,sha:String)->bool:
	if texture==null:return false
	var image:=texture.get_image()
	if image==null or image.get_size()!=Vector2i(64,64):return false
	image.convert(Image.FORMAT_RGBA8)
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data())
	return digest.finish().hex_encode()==sha

func supports(node:MeshInstance3D,source:BaseMaterial3D)->bool:
	if not source is StandardMaterial3D:return false
	if node.material_override!=null or source.next_pass!=null or source.albedo_texture==null:return false
	if (source.cull_mode!=BaseMaterial3D.CULL_DISABLED or source.texture_filter!=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		or source.texture_repeat or not source.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]
		or source.shading_mode!=BaseMaterial3D.SHADING_MODE_PER_PIXEL
		or source.diffuse_mode!=BaseMaterial3D.DIFFUSE_BURLEY or source.specular_mode!=BaseMaterial3D.SPECULAR_SCHLICK_GGX
		or source.depth_draw_mode!=BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
		or source.uv1_scale!=Vector3.ONE or source.uv1_offset!=Vector3.ZERO
		or source.vertex_color_use_as_albedo or source.disable_ambient_light or source.disable_receive_shadows or source.disable_fog):return false
	if source.alpha_antialiasing_mode!=BaseMaterial3D.ALPHA_ANTIALIASING_OFF or source.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED \
		or source.grow or source.proximity_fade_enabled or source.distance_fade_mode!=BaseMaterial3D.DISTANCE_FADE_DISABLED:return false
	# These two inert flags are allowed only because vertex color and height mapping
	# have already been excluded. All other non-feature behavior needs a new adapter.
	for flag in BaseMaterial3D.FLAG_MAX:
		if source.get_flag(flag) and not flag in [BaseMaterial3D.FLAG_SRGB_VERTEX_COLOR,BaseMaterial3D.FLAG_INVERT_HEIGHTMAP]:return false
	for feature in BaseMaterial3D.FEATURE_MAX:
		if feature!=BaseMaterial3D.FEATURE_EMISSION and source.get_feature(feature):return false
	return true

func variant(cutout:bool,direct:bool,sky:bool)->Shader:
	var key:=str([cutout,direct,sky])
	if not variants.has(key):
		var header:="shader_type spatial;"
		if cutout:header+="\n#define GAF_PLAYER_CUTOUT"
		if direct:header+="\n#define GAF_PLAYER_DIRECT"
		if sky:header+="\n#define GAF_PLAYER_SKY"
		var code:=SHADER.code.replace("shader_type spatial;",header)
		if ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_lambert_over_burley"):
			code=code.replace("diffuse_burley","diffuse_lambert").replace(header,header+"\n#define GAF_WORLD_FORCE_LAMBERT")
		var shader:=Shader.new();shader.code=code;variants[key]=shader
	return variants[key]

func channel(value:int)->Vector4:
	if value==BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE:return Vector4(1./3.,1./3.,1./3.,0)
	var result:=Vector4.ZERO;result[value]=1.;return result

func create(node:MeshInstance3D,source:BaseMaterial3D,tint:Color)->ShaderMaterial:
	if not available() or not supports(node,source):return null
	var m:=ShaderMaterial.new();m.shader=variant(source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,false,false)
	m.render_priority=source.render_priority
	for pair:Array in [["atlas",source.albedo_texture],["albedo_tint",tint],["metal_map",source.metallic_texture],["rough_map",source.roughness_texture],
		["metal_channel",channel(source.metallic_texture_channel)],["rough_channel",channel(source.roughness_texture_channel)],
		["native_metallic",source.metallic],["native_roughness",source.roughness],["native_specular",source.metallic_specular],
		["cutout",source.alpha_scissor_threshold],["glow_map",source.emission_texture],["glow_tint",source.emission],
		["glow_energy",source.emission_energy_multiplier],["glow_enabled",source.emission_enabled],["glow_add",source.emission_operator==BaseMaterial3D.EMISSION_OP_ADD]]:
		m.set_shader_parameter(pair[0],pair[1])
	var verified:=source_skin(node,source);m.set_meta("verified_valorie",verified)
	if verified:
		m.set_shader_parameter("roughness_transform",profile.roughness);m.set_shader_parameter("self_light_scale",profile.self_light)
		if skin_mask!=null:m.set_shader_parameter("skin_profile_mask",skin_mask);m.set_meta("has_profile_mask",true)
	return m
