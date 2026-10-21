extends Node3D
## Only instantiated by the existing research lab. No production shader edits.
const Field=preload("res://scenes/dev/actions_stuff_research/grass_md2_v001/interaction_field.gd")
const GRASS_SHADER=preload("res://scenes/dev/actions_stuff_research/grass_md2_v001/grass.gdshader")
const ASSETS:="res://scenes/dev/actions_stuff_research/grass_md2_v001/assets/"
var player:CharacterBody3D
var interaction=Field.new()
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

func setup(actor:CharacterBody3D)->void:
	player=actor
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"grass_data.json"))
	for entry:Dictionary in data.meshes:meshes.append(_mesh(entry,true))
	var ground_mesh:=_mesh(data.ground,false)
	var ground:=MultiMesh.new();ground.transform_format=MultiMesh.TRANSFORM_3D;ground.mesh=ground_mesh;ground.instance_count=900
	for x in 30:
		for z in 30:ground.set_instance_transform(x*30+z,Transform3D(Basis.IDENTITY,Vector3(x-14.5,-1.,z-14.5)))
	var terrain:=MultiMeshInstance3D.new();terrain.name="ThirtyByThirtyBlocks";terrain.multimesh=ground;add_child(terrain)
	# Four15x15regions, eight exact variants each. Static buffers never rebuilt per frame.
	var buckets:Array[Array]=[]
	for i in 32:buckets.append([])
	var rng:=RandomNumberGenerator.new();rng.seed=2301021
	for x in 30:
		for z in 30:
			cells.append(x*30+z)
			var count:=2 if rng.randf()<.48 else 1
			for j in count:
				var tall:=rng.randf()<.46
				var variant:=rng.randi_range(0,3)+(4 if tall else 0)
				var region:=int(x/15)*2+int(z/15)
				var position:=Vector3(x-14.5+rng.randf_range(-.20,.20),0,z-14.5+rng.randf_range(-.20,.20))
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
	print("MD2_GRASS_FIELD_READY ",JSON.stringify({"blocks":900,"clumps":instance_count,"short":short_count,"tall":tall_count,"batches":batch_count}))

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
				found.set_shader_parameter("interaction_field",interaction.texture)
				found.set_shader_parameter("interaction_previous",interaction.previous_texture)
				found.set_shader_parameter("family_response",.72 if entry.family=="short" else 1.)
				materials.append(found)
			material=found
		else:
			var mat:=StandardMaterial3D.new();mat.albedo_texture=_atlas(surface.atlas);mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;mat.roughness=1.;material=mat
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
