extends Node3D
## Additive E2 map. All visible geometry comes from the approved native exports.
const WIDTH := 50
const CHUNK_SIZE := 10
const Layout = preload("res://scripts/grassland_50x50_layout.gd")
const Motion = preload("res://scripts/grassland_motion.gd")
const BLOCK = preload("res://assets/environment/grassland/grass_dirt_block_v4.glb")
const DIRT = preload("res://assets/environment/grassland/dirt_block_v4.glb")
const GRASS = preload("res://assets/environment/grassland/grass_patch_v4.glb")
const ATLAS = preload("res://assets/environment/grassland/environment_atlas_v4.png")
const MANIFEST := "res://assets/environment/grassland/scatter_v1/export_manifest.json"
@export var environment_seed := 8055
@export_range(0.0,2.0) var grass_density := 1.0
@export_range(0.0,2.0) var rock_density := 1.0
@export_range(0.0,2.0) var flower_density := 1.0
@export_range(0.0,2.0) var dirt_density := 1.0
var layout = Layout.new()
var motion = Motion.new()
var entries: Array = []
var missing_assets: Array[String] = []
var asset_coverage := {}
var counts := {"grass":0,"rock":0,"flower":0,"dirt":0}
var terrain_triangles := 0
var high_quality := false
var enemies_enabled := false
var reload_requested := false
var grass_material: ShaderMaterial
var flower_material: ShaderMaterial
var scatter_material: Material
var terrain_material: ShaderMaterial
var dirt_material: ShaderMaterial
var vegetation: Array[MultiMeshInstance3D] = []
var rocks: Array[MultiMeshInstance3D] = []
var camera_offset := Vector3(12,15,16)
var elapsed := 0.0
var panel: VBoxContainer
var toggle_button: Button
var spawn_one_button: Button
var spawn_five_button: Button
@onready var player: CharacterBody3D = $Actors/Player
@onready var combat: Node = $Combat
@onready var spawner: Node = $SpawnDirector

func _ready() -> void:
	process_physics_priority = 2
	if FileAccess.file_exists(MANIFEST):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		entries = manifest.get("assets",[])
	else:
		missing_assets.append(MANIFEST)
	for i in range(entries.size()): entries[i]["placement_index"] = i
	layout.build(entries,environment_seed,grass_density,rock_density,flower_density,dirt_density)
	setup_materials()
	build_terrain(mesh_from_scene(BLOCK),mesh_from_scene(DIRT))
	build_instances("Grass",mesh_from_scene(GRASS),layout.grass,grass_material,"grass")
	asset_coverage["grass_dirt_block_v4"] = WIDTH * WIDTH - layout.dirt_cells
	asset_coverage["dirt_block_v4"] = layout.dirt_cells
	asset_coverage["grass_patch_v4"] = layout.grass.size()
	var collision_faces := PackedVector3Array()
	for entry in entries:
		var path := str(entry.res_path)
		if not ResourceLoader.exists(path):
			missing_assets.append(path)
			continue
		var mesh := mesh_from_scene(load(path))
		var transforms: Array[Transform3D] = layout.props[entry.name]
		var category := str(entry.category)
		if category != "flower" and scatter_material == null:
			scatter_material = mesh.surface_get_material(0).duplicate()
			if scatter_material is BaseMaterial3D: scatter_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# Native GLBs have base Y=0. Slight burial gives scenic dirt relief without coplanar faces.
		if category == "dirt":
			for i in range(transforms.size()): transforms[i].origin.y = 0.975
		build_instances(str(entry.name),mesh,transforms,flower_material if category == "flower" else scatter_material,category)
		asset_coverage[entry.name] = transforms.size()
		if category == "rock" and entry.variant != "small":
			var faces := mesh.get_faces()
			for t in transforms:
				for vertex in faces: collision_faces.append(t * vertex)
	if not collision_faces.is_empty():
		var body := StaticBody3D.new()
		body.name = "MergedRockCollision"
		var collision := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision_faces)
		collision.shape = shape
		body.add_child(collision)
		$Scatter.add_child(body)
	setup_presentation()
	setup_panel()
	set_enemies_enabled(false)
	set_graphics_quality(false)

func mesh_from_scene(scene: PackedScene) -> Mesh:
	var root := scene.instantiate()
	var nodes := root.find_children("*","MeshInstance3D",true,false)
	var mesh: Mesh = root.mesh if root is MeshInstance3D else nodes[0].mesh
	root.free()
	return mesh

func setup_materials() -> void:
	grass_material = ShaderMaterial.new()
	grass_material.shader = preload("res://materials/lookdev_grass.gdshader")
	grass_material.set_shader_parameter("atlas",ATLAS)
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = preload("res://materials/lookdev_terrain.gdshader")
	terrain_material.set_shader_parameter("atlas",ATLAS)
	dirt_material = terrain_material.duplicate()
	dirt_material.set_shader_parameter("dirt_surface",true)
	flower_material = ShaderMaterial.new()
	flower_material.shader = preload("res://materials/grassland_flowers.gdshader")
	var atlas_path := "res://assets/environment/grassland/scatter_v1/scatter_atlas_v1.png"
	if ResourceLoader.exists(atlas_path): flower_material.set_shader_parameter("atlas",load(atlas_path))

func build_terrain(grass_mesh: Mesh,dirt_mesh: Mesh) -> void:
	var sources := [grass_mesh.surface_get_arrays(0),dirt_mesh.surface_get_arrays(0)]
	for cz in range(5):
		for cx in range(5):
			var tools := [SurfaceTool.new(),SurfaceTool.new()]
			for tool in tools: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for z in range(cz*10,(cz+1)*10):
				for x in range(cx*10,(cx+1)*10):
					var offset := Vector3(x-24.5,0,z-24.5)
					var kind := 1 if layout.is_dirt(Vector2(offset.x,offset.z)) else 0
					var arrays: Array = sources[kind]
					var tool: SurfaceTool = tools[kind]
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					for triangle in range(0,indices.size(),3):
						var a := vertices[indices[triangle]]
						var b := vertices[indices[triangle+1]]
						var c := vertices[indices[triangle+2]]
						if not (a.y > 0.9999 and b.y > 0.9999 and c.y > 0.9999):
							if a.y < 0.0001 and b.y < 0.0001 and c.y < 0.0001: continue
							var center := (a+b+c)/3.0
							if not ((x==0 and center.x < -0.493) or (x==49 and center.x > 0.493) or (z==0 and center.z < -0.493) or (z==49 and center.z > 0.493)): continue
						terrain_triangles += 1
						for k in range(3):
							var idx := indices[triangle+k]
							tool.set_normal(normals[idx]); tool.set_uv(uv[idx]); tool.add_vertex(vertices[idx]+offset)
			var combined := ArrayMesh.new()
			for kind in range(2):
				tools[kind].set_material(terrain_material if kind == 0 else dirt_material)
				tools[kind].index()
				tools[kind].commit(combined)
			var node := MeshInstance3D.new()
			node.name = "Terrain_%d_%d" % [cx,cz]
			node.mesh = combined
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			$Terrain.add_child(node)

func build_instances(asset_name: String, mesh: Mesh, transforms: Array[Transform3D], material: Material, category: String) -> void:
	counts[category] += transforms.size()
	var buckets: Array[Array] = []
	for i in range(25): buckets.append([])
	for t in transforms:
		var cx := clampi(int((t.origin.x+25)/10),0,4)
		var cz := clampi(int((t.origin.z+25)/10),0,4)
		buckets[cz*5+cx].append(t)
	for i in range(25):
		if buckets[i].is_empty(): continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = mesh
		multi.instance_count = buckets[i].size()
		for j in range(buckets[i].size()):
			multi.set_instance_transform(j,buckets[i][j])
			multi.set_instance_custom_data(j,Color(float(j%13)/12.0,0,0,1))
		var node := MultiMeshInstance3D.new()
		node.name = "%s_%d" % [asset_name,i]
		node.multimesh = multi
		if material: node.material_override = material
		node.extra_cull_margin = 0.22
		$Grass.add_child(node) if category == "grass" else $Scatter.add_child(node)
		if category in ["grass","flower"]: vegetation.append(node)
		if category == "rock": rocks.append(node)

func setup_presentation() -> void:
	var env: Environment = $WorldEnvironment.environment.duplicate()
	env.background_color = Color(0.50,0.62,0.65)
	env.ambient_light_color = Color(0.63,0.75,0.84)
	env.ambient_light_energy = 0.52
	env.fog_enabled = false
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	$WorldEnvironment.environment = env
	$Sun.rotation_degrees = Vector3(-48,-42,0)
	$Sun.light_color = Color(1,0.94,0.82)
	$Sun.light_energy = 1.10
	$Sun.light_angular_distance = 0.0
	$Sun.shadow_bias = 0.025
	$Sun.shadow_normal_bias = 0.45
	$Sun.shadow_opacity = 0.78
	$Sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	$Sun.directional_shadow_max_distance = 29.0
	$HUD/Help.text = "GRASSLAND 50 × 50\nWASD move · Shift sprint · R center · F3 quality\n1/2/3 weapons · 0 unequip · T spawn 1 · K spawn 5\nARTISTIC STATUS: AWAITING HUMAN REVIEW"

func setup_panel() -> void:
	panel = VBoxContainer.new()
	panel.position = Vector2(24,132)
	panel.visible = OS.is_debug_build()
	$HUD.add_child(panel)
	toggle_button = Button.new(); toggle_button.name = "EnemyToggle"
	spawn_one_button = Button.new(); spawn_one_button.name = "Spawn1"; spawn_one_button.text = "Spawn 1 Enemy (T)"
	spawn_five_button = Button.new(); spawn_five_button.name = "Spawn5"; spawn_five_button.text = "Spawn 5 Enemies (K)"
	for button in [toggle_button,spawn_one_button,spawn_five_button]:
		button.focus_mode = Control.FOCUS_NONE
		panel.add_child(button)
	toggle_button.pressed.connect(func(): set_enemies_enabled(not enemies_enabled))
	spawn_one_button.pressed.connect(func(): spawn_review_enemies(1))
	spawn_five_button.pressed.connect(func(): spawn_review_enemies(5))

func set_enemies_enabled(enabled: bool) -> void:
	enemies_enabled = enabled
	spawner.enabled = enabled
	spawner.set_physics_process(false)
	combat.combat_enabled = enabled
	if not enabled:
		combat.living_zombies.clear()
		for actor in $Actors.get_children():
			if actor != player: actor.queue_free()
		for container in [combat.projectiles,combat.pickups,combat.effects]:
			for child in container.get_children(): child.queue_free()
	var pistol: Node = player.get_node("Pistol")
	pistol.enabled = enabled
	pistol.cached_frame = -1
	pistol.cached_target = null
	pistol.cached_threat = null
	pistol.cached_registry_size = -1
	if toggle_button:
		toggle_button.text = "Enemy Spawning: " + ("ON" if enabled else "OFF")
		spawn_one_button.disabled = not enabled
		spawn_five_button.disabled = not enabled

func spawn_review_enemies(count: int) -> int:
	return spawner.debug_spawn(count) if enemies_enabled else 0

func set_graphics_quality(high: bool) -> void:
	high_quality = high
	for node in vegetation:
		# The oblique camera is 25m away before its visible ground footprint.
		node.visibility_range_end = 65.0 if high else 50.0
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in rocks:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if high else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Sun.shadow_blur = 0.5 if high else 0.3

func get_environment_summary() -> Dictionary:
	return {"seed":environment_seed,"terraincells":2500,"terrain_cells":2500,"terrain_chunks":$Terrain.get_child_count(),"terrain_triangles":terrain_triangles,"grass_instances":counts.grass,"rock_instances":counts.rock,"flower_instances":counts.flower,"dirt_instances":counts.dirt,"asset_usage":asset_coverage.duplicate(),"counts":counts.duplicate(),"assetcoverage":asset_coverage.duplicate(),"asset_coverage":asset_coverage.duplicate(),"missing_assets":missing_assets.duplicate(),"dirt_cells":layout.dirt_cells,"multimesh_batches":$Grass.get_child_count()+$Scatter.get_child_count()-1,"enemies_enabled":enemies_enabled,"high_quality":high_quality}

func get_review_landmarks() -> Dictionary:
	return layout.landmarks()

func _physics_process(delta: float) -> void:
	if player.global_position.y < -3: reset_player()
	motion.advance(delta,player.global_position,player.get_real_velocity(),player.walk_speed,player.run_speed)
	motion.publish(grass_material)
	flower_material.set_shader_parameter("wind_phase",fmod(motion.clock,4.0)*TAU/4.0)
	terrain_material.set_shader_parameter("player_position",player.global_position)
	dirt_material.set_shader_parameter("player_position",player.global_position)

func _process(delta: float) -> void:
	$Camera3D.position = camera_offset + player.global_position
	elapsed += delta
	if elapsed > 0.25:
		elapsed = 0.0
		update_status()

func update_status() -> void:
	$HUD/Status.text = "%d grass · %d rocks · %d flowers · %s · %d FPS" % [counts.grass,counts.rock,counts.flower,"DETAIL" if high_quality else "MOBILE",Engine.get_frames_per_second()]

func reset_player() -> void:
	if player.is_dead:
		if not reload_requested:
			reload_requested = true
			get_tree().call_deferred("reload_current_scene")
		return
	player.global_position = Vector3(0,1.02,0)
	player.velocity = Vector3.ZERO
	motion = Motion.new()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_test"): reset_player()
	if not OS.is_debug_build(): return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_T: spawn_review_enemies(1)
			KEY_K: spawn_review_enemies(5)
			KEY_F3: set_graphics_quality(not high_quality)



