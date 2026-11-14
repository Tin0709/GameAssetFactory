extends RefCounted
## Original Mobile transfer policy; source-derived phase data stay private.
const FILE="godot_lab/world_map_unified_showcase_v001/deepdark_entrance_v001/appearance.private.json"
const SHA="741d37edf0740caac71bae975cc715b6e42d2a0a074f4dfda54a91eb211abb5c"
const FLOATS=["key_scale","ambient_energy_scale","fog_begin","fog_end","fog_opacity","glow_scale","bloom_scale","contrast_scale","saturation_scale","vignette","player_light_weight","volume_density","height_falloff"]
const VECTORS=["key_color_scale","ambient_tint","fog_color","player_light_color"]
var phases:Array=[]
var player_range:=0.
func _init(reference_path: String = FILE, reference_hash: String = SHA):
	if not OS.has_feature("editor"):return
	var research:=OS.get_environment("MD2_RESEARCH_ROOT")
	if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
	var path:=research.path_join(reference_path)
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=reference_hash:return
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema")!="gaf-private-forest-atmosphere/1":return
	var rows=data.get("phases",[])
	if not rows is Array or rows.size()!=4:return
	for row in rows:
		if not row is Dictionary:return
		for key in FLOATS:
			var v=row.get(key)
			if not (v is float or v is int) or not is_finite(v) or v<0 or v>100:return
		for key in VECTORS:
			var v=row.get(key)
			if not v is Array or v.size()!=3:return
			for n in v:
				if not (n is float or n is int) or not is_finite(n) or n<0 or n>8:return
		if row.fog_end<=row.fog_begin or row.fog_opacity>1 or row.vignette>1:return
	var radius=data.get("player_light_range_m")
	if not (radius is float or radius is int) or not is_finite(radius) or radius<=0 or radius>100:return
	player_range=radius
	phases=rows
func available()->bool:
	return phases.size()==4 and RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null and not ProjectSettings.get_setting("rendering/lights_and_shadows/use_physical_light_units",false)
func sample(hour:float)->Dictionary:
	if phases.size()!=4:return {}
	var hours=[0.,7.,12.,16.5,22.,24.];var indices=[3,0,1,2,3,3]
	var h:=fposmod(hour,24.) if is_finite(hour) else 12.;var i:=0
	while i<4 and h>hours[i+1]:i+=1
	var weight:=smoothstep(hours[i],hours[i+1],h);var a:Dictionary=phases[indices[i]];var b:Dictionary=phases[indices[i+1]];var result={}
	for key in FLOATS:result[key]=lerpf(a[key],b[key],weight)
	for key in VECTORS:
		var x:Vector3=Vector3(a[key][0],a[key][1],a[key][2]);var y:Vector3=Vector3(b[key][0],b[key][1],b[key][2])
		if key=="fog_color":
			var color:=Color(x.x,x.y,x.z).srgb_to_linear().lerp(Color(y.x,y.y,y.z).srgb_to_linear(),weight).linear_to_srgb()
			result[key]=Vector3(color.r,color.g,color.b)
		else:result[key]=x.lerp(y,weight)
	return result
