extends Node3D
## Grass-capped, metre-grid cliffs outside the 100 m playable floor.
const HALF_MAP := 50
const OUTER_LIMIT := 65
const CHUNK_SIZE := 10
const BLOCKS := [
	preload("res://assets/environment/litematic_m2_v2/dirt_block_di_v3.glb"),
	preload("res://assets/environment/litematic_m2_v2/stone_block_di_v3.glb"),
	preload("res://assets/environment/litematic_m2_v2/grass_block_di_v3.glb")
]
const GRASS_MATERIAL = preload("res://materials/gameplay_grass_ground.tres")
const CLIFF_SHADER = preload("res://materials/gameplay_cliff.gdshader")
const CLIFF_GRASS_SHADER = preload("res://materials/gameplay_cliff_grass.gdshader")
const DIRECTIONS := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
var columns: Dictionary = {}
var block_faces: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var shadow_materials: Array[Material] = []
var triangles := 0
var surface_faces := PackedInt32Array([0,0,0])

func build() -> void:
	create_profile()
	cache_blocks()
	var chunks: Dictionary = {}
	for cell: Vector2i in columns:
		var chunk := Vector2i(floori(float(cell.x)/CHUNK_SIZE),floori(float(cell.y)/CHUNK_SIZE))
		if not chunks.has(chunk): chunks[chunk] = []
		chunks[chunk].append(cell)
	for chunk: Vector2i in chunks:
		build_chunk(chunk,chunks[chunk])
	set_meta("triangles",triangles)
	set_meta("columns",columns.size())
	# Cached faces are no longer needed once meshes/colliders have been created.
	block_faces.clear()

func create_profile() -> void:
	var relief := FastNoiseLite.new()
	relief.seed = 3917
	relief.frequency = .073
	var geology := FastNoiseLite.new()
	geology.seed = 8213
	geology.frequency = .032
	var dirt_count := 0
	var stone_count := 0
	for z in range(-OUTER_LIMIT,OUTER_LIMIT):
		for x in range(-OUTER_LIMIT,OUTER_LIMIT):
			if x>=-HALF_MAP and x<HALF_MAP and z>=-HALF_MAP and z<HALF_MAP: continue
			var cell := Vector2i(x,z)
			var depth := maxi(maxi(-HALF_MAP-x,x-HALF_MAP+1),maxi(-HALF_MAP-z,z-HALF_MAP+1))
			# Three-metre patches form broad pillars; a higher rear tier breaks the rim.
			var px := floori(float(x)/3)*3
			var pz := floori(float(z)/3)*3
			var n := relief.get_noise_2d(px,pz)
			var thickness := clampi(roundi(9.0+4.0*n+2.0*sin(px*.14+pz*.09)),6,13)
			if depth>thickness: continue
			var ridge := 4.5*sin(px*.115+pz*.071)+2.0*cos(pz*.18-px*.064)+5.0*n
			var height := clampi(roundi(15.0+ridge+floorf(float(depth-1)/3.0)*2.0),11,26)
			var rock := geology.get_noise_2d(px,pz)+.12*sin(px*.051-pz*.083)>0
			columns[cell] = Vector2i(height,1 if rock else 0)
			if rock: stone_count += 1
			else: dirt_count += 1
	set_meta("dirt_columns",dirt_count)
	set_meta("stone_columns",stone_count)
	create_inner_columns(relief,geology)

func create_inner_columns(relief: FastNoiseLite, geology: FastNoiseLite) -> void:
	# Lower, broken buttresses project into the meadow in 3..7 m deep groups.
	# Each exposed step is at least two blocks above the original flat floor.
	for z in range(-50,50):
		for x in range(-50,50):
			var distances := [x+50,49-x,z+50,49-z]
			var depth: int = distances.min()
			if depth>7: continue
			var side := distances.find(depth)
			var along := z if side<2 else x
			var shifted := along+50+side*3
			var segment := floori(float(shifted)/7)
			var pattern := absi((segment*1177+side*371+8213)%3571)
			var width := 3+pattern%4
			var reach := 3+(pattern/7)%5
			if shifted%7>=width or depth>=reach: continue
			var height := 3+(reach-1-depth)/2+(pattern/31)%3
			var n := relief.get_noise_2d(x,z)
			var rock := geology.get_noise_2d(x,z)+.12*sin(x*.051-z*.083)+n*.12>0
			columns[Vector2i(x,z)] = Vector2i(height,1 if rock else 0)

func cache_blocks() -> void:
	for kind in BLOCKS.size():
		var source: Node3D = BLOCKS[kind].instantiate()
		var model: MeshInstance3D = source if source is MeshInstance3D else source.find_children("*","MeshInstance3D",true,false)[0]
		var arrays := model.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var faces := {}
		for i in range(0,indices.size(),3):
			var normal := normals[indices[i]]
			var direction := Vector3i(roundi(normal.x),roundi(normal.y),roundi(normal.z))
			if not faces.has(direction): faces[direction] = []
			for k in 3:
				var index := indices[i+k]
				faces[direction].append([vertices[index],normal,uv[index]])
		block_faces.append(faces)
		# Shadow-only solid blocks need no atlas sampling or alpha at tile borders.
		shadow_materials.append(StandardMaterial3D.new())
		if kind==2:
			materials.append(GRASS_MATERIAL.duplicate())
			materials[kind].shader = CLIFF_GRASS_SHADER
		else:
			var native: StandardMaterial3D = model.mesh.surface_get_material(0)
			var material := ShaderMaterial.new()
			material.shader = CLIFF_SHADER
			material.set_shader_parameter("atlas",native.albedo_texture)
			material.set_shader_parameter("albedo_tint",native.albedo_color)
			materials.append(material)
		source.free()

func update_cutaway(player_position: Vector3, camera_position: Vector3, enabled: bool = true) -> void:
	for material in materials:
		material.set_shader_parameter("cutaway_enabled",enabled)
		material.set_shader_parameter("cutaway_start",player_position+Vector3(0,.9,0))
		material.set_shader_parameter("cutaway_end",camera_position)

func emit_face(tools: Array[SurfaceTool], kind: int, direction: Vector3i, offset: Vector3) -> void:
	for vertex: Array in block_faces[kind][direction]:
		tools[kind].set_normal(vertex[1])
		tools[kind].set_uv(vertex[2])
		tools[kind].add_vertex(vertex[0]+offset)
	triangles += 2
	surface_faces[kind] += 1

func build_chunk(chunk: Vector2i, cells: Array) -> void:
	surface_faces.fill(0)
	var tools: Array[SurfaceTool] = []
	for material in materials:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(material)
		tools.append(st)
	var origin := Vector3(chunk.x*CHUNK_SIZE,0,chunk.y*CHUNK_SIZE)
	for cell: Vector2i in cells:
		var column: Vector2i = columns[cell]
		var height := column.x
		var top_offset := Vector3(cell.x+.5,height-1,cell.y+.5)-origin
		emit_face(tools,2,Vector3i.UP,top_offset)
		for direction in DIRECTIONS:
			var neighbour: Vector2i = columns.get(cell+direction,Vector2i.ZERO)
			var below := neighbour.x
			# Interior floor occupies Y=0..1, so its hidden shared faces are omitted.
			if below==0 and cell.x+direction.x>=-50 and cell.x+direction.x<50 and cell.y+direction.y>=-50 and cell.y+direction.y<50: below = 1
			for y in range(below,height):
				var kind := 2 if y==height-1 else column.y
				emit_face(tools,kind,Vector3i(direction.x,0,direction.y),Vector3(cell.x+.5,y,cell.y+.5)-origin)
	var mesh := ArrayMesh.new()
	var shadow_mesh := ArrayMesh.new()
	for kind in tools.size():
		if surface_faces[kind]==0: continue
		var st := tools[kind]
		st.index()
		st.commit(mesh)
		var shadow_st := SurfaceTool.new()
		shadow_st.create_from_arrays(st.commit_to_arrays(),Mesh.PRIMITIVE_TRIANGLES)
		shadow_st.set_material(shadow_materials[kind])
		shadow_st.commit(shadow_mesh)
	var visual := MeshInstance3D.new()
	visual.name = "Cliff_%d_%d" % [chunk.x,chunk.y]
	visual.position = origin
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	# Opaque caster preserves the wall's shadow while the visible material fades.
	var caster := MeshInstance3D.new()
	caster.name = "ShadowCaster"
	caster.mesh = shadow_mesh
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	visual.add_child(caster)
	var body := StaticBody3D.new()
	body.name = "WorldCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	visual.add_child(body)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
