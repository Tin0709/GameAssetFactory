extends "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/meadow.gd"
## Private reference planting on the EXISTING authored terrain, not another map.
const READER=preload("private_bundle.gd")
const GRASSES:=["MD2 | SM_GrassShort_01","MD2 | SM_GrassShort_02","MD2 | SM_GrassMedium_02","MD2 | SM_GrassMedium_03"]
const FLOWERS:={"pink":"MD2 | SM_CA1_TulipPink","yellow":"MD2 | SM_Dandelion_A","white":"MD2 | SM_Daisy_A","purple":"MD2 | SM_TPT_Purpleflower_S"}
const TILE:=32.
var world:Node3D
var error:=""
var placements:Array[Dictionary]=[]
var _groups:Dictionary={}
var _flower_centers:Array[Dictionary]=[]
var _cluster:=FastNoiseLite.new()
var _detail:=FastNoiseLite.new()

func setup_world(level:Node3D)->void:
	world=level;player=level.player;process_physics_priority=4;process_priority=1
	bundle=READER.new()
	var research:=OS.get_environment("MD2_RESEARCH_ROOT")
	if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
	if bundle.read(research.path_join("godot_lab/overworld_fidelity_v001/bundle.private.json")).is_empty():
		error=bundle.error;push_warning(error);set_physics_process(false);set_process(false);return
	interaction=Spring.new(104.)
	_rng.seed=110826
	_cluster.seed=8291;_cluster.frequency=.075;_cluster.fractal_octaves=2
	_detail.seed=721;_detail.frequency=.23;_detail.fractal_octaves=2
	_build_flower_centers()
	_build_cell_planting()
	_prepare_materials()
	_flush_cell_batches()
	player.presentation_reset.connect(reset)
	print("WORLD_MAP_GRASS_FLOWERS_READY ",JSON.stringify(snapshot()))

func _build_flower_centers()->void:
	var colors:Array=FLOWERS.keys()
	for z in range(-42,44,12):
		for x in range(-42,44,12):
			_flower_centers.append({"position":Vector2(x+_rng.randf_range(-3.,3.),z+_rng.randf_range(-3.,3.)),"radius":_rng.randf_range(1.8,3.8),"color":colors[_rng.randi()%4]})
	for i in 4:
		_flower_centers.append({"position":Vector2(-4. if i%2==0 else 4.,-4. if i<2 else 4.),"radius":2.2,"color":colors[i]})

func _build_cell_planting()->void:
	var keys:Array=world.columns.keys();keys.sort()
	for column:Vector2i in keys:
		var height:float=world.columns[column]
		var position:Vector3=world.source_to_world(Vector3i(column.x,0,column.y))
		position.y=height+float(world.runtime.offset[1])
		if absf(position.x)>48.5 or absf(position.z)>48.5:continue
		if not world.clear_standing_space(column,height):continue
		var source_cell:=Vector3i(column.x,floori(height-.01),column.y)
		var index:int=world.geometry.cells.get(source_cell,-1)
		if index<0 or not String(world.runtime.palette[index].kind).begins_with("grass_"):continue
		var cell:=Vector2i(floori(position.x),floori(position.z))
		var pixel:=Vector2i(Vector2(cell)-world.look.path_map_origin)
		var ground:Color=world.look.path_map_image.get_pixel(pixel.x,pixel.y)
		# Keep the existing blended dirt paths and their immediate edges open.
		if (int(round(ground.r))&255)!=0:continue
		if Vector2(position.x-world.spawn_position.x,position.z-world.spawn_position.z).length()<1.7:continue
		var p:=Vector2(position.x,position.z)
		var mass:=.5+.5*_cluster.get_noise_2d(p.x,p.y)
		var detail:=.5+.5*_detail.get_noise_2d(p.x,p.y)
		var carpet:=mass>.47
		var clump:=detail>.59 and mass>.34
		var color:=""
		var distance:=INF
		for center:Dictionary in _flower_centers:
			var d:float=p.distance_to(center.position)/float(center.radius)
			if d<distance:distance=d;color=center.color
		var flower:=distance<1. and _rng.randf()<(.82 if distance<.7 else .5)
		if not flower and not carpet and not clump:continue
		if not flower and _rng.randf()>(.93 if carpet else .72):continue
		# Coherent short/medium families per patch, rather than mixed-color noise.
		var grass_index: int=(0 if detail<.5 else 1)+(2 if mass>.55 else 0)
		var asset:String=FLOWERS[color] if flower else GRASSES[grass_index]
		_add_cell(asset,cell,position, color if flower else "",carpet)

func _add_cell(asset:String,cell:Vector2i,position:Vector3,color:String,carpet:bool)->void:
	var mesh:Mesh=bundle.meshes[asset]
	var original:=mesh.get_aabb()
	var yaw:=_rng.randf()*TAU
	var rotation:=Basis(Vector3.UP,yaw)
	var rotated:AABB=Transform3D(rotation,Vector3.ZERO)*original
	var scale_factor:=minf(1.,.84/maxf(rotated.size.x,rotated.size.z))*_rng.randf_range(.91,1.)
	var basis:=rotation.scaled(Vector3.ONE*scale_factor)
	var center:=original.get_center();center.y=original.position.y
	var transform:=Transform3D(basis,position-basis*center)
	var bounds:AABB=transform*original
	var key:=asset+"/"+str(Vector2i(floori(position.x/TILE),floori(position.z/TILE)))
	if not _groups.has(key):_groups[key]={"asset":asset,"transforms":[],"custom":[]}
	_groups[key].transforms.append(transform)
	_groups[key].custom.append(Color(_rng.randf()*TAU,cell.x+.5,cell.y+.5,scale_factor))
	placements.append({"cell":cell,"asset":asset,"bounds":bounds,"flower":color,"carpet":carpet})
	_add_plant_root(Vector2(position.x,position.z))
	instance_count+=1;species_counts[asset]=int(species_counts.get(asset,0))+1
	if not color.is_empty():flower_colors[color]=int(flower_colors.get(color,0))+1

func _prepare_materials()->void:
	var seen:Dictionary={}
	for key:String in _groups:
		var mesh:Mesh=bundle.meshes[_groups[key].asset]
		for surface in mesh.get_surface_count():
			var material:=mesh.surface_get_material(surface) as ShaderMaterial
			if material==null or seen.has(material.get_instance_id()):continue
			seen[material.get_instance_id()]=true;materials.append(material)
	var ground:Dictionary=bundle.data.materials["OW MD2 | MI_MasterTerrain_Opaque_Overworld"]
	var uv:=_grass_top_uv()
	for material:ShaderMaterial in materials:
		_wind_intensities.append(float(material.get_shader_parameter("wind_intensity")))
		material.set_shader_parameter("interaction_field",interaction.texture)
		material.set_shader_parameter("interaction_previous",interaction.previous_texture)
		material.set_shader_parameter("field_extent",interaction.extent)
		material.set_shader_parameter("ground_atlas",bundle.textures[ground.texture]);material.set_shader_parameter("ground_uv",uv)
		material.set_shader_parameter("cell_limited_motion",true)

func _flush_cell_batches()->void:
	for key:String in _groups:
		var row:Dictionary=_groups[key]
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true
		mm.mesh=bundle.meshes[row.asset];mm.instance_count=row.transforms.size()
		for i in mm.instance_count:
			mm.set_instance_transform(i,row.transforms[i]);mm.set_instance_custom_data(i,row.custom[i])
		var node:=MultiMeshInstance3D.new();node.name="GrassFlowers_%03d"%batch_count
		node.multimesh=mm;node.extra_cull_margin=.8
		node.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node);batch_count+=1
	_groups.clear()

func _physics_process(delta:float)->void:
	clock+=delta
	if not enabled or not visible:return
	var point:=player.global_position
	var height:float=world.surface_height(point.x,point.z)
	point.y=maxf(0.,point.y-height) if is_finite(height) else 100.
	if not interactions_enabled:point.y=100.
	interaction.advance(delta,point,player.velocity)

func _process(_delta:float)->void:
	if not visible:return
	present(Engine.get_physics_interpolation_fraction())
	var displayed:float=world.presentation.wind_time(clock) if world.presentation.enabled else clock
	for i in materials.size():
		materials[i].set_shader_parameter("wind_time",displayed)
		materials[i].set_shader_parameter("wind_intensity",_wind_intensities[i] if wind_enabled else 0.)

func snapshot()->Dictionary:
	var data:=super.snapshot()
	data["one_asset_per_block"]=true;data["trees"]=0
	data["carpet_cells"]=placements.filter(func(row:Dictionary)->bool:return row.carpet and row.flower.is_empty()).size()
	data["mesh_material_scope"]="Existing private MD2 source bundle; cell fit/distribution/motion limits are original adapters"
	return data
