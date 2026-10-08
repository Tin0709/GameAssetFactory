extends Node3D
## Flat 40x40 source-asset terrain, chunked instancing and one shared grass motion provider.
const WIDTH := 40
const CHUNK_SIZE := 10
const BLOCK = preload("res://assets/environment/grassland/grass_dirt_block_v4.glb")
const GRASS = preload("res://assets/environment/grassland/grass_patch_v4.glb")
const GRASS_SHADER = preload("res://materials/lookdev_grass.gdshader")
const PREVIOUS_GRASS = preload("res://assets/environment/grassland/grass_patch_v3.glb")
const PREVIOUS_BLOCK = preload("res://assets/environment/grassland/grass_dirt_block_v3.glb")
const PREVIOUS_SHADER = preload("res://materials/grassland_grass.gdshader")
const PREVIOUS_ATLAS = preload("res://assets/environment/grassland/environment_atlas_64.png")
const LOOK_TERRAIN = preload("res://materials/lookdev_terrain.gdshader")
const ATLAS = preload("res://assets/environment/grassland/environment_atlas_v4.png")
const MOTION = preload("res://scripts/grassland_motion.gd")
@export_range(0.0, 1.0) var grass_coverage := 0.25
@export var grass_seed := 8055
## -1 derives patch count from coverage; 0 hides grass; positive overrides it.
@export_range(-1, 1600) var grass_instance_count := -1
@export var wind_direction := Vector2(1, 0)
@export_range(0.0, 2.0) var wind_strength := 1.0
var cell_count := WIDTH * WIDTH
var grass_transforms: Array[Transform3D] = []
var terrain_triangles := 0
var grass_material: ShaderMaterial
var grass_mesh: Mesh
var motion = MOTION.new()
var camera_offset := Vector3.ZERO
var status_elapsed := 0.0
var combat: Node
var animation_test_enemy: CharacterBody3D
const REVIEW_ENEMY = preload("res://scenes/characters/CuboidZombie.tscn")
const REVIEW_ENEMY_SCRIPT = preload("res://scripts/animation_test_enemy.gd")

# Both appearances own local materials; shared Gameplay.tres is never mutated.
const SUN_PROPERTIES := ["rotation", "light_color", "light_energy", "light_angular_distance", "shadow_enabled", "shadow_bias", "shadow_blur", "shadow_normal_bias", "shadow_opacity", "directional_shadow_mode", "directional_shadow_max_distance", "directional_shadow_blend_splits"]
var new_look := true
var high_quality := false
var original_environment: Environment
var styled_environment: Environment
var original_grass: ShaderMaterial
var styled_grass: ShaderMaterial
var styled_terrain: ShaderMaterial
var original_sun := {}
var terrain_states: Array[Dictionary] = []
var grass_states: Array[Dictionary] = []
var previous_mesh: Mesh
var new_mesh: Mesh

@onready var player: CharacterBody3D = $Actors/Player
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	process_physics_priority = 2
	camera_offset = camera.position - Vector3(0, 1, 0)
	var source = BLOCK.instantiate()
	var source_mesh := source.find_child("*", true, false) as MeshInstance3D
	# Find the actual exported mesh, regardless of the glTF root wrapper.
	var meshes := source.find_children("*", "MeshInstance3D", true, false)
	if source is MeshInstance3D: source_mesh = source
	elif not meshes.is_empty(): source_mesh = meshes[0]
	build_terrain(source_mesh.mesh)
	source.free()
	var imported = GRASS.instantiate()
	meshes = imported.find_children("*", "MeshInstance3D", true, false)
	grass_mesh = imported.mesh if imported is MeshInstance3D else meshes[0].mesh
	imported.free()
	grass_material = ShaderMaterial.new()
	grass_material.shader = GRASS_SHADER
	grass_material.set_shader_parameter("atlas", ATLAS)
	grass_material.set_shader_parameter("wind_direction", wind_direction)
	grass_material.set_shader_parameter("wind_strength", wind_strength)
	build_distribution()
	build_grass()
	motion.advance(0.0, player.global_position, Vector3.ZERO, player.walk_speed, player.run_speed)
	motion.publish(grass_material)
	# No spawner or combat director exists in this scene; the unchanged player handles no targets.
	player.get_node("Pistol").enabled = false
	$HUD/Help.text = "GRASSLAND 40 × 40\nWASD move · Shift sprint · R center\nF7 combat target · 1/2/3 pistol/rifle/shotgun\nARTISTIC STATUS: AWAITING HUMAN REVIEW"
	# Optional scene-local review service uses the unchanged production targeting,
	# weapon behavior and firing pipeline; peaceful startup has no target.
	combat = Node.new()
	combat.name = "CombatDirector"
	combat.set_script(preload("res://scripts/combat_director.gd"))
	for child_name in ["Projectiles", "Pickups", "Effects"]:
		var child := Node3D.new(); child.name = child_name; combat.add_child(child)
	var audio := Node.new(); audio.name = "Audio"
	audio.set_script(preload("res://scripts/combat_audio.gd")); audio.silent_test = true; combat.add_child(audio)
	add_child(combat)
	combat.combat_enabled = false
	if "--combat-review" in OS.get_cmdline_user_args():
		player.equip_test_weapon(1)
		toggle_animation_test_enemy()

	setup_presentation()

func toggle_animation_test_enemy() -> void:
	if is_instance_valid(animation_test_enemy):
		combat.living_zombies.erase(animation_test_enemy)
		animation_test_enemy.queue_free(); animation_test_enemy = null
		combat.combat_enabled = false
		for bullet in combat.projectiles.get_children(): bullet.queue_free()
	else:
		combat.combat_enabled = true
		animation_test_enemy = REVIEW_ENEMY.instantiate()
		animation_test_enemy.set_script(REVIEW_ENEMY_SCRIPT)
		animation_test_enemy.name = "AnimationTestEnemy"
		$Actors.add_child(animation_test_enemy)
		animation_test_enemy.global_position = player.global_position + Vector3(0,0,-3)
		combat.register_zombie(animation_test_enemy)
	player.get_node("Pistol").enabled = true
	player.get_node("Pistol").cached_frame = -1

func select_test_weapon(index: int) -> void:
	player.equip_test_weapon(index)

func build_distribution() -> void:
	grass_transforms.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = grass_seed
	var cells: Array[Vector2i] = []
	# Keep whole rotated patches within the outer edge and clear the center spawn.
	for z in range(1, WIDTH - 1):
		for x in range(1, WIDTH - 1):
			var center := Vector2(x - 19.5, z - 19.5)
			if center.length() > 2.1: cells.append(Vector2i(x, z))
	# Seeded Fisher-Yates (Array.shuffle uses the unrelated global RNG).
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := cells[i]
		cells[i] = cells[j]
		cells[j] = temp
	var wanted := roundi(cell_count * grass_coverage) if grass_instance_count < 0 else grass_instance_count
	for i in range(mini(wanted, cells.size())):
		var center := Vector3(cells[i].x - 19.5 + rng.randf_range(-0.12, 0.12), 1, cells[i].y - 19.5 + rng.randf_range(-0.12, 0.12))
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(1, rng.randf_range(0.94, 1.06), 1))
		grass_transforms.append(Transform3D(basis, center))

func build_terrain(mesh: Mesh, populate := true) -> Array[Mesh]:
	var built: Array[Mesh] = []
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var material := StandardMaterial3D.new()
	material.albedo_texture = ATLAS
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.9
	material.metallic_specular = 0.08
	terrain_triangles = 0
	for cz in range(4):
		for cx in range(4):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for z in range(cz * CHUNK_SIZE, (cz + 1) * CHUNK_SIZE):
				for x in range(cx * CHUNK_SIZE, (cx + 1) * CHUNK_SIZE):
					var offset := Vector3(x - 19.5, 0, z - 19.5)
					for triangle in range(0, indices.size(), 3):
						var a := vertices[indices[triangle]]
						var b := vertices[indices[triangle + 1]]
						var c := vertices[indices[triangle + 2]]
						var top := a.y > 0.9999 and b.y > 0.9999 and c.y > 0.9999
						if not top:
							if a.y < 0.0001 and b.y < 0.0001 and c.y < 0.0001: continue
							var center := (a + b + c) / 3.0
							var outer := ((x == 0 and center.x < -0.493) or (x == WIDTH - 1 and center.x > 0.493)
								or (z == 0 and center.z < -0.493) or (z == WIDTH - 1 and center.z > 0.493))
							if not outer: continue
						terrain_triangles += 1
						for k in range(3):
							var idx := indices[triangle + k]
							tool.set_normal(normals[idx])
							tool.set_uv(uvs[idx])
							tool.add_vertex(vertices[idx] + offset)
			tool.index()
			var combined := tool.commit()
			built.append(combined)
			if not populate: continue
			var chunk := MeshInstance3D.new()
			chunk.name = "Chunk_%d_%d" % [cx, cz]
			chunk.mesh = combined
			chunk.material_override = material
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			$Terrain.add_child(chunk)

	return built

func build_grass() -> void:
	var buckets: Array[Array] = []
	for i in range(16): buckets.append([])
	for transform in grass_transforms:
		var cx := clampi(int((transform.origin.x + 20) / 10), 0, 3)
		var cz := clampi(int((transform.origin.z + 20) / 10), 0, 3)
		buckets[cz * 4 + cx].append(transform)
	for i in range(16):
		if buckets[i].is_empty(): continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = grass_mesh
		multi.instance_count = buckets[i].size()
		for j in range(buckets[i].size()):
			multi.set_instance_transform(j, buckets[i][j])
			multi.set_instance_custom_data(j, Color(float(j % 13) / 12.0, 0, 0, 1))
		var node := MultiMeshInstance3D.new()
		node.name = "GrassChunk_%d_%d" % [i % 4, i / 4]
		node.multimesh = multi
		node.material_override = grass_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = 0.15
		$Grass.add_child(node)

func _physics_process(delta: float) -> void:
	if player.global_position.y < -3.0:
		reset_player()
	motion.advance(delta, player.global_position, player.get_real_velocity(), player.walk_speed, player.run_speed)
	motion.publish(grass_material)
	if styled_terrain: styled_terrain.set_shader_parameter("player_position", player.global_position)

func _process(delta: float) -> void:
	# Preserve the production camera's projection/rotation/scale and follow the larger map.
	camera.position = camera_offset + player.global_position
	status_elapsed += delta
	if status_elapsed >= 0.25:
		status_elapsed = 0.0
		$HUD/Status.text = "%d grass patches  ·  %s  ·  %.2f m/s  ·  %d FPS" % [grass_transforms.size(), "SPRINT" if player.fast_sprinting else ("WALK" if player.current_speed > 0.1 else "WIND"), player.current_speed, Engine.get_frames_per_second()]

func reset_player() -> void:
	player.global_position = Vector3(0, 1.02, 0)
	player.velocity = Vector3.ZERO
	motion = MOTION.new()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_test"): reset_player()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F7:
			toggle_animation_test_enemy()
			get_viewport().set_input_as_handled()
		match event.physical_keycode:
			KEY_F1: set_look(false)
			KEY_F2: set_look(true)
			KEY_TAB: set_look(not new_look)
			KEY_F3: set_quality(not high_quality)
	# Existing AnimationWeaponDebug owns 1/2/3; avoid a second equip/reset.

func setup_presentation() -> void:
	original_environment = $WorldEnvironment.environment.duplicate()
	original_environment.fog_enabled = false
	for property in SUN_PROPERTIES: original_sun[property] = $Sun.get(property)
	new_mesh = grass_mesh
	var previous = PREVIOUS_GRASS.instantiate()
	var meshes := previous.find_children("*", "MeshInstance3D", true, false)
	previous_mesh = previous.mesh if previous is MeshInstance3D else meshes[0].mesh
	previous.free()
	original_grass = ShaderMaterial.new()
	original_grass.shader = PREVIOUS_SHADER
	original_grass.set_shader_parameter("atlas", PREVIOUS_ATLAS)
	original_grass.set_shader_parameter("wind_direction", wind_direction)
	original_grass.set_shader_parameter("wind_strength", wind_strength)
	styled_grass = grass_material
	var previous_ground := StandardMaterial3D.new()
	previous_ground.albedo_texture = PREVIOUS_ATLAS
	previous_ground.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	previous_ground.roughness = 0.9
	previous_ground.metallic_specular = 0.08
	var previous_block = PREVIOUS_BLOCK.instantiate()
	var block_meshes := previous_block.find_children("*", "MeshInstance3D", true, false)
	var source_mesh: Mesh = previous_block.mesh if previous_block is MeshInstance3D else block_meshes[0].mesh
	var new_triangles := terrain_triangles
	var previous_chunks := build_terrain(source_mesh, false)
	terrain_triangles = new_triangles
	previous_block.free()
	for i in range($Terrain.get_child_count()):
		var chunk = $Terrain.get_child(i)
		terrain_states.append({"node": chunk, "material": previous_ground, "previous_mesh": previous_chunks[i], "new_mesh": chunk.mesh})
	for chunk in $Grass.get_children():
		grass_states.append({"node": chunk})
	styled_environment = original_environment.duplicate()
	styled_environment.background_color = Color(0.50, 0.62, 0.65)
	styled_environment.ambient_light_color = Color(0.63, 0.75, 0.84)
	styled_environment.ambient_light_energy = 0.52
	styled_environment.fog_enabled = false
	styled_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	styled_terrain = ShaderMaterial.new()
	styled_terrain.shader = LOOK_TERRAIN
	styled_terrain.set_shader_parameter("atlas", ATLAS)
	set_look(true)

func set_look(enabled: bool) -> void:
	new_look = enabled
	$WorldEnvironment.environment = styled_environment if enabled else original_environment
	grass_material = styled_grass if enabled else original_grass
	grass_mesh = new_mesh if enabled else previous_mesh
	motion.publish(grass_material)
	for state in terrain_states:
		state.node.material_override = styled_terrain if enabled else state.material
		state.node.mesh = state.new_mesh if enabled else state.previous_mesh
		state.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for state in grass_states:
		state.node.multimesh.mesh = grass_mesh
		state.node.material_override = grass_material
		state.node.extra_cull_margin = 0.22 if enabled else 0.15
		# Absolute invariant: quality controls only the player's sun shadow.
		state.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if enabled:
		$Sun.rotation_degrees = Vector3(-48, -42, 0)
		$Sun.light_color = Color(1.0, 0.94, 0.82)
		$Sun.light_energy = 1.10
		$Sun.light_angular_distance = 0.0
		$Sun.shadow_bias = 0.025
		$Sun.shadow_blur = 0.5 if high_quality else 0.3
		$Sun.shadow_normal_bias = 0.45
		$Sun.shadow_opacity = 0.78
		$Sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		$Sun.directional_shadow_max_distance = 29.0
		$Sun.directional_shadow_blend_splits = false
	else:
		for property in original_sun: $Sun.set(property, original_sun[property])
	update_help()

func set_quality(high: bool) -> void:
	high_quality = high
	set_look(new_look)

func update_help() -> void:
	$HUD/Help.text = "GRASSLAND 40 × 40 · %s\nF1 Previous v3 · F2 New v4 · Tab A/B · F3 Player shadow\nWASD move · Shift sprint · R center\nF7 combat target · 1/2/3 pistol/rifle/shotgun\nARTISTIC STATUS: AWAITING HUMAN REVIEW" % ("V4 / PLAYER DETAIL" if new_look and high_quality else ("V4 / MOBILE" if new_look else "PREVIOUS V3"))
