extends "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/meadow.gd"
## Private reference planting on the EXISTING authored terrain, not another map.
const READER=preload("private_bundle.gd")
const GRASSES:=["MD2 | SM_GrassShort_01","MD2 | SM_GrassShort_02","MD2 | SM_GrassMedium_02","MD2 | SM_GrassMedium_03"]
const FLOWERS:={"pink":"MD2 | SM_CA1_TulipPink","yellow":"MD2 | SM_Dandelion_A","white":"MD2 | SM_Daisy_A","purple":"MD2 | SM_TPT_Purpleflower_S"}
const TILE:=32.
const MEDIUM:=["MD2 | SM_GrassMedium_01","MD2 | SM_GrassMedium_02","MD2 | SM_GrassMedium_03"]
const GRASS_LIGHT=preload("world_map_grass_light.gd")
const GRASS_SPLAY=preload("world_map_grass_splay.gd")
const GRASS_WIND=preload("world_map_grass_wind.gd")
var grass_wind:RefCounted
var recovered_wind_enabled:=true
var grass_light:RefCounted
var grass_lighting_enabled:=true
var grass_edge_sampling_enabled:=true
var grass_splay:RefCounted
var grass_splay_enabled:=true
var dense_grass_review:=true
var eligible_grass_cells:=0
var world:Node3D
var error:=""
var placements:Array[Dictionary]=[]
var _groups:Dictionary={}
var _flower_centers:Array[Dictionary]=[]
var _cluster:=FastNoiseLite.new()
var _detail:=FastNoiseLite.new()
var _native_wind_intensities:Dictionary={}

func setup_world(level:Node3D)->void:
	world=level;player=level.player;process_physics_priority=4;process_priority=1
	bundle=READER.new()
	var research:=OS.get_environment("MD2_RESEARCH_ROOT")
	if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
	if bundle.read(research.path_join("godot_lab/overworld_fidelity_v001/bundle.private.json")).is_empty():
		error=bundle.error;push_warning(error);set_physics_process(false);set_process(false);return
	for material:ShaderMaterial in bundle.materials:
		_native_wind_intensities[material.get_instance_id()]=float(material.get_shader_parameter("wind_intensity"))
	grass_light=GRASS_LIGHT.new();grass_light.setup(world,bundle)
	grass_splay=GRASS_SPLAY.new();grass_splay.setup(bundle)
	grass_wind=GRASS_WIND.new();grass_wind.setup(bundle)
	interaction=Spring.new(104.)
	interaction.surface_height_provider=world.surface_height
	_rng.seed=110826
	_cluster.seed=8291;_cluster.frequency=.075;_cluster.fractal_octaves=2
	_detail.seed=721;_detail.frequency=.23;_detail.fractal_octaves=2
	_rebuild_planting()
	player.presentation_reset.connect(reset)
	print("WORLD_MAP_GRASS_FLOWERS_READY ",JSON.stringify(snapshot()))

func set_dense_review(value:bool)->void:
	if value==dense_grass_review:return
	dense_grass_review=value;_rebuild_planting()

func _rebuild_planting()->void:
	for child:Node in get_children():
		remove_child(child);child.queue_free()
	placements.clear();_groups.clear();_plant_cells.clear();species_counts.clear();flower_colors.clear()
	materials.clear();_wind_intensities.clear();_flower_centers.clear()
	instance_count=0;batch_count=0;eligible_grass_cells=0;_rng.seed=110826
	_build_flower_centers()
	if dense_grass_review:
		_build_native_patches();_build_dense_planting()
	else:_build_cell_planting()
	_prepare_materials();_refresh_grass_lighting();_flush_cell_batches();_refresh_grass_wind();reset()

func set_recovered_wind(value:bool)->void:
	recovered_wind_enabled=value;_refresh_grass_wind()

func _refresh_grass_wind()->void:
	if grass_wind==null:return
	var active:bool=recovered_wind_enabled and dense_grass_review and grass_wind.configured
	grass_wind.apply(materials,active)
	for child:Node in get_children():
		if child is MultiMeshInstance3D:
			child.extra_cull_margin=grass_wind.margin(child.multimesh,child.global_transform.basis) if active and child.get_meta("green_grass",false) else .8

func set_grass_lighting(value:bool)->void:
	grass_lighting_enabled=value;_refresh_grass_lighting()

func set_grass_edge_sampling(value:bool)->void:
	if value==grass_edge_sampling_enabled:return
	grass_edge_sampling_enabled=value
	_refresh_grass_lighting()

func _grass_edge_sampling_wanted()->bool:
	return grass_edge_sampling_enabled and get_viewport().msaa_3d != Viewport.MSAA_DISABLED

func _refresh_grass_lighting()->void:
	if grass_light==null:return
	grass_light.apply(materials,grass_lighting_enabled and world.look.stage==2,_grass_edge_sampling_wanted())
	for node:Node in get_children():
		if node is MultiMeshInstance3D:
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if grass_light.active and node.get_meta("green_grass",false) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func grass_splay_active()->bool:
	return dense_grass_review and grass_splay_enabled and grass_splay!=null and grass_splay.configured

func set_grass_splay(value:bool)->void:
	if value==grass_splay_enabled:return
	grass_splay_enabled=value
	if dense_grass_review:_rebuild_planting()

func _patch_name(index:int)->String:
	return ("PRIVATE COMPOSITE | Native grass fan %02d" if grass_splay_active() else "PRIVATE COMPOSITE | Native grass patch %02d")%index

func _build_native_patches()->void:
	# One transient patch mesh per root. Native cards/UVs/heights stay at1x;
	# their assembly into crossed tufts is original, not a recovered MD2 mesh.
	for variant in 6:
		var name:=_patch_name(variant)
		if bundle.meshes.has(name):continue
		var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
		var uvs:=PackedVector2Array();var roots:=PackedVector2Array();var motion:=PackedFloat32Array()
		for card in 4:
			var source_name:String=MEDIUM[(variant+card)%3] if card<3 else GRASSES[variant%2]
			var source:Mesh=bundle.meshes[source_name]
			var arrays:=source.surface_get_arrays(0)
			var raw:Variant=arrays[Mesh.ARRAY_CUSTOM0]
			var source_motion:PackedFloat32Array=raw.to_float32_array() if raw is PackedByteArray else raw
			var angle:=float(card)*TAU/3.+float(variant)*.13 if card<3 else .37+variant*.23
			var rotation:=Basis(Vector3.UP,angle)
			var offset:=Vector3(cos(angle)*.12,0.,sin(angle)*.12)
			var tilt:=Basis.IDENTITY
			var pivot:=Vector3.ZERO
			if grass_splay_active():
				# Rigid pitch about each card's horizontal bottom edge. The three
				# outward headings are an original radial assembly, not native layout.
				tilt=Basis(Vector3.FORWARD,grass_splay.angle(variant*4+card))
				offset=rotation*Vector3(.12,0.,0.)
				var bounds:=source.get_aabb();pivot=Vector3(bounds.get_center().x,bounds.position.y,0.)
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				vertices.append(rotation*(pivot+tilt*(arrays[Mesh.ARRAY_VERTEX][i]-pivot))+offset)
				normals.append(rotation*tilt*arrays[Mesh.ARRAY_NORMAL][i]);uvs.append(arrays[Mesh.ARRAY_TEX_UV][i])
				var root:Vector2=arrays[Mesh.ARRAY_TEX_UV2][i]
				var transformed:=rotation*Vector3(root.x,0.,root.y)+offset
				roots.append(Vector2(transformed.x,transformed.z))
				motion.append_array(PackedFloat32Array([source_motion[i*4],source_motion[i*4+1],source_motion[i*4+2]+float(card)*1.1,source_motion[i*4+3]]))
		var result:Array=[];result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX]=vertices;result[Mesh.ARRAY_NORMAL]=normals
		result[Mesh.ARRAY_TEX_UV]=uvs;result[Mesh.ARRAY_TEX_UV2]=roots;result[Mesh.ARRAY_CUSTOM0]=motion
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.surface_set_material(0,bundle.meshes[MEDIUM[1]].surface_get_material(0))
		bundle.meshes[name]=mesh

func _build_dense_planting()->void:
	var keys:Array=world.columns.keys();keys.sort()
	for column:Vector2i in keys:
		var height:float=world.columns[column]
		var position:Vector3=world.source_to_world(Vector3i(column.x,0,column.y));position.y=height+float(world.runtime.offset[1])
		var low:Array=world.runtime.border.min;var high:Array=world.runtime.border.max
		if position.x<low[0] or position.x>=high[0] or position.z<low[2] or position.z>=high[2]:continue
		if not world.clear_standing_space(column,height):continue
		var index:int=world.geometry.cells.get(Vector3i(column.x,floori(height-.01),column.y),-1)
		if index<0:continue
		var kind:String=world.runtime.palette[index].kind
		if not kind.begins_with("grass_"):continue # Dirt path blocks remain bare.
		eligible_grass_cells+=1
		var cell:=Vector2i(floori(position.x),floori(position.z))
		var asset:=_patch_name(_rng.randi()%6)
		position+=Vector3(_rng.randf_range(-.09,.09),0.,_rng.randf_range(-.09,.09))
		var transform:=Transform3D(Basis(Vector3.UP,_rng.randf()*TAU),position)
		var bounds:AABB=transform*bundle.meshes[asset].get_aabb()
		var key:=asset+"/"+str(Vector2i(floori(position.x/TILE),floori(position.z/TILE)))
		if not _groups.has(key):_groups[key]={"asset":asset,"transforms":[],"custom":[]}
		_groups[key].transforms.append(transform);_groups[key].custom.append(Color(_rng.randf()*TAU,cell.x+.5,cell.y+.5,1.))
		placements.append({"cell":cell,"root":position,"asset":asset,"bounds":bounds,"flower":"","carpet":true,"scale":1.,"cards":4,"ground_kind":kind})
		_add_plant_root(Vector2(position.x,position.z))
		instance_count+=1;species_counts[asset]=int(species_counts.get(asset,0))+1

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
	var margin:=Vector2(.94-bounds.size.x,.94-bounds.size.z).max(Vector2.ZERO)*.5
	var jitter:=Vector3(_rng.randf_range(-margin.x,margin.x),0.,_rng.randf_range(-margin.y,margin.y))
	transform.origin+=jitter;position+=jitter;bounds=transform*original
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
		_wind_intensities.append(float(_native_wind_intensities.get(material.get_instance_id(),bundle.data.motion.intensity)))
		material.set_shader_parameter("interaction_field",interaction.texture)
		material.set_shader_parameter("interaction_previous",interaction.previous_texture)
		material.set_shader_parameter("field_extent",interaction.extent)
		material.set_shader_parameter("ground_atlas",bundle.textures[ground.texture]);material.set_shader_parameter("ground_uv",uv)
		material.set_shader_parameter("cell_limited_motion",not dense_grass_review)
		material.set_shader_parameter("splayed_rest_motion",grass_splay_active())
		material.set_shader_parameter("ground_mask_enabled",dense_grass_review)
		material.set_shader_parameter("ground_coverage_map",world.look.path_map)
		material.set_shader_parameter("ground_coverage_origin",world.look.path_map_origin)
		material.set_shader_parameter("ground_coverage_extent",world.look.path_map_size)

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
		var green:bool=mm.mesh.surface_get_material(0).get_shader_parameter("tinted_grass")==true
		node.set_meta("green_grass",green)
		if grass_light!=null and grass_light.active and green:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(node);batch_count+=1
	_groups.clear()

func _physics_process(delta:float)->void:
	clock+=delta
	if not enabled or not visible:return
	var point:=player.global_position
	if not interactions_enabled:point.y=100.
	interaction.advance(delta,point,player.velocity)

func _process(_delta:float)->void:
	if not visible:return
	if grass_light!=null:
		var wanted:bool=grass_lighting_enabled and world.look.stage==2 and grass_light.supported()
		if wanted!=grass_light.active or (wanted and _grass_edge_sampling_wanted()!=grass_light.edge_sampling_active):
			_refresh_grass_lighting()
		grass_light.sync()
	present(Engine.get_physics_interpolation_fraction())
	var displayed:float=world.presentation.wind_time(clock) if world.presentation.enabled else clock
	for i in materials.size():
		materials[i].set_shader_parameter("wind_time",displayed)
		materials[i].set_shader_parameter("wind_intensity",_wind_intensities[i] if wind_enabled else 0.)

func snapshot()->Dictionary:
	var data:=super.snapshot()
	data["one_asset_per_block"]=true;data["trees"]=0
	data["dense_grass_review"]=dense_grass_review;data["eligible_grass_cells"]=eligible_grass_cells
	data["grass_splay_active"]=grass_splay_active()
	data["recovered_wind_active"]=grass_wind!=null and grass_wind.configured and recovered_wind_enabled and dense_grass_review
	if dense_grass_review:
		data["source_card_scale"]=1.;data["cards_per_patch"]=4
		var heights:Array[float]=[]
		for name:String in MEDIUM:heights.append(bundle.meshes[name].get_aabb().size.y)
		data["native_medium_height_m"]=heights
		data["patch_height_m"]=bundle.meshes[_patch_name(0)].get_aabb().size.y
		data["player_source_height_m"]=bundle.data.scale_evidence.player_static_mesh_height_m
		data["patch_to_player_height_ratio"]=float(data.patch_height_m)/float(data.player_source_height_m)
	data["carpet_cells"]=placements.filter(func(row:Dictionary)->bool:return row.carpet and row.flower.is_empty()).size()
	data["mesh_material_scope"]="Existing private MD2 source bundle; cell fit/distribution/motion limits are original adapters"
	return data

func _exit_tree()->void:
	if grass_light!=null:grass_light.restore()
