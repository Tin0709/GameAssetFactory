extends SceneTree
## Missing/replaced asset, cliff-straddling cells, G shadow coupling and stale motion fail here.
const ASSET := "res://assets/environment/meadow_flowers_v1/white_flower_patch_1m.glb"
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("MEADOW FLOWERS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ResourceLoader.exists(ASSET),"Authored planar white flower patch is imported")
	var script = load("res://scripts/forest_meadow_v3.gd")
	var found_material := false
	for property in script.get_script_property_list():
		if property.name == "meadow_flower_material": found_material = true
	check(found_material,"V3 owns a motion-aware flower material")
	if not failures.is_empty(): finish(); return
	var level = load("res://scenes/ForestMeadowV3.tscn").instantiate()
	level.set_script(preload("res://tests/meadow_flower_fixture.gd"))
	root.add_child(level)
	current_scene = level
	level.set_enemies_enabled(false)
	for i in 8: await physics_frame
	var asset_root = load(ASSET).instantiate()
	var nodes: Array[Node] = asset_root.find_children("*","MeshInstance3D",true,false)
	check(nodes.size()==1,"Reusable block has one mesh")
	var mesh: Mesh = nodes[0].mesh
	check(mesh.get_surface_count()==1,"Reusable block has one surface")
	var native_material: StandardMaterial3D = mesh.surface_get_material(0)
	check(native_material.vertex_color_use_as_albedo and not native_material.vertex_color_is_srgb,"Reusable native flower material preserves linear vertex albedo")
	check(native_material.cull_mode==BaseMaterial3D.CULL_DISABLED,"Reusable opaque planar material draws both sides")
	var import_config := ConfigFile.new()
	check(import_config.load(ASSET+".import")==OK,"Authored flower import settings remain available for reuse")
	check(import_config.get_value("params","meshes/generate_lods",true)==false,"Generated decimation cannot break per-head motion metadata")
	check(import_config.get_value("params","meshes/light_baking",1)==0,"Dynamic vegetation excludes light baking and preserves UV2 roots")
	if DisplayServer.get_name()!="headless":
		var surface: Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),0)
		check(surface.get("lods",{}).is_empty(),"Native renderer retains authored topology without generated LODs")
	var a: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var roots: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	var colors: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	check((indices.size() if not indices.is_empty() else vertices.size())/3 <= 220,"Planar patch stays within authored triangle budget")
	check(uv.size()==vertices.size() and roots.size()==vertices.size() and colors.size()==vertices.size(),"Imported motion masks and linear albedo survive")
	check(mesh.get_aabb().size.x<=1.001 and mesh.get_aabb().size.z<=1.001,"Authored block footprint stays inside one metre")
	var heads := 0; var bases := 0; var white := 0; var yellow := 0
	for i in vertices.size():
		check(uv[i].x>=-.001 and uv[i].x<=1.001,"Normalized stem/head motion mask")
		var head_height := 1.0-uv[i].y # glTF flips the V coordinate during export.
		check(head_height>=.28 and head_height<=.45,"Per-flower head height is preserved")
		if uv[i].x>.999: heads+=1
		if vertices[i].y<.001:
			bases+=1
			check(absf(uv[i].x)<.001,"Root vertices anchored by mask")
			check(Vector2(vertices[i].x,vertices[i].z).distance_to(roots[i]-Vector2(.5,.5))<.04,"UV2 decodes the actual stem root after import")
		if colors[i].r>.7 and colors[i].g>.7 and colors[i].b>.7:
			white+=1
			check(absf(uv[i].x-1.0)<.001,"Every white petal vertex uses the rigid head mask")
		if colors[i].r>.5 and colors[i].g>.25 and colors[i].b<.2:
			yellow+=1
			check(absf(uv[i].x-1.0)<.001,"Every yellow center vertex uses the rigid head mask")
	check(heads>0 and bases>0 and white>0 and yellow>0,"Patch carries fixed roots, white petals and yellow centers")
	asset_root.free()
	var count := 0; var occupied: Dictionary = {}; var near := false
	var rendered: Array[Transform3D] = []
	for node in level.forest.get_children():
		if node is not MultiMeshInstance3D: continue
		check(not node.name.begins_with("ForestFlowers"),"V3 replaces cuboid flower accents")
		if not node.name.begins_with("MeadowWhiteFlowers"): continue
		check(node.material_override==level.meadow_flower_material,"All flowers share scene motion material")
		check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Flowers do not join temporary grass shadow review")
		check(is_equal_approx(node.extra_cull_margin,.3),"Chunk culling includes wind/player displacement")
		count+=node.multimesh.instance_count
		if DisplayServer.get_name()!="headless":
			for i in node.multimesh.instance_count: rendered.append(node.multimesh.get_instance_transform(i))
	check(count==level.captured_flowers.size(),"All authored placements reach the chunked MultiMesh batches")
	if DisplayServer.get_name()!="headless":
		check(rendered.size()==count,"Rendered flower buffers retain all placements")
		for t in level.captured_flowers: check(t in rendered,"Actual rendered transform matches scene scatter boundary")
	for t in level.captured_flowers:
		var p := Vector2(t.origin.x,t.origin.z)
		check(absf(p.x-floorf(p.x)-.5)<.001 and absf(p.y-floorf(p.y)-.5)<.001,"Patch occupies a terrain cell center")
		check(not occupied.has(p),"Full block patches do not overlap")
		occupied[p]=true
		check(t.basis.get_scale().distance_to(Vector3.ONE)<.001,"Reusable one-metre block retains identity scale")
		check(absf(t.origin.y-level.ground_height(p.x,p.y))<.001,"Patch roots follow the existing terrain")
		check(level.layout.path_distance(p)>=1.55 and p.length()>2.0,"Combat opening and path stay readable")
		if p.length()<4.7 and t.origin.y<1.1: near=true
		for vertex in vertices:
			var w: Vector3 = t*vertex
			check(absf(level.ground_height(w.x,w.z)-t.origin.y)<.001,"Flower block does not cross terrace levels")
	check(count>10 and count<=30,"Flowers stay clustered at current scene density")
	check(near,"An accessible flower cluster remains beside the opening")
	level.set_grass_shadows(false); level.set_grass_shadows(true)
	for node in level.forest.get_children():
		if node is MultiMeshInstance3D and node.name.begins_with("MeadowWhiteFlowers"):
			check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"G only controls grass shadows")
	Input.action_press("move_right")
	for i in 30: await physics_frame
	Input.action_release("move_right")
	var published: PackedVector4Array = level.meadow_flower_material.get_shader_parameter("motion_start")
	check(published==level.motion.starts and level.motion.active_count>0,"Actual player history reaches flowers each physics frame")
	for i in 100: await physics_frame
	var expired: PackedVector4Array = level.meadow_flower_material.get_shader_parameter("motion_start")
	check(expired==level.motion.starts and level.motion.active_count==0,"Stopped flower material recovers with scene history")
	level.queue_free()
	finish(count)

func finish(patches := 0) -> void:
	var report := {"checks":checks,"failures":failures,"patches":patches}
	DirAccess.make_dir_recursive_absolute("res://.validation/meadow_flowers_v1")
	FileAccess.open("res://.validation/meadow_flowers_v1/runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MEADOW_FLOWERS " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
