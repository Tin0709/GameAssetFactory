extends Node
## WorldMap-only look. Source textures, GLBs, shared environments and actors stay intact.
const GROUND=preload("res://materials/world_map_ground.gdshader")
const PLANTS=preload("res://materials/world_map_plants.gdshader")
const LEAVES=preload("res://materials/world_map_leaves.gdshader")
const MOTION=preload("res://scripts/grassland_motion.gd")
var level: Node3D
var motion=MOTION.new()
var wind_materials: Array[ShaderMaterial]=[]
var terrain_materials: Array[Array]=[]
var plant_meshes: Array[Array]=[]
var materials: Dictionary={}
var baseline_environment: Environment
var baseline_sun: Dictionary={}
var stage:=2
var previous_position:=Vector3.ZERO
var elapsed:=0.0
var active:=true
var saved_shadow_size:=1024
var saved_shadow_16bit:=true
var saved_shadow_quality:=1
var filtered_textures: Dictionary={}
var path_map: ImageTexture
var path_map_image: Image
var path_map_origin:=Vector2.ZERO
var path_map_size:=Vector2.ZERO
var path_edge_cells:=0
var cloud_image: Image
var cloud_texture: ImageTexture
var actor_materials: Array[Array]=[]
var cloud_clock:=0.0

func setup(map: Node3D) -> void:
	level=map
	process_physics_priority=3
	baseline_environment=level.get_node("WorldEnvironment").environment.duplicate()
	build_path_map()
	build_cloud_field()
	saved_shadow_size=int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size",1024))
	saved_shadow_16bit=bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits",true))
	saved_shadow_quality=int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality",1))
	for property: String in ["light_energy","light_color","shadow_opacity","shadow_blur","shadow_bias","shadow_normal_bias"]:
		baseline_sun[property]=level.get_node("Sun").get(property)
	for chunk: MeshInstance3D in level.geometry.terrain_chunks:
		for index in chunk.mesh.get_surface_count():
			var native: Material=chunk.mesh.surface_get_material(index)
			terrain_materials.append([chunk.mesh,index,native,make_material(native,"terrain")])
	var copies: Dictionary={}
	for batch: MultiMeshInstance3D in level.geometry.vegetation_batches:
		var native: Mesh=batch.multimesh.mesh
		var kind: String=batch.get_meta("kind")
		var key: String=str(native.get_instance_id())+":"+kind
		if not copies.has(key):
			var review: Mesh=native.duplicate()
			for surface in review.get_surface_count():
				review.surface_set_material(surface,make_material(native.surface_get_material(surface),kind))
			copies[key]=review
		plant_meshes.append([batch.multimesh,native,copies[key]])
		# Bound all wind/player deformation so chunk culling cannot trim tips.
		batch.extra_cull_margin=.65 if kind=="tall_grass" else .3
	configure_path_materials()
	for node: Node in level.player.visual.find_children("*","MeshInstance3D",true,false):
		for index in node.mesh.get_surface_count():
			var native: Material=node.get_active_material(index)
			if native is BaseMaterial3D:
				actor_materials.append([node,index,node.get_surface_override_material(index),native.duplicate(),native.albedo_color])
	previous_position=level.player.position
	set_stage(2)

func make_material(native: BaseMaterial3D,kind: String) -> ShaderMaterial:
	var key: String=str(native.get_instance_id())+":"+kind
	if materials.has(key):return materials[key]
	var material:=ShaderMaterial.new()
	if kind=="terrain":
		material.shader=GROUND
		var name_lower:=native.resource_name.to_lower()
		var grade:=3 if "stone" in name_lower else (1 if "grass" in name_lower else 2)
		material.set_shader_parameter("ground_grade",grade)
		material.set_shader_parameter("texture_contrast",.38 if grade!=3 else .42)
		material.set_shader_parameter("use_vertex_color",native.vertex_color_use_as_albedo)
	elif kind.begins_with("leaf"):
		material.shader=LEAVES
		material.set_shader_parameter("wind_strength",1.5)
		wind_materials.append(material)
	else:
		material.shader=PLANTS
		material.set_shader_parameter("plant_kind",0 if kind=="short_grass" else (2 if kind=="tall_grass" else 1))
		material.set_shader_parameter("wind_strength",1.5 if kind=="tall_grass" else 2.0)
		wind_materials.append(material)
	material.set_shader_parameter("atlas",native.albedo_texture)
	if kind=="terrain" and native.albedo_texture!=null:
		var texture_key:=native.albedo_texture.get_instance_id()
		if not filtered_textures.has(texture_key):
			var image: Image=native.albedo_texture.get_image().duplicate()
			if image.is_compressed():image.decompress()
			image.generate_mipmaps()
			filtered_textures[texture_key]=ImageTexture.create_from_image(image)
		material.set_shader_parameter("atlas",filtered_textures[texture_key])
		material.set_shader_parameter("smooth_atlas",filtered_textures[texture_key])
		material.set_shader_parameter("smooth_sampling",true)
	material.set_shader_parameter("use_albedo_texture",native.albedo_texture!=null)
	material.set_shader_parameter("albedo_tint",native.albedo_color)
	material.set_shader_parameter("cloud_field",cloud_texture)
	material.set_shader_parameter("clouds_enabled",true)
	materials[key]=material
	return material

func build_path_map() -> void:
	var bounds: Dictionary=level.runtime.source_bounds
	path_map_origin=Vector2(bounds.min[0]+level.runtime.offset[0],bounds.min[2]+level.runtime.offset[2])
	path_map_size=Vector2(bounds.max[0]-bounds.min[0]+1,bounds.max[2]-bounds.min[2]+1)
	path_map_image=Image.create(int(path_map_size.x),int(path_map_size.y),false,Image.FORMAT_RGBAF)
	var tops: Dictionary={}
	for cell: Array in level.runtime.cells:
		var entry: Dictionary=level.runtime.palette[cell[3]]
		if entry.category!="terrain":continue
		var key:=Vector2i(cell[0],cell[2])
		var height: float=cell[1]+entry.base_y_offset+entry.height+level.runtime.offset[1]
		if tops.has(key) and tops[key].y>=height:continue
		var kind:=1 if str(entry.kind).begins_with("grass_") else (2 if str(entry.kind).begins_with("dirt_") else 0)
		tops[key]=Vector2(kind,height)
	var directions: Array[Vector2i]=[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]
	for key: Vector2i in tops:
		var value: Vector2=tops[key]
		var mask:=0
		if value.x>0:
			for index in directions.size():
				var other: Vector2=tops.get(key+directions[index],Vector2.ZERO)
				if other.x>0 and other.x!=value.x and is_equal_approx(other.y,value.y):mask|=1<<index
		if mask!=0:path_edge_cells+=1
		path_map_image.set_pixel(key.x-bounds.min[0],key.y-bounds.min[2],Color(mask,value.y,value.x,1))
	path_map=ImageTexture.create_from_image(path_map_image)

func configure_path_materials() -> void:
	var grass: Texture2D
	var dirt: Texture2D
	for item: Array in terrain_materials:
		var native: Material=item[2]
		if native.resource_name=="DI_V3_grass_top_0":grass=item[3].get_shader_parameter("atlas")
		if native.resource_name=="DI_V3_dirt":dirt=item[3].get_shader_parameter("atlas")
	for item: Array in terrain_materials:
		var material: ShaderMaterial=item[3]
		material.set_shader_parameter("path_blending",grass!=null and dirt!=null)
		material.set_shader_parameter("path_surface_map",path_map)
		material.set_shader_parameter("path_map_origin",path_map_origin)
		material.set_shader_parameter("path_map_size",path_map_size)
		material.set_shader_parameter("path_grass_atlas",grass)
		material.set_shader_parameter("path_dirt_atlas",dirt)

func build_cloud_field() -> void:
	cloud_image=Image.create(64,64,false,Image.FORMAT_RF)
	var rng:=RandomNumberGenerator.new();rng.seed=78126
	for y in 64:
		for x in 64:cloud_image.set_pixel(x,y,Color(rng.randf(),0,0,1))
	cloud_texture=ImageTexture.create_from_image(cloud_image)

func cloud_sample(point: Vector2) -> float:
	var cell:=Vector2i(floori(point.x),floori(point.y))
	var f:=Vector2(fposmod(point.x,1.0),fposmod(point.y,1.0))
	return lerpf(lerpf(cloud_image.get_pixel(posmod(cell.x,64),posmod(cell.y,64)).r,cloud_image.get_pixel(posmod(cell.x+1,64),posmod(cell.y,64)).r,f.x),lerpf(cloud_image.get_pixel(posmod(cell.x,64),posmod(cell.y+1,64)).r,cloud_image.get_pixel(posmod(cell.x+1,64),posmod(cell.y+1,64)).r,f.x),f.y)

func cloud_shade(position: Vector3,time: float) -> float:
	var p: Vector2=(Vector2(position.x,position.z)+Vector2(time*.48,time*.19))/13.0
	var density: float=(cloud_sample(p)+cloud_sample(p*2.07+Vector2(17,9))*.32)/1.32
	return 1.0-smoothstep(.50,.73,density)*.20

func publish_clouds(time: float) -> void:
	cloud_clock=time
	for material: ShaderMaterial in materials.values():material.set_shader_parameter("cloud_time",time)
	level.geometry.update_cloud_time(time)
	var shade:=cloud_shade(level.player.position,time) if stage>0 else 1.0
	for item: Array in actor_materials:
		var linear: Color=item[4].srgb_to_linear()
		item[3].albedo_color=Color(linear.r*shade,linear.g*shade,linear.b*shade,linear.a).linear_to_srgb()

func set_stage(value: int) -> void:
	stage=clampi(value,0,2)
	if level.geometry.has_method("reset_cutaway_materials"):level.geometry.reset_cutaway_materials()
	for item: Array in terrain_materials:item[0].surface_set_material(item[1],item[2] if stage==0 else item[3])
	for item: Array in plant_meshes:item[0].mesh=item[1] if stage==0 else item[2]
	for item: Array in actor_materials:item[0].set_surface_override_material(item[1],item[2] if stage==0 else item[3])
	var environment: Environment=baseline_environment.duplicate()
	level.get_node("WorldEnvironment").environment=environment
	var sun: DirectionalLight3D=level.get_node("Sun")
	for property: String in baseline_sun:sun.set(property,baseline_sun[property])
	RenderingServer.directional_shadow_atlas_set_size(saved_shadow_size,saved_shadow_16bit)
	RenderingServer.directional_soft_shadow_filter_set_quality(saved_shadow_quality as RenderingServer.ShadowQuality)
	if stage==2:
		# Keep +5% LUT and exposure fixed; balance direct light against cool sky fill.
		environment.ambient_light_color=Color(.71,.78,.86)
		environment.ambient_light_energy=.53
		environment.glow_bloom=.04
		environment.glow_intensity=.40
		environment.glow_hdr_threshold=.95
		environment.fog_depth_begin=20.0
		environment.fog_depth_end=60.0
		environment.fog_depth_curve=1.7
		environment.fog_density=.13
		environment.fog_light_color=Color(.77,.82,.79)
		environment.fog_light_energy=.75
		sun.light_energy=1.18
		sun.light_color=Color(1.0,.97,.92)
		sun.shadow_opacity=.782 # User requested +15% relative to .68; exposure stays fixed.
		sun.shadow_blur=1.25
		sun.shadow_bias=.12
		sun.shadow_normal_bias=1.2
		RenderingServer.directional_shadow_atlas_set_size(2048,false)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	level.geometry.update_cutaway(level.player.position,level.get_node("Camera3D").position,level.view_mode=="gameplay")
	publish_clouds(cloud_clock)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(level):return
	var position: Vector3=level.player.global_position
	if position.distance_to(previous_position)>2.0:motion=MOTION.new();motion.clock=elapsed
	motion.advance(delta,position,level.player.get_real_velocity(),level.player.walk_speed,level.player.run_speed)
	elapsed=motion.clock
	previous_position=position
	publish_clouds(elapsed)
	for material: ShaderMaterial in wind_materials:
		motion.publish(material)
		material.set_shader_parameter("player_position",position)

func freeze_motion(time: float=0.0) -> void:
	active=false
	motion=MOTION.new();motion.clock=time
	motion.advance(0.0,level.player.position,Vector3.ZERO,3.0,5.0)
	for material: ShaderMaterial in wind_materials:
		motion.publish(material)
		material.set_shader_parameter("player_position",level.player.position)

func _exit_tree() -> void:
	RenderingServer.directional_shadow_atlas_set_size(saved_shadow_size,saved_shadow_16bit)
	RenderingServer.directional_soft_shadow_filter_set_quality(saved_shadow_quality as RenderingServer.ShadowQuality)
