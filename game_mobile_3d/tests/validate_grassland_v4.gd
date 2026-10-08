extends SceneTree
## Imported silhouette and actual production/A-B switching; catches accidental v3 adoption,
## needle tips, corrupted bend/root data and a quality switch re-enabling grass shadows.
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("GRASSLAND V4: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ResourceLoader.exists("res://assets/environment/grassland/grass_patch_v4.glb"), "Broad Blender v4 grass is available for actual game adoption")
	if not failures.is_empty():
		print(JSON.stringify({"checks": checks, "failures": failures}))
		quit(1)
		return
	var level = load("res://scenes/Grassland.tscn").instantiate()
	root.add_child(level)
	for i in range(8): await physics_frame
	check(level.new_look, "Actual Grassland starts in new v4 presentation")
	check(level.grass_mesh.resource_path.contains("grass_patch_v4"), "Actual rendered mesh uses v4")
	var arrays = level.grass_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var roots: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	check(colors.size() == vertices.size() and roots.size() == vertices.size(), "Imported vertex mask and UV2 counts match geometry")
	var blades := {}
	for i in range(vertices.size()):
		var root_id := Vector2i(roundi(roots[i].x * 100000), roundi(roots[i].y * 100000))
		if not blades.has(root_id): blades[root_id] = {"tips": [], "bases": []}
		check(absf(colors[i].r - colors[i].g * colors[i].g) < 0.007, "Four-ring quadratic bend data survives import")
		if colors[i].g > 0.999: blades[root_id].tips.append(vertices[i])
		if vertices[i].y < 0.0001:
			blades[root_id].bases.append(vertices[i])
			check(colors[i].r == 0 and colors[i].g == 0, "Every root is exactly anchored")
	check(blades.size() >= 32 and blades.size() <= 40, "Mobile patch contains 32–40 broad blades")
	for blade in blades.values():
		var tips: Array = blade.tips
		var bases: Array = blade.bases
		check(tips.size() == 2 and bases.size() == 2, "Every imported blade has a two-corner square end and base")
		if tips.size() != 2 or bases.size() != 2: continue
		var tip_width: float = tips[0].distance_to(tips[1])
		var base_width: float = bases[0].distance_to(bases[1])
		check(tip_width >= 0.115 and tip_width <= 0.205 and absf(tip_width - base_width) < 0.003, "Square end retains the broad rectangular blade width")
		check(absf(tips[0].y - tips[1].y) < 0.001 and tips[0].y >= 0.27 and tips[0].y <= 0.49, "Imported tips are level and squat")
	var new_mesh: Mesh = level.grass_mesh
	var transforms: Array = level.grass_transforms.duplicate()
	var nodes: int = level.find_children("*", "Node", true, false).size()
	for high in [false, true]:
		level.set_quality(high)
		for appearance in [false, true, false, true]:
			level.set_look(appearance)
			check(not level.get_node("WorldEnvironment").environment.fog_enabled, "Fog is disabled in every active appearance and quality")
			for chunk in level.get_node("Grass").get_children():
				check(chunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Grass never casts shadows in A/B or quality modes")
				check(chunk.multimesh.mesh == level.grass_mesh, "Every rendered chunk follows the chosen geometry")
			if appearance:
				check(level.grass_mesh == new_mesh, "New restores broad v4 geometry")
				var has_shade_map := false
				for uniform in level.styled_terrain.shader.get_shader_uniform_list():
					if uniform.name == "root_shade": has_shade_map = true
				check(not has_shade_map, "Terrain cannot bind the prior fake grass shade map")
			else:
				check(level.grass_mesh != new_mesh and level.grass_mesh.get_faces().size() / 3 == 294, "Previous comparison restores actual v3 geometry")
	check(level.grass_transforms == transforms and level.find_children("*", "Node", true, false).size() == nodes, "A/B preserves distribution and node count")
	var previous_quality: bool = level.high_quality
	var quality_key := InputEventKey.new()
	quality_key.physical_keycode = KEY_F3
	quality_key.pressed = true
	Input.parse_input_event(quality_key)
	await physics_frame
	check(level.high_quality != previous_quality, "F3 reaches the player-shadow quality control")
	for chunk in level.get_node("Grass").get_children():
		check(chunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "F3 input cannot enable grass casts")
	check(level.get_node("Sun").shadow_enabled, "Player shadow remains enabled")
	# Read the actual combined boundary geometry, rather than trusting a manifest.
	var cap_bottoms := {}
	for chunk in level.get_node("Terrain").get_children():
		var ground_arrays = chunk.mesh.surface_get_arrays(0)
		var ground_vertices: PackedVector3Array = ground_arrays[Mesh.ARRAY_VERTEX]
		var ground_uv: PackedVector2Array = ground_arrays[Mesh.ARRAY_TEX_UV]
		var ground_normal: PackedVector3Array = ground_arrays[Mesh.ARRAY_NORMAL]
		for i in range(ground_vertices.size()):
			if absf(ground_normal[i].y) < 0.1 and absf(ground_uv[i].y - (1.0 - 0.7421875)) < 0.001:
				if ground_vertices[i].y < 0.999:
					cap_bottoms[roundi((1.0 - ground_vertices[i].y) * 100000)] = true
	for expected in [14375, 21563, 28750]:
		check(cap_bottoms.has(expected) or cap_bottoms.has(expected - 1), "Actual rendered boundary cap has the requested 15 percent thicker depths")
	var collision = level.get_node("Ground/CollisionShape3D")
	check(collision.shape.size == Vector3(40, 1, 40), "Thicker green band preserves unit height and map collision")
	for mesh in level.player.find_children("*", "MeshInstance3D", true, false):
		check(mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Player meshes retain casting")
	var shared: Environment = load("res://environment/Gameplay.tres")
	check(level.get_node("WorldEnvironment").environment != shared and is_equal_approx(shared.ambient_light_energy, 0.65), "V4 presentation stays scene-local")
	check(shared.fog_enabled, "Disabling local fog does not mutate shared Gameplay")
	var before_f5: Environment = level.get_node("WorldEnvironment").environment
	var unused_key := InputEventKey.new()
	unused_key.physical_keycode = KEY_F5
	unused_key.pressed = true
	root.push_input(unused_key, true)
	await physics_frame
	check(level.get_node("WorldEnvironment").environment == before_f5 and not before_f5.fog_enabled, "F5 cannot re-enable deferred fog")
	# Appearance shortcuts must preserve the concurrent production combat review.
	var combat_key := InputEventKey.new()
	combat_key.physical_keycode = KEY_F7
	combat_key.pressed = true
	Input.parse_input_event(combat_key)
	await physics_frame
	check(is_instance_valid(level.animation_test_enemy) and level.combat.combat_enabled, "Actual game's existing F7 combat review still works")
	for index in range(3):
		var weapon_key := InputEventKey.new()
		weapon_key.physical_keycode = KEY_1 + index
		weapon_key.pressed = true
		Input.parse_input_event(weapon_key)
		await physics_frame
		check(level.player.get_node("Pistol").weapon_type == index and level.new_look, "Numeric keys retain the production weapon selection")
	Input.parse_input_event(combat_key)
	for i in range(2): await physics_frame
	check(not is_instance_valid(level.animation_test_enemy) and not level.combat.combat_enabled, "F7 still removes the optional target cleanly")
	var report := {"checks": checks, "failures": failures, "blades": blades.size()}
	FileAccess.open("res://.validation/grassland_v4_contract.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
