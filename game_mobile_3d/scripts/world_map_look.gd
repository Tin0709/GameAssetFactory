extends Node
## WorldMap-only look. Source textures, GLBs, shared environments and actors stay intact.
const PRESET=preload("res://assets/graphics/meadow_daylight_v5/preset.tres")
const DIRECT_ACTOR_SHADER=preload("res://materials/world_map_actor_direct.gdshader")
const CANOPY=preload("res://scripts/world_map_canopy.gd")
const LOCAL_EXPOSURE = preload("res://scripts/world_map_local_exposure.gd")
const MOTION=preload("res://scripts/grassland_motion.gd")
const REVIEW_SHADOW_BLUR := 1.08
const REVIEW_SHADOW_NORMAL_BIAS := 0.76
const ATMOSPHERE_FOG := {
	"fog_depth_begin": 25.8,
	"fog_depth_end": 43.0,
	"fog_depth_curve": 1.45,
	"fog_density": 0.26,
	"fog_light_color": Color(0.64, 0.72, 0.73),
	"fog_light_energy": 0.84,
}
const ATMOSPHERE_BACKDROP := Color(0.57, 0.68, 0.69)
const BASE_CLOUD_SHAPE:=Vector4(13.,.50,.73,.20)
const POCKET_CLOUD_SHAPE:=Vector4(1.35,.40,.65,.49)
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
var _pockets_requested:=false
var _atmosphere_requested := false
var _exposure_requested := false
var _exposure_effect: CompositorEffect
var _exposure_compositor: Compositor
var _previous_compositor: Compositor
var _exposure_camera: Camera3D
var _shadow_review_requested := false
var _canopy_requested := false
var _canopy_leaves: Array[Vector4] = []
var _canopy_profile: Dictionary = {}
var _direct_clouds_requested:=false
var _shader_variants: Dictionary[Shader,Dictionary]={}
var _review_shaders: Dictionary[ShaderMaterial,Shader]={}
var _direct_actor_materials: Array[ShaderMaterial]=[]
var _pockets_image: Image
var _pockets_texture: ImageTexture
var _cloud_shape:=BASE_CLOUD_SHAPE

func setup(map: Node3D) -> void:
	level=map
	process_physics_priority=3
	baseline_environment=level.get_node("WorldEnvironment").environment.duplicate()
	build_path_map()
	build_cloud_field()
	saved_shadow_size=int(ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/size"))
	saved_shadow_16bit=bool(ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/16_bits"))
	saved_shadow_quality=int(ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"))
	for property: String in PRESET.sun_settings:
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
		material.shader=PRESET.ground_shader
		var name_lower:=native.resource_name.to_lower()
		var grade:=3 if "stone" in name_lower else (1 if "grass" in name_lower else 2)
		material.set_shader_parameter("ground_grade",grade)
		material.set_shader_parameter("texture_contrast",.38 if grade!=3 else .42)
		material.set_shader_parameter("use_vertex_color",native.vertex_color_use_as_albedo)
	elif kind.begins_with("leaf"):
		material.shader=PRESET.leaves_shader
		material.set_shader_parameter("wind_strength",1.5)
		wind_materials.append(material)
	else:
		material.shader=PRESET.plants_shader
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
	_review_shaders[material]=material.shader
	materials[key]=material
	return material

func build_path_map() -> void:
	var bounds: Dictionary=level.runtime.source_bounds
	path_map_origin=Vector2(bounds.min[0]+level.runtime.offset[0],bounds.min[2]+level.runtime.offset[2])
	path_map_size=Vector2(bounds.max[0]-bounds.min[0]+1,bounds.max[2]-bounds.min[2]+1)
	path_map_image=Image.create(int(path_map_size.x),int(path_map_size.y),false,Image.FORMAT_RGBAF)
	var tops: Dictionary={}
	var offset: Array = level.runtime.offset
	for cell: Array in level.runtime.cells:
		var entry: Dictionary=level.runtime.palette[cell[3]]
		if entry.category=="leaf":
			_canopy_leaves.append(Vector4(cell[0] + offset[0], cell[2] + offset[2],
				cell[1] + entry.base_y_offset + offset[1], entry.height))
		if entry.category!="terrain":continue
		var key:=Vector2i(cell[0],cell[2])
		var height: float=cell[1]+entry.base_y_offset+entry.height+level.runtime.offset[1]
		if tops.has(key) and tops[key].y>=height:continue
		var kind:=1 if str(entry.kind).begins_with("grass_") else (2 if str(entry.kind).begins_with("dirt_") else 0)
		tops[key]=Vector2(kind,height)
	var directions: Array[Vector2i]=[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]
	var plant_contacts: Dictionary={}
	for cell: Array in level.runtime.cells:
		var entry: Dictionary=level.runtime.palette[cell[3]]
		if entry.category!="plant":continue
		var key:=Vector2i(cell[0],cell[2])
		if tops.has(key) and is_equal_approx(tops[key].y,float(cell[1])+float(level.runtime.offset[1])):
			plant_contacts[key]=2 if entry.kind=="short_grass" else (4 if entry.kind=="tall_grass" else 3)
	for key: Vector2i in tops:
		var value: Vector2=tops[key]
		var mask:=0
		if value.x>0:
			for index in directions.size():
				var other: Vector2=tops.get(key+directions[index],Vector2.ZERO)
				if other.x>0 and other.x!=value.x and is_equal_approx(other.y,value.y):mask|=1<<index
		if mask!=0:path_edge_cells+=1
		path_map_image.set_pixel(key.x-bounds.min[0],key.y-bounds.min[2],Color(mask,value.y,value.x,float(plant_contacts.get(key,1))))
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
	# Short/tall grass adopt the ground palette; flower colors stay unchanged.
	for material: ShaderMaterial in wind_materials:
		if material.shader!=PRESET.plants_shader or material.get_shader_parameter("plant_kind") not in [0,2]:continue
		material.set_shader_parameter("ground_blending",grass!=null and dirt!=null)
		material.set_shader_parameter("ground_grade",1)
		material.set_shader_parameter("texture_contrast",.38)
		material.set_shader_parameter("path_blending",grass!=null and dirt!=null)
		material.set_shader_parameter("path_surface_map",path_map)
		material.set_shader_parameter("path_map_origin",path_map_origin)
		material.set_shader_parameter("path_map_size",path_map_size)
		material.set_shader_parameter("path_grass_atlas",grass)
		material.set_shader_parameter("path_dirt_atlas",dirt)

func canopy_contact_active() -> bool:
	return stage == 2 and _canopy_requested

func set_canopy_contact(enabled: bool) -> void:
	if enabled == _canopy_requested: return
	_canopy_requested = enabled
	if stage != 2: return
	level.geometry.reset_cutaway_materials()
	_apply_review_shaders()
	level.geometry.update_cutaway(level.player.position,level.get_node("Camera3D").position,level.view_mode=="gameplay")

func _apply_canopy_contact() -> void:
	if not canopy_contact_active(): return
	if _canopy_profile.is_empty():
		var base_y: float = level.runtime.source_bounds.min[1] + level.runtime.offset[1]
		var field := CANOPY.bake(_canopy_leaves, path_map_image, Vector2i(path_map_origin), base_y)
		_canopy_profile = {"canopy_field": ImageTexture.create_from_image(field.image),
			"canopy_origin": field.origin, "canopy_extent": field.extent, "canopy_base_y": base_y}
	for material: ShaderMaterial in _review_shaders:
		if _review_shaders[material] == PRESET.leaves_shader: continue
		for parameter: String in _canopy_profile:
			material.set_shader_parameter(parameter, _canopy_profile[parameter])

func build_cloud_field() -> void:
	cloud_image=Image.create(64,64,false,Image.FORMAT_RF)
	var rng:=RandomNumberGenerator.new();rng.seed=78126
	for y in 64:
		for x in 64:cloud_image.set_pixel(x,y,Color(rng.randf(),0,0,1))
	cloud_texture=ImageTexture.create_from_image(cloud_image)

func daylight_pockets_active() -> bool:
	return stage==2 and _pockets_requested

func set_daylight_pockets(value: bool) -> void:
	if value==_pockets_requested and not _direct_clouds_requested:return
	_pockets_requested=value
	if _direct_clouds_requested:
		_direct_clouds_requested=false
		_refresh_cloud_look()
	else:
		_apply_daylight_pockets()
		publish_clouds(cloud_clock)

func direct_clouds_active() -> bool:
	return stage==2 and _direct_clouds_requested

func set_direct_clouds(value: bool) -> void:
	if value==_direct_clouds_requested:return
	# Godot does not call light() with forced vertex shading.
	if value and ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_vertex_shading"):
		return
	_direct_clouds_requested=value
	_pockets_requested=false
	_refresh_cloud_look()

func _refresh_cloud_look() -> void:
	level.geometry.reset_cutaway_materials()
	_apply_review_shaders()
	_apply_daylight_pockets()
	level.geometry.update_cutaway(level.player.position,level.get_node("Camera3D").position,level.view_mode=="gameplay")
	publish_clouds(cloud_clock)

func _review_variant(original: Shader, direct: bool, canopy: bool) -> Shader:
	if not (direct or canopy): return original
	var key := Vector2i(int(direct), int(canopy))
	var variants: Dictionary = _shader_variants.get_or_add(original, {})
	if not variants.has(key):
		var shader := Shader.new()
		var defines := "shader_type spatial;"
		if canopy:
			defines += "\n#define GAF_WORLD_CANOPY"
		if direct:
			defines += "\n#define GAF_WORLD_DIRECT_CLOUD"
			if ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_lambert_over_burley"):
				defines += "\n#define GAF_WORLD_FORCE_LAMBERT"
		shader.code = original.code.replace("shader_type spatial;", defines)
		variants[key] = shader
	return variants[key]

func _apply_review_shaders() -> void:
	var direct := direct_clouds_active()
	var canopy := canopy_contact_active()
	level.geometry.cutaway_shader = _review_variant(PRESET.cutaway_shader, direct, canopy)
	for material: ShaderMaterial in _review_shaders:
		var native: Shader = _review_shaders[material]
		var target := _review_variant(native, direct, canopy and native != PRESET.leaves_shader)
		if target == material.shader: continue
		var params: Dictionary = {}
		for row: Dictionary in native.get_shader_uniform_list():
			params[row.name] = material.get_shader_parameter(row.name)
		material.shader = target
		for parameter: String in params:
			if params[parameter] != null: material.set_shader_parameter(parameter, params[parameter])
	_apply_canopy_contact()
	if direct and _direct_actor_materials.is_empty():
		for item: Array in actor_materials:_direct_actor_materials.append(_make_direct_actor(item[0],item[3],item[4]))
	for index in actor_materials.size():
		var item: Array=actor_materials[index]
		var adapter: ShaderMaterial=_direct_actor_materials[index] if direct else null
		if stage==0 or (direct and adapter==null):
			item[0].set_surface_override_material(item[1],item[2])
		else:
			item[0].set_surface_override_material(item[1],adapter if direct else item[3])

func _make_direct_actor(node: MeshInstance3D, source: BaseMaterial3D, tint: Color) -> ShaderMaterial:
	# Restrict the adapter to the current opaque, textured actor and equipment contract.
	if node.material_override!=null or source.next_pass!=null or source.albedo_texture==null:
		return null
	if (source.cull_mode!=BaseMaterial3D.CULL_DISABLED or source.texture_filter!=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		or source.texture_repeat or source.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED
		or source.shading_mode!=BaseMaterial3D.SHADING_MODE_PER_PIXEL
		or source.diffuse_mode!=BaseMaterial3D.DIFFUSE_BURLEY or source.specular_mode!=BaseMaterial3D.SPECULAR_SCHLICK_GGX
		or source.depth_draw_mode!=BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
		or source.uv1_scale!=Vector3.ONE or source.uv1_offset!=Vector3.ZERO
		or source.vertex_color_use_as_albedo or source.roughness_texture!=null or source.metallic_texture!=null
		or source.disable_ambient_light or source.disable_receive_shadows or source.disable_fog):
		return null
	for feature in BaseMaterial3D.FEATURE_MAX:
		if source.get_feature(feature):return null
	var material:=ShaderMaterial.new()
	material.shader=_review_variant(DIRECT_ACTOR_SHADER, true, false)
	material.render_priority=source.render_priority
	material.set_shader_parameter("atlas",source.albedo_texture)
	material.set_shader_parameter("albedo_tint",tint)
	material.set_shader_parameter("native_roughness",source.roughness)
	material.set_shader_parameter("native_metallic",source.metallic)
	material.set_shader_parameter("native_specular",source.metallic_specular)
	material.set_shader_parameter("clouds_enabled",true)
	return material

func _apply_daylight_pockets() -> void:
	var pockets:=daylight_pockets_active() or direct_clouds_active()
	if pockets and _pockets_texture==null:
		var noise:=FastNoiseLite.new()
		noise.seed=97345
		noise.frequency=.085
		noise.fractal_octaves=2
		_pockets_image=noise.get_seamless_image(64,64)
		_pockets_texture=ImageTexture.create_from_image(_pockets_image)
	var texture:=_pockets_texture if pockets else cloud_texture
	_cloud_shape=POCKET_CLOUD_SHAPE if pockets else BASE_CLOUD_SHAPE
	for material: ShaderMaterial in materials.values():
		material.set_shader_parameter("cloud_field",texture)
		material.set_shader_parameter("cloud_shape",_cloud_shape)
	if direct_clouds_active():
		for material: ShaderMaterial in _direct_actor_materials:
			if material!=null:
				material.set_shader_parameter("cloud_field",texture)
				material.set_shader_parameter("cloud_shape",_cloud_shape)
	level.geometry.update_cloud_style(texture,_cloud_shape)
	if stage==2:
		var sun: DirectionalLight3D=level.get_node("Sun")
		sun.light_color=Color(1.,.963,.865) if pockets else PRESET.sun_settings.light_color
		sun.light_energy=1.72 if pockets else PRESET.sun_settings.light_energy

func cloud_sample(point: Vector2) -> float:
	var image:=_pockets_image if daylight_pockets_active() else cloud_image
	var cell:=Vector2i(floori(point.x),floori(point.y))
	var f:=Vector2(fposmod(point.x,1.0),fposmod(point.y,1.0))
	var x0:=posmod(cell.x,64)
	var x1:=posmod(cell.x+1,64)
	var y0:=posmod(cell.y,64)
	var y1:=posmod(cell.y+1,64)
	var top:=lerpf(image.get_pixel(x0,y0).r,image.get_pixel(x1,y0).r,f.x)
	var bottom:=lerpf(image.get_pixel(x0,y1).r,image.get_pixel(x1,y1).r,f.x)
	return lerpf(top,bottom,f.y)

func cloud_shade(position: Vector3,time: float) -> float:
	var p: Vector2=(Vector2(position.x,position.z)+Vector2(time*.48,time*.19))/_cloud_shape.x
	var density: float=(cloud_sample(p)+cloud_sample(p*2.07+Vector2(17,9))*.32)/1.32
	return 1.0-smoothstep(_cloud_shape.y,_cloud_shape.z,density)*_cloud_shape.w

func publish_clouds(time: float) -> void:
	cloud_clock=time
	for material: ShaderMaterial in materials.values():material.set_shader_parameter("cloud_time",time)
	level.geometry.update_cloud_time(time)
	if direct_clouds_active():
		for material: ShaderMaterial in _direct_actor_materials:
			if material!=null:material.set_shader_parameter("cloud_time",time)
		return
	var shade:=cloud_shade(level.player.position,time) if stage>0 else 1.0
	for item: Array in actor_materials:
		var linear: Color=item[4].srgb_to_linear()
		item[3].albedo_color=Color(linear.r*shade,linear.g*shade,linear.b*shade,linear.a).linear_to_srgb()

func atmosphere_review_available() -> bool:
	return RenderingServer.get_current_rendering_method() == "mobile" and RenderingServer.get_rendering_device() != null

func atmosphere_review_active() -> bool:
	return stage == 2 and _atmosphere_requested and level.view_mode == "gameplay"

func set_atmosphere_review(enabled: bool) -> void:
	if enabled == _atmosphere_requested or (enabled and not atmosphere_review_available()): return
	_atmosphere_requested = enabled
	refresh_atmosphere()

func refresh_atmosphere() -> void:
	if stage != 2: return
	var environment: Environment = level.get_node("WorldEnvironment").environment
	var active_review := atmosphere_review_active()
	for property: String in ATMOSPHERE_FOG:
		environment.set(property, ATMOSPHERE_FOG[property] if active_review else PRESET.environment.get(property))
	environment.background_color = PRESET.environment.background_color
	if active_review:
		# Mobile's fog-only sky draw and no-fog clear use different color encodings.
		# Keep the reviewed backdrop visually stable when H isolates the haze.
		environment.background_color = ATMOSPHERE_BACKDROP if environment.fog_enabled else ATMOSPHERE_BACKDROP.srgb_to_linear()

func local_exposure_available() -> bool:
	return RenderingServer.get_current_rendering_method() == "mobile" and RenderingServer.get_rendering_device() != null

func local_exposure_active() -> bool:
	return _exposure_effect != null

func set_local_exposure(enabled: bool) -> void:
	if enabled and not local_exposure_available(): return
	_exposure_requested = enabled
	_apply_local_exposure()

func _apply_local_exposure() -> void:
	if stage != 2 or not _exposure_requested:
		_release_local_exposure()
		return
	if _exposure_effect != null: return
	_exposure_camera = level.get_node("Camera3D")
	_previous_compositor = _exposure_camera.compositor
	_exposure_effect = LOCAL_EXPOSURE.new()
	_exposure_compositor = Compositor.new()
	var source := _previous_compositor
	if source == null:
		var environment: WorldEnvironment = level.get_node("WorldEnvironment")
		source = environment.compositor
	var effects: Array[CompositorEffect] = []
	if source != null:
		effects.assign(source.compositor_effects)
	effects.append(_exposure_effect)
	_exposure_compositor.compositor_effects = effects
	_exposure_camera.compositor = _exposure_compositor

func _release_local_exposure() -> void:
	if _exposure_effect == null: return
	var effect := _exposure_effect
	_exposure_effect = null
	effect.enabled = false
	if is_instance_valid(_exposure_camera) and _exposure_camera.compositor == _exposure_compositor:
		_exposure_camera.compositor = _previous_compositor
	_exposure_compositor = null
	_previous_compositor = null
	_exposure_camera = null
	RenderingServer.call_on_render_thread(func(): effect.release_on_render_thread())

func _process(_delta: float) -> void:
	if _exposure_effect == null: return
	if not is_instance_valid(_exposure_camera) or _exposure_camera.compositor != _exposure_compositor:
		set_local_exposure(false)
		return
	var error: String = _exposure_effect.failure()
	if not error.is_empty():
		push_warning("WorldMap local exposure disabled: " + error)
		set_local_exposure(false)

func directional_shadow_review_active() -> bool:
	return stage == 2 and _shadow_review_requested

func set_directional_shadow_review(enabled: bool) -> void:
	if enabled == _shadow_review_requested: return
	if enabled and RenderingServer.get_rendering_device() == null: return
	_shadow_review_requested = enabled
	if stage == 2:
		_apply_directional_shadow_review(level.get_node("Sun"))

func _apply_directional_shadow_review(sun: DirectionalLight3D) -> void:
	var review := directional_shadow_review_active()
	sun.shadow_blur = REVIEW_SHADOW_BLUR if review else PRESET.sun_settings.shadow_blur
	sun.shadow_normal_bias = REVIEW_SHADOW_NORMAL_BIAS if review else PRESET.sun_settings.shadow_normal_bias
	var use_16bit: bool = PRESET.shadow_16bit
	if review:
		var device := RenderingServer.get_rendering_device()
		var usage := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT
		if device != null and device.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_D16_UNORM, usage):
			use_16bit = true
	RenderingServer.directional_shadow_atlas_set_size(PRESET.shadow_atlas_size, use_16bit)
	var quality := RenderingServer.SHADOW_QUALITY_SOFT_HIGH if review else PRESET.shadow_quality
	RenderingServer.directional_soft_shadow_filter_set_quality(quality as RenderingServer.ShadowQuality)

func set_stage(value: int) -> void:
	stage=clampi(value,0,2)
	if level.geometry.has_method("reset_cutaway_materials"):level.geometry.reset_cutaway_materials()
	for item: Array in terrain_materials:item[0].surface_set_material(item[1],item[2] if stage==0 else item[3])
	for item: Array in plant_meshes:item[0].mesh=item[1] if stage==0 else item[2]
	var environment: Environment=(PRESET.environment if stage==2 else baseline_environment).duplicate()
	level.get_node("WorldEnvironment").environment=environment
	refresh_atmosphere()
	var sun: DirectionalLight3D=level.get_node("Sun")
	for property: String in baseline_sun:sun.set(property,baseline_sun[property])
	RenderingServer.directional_shadow_atlas_set_size(saved_shadow_size,saved_shadow_16bit)
	RenderingServer.directional_soft_shadow_filter_set_quality(saved_shadow_quality as RenderingServer.ShadowQuality)
	if stage==2:
		for property: String in PRESET.sun_settings:sun.set(property,PRESET.sun_settings[property])
		_apply_directional_shadow_review(sun)
	_apply_review_shaders()
	_apply_daylight_pockets()
	_apply_local_exposure()
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
	_release_local_exposure()
	RenderingServer.directional_shadow_atlas_set_size(saved_shadow_size,saved_shadow_16bit)
	RenderingServer.directional_soft_shadow_filter_set_quality(saved_shadow_quality as RenderingServer.ShadowQuality)
