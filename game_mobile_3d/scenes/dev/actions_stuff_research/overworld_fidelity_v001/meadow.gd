extends Node3D
## Original meadow layout with transient external reference meshes and textures.
const Spring=preload("res://scenes/dev/actions_stuff_research/grass_md2_v001/interaction_field.gd")
var materials:Array[ShaderMaterial]=[]
var enabled:=true
var wind_enabled:=true
var interactions_enabled:=true
var player:CharacterBody3D
var bundle:RefCounted
var interaction=Spring.new()
var clock:=0.
var instance_count:=0
var batch_count:=0
var species_counts:Dictionary={}
var flower_colors:Dictionary={}
var flowers:Array[Vector2]=[]
var _batches:Dictionary={}
var _rng:=RandomNumberGenerator.new()
var _wind_intensities:Array[float]=[]

static func path_center(z:float)->float:return 1.9*sin(z*.24)+.55*sin(z*.57)
static func is_path(point:Vector3)->bool:return absf(point.x-path_center(point.z))<.85
static func foliage_density(point:Vector3)->float:
	var distance:=absf(point.x-path_center(point.z))
	return smoothstep(.7,2.1,distance)

func setup(actor:CharacterBody3D,reader:RefCounted)->void:
	player=actor;bundle=reader;materials=reader.materials
	_rng.seed=281026
	var ground:Dictionary=reader.data.materials["OW MD2 | MI_MasterTerrain_Opaque_Overworld"]
	var top_uv:=_grass_top_uv()
	for material:ShaderMaterial in materials:
		_wind_intensities.append(float(material.get_shader_parameter("wind_intensity")))
		material.set_shader_parameter("interaction_field",interaction.texture);material.set_shader_parameter("interaction_previous",interaction.previous_texture)
		material.set_shader_parameter("ground_atlas",reader.textures[ground.texture]);material.set_shader_parameter("ground_uv",top_uv)
		material.set_shader_parameter("field_extent",interaction.extent)
	_build_ground();_build_plants();_build_rocks();_flush()
	print("OVERWORLD_FIELD_READY ",JSON.stringify(snapshot()))

func _grass_top_uv()->Vector4:
	var entry:Dictionary={}
	for candidate:Dictionary in bundle.data.assets:
		if candidate.name=="MD2 RECON | Grass block 1":entry=candidate;break
	var lo:=Vector2.ONE;var hi:=Vector2.ZERO
	for s:Dictionary in entry.get("surfaces",[]):
		for i in int(s.normals.size()/3):
			if float(s.normals[i*3+1])>.99:
				var uv:=Vector2(s.uv[i*2],s.uv[i*2+1]);lo=lo.min(uv);hi=hi.max(uv)
	return Vector4(lo.x,lo.y,hi.x,hi.y)

func _place(asset:String,position:Vector3,yaw:float=0.,scale_factor:float=1.)->void:
	if not bundle.meshes.has(asset):push_error("Missing meadow species "+asset);return
	var cell:=Vector2i(floori((position.x+16.)/16.),floori((position.z+16.)/16.))
	var key:=asset+"/"+str(cell)
	if not _batches.has(key):_batches[key]={"asset":asset,"transforms":[],"phases":[]}
	var t:=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_factor),position)
	_batches[key].transforms.append(t);_batches[key].phases.append(_rng.randf()*TAU)
	instance_count+=1;species_counts[asset]=int(species_counts.get(asset,0))+1

func _build_ground()->void:
	for z in range(-16,16):
		for x in range(-16,16):
			var pos:=Vector3(x+.5,0,z+.5)
			var path:=is_path(pos)
			var asset:="MD2 RECON | Dirt block "+str(_rng.randi_range(1,3)) if path else "MD2 RECON | Grass block "+str(1 if _rng.randf()<.82 else 2)
			_place(asset,Vector3(x,-1,z))
	# Source-textured stone/dirt perimeter reads as a small voxel terrain chunk.
	for i in range(-16,16):
		for side in [Vector3(i,-2,-16),Vector3(i,-2,15),Vector3(-16,-2,i),Vector3(15,-2,i)]:
			_place("MD2 RECON | Stone block "+str(_rng.randi_range(1,3)),side)

func _build_plants()->void:
	var short_names:=["SM_GrassShort_01","SM_GrassShort_02"]
	var medium_names:=["SM_GrassMedium_01","SM_GrassMedium_02","SM_GrassMedium_03"]
	for z in range(-16,16):
		for x in range(-16,16):
			for n in 3:
				if n==2 and _rng.randf()>.3:continue
				var p:=Vector3(x+_rng.randf(),0.,z+_rng.randf())
				var density:=foliage_density(p)
				var patch:=.73+.27*sin(p.x*.51+sin(p.z*.38))*cos(p.z*.42)
				if _rng.randf()>density*patch:continue
				var names:Array=short_names if n<2 else medium_names
				_place("MD2 | "+String(names[_rng.randi()%names.size()]),p,_rng.randf()*TAU)
	# Clusters use independent centers/radii, irregular boundaries and source scale.
	# Keep source dimensions1x. Smaller native species dominate the walkable meadow;
	# the tall library specimens are not a generic uniformly scaled flower population.
	var color_names:={"pink":["SM_CA1_TulipPink","SM_CA1_TulipPink","SM_CA1_TulipPink","SM_CA1_TulipPink","SM_TulipPink_A"],"yellow":["SM_Dandelion_A","SM_Dandelion_A","SM_Dandelion_A","SM_Dandelion_B"],"white":["SM_Daisy_A","SM_AzureBluetFlower_A","SM_Daisy_A","SM_AzureBluetFlower_A","SM_OxeyeDaisy_A","SM_Dandelion_C"],"purple":["SM_TPT_Purpleflower_S","SM_TPT_Purpleflower_S","SM_TPT_Purpleflower_S","SM_TPT_Purpleflower_M","SM_TPT_Purpleflower_L","SM_CornflowerBlue_A"]}
	var colors:Array=color_names.keys()
	for cluster in 32:
		var center:=Vector2(_rng.randf_range(-14.8,14.8),_rng.randf_range(-14.8,14.8))
		if absf(center.x-path_center(center.y))<2.:center.x+=3.8 if center.x>=0 else -3.8
		center=center.clamp(Vector2(-14,-14),Vector2(14,14))
		var color:String=colors[cluster%4];var names:Array=color_names[color]
		var radius:=_rng.randf_range(.65,1.65)
		for n in _rng.randi_range(7,16):
			var p2:=center+Vector2.from_angle(_rng.randf()*TAU)*sqrt(_rng.randf())*radius
			var p:=Vector3(p2.x,0.,p2.y)
			if foliage_density(p)<.7:continue
			if flowers.any(func(other:Vector2):return other.distance_squared_to(p2)<.14):continue
			flowers.append(p2);flower_colors[color]=int(flower_colors.get(color,0))+1
			_place("MD2 | "+String(names[n%names.size()]),p,_rng.randf()*TAU)
	var tall_names:=["SM_GrassTall_01","SM_GrassTall_02"]
	for i in 40:
		var p:=Vector3(_rng.randf_range(-15,15),0,_rng.randf_range(-15,15))
		if foliage_density(p)<.95 or absf(p.x)<8.:continue
		_place("MD2 | "+String(tall_names[i%tall_names.size()]),p,_rng.randf()*TAU)

func _build_rocks()->void:
	for i in 9:
		var angle:=float(i)/9.*TAU+.2;var point:=Vector3(cos(angle)*11.,-.08,sin(angle)*11.)
		if is_path(point):continue
		var yaw:=_rng.randf()*TAU
		_place("MD2 | SM_SF_Boulder_01",point,yaw)
		var body:=StaticBody3D.new();body.name="RockCollision";add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=bundle.meshes["MD2 | SM_SF_Boulder_01"].create_trimesh_shape();body.add_child(shape);body.position=point;body.rotation.y=yaw
	# Large source rock remains beyond the playable boundary, without hiding player.
	_place("MD2 | SM_PA1_Blocker_Boulder_A",Vector3(-14,-.15,-13),.7)

func _flush()->void:
	for key:String in _batches:
		var row:Dictionary=_batches[key];var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=bundle.meshes[row.asset];mm.instance_count=row.transforms.size()
		for i in mm.instance_count:mm.set_instance_transform(i,row.transforms[i]);mm.set_instance_custom_data(i,Color(row.phases[i],0,0,1))
		var instance:=MultiMeshInstance3D.new();instance.name="MeadowBatch_"+str(batch_count);instance.multimesh=mm;instance.extra_cull_margin=1.8;instance.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;add_child(instance);batch_count+=1
	_batches.clear()

func _physics_process(delta:float)->void:
	if is_instance_valid(player) and enabled:
		var point:=player.global_position
		if not interactions_enabled:point.y=100.
		interaction.advance(delta,point,player.velocity)

func _process(delta:float)->void:
	clock+=delta;present(Engine.get_physics_interpolation_fraction())
	for i in materials.size():
		materials[i].set_shader_parameter("wind_time",clock)
		materials[i].set_shader_parameter("wind_intensity",_wind_intensities[i] if wind_enabled else 0.)

func present(alpha:float)->void:
	interaction.upload()
	for material:ShaderMaterial in materials:
		material.set_shader_parameter("interaction_alpha",clampf(alpha,0.,1.));material.set_shader_parameter("interaction_strength",1. if interactions_enabled else 0.)

func reset()->void:interaction.reset()
func snapshot()->Dictionary:
	return {"instances":instance_count,"batches":batch_count,"species":species_counts.size(),"flower_colors":flower_colors,"wind":wind_enabled,"interaction":interactions_enabled,"active_spring_cells":interaction.active.size(),"spring_update_us":interaction.update_usec}
