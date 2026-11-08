extends RefCounted
## Measured inclinations stay private; radial composition is an original adapter.
var configured:=false
var error:=""
var angles:Array[float]=[]

func setup(reader:RefCounted)->void:
	var research:=OS.get_environment("MD2_RESEARCH_ROOT")
	if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
	var path:=research.path_join("godot_lab/world_map_unified_showcase_v001/grass_splay_v001/profile.private.json")
	if not reader.permitted(path) or not FileAccess.file_exists(path):error="Private grass inclination evidence unavailable";return
	var profile:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not profile is Dictionary or profile.get("schema","")!="private_grass_splay_v1":error="Invalid grass inclination profile";return
	var file:Variant=profile.get("angles_path")
	if not file is String or not reader.permitted(file) or not FileAccess.file_exists(file):error="Private grass inclination data missing";return
	if FileAccess.get_sha256(file)!=profile.get("angles_sha256",""):error="Grass inclination evidence changed";return
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
	if not data is Dictionary or data.get("schema","")!="captured_grass_rest_inclinations_v1":error="Invalid grass inclination evidence";return
	var values:Variant=data.get("angle_degrees")
	if not values is Array or values.is_empty() or values.size()>4096:error="Invalid grass inclination count";return
	var checked:Array[float]=[]
	for value:Variant in values:
		if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)) or float(value)<0. or float(value)>=90.:
			error="Invalid grass inclination";return
		checked.append(deg_to_rad(float(value)))
	angles=checked;configured=true

func angle(index:int)->float:
	return angles[posmod(index*37,angles.size())] if configured else 0.

func snapshot()->Dictionary:
	return {"configured":configured,"samples":angles.size(),"error":error,"scope":"Captured pre-WPO inclinations; radial tuft composition is an original adapter"}
