extends Node
## Original static GAF diffuse transport, not Lumen. Never owns global light/player.
const PATH="res://assets/graphics/world_map_terrain_transport_v001/transport.res"
const BRDF=preload("res://assets/graphics/world_map_air_light_v001/brdf.res")
var level:Node3D
var cache:Resource
var installed:=false
var error:=""
var _applied:=false
var _last_key:=Vector3.INF
var _last_scale:=-1.
var _last_tint:=Vector3.INF
var _last_response:Variant=null
var _last_dielectric:Variant=null
var _world_transforms:Dictionary={}
var _transforms_dirty:=false
var _transforms_valid:=true
class TransformWatch extends Node3D:
	var guard:Node
	func _notification(what:int)->void:
		if what==NOTIFICATION_TRANSFORM_CHANGED and is_instance_valid(guard):guard._transforms_dirty=true

static func signature(mesh:ArrayMesh,surface:int)->String:
	var a:=mesh.surface_get_arrays(surface)
	for slot in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2]:a[slot]=null
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(a));return h.finish().hex_encode()
static func material_digest(source:BaseMaterial3D,m:ShaderMaterial)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes([source.albedo_color,source.vertex_color_use_as_albedo]))
	h.update(var_to_bytes([m.get_shader_parameter("ground_grade"),m.get_shader_parameter("texture_contrast")]))
	if source.albedo_texture!=null:
		var im:=source.albedo_texture.get_image();if im.is_compressed():im.decompress()
		im.convert(Image.FORMAT_RGBA8);h.update(im.get_data())
	return h.finish().hex_encode()
func setup(world:Node3D)->void:
	level=world;process_priority=20
	if RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null and ResourceLoader.exists(PATH):
		cache=load(PATH);installed=_install()
	refresh()
func reject(message:String)->bool:error=message;return false
func _install()->bool:
	var energy:Variant=cache.get_meta("ambient_energy",null)
	if not (energy is float or energy is int) or not is_finite(float(energy)) or float(energy)<=0.:return reject("Invalid normalization profile")
	for key:String in ["ambient_srgb","sun_direction"]:
		var v:Variant=cache.get_meta(key,null)
		if not v is Array or v.size()!=3:return reject("Invalid normalization profile")
		for x in v:
			if not (x is float or x is int) or not is_finite(float(x)):return reject("Invalid normalization profile")
			if key=="ambient_srgb" and (float(x)<=0. or float(x)>1.):return reject("Invalid normalization profile")
	var d:Array=cache.get_meta("sun_direction")
	if absf(Vector3(d[0],d[1],d[2]).length()-1.)>.0001:return reject("Invalid normalization profile")
	if cache.get_meta("source_runtime_sha256","")!=FileAccess.get_sha256(level.DATA):return reject("Map changed")
	if cache.get_meta("surface_recipe_sha256","")!=FileAccess.get_sha256("res://materials/world_map_surface_v5.gdshaderinc"):return reject("Albedo recipe changed")
	if cache.get_meta("ambient_recipe_identity","")!=FileAccess.get_sha256("res://scripts/world_map_ambient.gd")+":"+FileAccess.get_sha256("res://materials/world_map_ambient.gdshader"):return reject("Ambient recipe changed")
	var fingerprints:Dictionary=cache.get_meta("material_fingerprints",{})
	for row in level.look.terrain_materials:
		if not preload("res://scripts/world_map_terrain_material.gd").supported(row[2]):return reject("Unsupported diffuse material")
		if fingerprints.get(row[2].resource_name,"")!=material_digest(row[2],row[3]) or row[2].metallic!=0. or row[2].emission_enabled:return reject("Original diffuse material changed")
	var sky:PackedFloat32Array=cache.get_meta("sky",PackedFloat32Array());var sun:PackedFloat32Array=cache.get_meta("sun",PackedFloat32Array())
	if sky.size()!=int(cache.get_meta("count",0))*3 or sky.size()!=sun.size():return reject("Cache length mismatch")
	for values in [sky,sun]:
		for v in values:
			if not is_finite(v) or v<0. or v>4.:return reject("Invalid irradiance")
	var chunks={};var expected:=0
	for chunk:MeshInstance3D in level.geometry.terrain_chunks:chunks[str(chunk.name)]=chunk;expected+=chunk.mesh.get_surface_count()
	var rows:Array=cache.get_meta("rows",[])
	if rows.size()!=expected:return reject("Incomplete coverage")
	var indexed={};var next:=0
	for row in rows:
		var chunk:MeshInstance3D=chunks.get(row.chunk);var s:=int(row.surface);var key:=str(row.chunk)+":"+str(s)
		if chunk==null or s<0 or s>=chunk.mesh.get_surface_count() or indexed.has(key):return reject("Invalid surface")
		var a:=chunk.mesh.surface_get_arrays(s)
		var t:Array=row.get("world_transform",[])
		if t.size()!=12:return reject("World transform missing")
		for v in t:
			if not (v is float or v is int) or not is_finite(float(v)):return reject("World transform changed")
		var baked:=Transform3D(Basis(Vector3(t[0],t[1],t[2]),Vector3(t[3],t[4],t[5]),Vector3(t[6],t[7],t[8])),Vector3(t[9],t[10],t[11]))
		if not baked.is_finite() or not baked.is_equal_approx(chunk.global_transform):return reject("World transform changed")
		_world_transforms[chunk]=baked
		if int(row.start)!=next or int(row.count)!=a[Mesh.ARRAY_VERTEX].size() or signature(chunk.mesh,s)!=str(row.signature):return reject("Source geometry changed")
		if a[Mesh.ARRAY_CUSTOM1]!=null or a[Mesh.ARRAY_CUSTOM2]!=null:return reject("Custom stream already owned")
		indexed[key]=row;next+=int(row.count)
	if next*3!=sky.size():return reject("Coverage count mismatch")
	var replacements={};var candidates={}
	for name:String in chunks:
		var old:ArrayMesh=chunks[name].mesh;var mesh:=ArrayMesh.new()
		for s in old.get_surface_count():
			var a:=old.surface_get_arrays(s);var row:Dictionary=indexed[name+":"+str(s)]
			var begin:=int(row.start)*3;var end:=begin+int(row.count)*3
			a[Mesh.ARRAY_CUSTOM1]=sky.slice(begin,end);a[Mesh.ARRAY_CUSTOM2]=sun.slice(begin,end)
			var flags:=old.surface_get_format(s)|Mesh.ARRAY_FORMAT_CUSTOM1|Mesh.ARRAY_FORMAT_CUSTOM2|(Mesh.ARRAY_CUSTOM_RGB_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)|(Mesh.ARRAY_CUSTOM_RGB_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
			mesh.add_surface_from_arrays(old.surface_get_primitive_type(s),a,[],{},flags)
			if mesh.get_surface_count()!=s+1 or signature(mesh,s)!=str(row.signature):return reject("Runtime stream altered authored geometry")
			mesh.surface_set_material(s,old.surface_get_material(s))
		candidates[name]=mesh;replacements[old]=mesh
	# No scene mutation until every row and every candidate has validated.
	level.geometry.reset_cutaway_materials()
	for name:String in candidates:
		chunks[name].mesh=candidates[name];chunks[name].get_node("NativeShadowCaster").mesh=candidates[name]
	for row in level.look.terrain_materials:row[0]=replacements[row[0]]
	for chunk:Node3D in _world_transforms:
		var watch:=TransformWatch.new();watch.name="TransportTransformGuard";watch.guard=self;chunk.add_child(watch);watch.set_notify_transform(true)
	_transforms_dirty=false
	return true
func available()->bool:
	if _transforms_dirty:
		_transforms_dirty=false;_transforms_valid=true
		for chunk:Node3D in _world_transforms:
			if not is_instance_valid(chunk) or not chunk.global_transform.is_equal_approx(_world_transforms[chunk]):_transforms_valid=false;break
	if not _transforms_valid:return false
	if not installed or not level.ambient.is_active() or level.look.stage!=2:return false
	if ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_vertex_shading") or ProjectSettings.get_setting("rendering/lights_and_shadows/use_physical_light_units",false):return false
	if level.terrain_sky.enabled or not level.look.direct_clouds_active() or not level.look.day_finish_active() or not level.look.day_composition_active():return false
	var forest_sky:bool=level.showcase.forest_spatial_sky_context()
	if level.showcase.private_primary and not level.showcase.is_day_anchor() and not forest_sky:return false
	var sun:DirectionalLight3D=level.get_node("Sun");var d:Array=cache.get_meta("sun_direction",[])
	if not is_finite(sun.light_energy) or sun.light_energy<0.:return false
	for v in [sun.light_color.r,sun.light_color.g,sun.light_color.b]:
		if not is_finite(v) or v<0.:return false
	if d.size()!=3 or not sun.is_visible_in_tree() or not sun.shadow_enabled:return false
	if sun.global_basis.z.normalized().dot(Vector3(d[0],d[1],d[2]))<cos(deg_to_rad(.1)) and not forest_sky:return false
	var env:Environment=level.get_node("WorldEnvironment").environment;var color:Array=cache.get_meta("ambient_srgb",[])
	if color.size()!=3:return false
	var source:=Color(color[0],color[1],color[2])
	var matches:bool=env.ambient_light_color.is_equal_approx(source) or level.showcase.terrain_ambient_matches(env.ambient_light_color,source)
	return matches and is_finite(env.ambient_light_energy) and env.ambient_light_energy>=0.
func is_active()->bool:return available() and level.look.terrain_review in ["lighting","combined"]
func refresh()->void:
	var active:=is_active()
	if active!=_applied:
		_applied=active;level.look._refresh_ground_bounce()
	bind()

func ambient_scale(env:Environment)->float:
	return env.ambient_light_energy/float(cache.get_meta("ambient_energy"))

func ambient_tint(env:Environment)->Vector3:
	var original:Array=cache.get_meta("ambient_srgb")
	var source:=Color(original[0],original[1],original[2]).srgb_to_linear()
	var now:=env.ambient_light_color.srgb_to_linear()
	return Vector3(now.r/source.r,now.g/source.g,now.b/source.b)

func bind(force:bool=false)->void:
	if not is_active():return
	var sun:DirectionalLight3D=level.get_node("Sun");var c:=sun.light_color.srgb_to_linear();var key:=Vector3(c.r,c.g,c.b)*sun.light_energy
	var direction:Array=cache.get_meta("sun_direction")
	if not level.look._ground_bounce_requested or sun.global_basis.z.normalized().dot(Vector3(direction[0],direction[1],direction[2]))<cos(deg_to_rad(.1)):key=Vector3.ZERO
	var env:Environment=level.get_node("WorldEnvironment").environment
	var scale:=ambient_scale(env)
	var tint:=ambient_tint(env)
	var response:bool=level.look.terrain_visibility_response
	var dielectric:bool=level.look.terrain_dielectric_response and level.look.terrain_review=="combined"
	if not force and key==_last_key and scale==_last_scale and tint==_last_tint and response==_last_response and dielectric==_last_dielectric:return
	_last_key=key;_last_scale=scale;_last_tint=tint;_last_response=response
	_last_dielectric=dielectric
	var materials={}
	for row in level.look.terrain_materials:materials[row[3]]=true
	for chunk in level.geometry._cutaway_chunks:
		for m in chunk.materials:materials[m]=true
	for m:ShaderMaterial in materials:
		m.set_shader_parameter("terrain_key_radiance",key);m.set_shader_parameter("terrain_ambient_scale",scale);m.set_shader_parameter("terrain_ambient_tint",tint)
		m.set_shader_parameter("terrain_colored_visibility",response)
		var compatible:bool=dielectric and is_zero_approx(float(m.get_shader_parameter("native_metallic")))
		m.set_shader_parameter("terrain_dielectric_response",compatible);m.set_shader_parameter("terrain_rough_reflection",compatible);m.set_shader_parameter("terrain_env_brdf",BRDF)
func _process(_delta:float)->void:refresh()
