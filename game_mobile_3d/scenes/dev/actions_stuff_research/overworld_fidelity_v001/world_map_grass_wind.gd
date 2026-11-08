extends RefCounted
## Reuses external wind evidence only; never applies the source graphics preset.
const BOUNDS=preload("graphics_review_v001/wind_bounds.gd")
var configured:=false
var error:=""
var data:Dictionary={}
var noise:Texture2D
var _radii:Dictionary={}

func setup(reader:RefCounted)->void:
	var research:=OS.get_environment("MD2_RESEARCH_ROOT")
	if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
	var path:=research.path_join("godot_lab/world_map_unified_showcase_v001/grass_wind_v001/profile.private.json")
	if not reader.permitted(path) or not FileAccess.file_exists(path):error="Private wind evidence unavailable";return
	var profile:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not profile is Dictionary or profile.get("schema","")!="private_world_grass_wind_v1":error="Invalid wind manifest";return
	var file:Variant=profile.get("source_profile")
	if not file is String or not reader.permitted(file) or not FileAccess.file_exists(file) or FileAccess.get_sha256(file)!=profile.get("source_profile_sha256",""):
		error="Source wind profile missing or changed";return
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
	if not parsed is Dictionary or not parsed.get("background_wind") is Dictionary:error="Invalid source wind profile";return
	var wind:Dictionary=parsed.background_wind
	for key:String in ["gain","pin_m","ramp_m","max_m","time_bias","speed","spatial"]:
		var value:Variant=wind.get(key)
		if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)):error="Invalid wind parameter "+key;return
	if wind.gain<0. or wind.gain>PI or wind.pin_m<0. or wind.ramp_m<=0. or wind.max_m<0. or wind.spatial<=0. or wind.speed<0.:
		error="Wind parameters outside supported range";return
	for key:String in ["axis"]:
		if not _vec2(wind.get(key)):error="Invalid wind axis";return
	if Vector2(wind.axis[0]+.01,wind.axis[1]+.01).length()<.000001:error="Zero wind axis";return
	if not _vec2(parsed.get("grass_world_origin_cm")):error="Invalid wind world origin";return
	var image:Variant=parsed.get("grass_noise_path")
	if not image is String or not reader.permitted(image) or not FileAccess.file_exists(image) or FileAccess.get_sha256(image)!=parsed.get("grass_noise_sha256",""):
		error="Captured noise texture missing or changed";return
	var pixels:=Image.load_from_file(image)
	if pixels==null or pixels.is_empty():error="Captured wind noise cannot decode";return
	noise=ImageTexture.create_from_image(pixels);data=parsed;configured=true

func _vec2(value:Variant)->bool:
	if not value is Array or value.size()!=2:return false
	for x:Variant in value:
		if typeof(x) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(x)):return false
	return true

func apply(materials:Array[ShaderMaterial],enabled:bool)->void:
	for mat:ShaderMaterial in materials:
		var active:bool=configured and enabled and mat.get_shader_parameter("tinted_grass")==true
		mat.set_shader_parameter("review_source_wind",active)
		if not active:continue
		var w:Dictionary=data.background_wind
		mat.set_shader_parameter("review_grass_noise",noise)
		mat.set_shader_parameter("review_world_origin_cm",Vector2(data.grass_world_origin_cm[0],data.grass_world_origin_cm[1]))
		mat.set_shader_parameter("review_wind_axis",Vector2(w.axis[0],w.axis[1]))
		for pair:Array in [["gain","gain"],["pin_m","pin_m"],["ramp_m","ramp_m"],["max_m","max_m"],["time_bias","time_bias"],["speed","speed"],["spatial","spatial"]]:
			mat.set_shader_parameter("review_wind_"+pair[0],w[pair[1]])

func margin(mm:MultiMesh,node_basis:Basis)->float:
	if not configured:return .8
	var mesh:Mesh=mm.mesh
	if not _radii.has(mesh):
		var radius:=0.
		for s in mesh.get_surface_count():
			var a:=mesh.surface_get_arrays(s);var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var roots:PackedVector2Array=a[Mesh.ARRAY_TEX_UV2]
			for i in vertices.size():radius=maxf(radius,vertices[i].distance_to(Vector3(roots[i].x,0.,roots[i].y)))
		_radii[mesh]=radius
	var scale:=0.
	for i in mm.instance_count:scale=maxf(scale,BOUNDS.norm_bound(mm.get_instance_transform(i).basis))
	var conversion:float=BOUNDS.norm_bound(node_basis)*BOUNDS.norm_bound(node_basis.inverse())
	return .8+2.*float(_radii[mesh])*scale*conversion*sin(float(data.background_wind.gain)*.5)

func snapshot()->Dictionary:
	return {"configured":configured,"error":error,"gain":data.get("background_wind",{}).get("gain",0.),"scope":"Recovered background wind permutation; world phase, composite pivots and existing contact field are adapters"}
