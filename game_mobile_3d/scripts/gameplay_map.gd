extends Node3D
## Starting ground for the official map. A block is one metre, with its base at Y=0.
const MAP_WIDTH := 100
const MAP_DEPTH := 100
const CHUNK_SIZE := 10
const BLOCK = preload("res://assets/environment/litematic_m2_v2/grass_block_di_v3.glb")
const GROUND_MATERIAL = preload("res://materials/gameplay_grass_ground.tres")
const BORDER_SCRIPT = preload("res://scripts/gameplay_map_border.gd")
const CAMERA_OFFSET := Vector3(12,15,16)
var terrain_triangles := 0
var reload_requested := false
@onready var player: CharacterBody3D = $Actors/Player

func _ready() -> void:
	process_physics_priority = 2
	$WorldEnvironment.environment = $WorldEnvironment.environment.duplicate()
	build_ground()
	var border := Node3D.new()
	border.name = "Border"
	border.set_script(BORDER_SCRIPT)
	add_child(border)
	border.build()
	$Combat.combat_enabled = false
	player.get_node("Pistol").enabled = false
	$HUD/Status.hide()
	get_viewport().msaa_3d = Viewport.MSAA_2X
	$Camera3D.position = player.position + CAMERA_OFFSET
	DisplayServer.window_set_title("Gameplay Map · 100 × 100 · WASD / Shift")

func build_ground() -> void:
	# Reuse the authored block's vertices, normals, UVs and native texture.
	var source := BLOCK.instantiate()
	var model: MeshInstance3D = source if source is MeshInstance3D else source.find_children("*","MeshInstance3D",true,false)[0]
	var mesh: Mesh = model.mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var material: ShaderMaterial = GROUND_MATERIAL
	for cz in MAP_DEPTH / CHUNK_SIZE:
		for cx in MAP_WIDTH / CHUNK_SIZE:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(material)
			# Local chunk origins also make future map additions easier to place.
			var origin := Vector3(cx*CHUNK_SIZE-MAP_WIDTH*.5,0,cz*CHUNK_SIZE-MAP_DEPTH*.5)
			for local_z in CHUNK_SIZE:
				for local_x in CHUNK_SIZE:
					var x := cx*CHUNK_SIZE+local_x
					var z := cz*CHUNK_SIZE+local_z
					var offset := Vector3(local_x+.5,0,local_z+.5)
					for i in range(0,indices.size(),3):
						var normal := normals[indices[i]]
						var exposed := normal.y>.9 or (x==0 and normal.x<-.9) or (x==MAP_WIDTH-1 and normal.x>.9) or (z==0 and normal.z<-.9) or (z==MAP_DEPTH-1 and normal.z>.9)
						if not exposed: continue
						for k in 3:
							var index := indices[i+k]
							st.set_normal(normals[index])
							st.set_uv(uv[index])
							st.add_vertex(vertices[index]+offset)
						terrain_triangles += 1
			st.index()
			var chunk := MeshInstance3D.new()
			chunk.name = "GrassBlocks_%02d_%02d" % [cx,cz]
			chunk.position = origin
			chunk.mesh = st.commit()
			# A completely flat floor receives actor/cliff shadows but need not cast.
			# Its own triangle shadow raster caused visible stippling in the baseline.
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			$Terrain.add_child(chunk)
	source.free()

func _process(_delta: float) -> void:
	$Camera3D.position = player.global_position + CAMERA_OFFSET
	$Border.update_cutaway(player.global_position,$Camera3D.global_position)

func _physics_process(_delta: float) -> void:
	if player.global_position.y < -3.0: reset_player()

func reset_player() -> void:
	if player.is_dead:
		if not reload_requested:
			reload_requested = true
			get_tree().call_deferred("reload_current_scene")
		return
	player.position = Vector3(0,1.02,0)
	player.velocity = Vector3.ZERO

func update_status() -> void:
	# Existing combat services can still notify the same HUD on defeat.
	$HUD/Defeated.visible = player.is_dead

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_test"): reset_player()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_H:
		$WorldEnvironment.environment.fog_enabled = not $WorldEnvironment.environment.fog_enabled
