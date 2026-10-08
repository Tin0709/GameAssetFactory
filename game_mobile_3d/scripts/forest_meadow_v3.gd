extends "res://scripts/forest_quality_slice.gd"
## Third, scene-local study. V2 and its sources remain available unchanged.
const MEADOW_ASSETS := "res://assets/environment/forest_canopy_v3/"
var v3_missing_assets: Array[String] = []

func _ready() -> void:
	super._ready()
	DisplayServer.window_set_title("Forest V3 · Leafy meadow · WASD/Shift · T/K zombies")

func ground_height(x: float, z: float) -> float:
	var h := super.ground_height(x,z)
	var p := Vector2(floorf(x)+.5,floorf(z)+.5)
	if layout.path_distance(p)<2.0 or p.length()<3.5: return h
	# A tall mineral/earth backdrop beyond the playable half-metre terraces.
	if p.x < -7.0 and p.y < -2.0: h=maxf(h,2.5)
	if p.x < -10.0 and p.y < -4.0: h=maxf(h,4.0)
	if p.x < -13.0 and p.y < -7.0: h=maxf(h,5.0)
	return h

func add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	var face_top := maxf(maxf(a.y,b.y),maxf(c.y,d.y))
	for vertex in [a,c,b,a,d,c]:
		st.set_normal(normal)
		st.set_uv2(Vector2(face_top,0))
		st.set_color(color*Color(contact_shade(vertex),contact_shade(vertex),contact_shade(vertex),1.0))
		st.add_vertex(vertex)
	forest_mesh_triangles+=2

func build_terraced_ground() -> void:
	forest_ground_material.shader=preload("res://materials/meadow_ground_v3.gdshader")
	super.build_terraced_ground()

func build_grove_assets() -> void:
	canopy_material.shader=preload("res://materials/meadow_canopy_v3.gdshader")
	var trees := [Vector4(-6.4,-1.8,1.05,.2),Vector4(-8.4,-6.6,1.05,1.7),Vector4(-4.8,-9.0,1.02,2.2),Vector4(2.3,-10.2,1.08,.9),Vector4(7.8,-5.3,.94,2.5),Vector4(-9.6,4.9,.85,.7),Vector4(8.3,5.4,.82,1.4),Vector4(-12,-12,1.10,0.0),Vector4(9.5,-13.2,1.20,1.8),Vector4(-14,0,.90,.0),Vector4(14,-3,1.08,.8)]
	for i in trees.size():
		var t: Vector4=trees[i]
		var asset: String="tree_oak_a" if i%2==0 else "tree_oak_b"
		place_asset(_meadow_asset(asset),Vector3(t.x,ground_height(t.x,t.y),t.y),t.z,t.w,true)
		contact_points.append(Vector3(t.x,1.18*t.z,t.y))
	var rng:=RandomNumberGenerator.new();rng.seed=71902
	for i in 74:
		var p:=Vector2(rng.randf_range(-16,16),rng.randf_range(-15,12))
		if layout.path_distance(p)<1.65 or p.length()<4.1:continue
		place_asset(_meadow_asset("shrub_fern" if i%3==0 else "shrub_leaf"),Vector3(p.x,ground_height(p.x,p.y),p.y),rng.randf_range(.65,1.2),rng.randf_range(0,TAU),false)

func _meadow_asset(name: String) -> String:
	var path:=MEADOW_ASSETS+name+".glb"
	var imported:=ConfigFile.new()
	if imported.load(path+".import")==OK:
		var cache_path: String=imported.get_value("remap","path","")
		if not cache_path.is_empty() and FileAccess.file_exists(cache_path):return path
	if not name in v3_missing_assets:v3_missing_assets.append(name)
	return FOREST_ASSET_PATH+name+".glb" # Temporary authoring fallback, validation rejects it.

func place_asset(path: String, at: Vector3, scale_value: float, angle: float, tree: bool) -> void:
	var previous_count:=forest.get_child_count()
	super.place_asset(path,at,scale_value,angle,tree)
	if forest.get_child_count()==previous_count:return
	var instance: Node=forest.get_child(forest.get_child_count()-1)
	for mesh in instance.find_children("*","MeshInstance3D",true,false):
		if "bark" in mesh.name.to_lower() or "trunk" in mesh.name.to_lower():mesh.material_override=null

func build_ruins() -> void:
	masonry_material.shader=preload("res://materials/meadow_masonry_v3.gdshader")
	super.build_ruins()

func build_forest_grass() -> void:
	forest_blade_material.shader=preload("res://materials/meadow_blades_v3.gdshader")
	var rng:=RandomNumberGenerator.new();rng.seed=83147
	var transforms: Array[Transform3D]=[]
	for z in range(-24,24):
		for x in range(-24,24):
			var p:=Vector2(x+rng.randf_range(.05,.95),z+rng.randf_range(.05,.95))
			var distance:=layout.path_distance(p)
			if distance<1.16 or p.length()<1.8:continue
			var grouping:=sin(p.x*.61+sin(p.y*.52))*sin(p.y*.34-.5)
			if rng.randf()>.55+grouping*.27:continue
			var height_scale:=rng.randf_range(.48,.92) if distance>2.0 else rng.randf_range(.34,.53)
			var basis:=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(1,height_scale,1))
			transforms.append(Transform3D(basis,Vector3(p.x,ground_height(p.x,p.y),p.y)))
	scatter_batch(mesh_from_scene(GRASS),transforms,forest_blade_material,"MeadowBroadGrass",true)

func set_forest_stage(stage: int) -> void:
	super.set_forest_stage(stage)
	if not forest_ready:return
	if forest_stage==2:
		var env: Environment=$WorldEnvironment.environment
		env.ambient_light_color=Color(.65,.73,.86)
		env.ambient_light_energy=.40
		env.tonemap_exposure=.96
		env.glow_enabled=true
		env.glow_bloom=.055
		env.glow_intensity=.45
		env.glow_strength=.85
		env.glow_hdr_threshold=.85
		env.glow_hdr_scale=1.0
		env.glow_blend_mode=Environment.GLOW_BLEND_MODE_SCREEN
		$Sun.light_energy=1.32
		$Sun.light_color=Color(1.0,.97,.91)
		$Sun.shadow_opacity=.66
	review_label.text="FOREST V3 · "+["EARLY QUALITY STUDY","MEADOW / PREVIOUS LIGHT","LEAFY MEADOW"][forest_stage]+"\nF1 early study · F2 geometry · F4 sunlight · Tab compare · WASD/Shift · T/K zombies"
