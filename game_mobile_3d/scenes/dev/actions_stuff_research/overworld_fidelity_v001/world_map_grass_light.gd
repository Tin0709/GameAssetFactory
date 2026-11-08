extends RefCounted
## Captured parameter stays external; lighting response is independently authored.
var world:Node3D
var configured:=false
var active:=false
var error:=""
var weight:=0.
var _records:Array[Dictionary]=[]
var _variants:Dictionary={}

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
		if row.material.shader==row.variant:row.material.shader=row.original
	_records.clear();active=false

func apply(materials:Array[ShaderMaterial],enabled:bool)->void:
	restore()
	if not enabled or not supported():return
	for material:ShaderMaterial in materials:
		if material.get_shader_parameter("tinted_grass")!=true:continue
		var source:Shader=material.shader
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
	sync()

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

func snapshot()->Dictionary:
	return {"configured":configured,"active":active,"normal_weight":weight,"materials":_records.size(),"error":error,"normal_scope":"Captured Day grass world-normal consumer; other biome weights unverified","lighting_scope":"Original mobile transmission and alpha shadows, not native Lumen"}
