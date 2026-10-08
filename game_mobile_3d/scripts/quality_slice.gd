extends "res://scripts/grassland_50x50.gd"
## Local visual study. Original scene/resources and selected proportions are retained.
## Tree meshes are original silhouette proxies, not approved production tree assets.
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
const ROCK = preload("res://assets/environment/grassland/scatter_v1/env_rock_large_02.glb")
var review_stage := 3
var review_props: Node3D
var flower_batches: Array = []
var baseline_environment: Environment
var baseline_sun := {}
var baseline_msaa: int
var review_label: Label
var review_colliders: Array[StaticBody3D] = []

func _ready() -> void:
	super._ready()
	baseline_environment = $WorldEnvironment.environment.duplicate()
	for key in ["light_energy","light_color","rotation_degrees","shadow_opacity","shadow_bias","shadow_normal_bias"]:
		baseline_sun[key] = $Sun.get(key)
	baseline_msaa = get_viewport().msaa_3d
	for node in $Scatter.get_children():
		if node is MultiMeshInstance3D and node.name.begins_with("ENV_Flowers"):
			flower_batches.append([node,node.multimesh.visible_instance_count])
	review_props = Node3D.new()
	review_props.name = "StudyProps"
	add_child(review_props)
	build_study_props()
	$HUD/Help.hide()
	$HUD/Status.hide()
	panel.hide()
	review_label = Label.new()
	review_label.position = Vector2(22,18)
	review_label.add_theme_font_size_override("font_size",17)
	review_label.add_theme_color_override("font_shadow_color",Color(0.02,0.05,0.04))
	review_label.add_theme_constant_override("shadow_offset_x",2)
	review_label.add_theme_constant_override("shadow_offset_y",2)
	$HUD.add_child(review_label)
	set_review_stage(3)
	set_enemies_enabled(true)
	add_review_zombie(Vector3(3.7,1.02,-2.8))

func set_review_stage(stage: int) -> void:
	review_stage = clampi(stage,0,3)
	review_props.visible = review_stage > 0
	# Restore from snapshots first: repeated A/B never accumulates a material/light edit.
	$WorldEnvironment.environment = baseline_environment.duplicate()
	for key in baseline_sun: $Sun.set(key,baseline_sun[key])
	for body in review_colliders: body.collision_layer = 1 if review_stage > 0 else 0
	if review_stage > 0:
		# The sparse original's low bias produces visible acne on large flat casters.
		# Rendered no-shadow/bias probes isolate this from mesh/color artifacts.
		$Sun.shadow_bias = 0.10
		$Sun.shadow_normal_bias = 1.5
	get_viewport().msaa_3d = baseline_msaa as Viewport.MSAA
	for pair in flower_batches:
		pair[0].multimesh.visible_instance_count = pair[1] if review_stage == 0 else maxi(1,ceili(pair[0].multimesh.instance_count * 0.25))
	if review_stage >= 2:
		var env: Environment = $WorldEnvironment.environment
		env.ambient_light_color = Color(0.53,0.69,0.78)
		env.ambient_light_energy = 0.34
		$Sun.light_color = Color(1.0,0.92,0.79)
		$Sun.light_energy = 1.12
		$Sun.shadow_opacity = 0.86
	if review_stage >= 3: get_viewport().msaa_3d = Viewport.MSAA_2X
	if review_label:
		review_label.text = "QUALITY STUDY · " + ["0 BASELINE","1 COMPOSITION","2 LIGHT","3 LIGHT + MSAA 2x"][review_stage] + "\nF1/F2/F4/F5 stages · Tab A/B · WASD/Shift move · T/K zombies\nOriginal tree proxies · art direction pending review · target 30 FPS"

func add_review_zombie(at: Vector3) -> CharacterBody3D:
	var zombie = ZOMBIE.instantiate()
	zombie.position = at
	$Actors.add_child(zombie)
	combat.register_zombie(zombie)
	return zombie

func append_box(tool: SurfaceTool, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = dimensions
	var arrays := box.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index in arrays[Mesh.ARRAY_INDEX]:
		tool.set_normal(normals[index])
		tool.set_color(color)
		tool.add_vertex(vertices[index] + at)

func make_tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(st,Vector3(0,1.1,0),Vector3(0.48,2.2,0.48),Color(0.28,0.20,0.13))
	append_box(st,Vector3(0.5,2.05,0),Vector3(1.15,0.32,0.32),Color(0.32,0.23,0.14))
	append_box(st,Vector3(-0.25,0.2,0.05),Vector3(0.85,0.4,0.62),Color(0.26,0.19,0.13))
	# Irregular stepped masses, opaque leaves: no leaf cards/alpha sorting.
	append_box(st,Vector3(-0.45,2.50,0.1),Vector3(1.95,0.95,1.7),Color(0.16,0.32,0.23))
	append_box(st,Vector3(0.65,2.8,-0.05),Vector3(1.8,1.05,1.8),Color(0.21,0.39,0.25))
	append_box(st,Vector3(-0.1,3.45,-0.3),Vector3(1.8,0.85,1.6),Color(0.25,0.43,0.28))
	append_box(st,Vector3(-0.65,3.0,0.9),Vector3(1.1,0.8,0.8),Color(0.22,0.36,0.22))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	st.set_material(material)
	st.index()
	return st.commit()

func build_study_props() -> void:
	var tree_mesh := make_tree_mesh()
	var placements := [Vector4(-6.0,1.0,-1.0,1.15),Vector4(4.8,1.0,-5.0,1.0),Vector4(-6.5,1.0,-7.6,0.85),Vector4(7.7,1.0,2.7,1.1)]
	for i in placements.size():
		var data: Vector4 = placements[i]
		var tree := MeshInstance3D.new()
		tree.mesh = tree_mesh
		tree.position = Vector3(data.x,data.y,data.z)
		tree.scale = Vector3.ONE * data.w
		tree.rotation.y = i * PI * 0.5
		tree.name = "CanopyProxy%d" % i
		review_props.add_child(tree)
		var trunk := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.55,2.2,0.55)
		shape.shape = box
		shape.position.y = 1.1
		trunk.add_child(shape)
		tree.add_child(trunk)
		review_colliders.append(trunk)
	var rock_mesh := mesh_from_scene(ROCK)
	for data in [Vector4(-4.5,1,-3.5,2.0),Vector4(5.2,1,-2.8,2.4),Vector4(6.0,1,-3.2,1.6),Vector4(-6.5,1,1.6,2.5)]:
		var rock := MeshInstance3D.new()
		rock.mesh = rock_mesh
		# The scatter exports share a palette; retain the baseline's nearest material
		# instead of activating another texture's automatic 3D import conversion.
		rock.material_override = scatter_material
		rock.position = Vector3(data.x,data.y,data.z)
		rock.scale = Vector3.ONE * data.w
		review_props.add_child(rock)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = rock_mesh.get_aabb().size
		shape.shape = box
		shape.position = rock_mesh.get_aabb().get_center()
		body.add_child(shape)
		rock.add_child(body)
		review_colliders.append(body)

func _unhandled_input(event: InputEvent) -> void:
	# This study owns quality through its numbered stages; the inherited F3
	# toggle would leave rock shadows/culling/blur outside the reversible A/B.
	if event is InputEventKey and event.physical_keycode == KEY_F3: return
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1: set_review_stage(0)
			KEY_F2: set_review_stage(1)
			KEY_F4: set_review_stage(2)
			KEY_F5: set_review_stage(3)
			KEY_TAB: set_review_stage(0 if review_stage > 0 else 3)
