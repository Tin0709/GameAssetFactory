extends Node3D
## Original meadow layout with transient external reference meshes and textures.
const Spring=preload("res://scenes/dev/actions_stuff_research/grass_md2_v001/interaction_field.gd")
const FlowerPockets=preload("flower_pockets.gd")
var materials:Array[ShaderMaterial]=[]
var enabled:=true
var wind_enabled:=true
var interactions_enabled:=true
var player:CharacterBody3D
var bundle:RefCounted
const MAP_EXTENT:=100.
const BATCH_SIZE:=16.
var interaction=Spring.new(MAP_EXTENT+4.)
var clock:=0.
var instance_count:=0
var batch_count:=0
var species_counts:Dictionary={}
var flower_colors:Dictionary={}
var flowers:Array[Vector2]=[]
var flower_pockets_enabled:=false
var _flower_batches:Array[Dictionary]=[]
var _flower_palette:=PackedInt32Array()
var _flower_original:Array[Vector2]=[]
var _flower_composed:Array[Vector2]=[]
var _decorative_rock_footprint:=Rect2()
var _batches:Dictionary={}
var _rng:=RandomNumberGenerator.new()
var _wind_intensities:Array[float]=[]
var _plant_cells:Dictionary={}

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
	_build_ground();_build_plants();_build_rocks();_extend_map();_flush()
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

func _place(asset:String,position:Vector3,yaw:float=0.,scale_factor:float=1.,flower_index:int=-1)->void:
	if not bundle.meshes.has(asset):push_error("Missing meadow species "+asset);return
	var cell:=Vector2i(floori((position.x+BATCH_SIZE)/BATCH_SIZE),floori((position.z+BATCH_SIZE)/BATCH_SIZE))
	var key:=asset+"/"+str(cell)
	if not _batches.has(key):_batches[key]={"asset":asset,"transforms":[],"phases":[]}
	var t:=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_factor),position)
	_batches[key].transforms.append(t);_batches[key].phases.append(_rng.randf()*TAU)
	if flower_index>=0:
		if not _batches[key].has("flowers"):_batches[key].flowers=PackedInt32Array()
		_batches[key].flowers.append(flower_index)
	instance_count+=1;species_counts[asset]=int(species_counts.get(asset,0))+1
	if asset.begins_with("MD2 | SM_")and not asset.contains("Boulder"):
		_add_plant_root(Vector2(position.x,position.z))

func _add_plant_root(point:Vector2)->void:
	var cell:=Vector2i(point.floor())
	if not _plant_cells.has(cell):_plant_cells[cell]=[]
	_plant_cells[cell].append(point)

func _remove_plant_root(point:Vector2)->void:
	var cell:=Vector2i(point.floor())
	var roots:Array=_plant_cells[cell]
	roots.erase(point)
	if roots.is_empty():_plant_cells.erase(cell)

func _build_ground(outer:bool=false)->void:
	var half:=50 if outer else 16
	for z in range(-half,half):
		for x in range(-half,half):
			if outer and x>=-16 and x<16 and z>=-16 and z<16:continue
			var pos:=Vector3(x+.5,0,z+.5)
			var path:=is_path(pos)
			var asset:="MD2 RECON | Dirt block "+str(_rng.randi_range(1,3)) if path else "MD2 RECON | Grass block "+str(1 if _rng.randf()<.82 else 2)
			_place(asset,Vector3(x,-1,z))
	# Source-textured stone/dirt perimeter reads as a small voxel terrain chunk.
	for i in range(-half,half):
		for side in [Vector3(i,-2,-half),Vector3(i,-2,half-1),Vector3(-half,-2,i),Vector3(half-1,-2,i)]:
			_place("MD2 RECON | Stone block "+str(_rng.randi_range(1,3)),side)

func _build_plants(outer:bool=false)->void:
	var half:=50 if outer else 16
	var short_names:=["SM_GrassShort_01","SM_GrassShort_02"]
	var medium_names:=["SM_GrassMedium_01","SM_GrassMedium_02","SM_GrassMedium_03"]
	for z in range(-half,half):
		for x in range(-half,half):
			if outer and x>=-16 and x<16 and z>=-16 and z<16:continue
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
	for cluster in (288 if outer else 32):
		var center:=Vector2(_rng.randf_range(-half+1.2,half-1.2),_rng.randf_range(-half+1.2,half-1.2))
		if absf(center.x-path_center(center.y))<2.:center.x+=3.8 if center.x>=0 else -3.8
		center=center.clamp(Vector2(-half+2,-half+2),Vector2(half-2,half-2))
		if outer and absf(center.x)<18. and absf(center.y)<18.:continue
		var color:String=colors[cluster%4];var names:Array=color_names[color]
		var radius:=_rng.randf_range(.65,1.65)
		for n in _rng.randi_range(7,16):
			var p2:=center+Vector2.from_angle(_rng.randf()*TAU)*sqrt(_rng.randf())*radius
			var p:=Vector3(p2.x,0.,p2.y)
			if foliage_density(p)<.7 or (outer and absf(p.x)<16. and absf(p.z)<16.):continue
			if flowers.any(func(other:Vector2):return other.distance_squared_to(p2)<.14):continue
			flowers.append(p2);flower_colors[color]=int(flower_colors.get(color,0))+1
			_flower_palette.append(cluster%colors.size())
			_place("MD2 | "+String(names[n%names.size()]),p,_rng.randf()*TAU,1.,flowers.size()-1)
	var tall_names:=["SM_GrassTall_01","SM_GrassTall_02"]
	for i in (360 if outer else 40):
		var p:=Vector3(_rng.randf_range(-half+1,half-1),0,_rng.randf_range(-half+1,half-1))
		if foliage_density(p)<.95 or absf(p.x)<8. or (outer and absf(p.x)<16. and absf(p.z)<16.):continue
		_place("MD2 | "+String(tall_names[i%tall_names.size()]),p,_rng.randf()*TAU)

func _build_rocks()->void:
	for i in 9:
		var angle:=float(i)/9.*TAU+.2;var point:=Vector3(cos(angle)*11.,-.08,sin(angle)*11.)
		if is_path(point):continue
		var yaw:=_rng.randf()*TAU
		_place("MD2 | SM_SF_Boulder_01",point,yaw)
		var body:=StaticBody3D.new();body.name="RockCollision";body.set_meta("overworld_surface","stone");add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=bundle.meshes["MD2 | SM_SF_Boulder_01"].create_trimesh_shape();body.add_child(shape);body.position=point;body.rotation.y=yaw
	# Decorative blocker has no collision body, but flowers still avoid its footprint.
	var asset:="MD2 | SM_PA1_Blocker_Boulder_A"
	var position:=Vector3(-14,-.15,-13)
	var yaw:=.7
	_place(asset,position,yaw)
	var mesh:Mesh=bundle.meshes.get(asset)
	if mesh!=null:
		var bounds:=Transform3D(Basis(Vector3.UP,yaw),position)*mesh.get_aabb()
		_decorative_rock_footprint=Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(.18)

func _extend_map()->void:
	# Separate random stream preserves every original central placement.
	_rng.seed=281126
	_build_ground(true);_build_plants(true)
	for i in 52:
		var point:=Vector3(_rng.randf_range(-48,48),-.08,_rng.randf_range(-48,48))
		if (absf(point.x)<18. and absf(point.z)<18.)or is_path(point):continue
		var yaw:=_rng.randf()*TAU
		_place("MD2 | SM_SF_Boulder_01",point,yaw)
		var body:=StaticBody3D.new();body.name="OuterRockCollision";body.set_meta("overworld_surface","stone");add_child(body)
		var shape:=CollisionShape3D.new();shape.shape=bundle.meshes["MD2 | SM_SF_Boulder_01"].create_trimesh_shape();body.add_child(shape);body.position=point;body.rotation.y=yaw

func _flush()->void:
	for key:String in _batches:
		var row:Dictionary=_batches[key];var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=bundle.meshes[row.asset];mm.instance_count=row.transforms.size()
		for i in mm.instance_count:mm.set_instance_transform(i,row.transforms[i]);mm.set_instance_custom_data(i,Color(row.phases[i],0,0,1))
		var instance:=MultiMeshInstance3D.new();instance.name="MeadowBatch_"+str(batch_count);instance.multimesh=mm;instance.extra_cull_margin=1.8;instance.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		# Preserve the approved lab's foliage shadow policy; native per-type flags
		# remain unverified. Dense alpha cards must not acquire new black self-shadows.
		if String(row.asset).begins_with("MD2 | SM_")and not String(row.asset).contains("Boulder"):instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance);batch_count+=1
		if row.has("flowers"):_flower_batches.append({"mesh":mm,"indices":row.flowers})
	_batches.clear()

func set_flower_pockets(value:bool,trunks:Array[StaticBody3D])->void:
	if value==flower_pockets_enabled:return
	if value and _flower_composed.is_empty():_compose_flower_pockets(trunks)
	var target:=_flower_composed if value else _flower_original
	for row:Dictionary in _flower_batches:
		var mm:MultiMesh=row.mesh
		var indices:PackedInt32Array=row.indices
		for i in indices.size():
			var index:=indices[i]
			var previous:=flowers[index]
			var point:=target[index]
			if previous==point:continue
			var transform:=mm.get_instance_transform(i)
			transform.origin.x=point.x
			transform.origin.z=point.y
			mm.set_instance_transform(i,transform)
			_remove_plant_root(previous)
			_add_plant_root(point)
			flowers[index]=point
	flower_pockets_enabled=value

func _compose_flower_pockets(trunks:Array[StaticBody3D])->void:
	_flower_original=flowers.duplicate()
	_flower_composed=flowers.duplicate()
	var roots:Array[Vector2]=[]
	var palette:=PackedInt32Array()
	var flower_order:=PackedInt32Array()
	for row:Dictionary in _flower_batches:
		for index:int in row.indices:
			roots.append(flowers[index])
			palette.append(_flower_palette[index])
			flower_order.append(index)
	var obstacles:Array[Rect2]=[]
	if _decorative_rock_footprint.has_area():obstacles.append(_decorative_rock_footprint)
	for trunk:StaticBody3D in trunks:
		var point:=trunk.global_position
		obstacles.append(Rect2(Vector2(point.x,point.z)-Vector2.ONE*.53,Vector2.ONE*1.06))
	for child:Node in get_children():
		if child is not StaticBody3D or child.get_meta("overworld_surface","")!="stone":continue
		var shape:CollisionShape3D=child.get_child(0)
		var hull:=shape.shape as ConcavePolygonShape3D
		if hull==null:continue
		var points:=hull.get_faces()
		if points.is_empty():continue
		var world:=shape.global_transform
		var first:=world*points[0]
		var bounds:=Rect2(Vector2(first.x,first.z),Vector2.ZERO)
		for local:Vector3 in points:
			var point:=world*local
			bounds=bounds.expand(Vector2(point.x,point.z))
		obstacles.append(bounds.grow(.18))
	var positions:=FlowerPockets.compose(roots,palette,obstacles,path_center,BATCH_SIZE,MAP_EXTENT*.5)
	for i in flower_order.size():_flower_composed[flower_order[i]]=positions[i]

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
func has_foliage(point:Vector3)->bool:
	var cell:=Vector2i(floori(point.x),floori(point.z));var p:=Vector2(point.x,point.z)
	for dz in range(-1,2):
		for dx in range(-1,2):
			for root:Vector2 in _plant_cells.get(cell+Vector2i(dx,dz),[]):
				if root.distance_squared_to(p)<.55*.55:return true
	return false
func surface_at(point:Vector3)->String:
	var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.2,point-Vector3.UP*.3,1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty()and hit.collider.has_meta("overworld_surface"):return hit.collider.get_meta("overworld_surface")
	return "dirt"if is_path(point)else"grass"
func snapshot()->Dictionary:
	return {"extent_m":MAP_EXTENT,"interaction_extent_m":interaction.extent,"instances":instance_count,"batches":batch_count,"species":species_counts.size(),"flower_colors":flower_colors,"wind":wind_enabled,"interaction":interactions_enabled,"active_spring_cells":interaction.active.size(),"spring_update_us":interaction.update_usec}
