extends "res://scripts/quality_slice.gd"
## Second study: original authored canopy assets, terraced grove and broken masonry.
## The previous QualitySlice remains available through F1 at the same camera.
const FOREST_ASSET_PATH := "res://assets/environment/forest_canopy_v2/"
var forest: Node3D
var forest_stage := 2
var forest_ready := false
var forest_bodies: Array[StaticBody3D] = []
var forest_grass: Array[MultiMeshInstance3D] = []
var forest_ground_material: ShaderMaterial
var forest_blade_material: ShaderMaterial
var masonry_material: ShaderMaterial
var canopy_material: ShaderMaterial
var contact_points: Array[Vector3] = []
var saved_shadow_size: int
var saved_shadow_quality: int
var saved_shadow_16bit: bool
var previous_shadow_blur: float
var forest_mesh_triangles := 0

func _ready() -> void:
	super._ready()
	previous_shadow_blur = $Sun.shadow_blur
	saved_shadow_size = int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size",1024))
	saved_shadow_quality = int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality",1))
	saved_shadow_16bit = bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits",true))
	forest = Node3D.new()
	forest.name = "ForestStudy"
	add_child(forest)
	forest_ground_material = ShaderMaterial.new()
	forest_ground_material.shader = preload("res://materials/forest_ground.gdshader")
	masonry_material = ShaderMaterial.new()
	masonry_material.shader = preload("res://materials/forest_masonry.gdshader")
	canopy_material = ShaderMaterial.new()
	canopy_material.shader = preload("res://materials/forest_canopy.gdshader")
	forest_blade_material = grass_material.duplicate()
	forest_blade_material.shader = load("res://materials/forest_blades.gdshader")
	build_grove_assets()
	build_ruins()
	build_terraced_ground()
	build_forest_grass()
	build_flower_accents()
	forest_ready = true
	set_forest_stage(2)
	DisplayServer.window_set_title("Forest study · F1 before / F2 terrain / F4 sunlight · Tab compare")

func ground_height(x: float, z: float) -> float:
	var p := Vector2(floorf(x)+0.5,floorf(z)+0.5)
	if layout.path_distance(p) < 2.0 or p.length() < 3.5: return 1.0
	var h := 1.0
	if p.x < -4.0 and p.y < -1.0:
		h += 0.5
		if p.x < -6.0 and p.y < -3.0: h += 0.5
		if p.y < -7.0: h += 0.5
	if p.x > 3.5 and p.y < -4.0:
		h += 0.5
		if p.x > 7.0 and p.y < -7.0: h += 0.5
	if p.y < -13.0: h += 0.5
	return h

func contact_shade(p: Vector3) -> float:
	var occlusion := 0.0
	for point in contact_points:
		var d := Vector2(p.x-point.x,p.z-point.z).length()
		occlusion = maxf(occlusion,(1.0-smoothstep(0.1,point.y,d))*0.23)
	return 1.0-occlusion

func add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	# Godot front faces use clockwise winding; normals stay explicit for lighting.
	for vertex in [a,c,b,a,d,c]:
		st.set_normal(normal)
		st.set_color(color*Color(contact_shade(vertex),contact_shade(vertex),contact_shade(vertex),1.0))
		st.add_vertex(vertex)
	forest_mesh_triangles += 2

func build_terraced_ground() -> void:
	for cz in 5:
		for cx in 5:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(forest_ground_material)
			for iz in 10:
				for ix in 10:
					var x: float = cx*10+ix-25
					var z: float = cz*10+iz-25
					var h := ground_height(x,z)
					add_quad(st,Vector3(x,h,z),Vector3(x,h,z+1),Vector3(x+1,h,z+1),Vector3(x+1,h,z),Vector3.UP,Color.WHITE)
					var west := ground_height(x-1,z) if x > -25 else 0.0
					var east := ground_height(x+1,z) if x < 24 else 0.0
					var north := ground_height(x,z-1) if z > -25 else 0.0
					var south := ground_height(x,z+1) if z < 24 else 0.0
					if h > west: add_quad(st,Vector3(x,west,z),Vector3(x,west,z+1),Vector3(x,h,z+1),Vector3(x,h,z),Vector3.LEFT,Color.WHITE)
					if h > east: add_quad(st,Vector3(x+1,east,z+1),Vector3(x+1,east,z),Vector3(x+1,h,z),Vector3(x+1,h,z+1),Vector3.RIGHT,Color.WHITE)
					if h > north: add_quad(st,Vector3(x+1,north,z),Vector3(x,north,z),Vector3(x,h,z),Vector3(x+1,h,z),Vector3.FORWARD,Color.WHITE)
					if h > south: add_quad(st,Vector3(x,south,z+1),Vector3(x+1,south,z+1),Vector3(x+1,h,z+1),Vector3(x,h,z+1),Vector3.BACK,Color.WHITE)
			st.index()
			var mesh := st.commit()
			var instance := MeshInstance3D.new()
			instance.name = "Terrace_%d_%d" % [cx,cz]
			instance.mesh = mesh
			forest.add_child(instance)
			var body := StaticBody3D.new()
			var collision := CollisionShape3D.new()
			collision.shape = mesh.create_trimesh_shape()
			body.add_child(collision)
			forest.add_child(body)
			forest_bodies.append(body)

func build_grove_assets() -> void:
	var trees := [Vector4(-6.4,-1.8,1.05,0.2),Vector4(-8.4,-6.6,1.05,1.7),Vector4(-4.8,-9.0,1.02,2.2),Vector4(2.3,-10.2,1.08,0.9),Vector4(7.8,-5.3,0.94,2.5),Vector4(-9.6,4.9,0.85,0.7),Vector4(8.3,5.4,0.82,1.4),Vector4(-12,-12,1.10,0.0),Vector4(9.5,-13.2,1.20,1.8),Vector4(-14,0,0.90,1.1),Vector4(14,-3,1.08,0.8)]
	for i in trees.size():
		var t: Vector4 = trees[i]
		var path := FOREST_ASSET_PATH + ("tree_oak_a.glb" if i%2 == 0 else "tree_oak_b.glb")
		place_asset(path,Vector3(t.x,ground_height(t.x,t.y),t.y),t.z,t.w,true)
		contact_points.append(Vector3(t.x,1.1*t.z,t.y))
	var rng := RandomNumberGenerator.new()
	rng.seed = 71902
	for i in 74:
		var p := Vector2(rng.randf_range(-16,16),rng.randf_range(-15,12))
		if layout.path_distance(p) < 1.65 or p.length() < 4.1: continue
		var path := FOREST_ASSET_PATH + ("shrub_fern.glb" if i%3 == 0 else "shrub_leaf.glb")
		place_asset(path,Vector3(p.x,ground_height(p.x,p.y),p.y),rng.randf_range(0.65,1.2),rng.randf_range(0,TAU),false)

func place_asset(path: String, at: Vector3, scale_value: float, angle: float, tree: bool) -> void:
	if not ResourceLoader.exists(path):
		push_error("Missing forest study asset: " + path)
		return
	var instance: Node3D = load(path).instantiate()
	instance.position = at
	instance.scale = Vector3.ONE*scale_value
	instance.rotation.y = angle
	forest.add_child(instance)
	for node in instance.find_children("*","MeshInstance3D",true,false):
		node.material_override = canopy_material
		if not tree: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if tree:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.55,2.0,0.55)
		shape.shape = box
		shape.position.y = 1.0
		body.add_child(shape)
		instance.add_child(body)
		forest_bodies.append(body)

func scatter_batch(mesh: Mesh, transforms: Array[Transform3D], material: Material, name_prefix: String, grass := false) -> void:
	var buckets: Array[Array] = []
	for i in 25: buckets.append([])
	for t in transforms:
		var cx := clampi(int((t.origin.x+25)/10),0,4)
		var cz := clampi(int((t.origin.z+25)/10),0,4)
		buckets[cz*5+cx].append(t)
	for bucket in buckets:
		if bucket.is_empty(): continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = mesh
		multi.instance_count = bucket.size()
		for i in bucket.size():
			multi.set_instance_transform(i,bucket[i])
			multi.set_instance_custom_data(i,Color(float(i%17)/16.0,0,0,1))
		var node := MultiMeshInstance3D.new()
		node.name = name_prefix
		node.multimesh = multi
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = 0.3
		node.visibility_range_end = 60.0
		forest.add_child(node)
		if grass: forest_grass.append(node)

func build_forest_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 83147
	var transforms: Array[Transform3D] = []
	for z in range(-24,24):
		for x in range(-24,24):
			var p := Vector2(x+rng.randf_range(0.05,0.95),z+rng.randf_range(0.05,0.95))
			var distance := layout.path_distance(p)
			if distance < 1.28 or p.length() < 1.8: continue
			var grouping := sin(p.x*0.61+sin(p.y*0.52))*sin(p.y*0.34-0.5)
			if rng.randf() > 0.49+grouping*0.40: continue
			var height_scale := rng.randf_range(0.68,1.18) if distance > 2 else rng.randf_range(0.46,0.70)
			# XZ stay unit scale: v4 wind's transpose basis relies on this contract.
			var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(1,height_scale,1))
			transforms.append(Transform3D(basis,Vector3(p.x,ground_height(p.x,p.y),p.y)))
	scatter_batch(mesh_from_scene(GRASS),transforms,forest_blade_material,"ForestBroadGrass",true)

func stone_box(st: SurfaceTool, at: Vector3, size: Vector3, color: Color, collision := false) -> void:
	append_box(st,at,size,color.srgb_to_linear())
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.position = at
		body.add_child(shape)
		forest.add_child(body)
		forest_bodies.append(body)

func build_ruins() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(masonry_material)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9227
	# Broken courtyard wall sits beyond the clear combat lane, with a stepped cap.
	for row in 5:
		for col in 5:
			if row > 2 and col in [1,2,3]: continue
			var x := 3.7+col*0.77+(0.18 if row%2 else 0.0)
			var at := Vector3(x,ground_height(x,-6.3)+row*0.46+0.23,-6.3)
			var tint := Color("899494").lerp(Color("616f70"),rng.randf()*0.65)
			stone_box(st,at,Vector3(0.74,0.435,0.8),tint,true)
	for x in [3.72,6.88]:
		var base := ground_height(x,-6.3)
		stone_box(st,Vector3(x,base+2.52,-6.3),Vector3(1.05,0.22,1.04),Color("a0aa98"),true)
		stone_box(st,Vector3(x,base+0.15,-6.3),Vector3(1.03,0.30,1.02),Color("788b70"),true)
	for col in 4:
		for row in 3:
			if col > 1 and row > 1: continue
			var z := -5.5+col*0.75
			stone_box(st,Vector3(6.8,ground_height(6.8,z)+0.25+row*0.45,z),Vector3(0.8,0.43,0.72),Color("7c8880"),true)
	# Fallen slabs and irregular paving stones echo the ruin without obstructing the lane.
	for i in 22:
		var p := Vector2(rng.randf_range(2.7,7.4),rng.randf_range(-5.5,-2.5))
		var h := ground_height(p.x,p.y)
		stone_box(st,Vector3(p.x,h+0.045,p.y),Vector3(rng.randf_range(0.35,0.7),0.09,rng.randf_range(0.35,0.75)),Color("84917b"),false)
	for spec in [Vector4(-4.2,0.0,1.2,0.9),Vector4(-5.1,1.3,0.8,0.7),Vector4(4.3,3.3,1.1,0.85),Vector4(5.0,3.7,0.8,0.6),Vector4(-5.4,-4.0,1.1,0.8)]:
		var h := ground_height(spec.x,spec.y)
		stone_box(st,Vector3(spec.x,h+spec.w*0.5,spec.y),Vector3(spec.z,spec.w,spec.z*0.75),Color("859189"),true)
		stone_box(st,Vector3(spec.x+0.16,h+spec.w+0.14,spec.y-0.08),Vector3(spec.z*0.65,0.28,spec.z*0.50),Color("9aa38e"),false)
		contact_points.append(Vector3(spec.x,1.0,spec.y))
	st.index()
	var node := MeshInstance3D.new()
	node.name = "MossCourtyardMasonry"
	node.mesh = st.commit()
	forest.add_child(node)

func build_flower_accents() -> void:
	var centers := [Vector2(-3.8,-2.5),Vector2(4.0,-2.0),Vector2(-5.7,4.5),Vector2(4.8,4.8),Vector2(-5.3,-7.0)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9291
	for entry in entries:
		if entry.category != "flower" or not ("White_01" in str(entry.name) or "Purple_01" in str(entry.name) or "Yellow_01" in str(entry.name)): continue
		var transforms: Array[Transform3D] = []
		for center in centers:
			for i in 6:
				var p: Vector2 = center+Vector2(rng.randfn(0,0.55),rng.randfn(0,0.55))
				if layout.path_distance(p)<1.55: continue
				var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(0.7,1.05))
				transforms.append(Transform3D(basis,Vector3(p.x,ground_height(p.x,p.y),p.y)))
		scatter_batch(mesh_from_scene(load(entry.res_path)),transforms,flower_material,"ForestFlowers",false)

func set_forest_stage(stage: int) -> void:
	if not forest_ready: return
	forest_stage = clampi(stage,0,2)
	super.set_review_stage(3)
	$Sun.shadow_blur = previous_shadow_blur
	var enabled := forest_stage > 0
	forest.visible = enabled
	$Terrain.visible = not enabled
	$Grass.visible = not enabled
	$Scatter.visible = not enabled
	$Ground.collision_layer = 0 if enabled else 1
	var old_rock_collision := $Scatter.get_node("MergedRockCollision") as StaticBody3D
	old_rock_collision.collision_layer = 0 if enabled else 1
	review_props.visible = not enabled
	for body in review_colliders: body.collision_layer = 0 if enabled else 1
	for body in forest_bodies: body.collision_layer = 1 if enabled else 0
	RenderingServer.directional_shadow_atlas_set_size(saved_shadow_size,saved_shadow_16bit)
	RenderingServer.directional_soft_shadow_filter_set_quality(saved_shadow_quality as RenderingServer.ShadowQuality)
	if forest_stage == 2:
		var env: Environment = $WorldEnvironment.environment
		env.ambient_light_color = Color(0.45,0.63,0.90)
		env.ambient_light_energy = 0.32
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.0
		env.tonemap_white = 4.0
		$Sun.rotation_degrees = Vector3(-55,-38,0)
		$Sun.light_color = Color(1.0,0.95,0.84)
		$Sun.light_energy = 1.65
		$Sun.shadow_opacity = 0.80
		$Sun.shadow_bias = 0.035
		$Sun.shadow_normal_bias = 0.8
		$Sun.shadow_blur = 1.1
		RenderingServer.directional_shadow_atlas_set_size(2048,true)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	review_label.text = "FOREST STUDY · " + ["PREVIOUS VERSION","NEW GROVE / PREVIOUS LIGHT","SUNLIT GROVE"][forest_stage] + "\nF1 before · F2 grove · F4 light · Tab compare · WASD/Shift · T/K zombies"

func set_review_stage(stage: int) -> void:
	if forest_ready: set_forest_stage(stage)
	else: super.set_review_stage(stage)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if forest_ready:
		motion.publish(forest_blade_material)
		forest_ground_material.set_shader_parameter("player_position",player.global_position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1: set_forest_stage(0); return
			KEY_F2: set_forest_stage(1); return
			KEY_F4: set_forest_stage(2); return
			KEY_F3,KEY_F5: return
			KEY_TAB: set_forest_stage(0 if forest_stage else 2); return
	super._unhandled_input(event)

func _exit_tree() -> void:
	if forest_ready:
		RenderingServer.directional_shadow_atlas_set_size(saved_shadow_size,saved_shadow_16bit)
		RenderingServer.directional_soft_shadow_filter_set_quality(saved_shadow_quality as RenderingServer.ShadowQuality)
