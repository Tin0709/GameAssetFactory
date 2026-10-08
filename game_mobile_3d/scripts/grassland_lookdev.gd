extends "res://scripts/grassland.gd"
## Peaceful review inherits the actual game's v4/A-B presentation.
const SOIL_BLOCK = preload("res://assets/environment/grassland/dirt_block_v4.glb")
var soil_enabled := true
var soil_root: Node3D
var soil_material: ShaderMaterial
var soil_chunks: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	setup_soil_review()
	set_look(true)

func setup_soil_review() -> void:
	soil_root = Node3D.new()
	soil_root.name = "SoilReview"
	add_child(soil_root)
	soil_material = ShaderMaterial.new()
	soil_material.shader = LOOK_TERRAIN
	soil_material.set_shader_parameter("atlas", ATLAS)
	soil_material.set_shader_parameter("dirt_surface", true)
	for z in [-0.5, 0.5]:
		for x in [-1.5, -0.5, 0.5, 1.5]:
			var cell = SOIL_BLOCK.instantiate()
			cell.position = Vector3(x, 0.0, z)
			soil_root.add_child(cell)
			for mesh in cell.find_children("*", "MeshInstance3D", true, false):
				mesh.material_override = soil_material
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Remove only the eight replaced top faces. Dirt uses the same exact Y=1
	# plane; no offset, extra collider, hole or fighting coplanar triangles.
	for state in terrain_states:
		var arrays = state.new_mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var removed := 0
		for i in range(0, indices.size(), 3):
			var a := vertices[indices[i]]
			var b := vertices[indices[i + 1]]
			var c := vertices[indices[i + 2]]
			var midpoint := (a + b + c) / 3.0
			if a.y > 0.9999 and b.y > 0.9999 and c.y > 0.9999 and absf(midpoint.x) < 2.0 and absf(midpoint.z) < 1.0:
				removed += 1
				continue
			for corner in range(3):
				var index := indices[i + corner]
				tool.set_normal(normals[index])
				tool.set_uv(uvs[index])
				tool.add_vertex(vertices[index])
		if removed > 0:
			tool.index()
			soil_chunks.append({"node": state.node, "grass_mesh": state.new_mesh, "soil_mesh": tool.commit()})

func set_look(enabled: bool) -> void:
	super.set_look(enabled)
	apply_soil_review()

func set_soil_review(enabled: bool) -> void:
	soil_enabled = enabled
	apply_soil_review()

func apply_soil_review() -> void:
	if not is_instance_valid(soil_root): return
	soil_root.visible = new_look and soil_enabled
	for state in soil_chunks:
		if new_look: state.node.mesh = state.soil_mesh if soil_enabled else state.grass_mesh
	update_help()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if soil_material:
		soil_material.set_shader_parameter("player_position", player.global_position)

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
		set_soil_review(not soil_enabled)

func toggle_animation_test_enemy() -> void:
	# Preserve the no-enemy guard for inherited F7 and --combat-review.
	pass

func update_help() -> void:
	$HUD/Help.text = "GRASSLAND LOOK-DEV · %s\nF1 Previous v3 · F2 New v4 · Tab A/B · F3 Player shadow\nF4 Soil sample · WASD move · Shift sprint · R center\nARTISTIC STATUS: AWAITING HUMAN REVIEW" % ("V4 / PLAYER DETAIL" if new_look and high_quality else ("V4 / MOBILE" if new_look else "PREVIOUS V3"))
