extends RefCounted
## Captured parameter stays external; lighting response is independently authored.
const GROUND_SKY_PATH = "res://assets/graphics/world_map_terrain_transport_v001/grass_sky.res"
var world:Node3D
var configured:=false
var active:=false
var error:=""
var weight:=0.
var _records:Array[Dictionary]=[]
var _variants:Dictionary={}
var _ground_sky:Texture2D
var _ground_sky_checked:=false
var _ground_sky_state:=Vector4.INF
var _grass_shade_color := Vector3.INF
var _grass_root_tone := -1.
var _night_albedo := -1.
var _shadow_height_scale := -1.

func setup(level:Node3D,reader:RefCounted)->void:
	world=level
	var research:=OS.get_environment("MD2_RESEARCH_ROOT")
	if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
	var path:=research.path_join("godot_lab/grass_normal_response_v001/profile.private.json")
	if not OS.has_feature("editor") or not reader.permitted(path) or not FileAccess.file_exists(path):
		error="Private captured grass-normal parameter unavailable";return
	var p:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not p is Dictionary or p.get("schema","")!="private_grass_normal_parameter_v1":error="Invalid grass normal profile";return
	var file:Variant=p.get("parameter_path")
	var offset:Variant=p.get("byte_offset")
	if not file is String or typeof(offset) not in [TYPE_INT,TYPE_FLOAT]:error="Invalid parameter reference";return
	if not is_finite(float(offset)) or float(offset)<0. or float(offset)!=floor(float(offset)):error="Invalid parameter offset";return
	if not reader.permitted(file) or not FileAccess.file_exists(file) or FileAccess.get_sha256(file)!=p.get("parameter_sha256",""):
		error="Captured grass parameter missing or changed";return
	var bytes:=FileAccess.get_file_as_bytes(file)
	if float(offset)>float(bytes.size()-4):error="Grass parameter outside payload";return
	weight=bytes.decode_float(int(offset))
	if not is_finite(weight) or weight<0. or weight>1.:error="Invalid captured normal weight";return
	configured=true

func supported()->bool:
	return configured and RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null and not ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_vertex_shading")

func restore()->void:
	for row:Dictionary in _records:
		if preload("res://scripts/world_map_atmosphere_volume.gd").base_shader(row.material.shader)==row.variant:row.material.shader=row.original
	_records.clear();active=false
	_ground_sky_state=Vector4.INF
	_grass_shade_color = Vector3.INF
	_grass_root_tone = -1.
	_night_albedo = -1.
	_shadow_height_scale = -1.

func apply(materials:Array[ShaderMaterial],enabled:bool)->void:
	restore()
	if not enabled or not supported():return
	for material:ShaderMaterial in materials:
		if material.get_shader_parameter("tinted_grass")!=true:continue
		var source:Shader=preload("res://scripts/world_map_atmosphere_volume.gd").base_shader(material.shader)
		if not _variants.has(source):
			var variant:=Shader.new();variant.resource_name="Grass lighting · captured world normal"
			var header:="shader_type spatial;\n#define GAF_REFERENCE_GRASS_LIGHTING"
			if ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_lambert_over_burley"):header+="\n#define GAF_GRASS_FORCE_LAMBERT"
			variant.code=source.code.replace("shader_type spatial;",header)
			_variants[source]=variant
		var shader:Shader=_variants[source]
		_records.append({"material":material,"original":source,"variant":shader})
		material.shader=shader
		material.set_shader_parameter("study_grass_up_weight",weight)
		material.set_shader_parameter("study_transmission",.1248)
	active=not _records.is_empty()
	if world.terrain_light != null:
		bind_regional_sky(world.terrain_light)
	sync()

func bind_regional_sky(transport: Node) -> void:
	for row in _records:
		transport.bind_regional_sky(row.material)

func sync()->void:
	if not active:return
	var look=world.look
	var ground:ShaderMaterial=look.terrain_materials[0][3]
	for row:Dictionary in _records:
		var m:ShaderMaterial=row.material
		m.set_shader_parameter("clouds_enabled",look.direct_clouds_active())
		m.set_shader_parameter("cloud_field",ground.get_shader_parameter("cloud_field"))
		m.set_shader_parameter("cloud_shape",ground.get_shader_parameter("cloud_shape"))
		m.set_shader_parameter("cloud_time",look.cloud_clock)
	_sync_ground_sky()
	var night_albedo: float = world.showcase.grass_night_albedo_mix()
	if night_albedo != _night_albedo:
		_night_albedo = night_albedo
		for row: Dictionary in _records:
			row.material.set_shader_parameter("study_grass_night_albedo", night_albedo)
	var shadow_scale: float = world.showcase.grass_shadow_height_scale()
	if shadow_scale != _shadow_height_scale:
		_shadow_height_scale = shadow_scale
		for row: Dictionary in _records:
			row.material.set_shader_parameter("study_grass_shadow_height",shadow_scale)

func _sync_ground_sky()->void:
	var terrain=world.terrain_light
	var blend:float=world.showcase.grass_sky_fill_mix_scale()
	var state:=Vector4.ZERO
	if blend>0. and terrain!=null and terrain.is_active():
		if not _ground_sky_checked:
			_ground_sky_checked=true
			if ResourceLoader.exists(GROUND_SKY_PATH):
				var field:=load(GROUND_SKY_PATH) as Texture2D
				if field!=null and field.get_meta("origin",null) is Vector2 and field.get_meta("terrain_sha256","")==FileAccess.get_sha256(terrain.PATH):
					_ground_sky=field
		if _ground_sky!=null:
			var env:Environment=world.get_node("WorldEnvironment").environment
			var rgb:Vector3=terrain.ambient_tint(env)*terrain.ambient_scale(env)
			state=Vector4(rgb.x,rgb.y,rgb.z,blend)
	var shade_color: Vector3 = world.showcase.grass_shade_color_mix() if state.w > 0. else Vector3.ZERO
	var sky_changed := state != _ground_sky_state
	var color_changed := shade_color != _grass_shade_color
	var root_tone: float = world.showcase.grass_root_tone_mix()
	var root_changed := root_tone != _grass_root_tone
	if not sky_changed and not color_changed and not root_changed:
		return
	_ground_sky_state=state
	_grass_shade_color = shade_color
	_grass_root_tone = root_tone
	for row:Dictionary in _records:
		var material:ShaderMaterial=row.material
		if sky_changed:
			if state.w>0.:
				material.set_shader_parameter("study_ground_sky",_ground_sky)
				material.set_shader_parameter("study_ground_sky_origin",_ground_sky.get_meta("origin"))
				material.set_shader_parameter("study_ground_sky_scale",Vector3(state.x,state.y,state.z))
			material.set_shader_parameter("study_ground_sky_mix",state.w)
		if color_changed:
			material.set_shader_parameter("study_grass_shade_color", shade_color)
		if root_changed:
			material.set_shader_parameter("study_grass_root_tone", root_tone)

func snapshot()->Dictionary:
	return {"configured":configured,"active":active,"normal_weight":weight,"materials":_records.size(),"error":error,"normal_scope":"Captured Day grass world-normal consumer; other biome weights unverified","lighting_scope":"Original mobile transmission and alpha shadows, not native Lumen"}
