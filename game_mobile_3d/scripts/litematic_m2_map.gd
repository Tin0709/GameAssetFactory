extends Node3D
## Exact saved schematic reconstruction. No scatter, region mirroring, or per-cell nodes.
const Motion = preload("res://scripts/grassland_motion.gd")
const DATA := "res://assets/environment/litematic_m2_v2/runtime_map.json"
const BASE := "res://assets/environment/litematic_m2_v2/"
const SOLIDS := ["minecraft:dirt", "minecraft:grass_block[snowy=false]", "minecraft:stone"]
const SHORT := "minecraft:short_grass"
const LOWER := "minecraft:tall_grass[half=lower]"
const UPPER := "minecraft:tall_grass[half=upper]"
const DIRECTIONS := [Vector3i(1,0,0),Vector3i(-1,0,0),Vector3i(0,1,0),Vector3i(0,-1,0),Vector3i(0,0,1),Vector3i(0,0,-1)]
var runtime: Dictionary
var cells := {}
var motion = Motion.new()
var grass_material: ShaderMaterial
var tall_grass_material: ShaderMaterial
var terrain_material: StandardMaterial3D
var vegetation: Array[MultiMeshInstance3D] = []
var native_meshes := {}
var terrain_triangles := 0
var build_msec := 0
var spawn_position := Vector3.ZERO
var enemies_enabled := false
var camera_offset := Vector3(12,15,16)
var review_mode := "gameplay"
var panel: VBoxContainer
var toggle_button: Button
var spawn_one_button: Button
var spawn_five_button: Button
@onready var player: CharacterBody3D = $Actors/Player
@onready var combat: Node = $Combat
@onready var spawner: Node = $SpawnDirector

func _ready() -> void:
	process_physics_priority = 2
	get_viewport().msaa_3d = Viewport.MSAA_2X
	# Match the approved studio feel on Mobile using filtered shadow maps.
	# The key's depth bias prevents flat terrain from shadowing itself.
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.directional_shadow_atlas_set_size(2048,true)
	$Actors.child_entered_tree.connect(func(actor): configure_actor_lighting.call_deferred(actor))
	for actor in $Actors.get_children(): configure_actor_lighting(actor)
	var start := Time.get_ticks_msec()
	runtime = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not validate_runtime():
		push_error("M2 package malformed or unsupported: refusing reconstruction")
		set_process(false)
		set_physics_process(false)
		player.set_physics_process(false)
		return
	for c in runtime.cells: cells[Vector3i(c[0],c[1],c[2])] = c[3]
	# Fail closed before building geometry if a saved package is malformed.
	assert(cells.size() == 15000)
	for p in cells:
		if cells[p] == LOWER: assert(cells.get(p+Vector3i.UP) == UPPER)
		if cells[p] == UPPER: assert(cells.get(p-Vector3i.UP) == LOWER)
	for entry in runtime.registry:
		assert(entry.supported and ResourceLoader.exists(entry.asset))
		if not native_meshes.has(entry.state): native_meshes[entry.state] = mesh_from_scene(load(entry.asset))
	setup_materials()
	build_terrain(cells,$Terrain)
	build_plants(SHORT,prepare_short_mesh(native_meshes[SHORT]),grass_material)
	build_plants(LOWER,native_meshes[LOWER],tall_grass_material)
	spawn_position = find_safe_center()
	reset_player()
	setup_panel()
	set_enemies_enabled(false)
	$HUD/Help.text = "M2 — STUDIO LOOK V4\nWASD move · Shift sprint · R center · V review camera\n1/2/3 weapons · 0 unequip · T spawn 1 · K spawn 5\nCOLOR / LIGHTING REVIEW"
	$WorldEnvironment.environment = $WorldEnvironment.environment.duplicate()
	$WorldEnvironment.environment.fog_enabled = false
	build_msec = Time.get_ticks_msec()-start
	update_status()

func validate_runtime() -> bool:
	if runtime.get("dimensions") != [50.0,6.0,50.0] or runtime.get("source_min") != [0.0,0.0,0.0]: return false
	var supported := {"minecraft:air":true}
	var canonical := SOLIDS+[SHORT,LOWER,UPPER]
	for entry in runtime.get("registry",[]):
		if not entry.get("supported",false) or not ResourceLoader.exists(entry.get("asset","")): return false
		if entry.get("state","") not in canonical or supported.has(entry.state): return false
		supported[entry.state] = true
	if supported.size() != canonical.size()+1: return false
	var logical := {}
	for c in runtime.get("cells",[]):
		if c.size() != 4 or not supported.has(c[3]): return false
		for axis in range(3):
			if not (c[axis] is float or c[axis] is int): return false
			if not is_finite(float(c[axis])) or float(c[axis]) != floorf(float(c[axis])): return false
		var p := Vector3i(c[0],c[1],c[2])
		if p.x<0 or p.x>=50 or p.y<0 or p.y>=6 or p.z<0 or p.z>=50 or logical.has(p): return false
		logical[p] = c[3]
	if logical.size() != 15000: return false
	var lower_count := 0
	var upper_count := 0
	for p in logical:
		if logical[p] == LOWER:
			if logical.get(p+Vector3i.UP) != UPPER: return false
			lower_count += 1
		if logical[p] == UPPER:
			if logical.get(p-Vector3i.UP) != LOWER: return false
			upper_count += 1
	return lower_count == 50 and upper_count == 50

func mesh_from_scene(scene: PackedScene) -> Mesh:
	var root := scene.instantiate()
	var nodes := root.find_children("*","MeshInstance3D",true,false)
	var mesh: Mesh = root.mesh if root is MeshInstance3D else nodes[0].mesh
	root.free()
	return mesh

func setup_materials() -> void:
	var atlas = load(BASE+"meadow_m2_atlas.png")
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_texture = studio_atlas(atlas)
	terrain_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	terrain_material.roughness = 1.0
	terrain_material.metallic_specular = 0.08
	terrain_material.vertex_color_use_as_albedo = true
	grass_material = ShaderMaterial.new()
	grass_material.shader = load(BASE+"m2_grass.gdshader")
	grass_material.set_shader_parameter("atlas",atlas)
	grass_material.set_shader_parameter("wind_direction",Vector2(1,0))
	grass_material.set_shader_parameter("meadow_color_tint",Vector3.ONE)
	tall_grass_material = grass_material.duplicate()
	tall_grass_material.set_shader_parameter("review_wind_gain",4.0)
	tall_grass_material.set_shader_parameter("review_interaction_gain",3.0)
	tall_grass_material.set_shader_parameter("review_max_bend",0.6)

func configure_actor_lighting(actor: Node) -> void:
	if not is_instance_valid(actor): return
	# A faint camera fill affects characters only, keeping terrain contrast.
	for mesh in actor.find_children("*","GeometryInstance3D",true,false): mesh.layers |= 2

func studio_atlas(source: Texture2D) -> Texture2D:
	# Preserve the approved pixel shapes/mean colors, but reduce the grass-top
	# contrast at gameplay scale. Original on-disk textures remain intact.
	var image: Image = source.get_image().duplicate()
	for region in range(4):
		var x0 := 2+36*region
		var mean := Color(0,0,0,0)
		for y in range(94,126):
			for x in range(x0,x0+32): mean += image.get_pixel(x,y)
		mean /= 1024.0
		for y in range(92,128):
			for x in range(x0-2,x0+34):
				var original := image.get_pixel(x,y)
				var softened := mean.lerp(original,0.72)
				softened.a = original.a
				image.set_pixel(x,y,softened)
	return ImageTexture.create_from_image(image)

func prepare_short_mesh(source: Mesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	for s in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		var roots := PackedVector2Array()
		var height := source.get_aabb().size.y
		for v in vertices:
			var t := clampf(v.y/height,0,1)
			colors.append(Color(t*t,t,0,1))
			roots.append(Vector2(0.5,0.5))
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV2] = roots
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

func direction_of(normal: Vector3) -> Vector3i:
	return Vector3i(roundi(normal.x),roundi(normal.y),roundi(normal.z))

func build_terrain(source_cells: Dictionary, parent: Node3D) -> void:
	var chunks := {}
	for p in source_cells:
		if source_cells[p] not in SOLIDS: continue
		var bucket := Vector2i(floori(p.x/10.0),floori(p.z/10.0))
		if not chunks.has(bucket): chunks[bucket] = []
		chunks[bucket].append(p)
	for bucket in chunks:
		var combined := ArrayMesh.new()
		for state in SOLIDS:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var emitted := 0
			var mesh: Mesh = native_meshes[state]
			for p in chunks[bucket]:
				if source_cells[p] != state: continue
				for s in range(mesh.get_surface_count()):
					var arrays := mesh.surface_get_arrays(s)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					for i in range(0,indices.size(),3):
						var direction := direction_of(normals[indices[i]])
						if source_cells.get(p+direction,"") in SOLIDS: continue
						for k in range(3):
							var index := indices[i+k]
							tool.set_normal(normals[index])
							tool.set_uv(terrain_uv(uv[index],p,state,direction))
							var world_vertex := vertices[index]+Vector3(p)+Vector3(0.5,0,0.5)
							tool.set_color(terrain_contact_color(world_vertex,p,direction,source_cells))
							tool.add_vertex(world_vertex)
						emitted += 1
			if emitted > 0:
				tool.set_material(terrain_material)
				tool.index()
				tool.commit(combined)
		var node := MeshInstance3D.new()
		node.name = "Terrain_%d_%d" % [bucket.x,bucket.y]
		node.mesh = combined
		parent.add_child(node)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 2
		var shape := ConcavePolygonShape3D.new()
		var faces := combined.get_faces()
		shape.set_faces(faces)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
		if parent == $Terrain: terrain_triangles += faces.size()/3

func terrain_contact_color(vertex: Vector3, owner: Vector3i, direction: Vector3i, source_cells: Dictionary) -> Color:
	# Static voxel corner occlusion; source geometry/collision stay intact.
	var axes := [0,2] if direction.y != 0 else ([1,2] if direction.x != 0 else [0,1])
	var a := Vector3i.ZERO
	var b := Vector3i.ZERO
	a[axes[0]] = 1 if vertex[axes[0]] > owner[axes[0]]+0.5 else -1
	b[axes[1]] = 1 if vertex[axes[1]] > owner[axes[1]]+0.5 else -1
	var side_a: bool = source_cells.get(owner+direction+a,"") in SOLIDS
	var side_b: bool = source_cells.get(owner+direction+b,"") in SOLIDS
	var diagonal: bool = source_cells.get(owner+direction+a+b,"") in SOLIDS
	var occlusion := 3 if side_a and side_b else int(side_a)+int(side_b)+int(diagonal)
	var shade := 1.0-0.24*occlusion/3.0
	return Color(shade,shade,shade,1.0)

func terrain_uv(uv: Vector2, cell: Vector3i, state: String, direction: Vector3i) -> Vector2:
	# The approved V3 atlas has four grass tops. Change only surface UVs;
	# source cells, native cube vertices, normals and collision stay identical.
	if state != "minecraft:grass_block[snowy=false]" or direction != Vector3i.UP:
		return uv
	var variant := posmod(cell.x*7+cell.z*3,4)
	var rotation := posmod(cell.x+cell.z*2,4)
	var local := (uv-Vector2(2.0/256.0,94.0/128.0))/Vector2(32.0/256.0,32.0/128.0)
	for i in range(rotation): local = Vector2(1.0-local.y,local.x)
	return Vector2((2.0+36.0*variant)/256.0,94.0/128.0)+local*Vector2(32.0/256.0,32.0/128.0)

func build_plants(state: String, mesh: Mesh, material: Material) -> void:
	var buckets := {}
	for p in cells:
		if cells[p] != state: continue
		var bucket := Vector2i(p.x/10,p.z/10)
		if not buckets.has(bucket): buckets[bucket] = []
		buckets[bucket].append(p)
	for bucket in buckets:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = mesh
		multi.instance_count = buckets[bucket].size()
		for i in range(multi.instance_count):
			var p: Vector3i = buckets[bucket][i]
			multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(p)+Vector3(0.5,0,0.5)))
			multi.set_instance_custom_data(i,Color(0.5,0,0,1))
		var node := MultiMeshInstance3D.new()
		node.name = ("Short" if state == SHORT else "Tall")+"_%d_%d" % [bucket.x,bucket.y]
		node.set_meta("source_state",state)
		node.multimesh = multi
		node.material_override = material
		node.extra_cull_margin = 0.7
		# Cutout silhouettes use the same authored wind/interaction deformation
		# in the shadow pass; both crossed-card sides can cast onto the terrain.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		$Grass.add_child(node)
		vegetation.append(node)

func surface_height(x: float,z: float) -> float:
	for y in range(5,-1,-1):
		if cells.get(Vector3i(floori(x),y,floori(z)),"") in SOLIDS: return y+1.0
	return NAN

func find_safe_center() -> Vector3:
	for r in range(12):
		for z in range(25-r,26+r):
			for x in range(25-r,26+r):
				var h := surface_height(x+0.5,z+0.5)
				if not is_finite(h): continue
				var clear := true
				for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					if surface_height(x+d.x+0.5,z+d.y+0.5) != h: clear = false
				if clear: return Vector3(x+0.5,h+0.02,z+0.5)
	assert(false,"No safe central spawn")
	return Vector3.ZERO

func reset_player() -> void:
	if player.is_dead:
		get_tree().call_deferred("reload_current_scene")
		return
	player.global_position = spawn_position
	player.velocity = Vector3.ZERO
	motion = Motion.new()

func _physics_process(delta: float) -> void:
	if player.global_position.y < -3: reset_player()
	motion.advance(delta,player.global_position,player.get_real_velocity(),player.walk_speed,player.run_speed)
	motion.publish(grass_material)
	motion.publish(tall_grass_material)

func _process(_delta: float) -> void:
	if review_mode == "gameplay": $Camera3D.position = player.global_position+camera_offset

func set_review_view(mode: String) -> void:
	review_mode = mode
	var camera: Camera3D = $Camera3D
	if mode == "gameplay":
		camera.position = player.global_position+camera_offset
		camera.rotation_degrees = Vector3(-36.31588642394517,36.86989764584402,0)
		camera.size = 14.5
	elif mode == "overhead":
		camera.position = Vector3(25,60,25)
		camera.rotation_degrees = Vector3(-90,0,0)
		camera.size = 57
	else:
		camera.position = Vector3(65,70,75)
		camera.look_at(Vector3(25,1,25))
		camera.size = 68
	camera.far = 150

func setup_panel() -> void:
	panel = VBoxContainer.new()
	panel.position = Vector2(24,132)
	panel.visible = OS.is_debug_build()
	$HUD.add_child(panel)
	toggle_button = Button.new()
	spawn_one_button = Button.new()
	spawn_five_button = Button.new()
	spawn_one_button.text = "Spawn 1 Enemy (T)"
	spawn_five_button.text = "Spawn 5 Enemies (K)"
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
	toggle_button.text = "Enemy Spawning: "+("ON (manual only)" if enabled else "OFF")
	spawn_one_button.disabled = not enabled
	spawn_five_button.disabled = not enabled

func spawn_review_enemies(count: int) -> int:
	return spawner.debug_spawn(count) if enemies_enabled else 0

func update_status() -> void:
	$HUD/Status.text = "15000 logical cells · 512 short · 50 tall · exact source terrain"

func get_map_summary() -> Dictionary:
	var vegetation_triangles := 0
	for node in vegetation:
		vegetation_triangles += node.multimesh.mesh.get_faces().size()/3*node.multimesh.instance_count
	return {"dimensions":runtime.dimensions,"counts":runtime.counts,"source_min":runtime.source_min,"logical_cells":cells.size(),"tall_pairs":runtime.tall_pairs,"terrain_chunks":$Terrain.get_child_count(),"terrain_triangles":terrain_triangles,"vegetation_triangles":vegetation_triangles,"multimesh_batches":vegetation.size(),"terrain_static_bodies":$Terrain.find_children("*","StaticBody3D",true,false).size(),"scene_node_count":find_children("*","Node",true,false).size()+1,"build_msec":build_msec,"spawn":[spawn_position.x,spawn_position.y,spawn_position.z],"enemies_enabled":enemies_enabled,"unsupported":[]}

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_test"): reset_player()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_T: spawn_review_enemies(1)
			KEY_K: spawn_review_enemies(5)
			KEY_V: set_review_view("overhead" if review_mode == "gameplay" else ("isometric" if review_mode == "overhead" else "gameplay"))
