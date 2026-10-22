extends Node3D
## Only instantiated by the existing research lab. No production shader edits.
const Field=preload("res://scenes/dev/actions_stuff_research/grass_md2_v001/interaction_field.gd")
const GRASS_SHADER=preload("res://scenes/dev/actions_stuff_research/grass_md2_v001/grass.gdshader")
const ASSETS:="res://scenes/dev/actions_stuff_research/grass_md2_v001/assets/"
var player:CharacterBody3D
var interaction:Field
var side_length:=30
var regions_per_axis:=2
var terrain:MultiMeshInstance3D
var cells:=PackedInt32Array()
var meshes:Array[ArrayMesh]=[]
var materials:Array[ShaderMaterial]=[]
var instance_count:=0
var short_count:=0
var tall_count:=0
var batch_count:=0
var clock:=0.
var enabled:=true
var _atlases:Dictionary={}
var _ground_top:Texture2D

func setup(actor:CharacterBody3D,blocks:int=30)->void:
	player=actor
	side_length=clampi(blocks,1,200)
	regions_per_axis=ceili(float(side_length)/15.)
	interaction=Field.new(float(side_length)+4.)
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"grass_data.json"))
	# Reuse the actual upward terrain surface, without duplicating its texture.
	for surface:Dictionary in data.ground.surfaces:
		if not surface.normals.is_empty() and float(surface.normals[0][1])>0.99:
			_ground_top=_atlas(surface.atlas)
			break
	assert(_ground_top!=null,"Grass root blending requires the terrain's top atlas")
	for entry:Dictionary in data.meshes:meshes.append(_mesh(entry,true))
	var ground_mesh:=_mesh(data.ground,false)
	var ground:=MultiMesh.new();ground.transform_format=MultiMesh.TRANSFORM_3D;ground.mesh=ground_mesh;ground.instance_count=side_length*side_length
	var offset:=float(side_length-1)*.5
	for x in side_length:
		for z in side_length:ground.set_instance_transform(x*side_length+z,Transform3D(Basis.IDENTITY,Vector3(x-offset,-1.,z-offset)))
	terrain=MultiMeshInstance3D.new();terrain.name="ThirtyByThirtyBlocks" if side_length==30 else "TerrainBlocks";terrain.multimesh=ground;add_child(terrain)
	# Same15x15regional batches: distant foliage can be frustum-culled as the map grows.
	var buckets:Array[Array]=[]
	for i in regions_per_axis*regions_per_axis*8:buckets.append([])
	var rng:=RandomNumberGenerator.new();rng.seed=2301021
	for x in side_length:
		for z in side_length:
			cells.append(x*side_length+z)
			var count:=2 if rng.randf()<.48 else 1
			for j in count:
				var tall:=rng.randf()<.46
				var variant:=rng.randi_range(0,3)+(4 if tall else 0)
				var region:=int(x/15)*regions_per_axis+int(z/15)
				var position:=Vector3(x-offset+rng.randf_range(-.20,.20),0,z-offset+rng.randf_range(-.20,.20))
				var basis:=Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*rng.randf_range(1.,1.07))
				buckets[region*8+variant].append([Transform3D(basis,position),Color(rng.randf(),0,0,1)])
				instance_count+=1
				if tall:tall_count+=1
				else:short_count+=1
	for i in buckets.size():
		var rows:Array=buckets[i]
		if rows.is_empty():continue
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=meshes[i%8];mm.instance_count=rows.size()
		var bounds:=AABB()
		for j in rows.size():
			var transform:Transform3D=rows[j][0];mm.set_instance_transform(j,transform);mm.set_instance_custom_data(j,rows[j][1])
			var one: AABB=transform*mm.mesh.get_aabb()
			bounds=one if j==0 else bounds.merge(one)
		mm.custom_aabb=bounds.grow(.8)
		var batch:=MultiMeshInstance3D.new();batch.name="GrassRegion_%d_Variant_%d"%[i/8,i%8];batch.multimesh=mm
		batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(batch);batch_count+=1
	print("MD2_GRASS_FIELD_READY ",JSON.stringify({"blocks":side_length*side_length,"clumps":instance_count,"short":short_count,"tall":tall_count,"batches":batch_count,"interaction_size":interaction.size,"interaction_extent":interaction.extent}))

func _atlas(name:String)->Texture2D:
	if not _atlases.has(name):_atlases[name]=load(ASSETS+name)
	return _atlases[name]

func _mesh(entry:Dictionary,grass:bool)->ArrayMesh:
	var mesh:=ArrayMesh.new()
	for surface:Dictionary in entry.surfaces:
		var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array();var uv2:=PackedVector2Array();var colors:=PackedColorArray()
		for v:Array in surface.vertices:vertices.append(Vector3(v[0],v[1],v[2]))
		for v:Array in surface.normals:normals.append(Vector3(v[0],v[1],v[2]))
		for v:Array in surface.uv:uv.append(Vector2(v[0],v[1]))
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv
		if grass:
			for v:Array in surface.roots:uv2.append(Vector2(v[0],v[1]))
			for v:Array in surface.colors:colors.append(Color(v[0],v[1],v[2],v[3]))
			arrays[Mesh.ARRAY_TEX_UV2]=uv2;arrays[Mesh.ARRAY_COLOR]=colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material:Material
		if grass:
			# One shared material per family/atlas, not per instance or variant.
			var found:ShaderMaterial=null
			for m in materials:
				if m.get_shader_parameter("atlas")==_atlas(surface.atlas):found=m;break
			if found==null:
				found=ShaderMaterial.new();found.shader=GRASS_SHADER;found.set_shader_parameter("atlas",_atlas(surface.atlas))
				found.set_shader_parameter("ground_atlas",_ground_top)
				found.set_shader_parameter("interaction_field",interaction.texture)
				found.set_shader_parameter("interaction_previous",interaction.previous_texture)
				found.set_shader_parameter("field_extent",interaction.extent)
				found.set_shader_parameter("family_response",.72 if entry.family=="short" else 1.)
				materials.append(found)
			material=found
		else:
			var mat:=StandardMaterial3D.new();mat.albedo_texture=_atlas(surface.atlas);mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;mat.roughness=1.;mat.metallic_specular=0.;material=mat
		mesh.surface_set_material(mesh.get_surface_count()-1,material)
	return mesh

func _physics_process(delta:float)->void:
	if is_instance_valid(player) and enabled:interaction.advance(delta,player.global_position,player.velocity)

func _process(delta:float)->void:
	clock+=delta
	present(Engine.get_physics_interpolation_fraction())
	for material in materials:material.set_shader_parameter("wind_time",clock)

func present(alpha:float)->void:
	# Publish only changed physics histories, never on an independent timer.
	# The GPU blends them EVERY render frame without per-blade CPU work.
	interaction.upload()
	for material in materials:material.set_shader_parameter("interaction_alpha",clampf(alpha,0.,1.))

func reset()->void:
	interaction.reset()
