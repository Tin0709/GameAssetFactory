extends RefCounted
## Editor-only transient private reference loader. No imported/cached assets in res://.
const PlantShader=preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/vegetation.gdshader")
const GroundShader=preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/solid.gdshader")
var error:=""
var data:Dictionary={}
var meshes:Dictionary={}
var textures:Dictionary={}
var materials:Array[ShaderMaterial]=[]
var _material_map:Dictionary={}
var root:=""

static func default_path()->String:
	var custom:=OS.get_environment("MD2_OVERWORLD_BUNDLE")
	if not custom.is_empty():return custom
	return OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research/godot_lab/overworld_fidelity_v001/bundle.private.json")

func permitted(path:String)->bool:
	if not OS.has_feature("editor") or not path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://"):return false
	var clean:=path.simplify_path().replace("\\","/").to_lower()
	var project:=ProjectSettings.globalize_path("res://").simplify_path().replace("\\","/").to_lower()
	return not clean.begins_with(project) and (root.is_empty() or clean.begins_with(root+"/"))

func read(path:String)->Dictionary:
	error="";data.clear();meshes.clear();textures.clear();materials.clear();_material_map.clear();root=""
	if not permitted(path) or not FileAccess.file_exists(path):return _fail("Private reference bundle unavailable; use its Research launcher (editor only).")
	root=path.simplify_path().replace("\\","/").get_base_dir().get_base_dir().get_base_dir().to_lower()
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema","")!="private_overworld_v1" or not parsed.get("private_only",false):return _fail("Invalid private bundle schema.")
	data=parsed
	var blend:String=data.get("source_blend","")
	if not permitted(blend) or not FileAccess.file_exists(blend) or FileAccess.get_sha256(blend)!=String(data.get("source_blend_sha256","")):return _fail("Approved Blender source changed; refresh the private bundle before review.")
	if data.get("assets",[]).is_empty() or data.get("assets",[]).size()>100:return _fail("Invalid asset count.")
	for entry:Dictionary in data.get("media",{}).values():
		var file:String=entry.get("path","")
		if not permitted(file) or not FileAccess.file_exists(file) or FileAccess.get_sha256(file)!=String(entry.get("sha256","")):return _fail("Missing or changed external image: "+file.get_file())
		var image:=Image.load_from_file(file)
		if image==null or image.is_empty():return _fail("Cannot decode image: "+file.get_file())
		textures[file]=ImageTexture.create_from_image(image)
	for key:String in data.get("materials",{}):
		var row:Dictionary=data.materials[key]
		if not textures.has(row.get("texture","")):return _fail("Unbound source atlas: "+key)
		var plant:bool=not String(row.source_material).contains("Terrain") and not String(row.source_material).contains("Boulder") and not String(row.source_material).contains("ForestAtlas")
		var mat:=ShaderMaterial.new();mat.shader=PlantShader if plant else GroundShader
		mat.set_shader_parameter("atlas",textures[row.texture]);mat.set_meta("source_material",row.source_material);mat.set_meta("evidence",row.get("material_state_status","unresolved"))
		mat.set_shader_parameter("cutoff",float(row.get("source_alpha_cutoff",row.get("inferred_alpha_cutoff",.3333))))
		for image_row:Dictionary in row.get("images",[]):
			if image_row.get("data",false) and textures.has(image_row.path):mat.set_shader_parameter("mre_map",textures[image_row.path]);mat.set_shader_parameter("has_mre",true)
		if plant:
			var palette:Array=row.get("grass_palette",[])
			mat.set_shader_parameter("tinted_grass",palette.size()==2)
			if palette.size()==2:
				mat.set_shader_parameter("base_tint",Vector3(palette[0][0],palette[0][1],palette[0][2]));mat.set_shader_parameter("tip_tint",Vector3(palette[1][0],palette[1][1],palette[1][2]))
			var motion:Dictionary=data.motion
			mat.set_shader_parameter("wind_intensity",float(motion.intensity));mat.set_shader_parameter("wind_direction",Vector2(motion.direction[0],motion.direction[1]));mat.set_shader_parameter("frequency",float(motion.frequency_adapter))
			materials.append(mat)
		_material_map[key]=mat
	for entry:Dictionary in data.assets:
		var mesh:=ArrayMesh.new()
		for surface:Dictionary in entry.surfaces:
			var count:int=surface.positions.size()/3
			if count<3 or count>200000 or surface.normals.size()!=count*3 or surface.uv.size()!=count*2 or surface.roots.size()!=count*2 or surface.motion.size()!=count*4:return _fail("Malformed vertex arrays: "+entry.name)
			var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=_v3(surface.positions);arrays[Mesh.ARRAY_NORMAL]=_v3(surface.normals)
			arrays[Mesh.ARRAY_TEX_UV]=_v2(surface.uv);arrays[Mesh.ARRAY_TEX_UV2]=_v2(surface.roots)
			arrays[Mesh.ARRAY_CUSTOM0]=PackedFloat32Array(surface.motion)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
			if mesh.get_surface_count()==0:return _fail("Cannot build mesh surface: "+entry.name)
			mesh.surface_set_material(mesh.get_surface_count()-1,_material_map[surface.material])
		meshes[entry.name]=mesh
	return data

func audio_stream(row:Dictionary)->AudioStreamOggVorbis:
	var path:String=row.get("path","")
	if not permitted(path) or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=String(row.get("sha256","")):return null
	return AudioStreamOggVorbis.load_from_file(path)

func _fail(message:String)->Dictionary:
	error=message;data.clear();meshes.clear();textures.clear();materials.clear();_material_map.clear();return {}
func _v3(a:Array)->PackedVector3Array:
	var out:=PackedVector3Array();out.resize(a.size()/3)
	for i in out.size():out[i]=Vector3(a[i*3],a[i*3+1],a[i*3+2])
	return out
func _v2(a:Array)->PackedVector2Array:
	var out:=PackedVector2Array();out.resize(a.size()/2)
	for i in out.size():out[i]=Vector2(a[i*2],a[i*2+1])
	return out
