extends Node
## Lab-local owner. Uses only Mobile features and restores its borrowed resources.
const Palette=preload("res://scenes/dev/actions_stuff_research/lighting_md2_v001/palette.gd")
const Metrics=preload("res://scenes/dev/actions_stuff_research/lighting_md2_v001/metrics.gd")
const PreviewUI=preload("res://scenes/dev/actions_stuff_research/lighting_md2_v001/preview_ui.gd")
const ReviewProps=preload("res://scenes/dev/actions_stuff_research/lighting_md2_v001/review_props.gd")
const TIERS:=[
	{"name":"Low","scale":.75,"atlas":1024,"bits16":true,"filter":1,"distance":24.,"splits":0,"glow":false},
	{"name":"Medium","scale":.85,"atlas":2048,"bits16":true,"filter":2,"distance":32.,"splits":1,"glow":true},
	{"name":"High","scale":1.,"atlas":2048,"bits16":false,"filter":3,"distance":38.,"splits":1,"glow":true}
]
const SUN_PROPERTIES:=["rotation","light_color","light_energy","shadow_enabled","shadow_opacity","shadow_blur","shadow_bias","shadow_normal_bias","directional_shadow_mode","directional_shadow_max_distance","directional_shadow_fade_start","directional_shadow_blend_splits","directional_shadow_split_1","light_angular_distance"]
var lab:Node3D
var grass_field:Node
var world:WorldEnvironment
var sun:DirectionalLight3D
var viewport:Viewport
var original_environment:Environment
var original_sun:Dictionary={}
var original_view:Dictionary={}
var environment:Environment
var sky_material:ProceduralSkyMaterial
var palette=Palette.new()
var state:Dictionary={}
var current_hour:=12.
var target_hour:=12.
var automatic:=false
var hours_per_second:=.08
var quality:=1
var original:=false
var fog_requested:=true
var glow_requested:=true
var released:=false
var ui:CanvasLayer
var metrics:RefCounted
var _dirty:=true

func setup(scene:Node3D,foliage:Node=null)->void:
	lab=scene;grass_field=foliage;viewport=lab.get_viewport()
	for child in lab.get_children():
		if child is WorldEnvironment:world=child
		elif child is DirectionalLight3D:sun=child
	assert(world!=null and sun!=null)
	original_environment=world.environment
	for property:String in SUN_PROPERTIES:original_sun[property]=sun.get(property)
	original_view={"scale":viewport.scaling_3d_scale,"mode":viewport.scaling_3d_mode,
		"bits16":bool(ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/16_bits")),
		"atlas":int(ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/size")),
		"filter":int(ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"))}
	environment=Environment.new();environment.background_mode=Environment.BG_SKY
	var sky:=Sky.new();sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL;sky.radiance_size=Sky.RADIANCE_SIZE_64
	sky_material=ProceduralSkyMaterial.new();sky.sky_material=sky_material;environment.sky=sky
	sky_material.sky_curve=.18;sky_material.ground_curve=.25
	sky_material.sun_angle_max=15.;sky_material.sun_curve=.12
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_sky_contribution=0.;environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.tonemap_white=1.8
	environment.adjustment_enabled=true;environment.adjustment_contrast=1.04
	environment.fog_mode=Environment.FOG_MODE_DEPTH;environment.fog_depth_begin=10.;environment.fog_depth_curve=1.5
	environment.fog_height=0.;environment.fog_height_density=.015;environment.fog_sky_affect=.25
	environment.fog_sun_scatter=.08
	environment.glow_intensity=.14;environment.glow_strength=.65;environment.glow_bloom=0.
	environment.glow_hdr_threshold=1.25;environment.glow_hdr_luminance_cap=12.
	world.environment=environment
	sun.light_angular_distance=0.;sun.shadow_bias=.10;sun.shadow_normal_bias=.8
	sun.shadow_blur=1.25;sun.directional_shadow_fade_start=.85;sun.directional_shadow_blend_splits=false;sun.directional_shadow_split_1=.35
	set_quality(quality);_apply()
	metrics=Metrics.new();metrics.setup(viewport)
	ui=PreviewUI.new();ui.name="LightingPreviewControls";add_child(ui);ui.setup(self)
	# Demonstration props belong to this opt-in lab module and leave with it.
	var props:=ReviewProps.new();add_child(props)

func set_time(hour:float,snap:bool=false)->void:
	if released:return
	target_hour=fposmod(hour,24.) if is_finite(hour) else 12.
	if snap:current_hour=target_hour
	_dirty=true
	if snap and environment!=null:_apply()

func set_quality(index:int)->void:
	if released:return
	quality=clampi(index,0,TIERS.size()-1)
	if viewport==null or original:return
	var tier:Dictionary=TIERS[quality]
	viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR;viewport.scaling_3d_scale=tier.scale
	RenderingServer.directional_shadow_atlas_set_size(tier.atlas,tier.bits16)
	RenderingServer.directional_soft_shadow_filter_set_quality(tier.filter)
	sun.directional_shadow_max_distance=tier.distance;sun.directional_shadow_mode=tier.splits
	sun.shadow_enabled=true
	environment.glow_enabled=tier.glow and glow_requested
	_dirty=true

func set_original(value:bool)->void:
	if released:return
	original=value
	if original:_restore()
	else:
		world.environment=environment
		sun.light_angular_distance=0.;sun.shadow_bias=.10;sun.shadow_normal_bias=.8;sun.shadow_blur=1.25
		sun.directional_shadow_fade_start=.85;sun.directional_shadow_blend_splits=false;sun.directional_shadow_split_1=.35
		set_quality(quality);_apply()
	_foliage_grade(0. if original else 1.)

func set_fog(value:bool)->void:
	if released:return
	fog_requested=value;_dirty=true
func set_glow(value:bool)->void:
	if released:return
	glow_requested=value;_dirty=true

func advance(delta:float)->void:
	if released:return
	if automatic:target_hour=fposmod(target_hour+maxf(0.,delta)*hours_per_second,24.);_dirty=true
	var difference:=wrapf(target_hour-current_hour,-12.,12.)
	if absf(difference)>.00001:
		current_hour=fposmod(current_hour+difference*(1.-exp(-8.*maxf(0.,delta))),24.);_dirty=true
	if _dirty and not original:_apply()

func _process(delta:float)->void:advance(delta)

func _apply()->void:
	if released or original:return
	palette.sample(current_hour,state)
	sun.light_color=state.key;sun.light_energy=state.energy
	sun.rotation_degrees=Vector3(state.pitch,state.yaw,0.)
	sun.shadow_opacity=.82
	environment.ambient_light_color=state.ambient;environment.ambient_light_energy=state.ambient_energy
	environment.tonemap_exposure=state.exposure;environment.adjustment_saturation=state.saturation
	sky_material.sky_top_color=state.sky;sky_material.sky_horizon_color=state.horizon
	sky_material.ground_bottom_color=state.ground;sky_material.ground_horizon_color=state.horizon
	environment.fog_enabled=fog_requested;environment.fog_light_color=state.fog
	environment.fog_light_energy=.8;environment.fog_density=state.fog_amount;environment.fog_depth_end=state.fog_end
	environment.glow_enabled=TIERS[quality].glow and glow_requested
	_foliage_grade(1.);_dirty=false

func _foliage_grade(value:float)->void:
	if is_instance_valid(grass_field):
		for material:ShaderMaterial in grass_field.materials:material.set_shader_parameter("lighting_grade",value)

func _restore()->void:
	if original_view.is_empty():return
	if is_instance_valid(world):world.environment=original_environment
	if is_instance_valid(sun):
		for property:String in SUN_PROPERTIES:sun.set(property,original_sun[property])
	if is_instance_valid(viewport):viewport.scaling_3d_mode=original_view.mode;viewport.scaling_3d_scale=original_view.scale
	RenderingServer.directional_shadow_atlas_set_size(original_view.atlas,original_view.bits16)
	RenderingServer.directional_soft_shadow_filter_set_quality(original_view.filter)
	_foliage_grade(0.)

func release()->void:
	if released:return
	_restore()
	if metrics!=null:metrics.release()
	if is_instance_valid(ui):ui.visible=false;ui.process_mode=Node.PROCESS_MODE_DISABLED
	set_process(false)
	released=true
func _exit_tree()->void:release()
