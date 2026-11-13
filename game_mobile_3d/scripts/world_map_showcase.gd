extends Node
## Owns the unified review, not the private assets or the original controller.
const PlayerFactory := preload("res://scripts/world_map_player_factory.gd")
const PALETTE=preload("res://scripts/world_map_showcase_palette.gd")
const FOREST=preload("res://scripts/world_map_forest_atmosphere.gd")
const PHASE_FINISH=preload("res://scripts/world_map_phase_finish.gd")
const CrownWind := preload("res://scripts/world_map_crown_wind.gd")
const DirectionalAir := preload("res://scripts/world_map_directional_air.gd")
const PlayerContact := preload("res://scripts/world_map_player_contact.gd")
const ProjectedSun := preload("res://scripts/world_map_projected_sun.gd")
const DepthDiffusion := preload("res://scripts/world_map_depth_diffusion.gd")
const LOCAL_EXPOSURE_STRENGTH:=.12
# User-directed art adjustment; recovered Forest profiles stay untouched.
const GENTLE_NOON_DIRECT_SCALE:=.82
const TIME_SHORTCUT_HOURS := [7.0, 12.0, 16.5, 22.0]
## Original WorldMap entry distance and reference height. Extinction is fitted
## to three captured actor rays, normalized by their relative phase density.
const NEAR_HAZE_ENTRY_M := 23.945624
const NEAR_HAZE_EXTINCTION := 0.00468248024
const NEAR_HAZE_REFERENCE_HEIGHT_M := 1.65
const FOREST_NEAR_SCATTER_CENTER := Vector2(-24.0, 15.0)
const FOREST_NEAR_SCATTER_MAX_GAIN := 2.0
var level:Node3D
var _flat_lab := false
var private_primary:=true
var unavailable_reason:=""
var panel:PanelContainer
var status:Label
var hour:=12.
var cycle_enabled:=false
var audio_enabled:=false
var plants:Node3D
var palette:=PALETTE.new()
var key_response=preload("res://scripts/world_map_key_response.gd").new()
var captured_key_response:=true
var key_response_active:=false
var _key_response_toggle:CheckButton
var direction_response=preload("res://scripts/world_map_light_direction.gd").new()
var captured_key_direction:=true
var key_direction_active:=false
var sunrise_elevation_active := false
var _direction_toggle:CheckButton
var _player_source_toggle:CheckButton
var sky_response=preload("res://scripts/world_map_sky_response.gd").new()
var captured_sky_response:=true
var sky_response_active:=false
var captured_mist_source:=true
var mist_source_active:=false
var grove_mist_enabled := true
var _grove_mist_toggle: CheckButton
var _spruce_toggle: CheckButton
var _source_terrain_tiles: Texture2DArray
var _source_terrain_toggle: CheckButton
var forest:=FOREST.new()
var forest_accents := preload("res://scripts/world_map_forest_accents.gd").new()
var sculk_surface := preload("res://scripts/world_map_sculk_surface.gd").new()
var forest_replay := preload("res://scripts/world_map_forest_replay.gd").new()
var forest_path_light := preload("res://scripts/world_map_forest_path_light.gd").new()
var atmosphere_review:="combined"
var _forest_expected:Dictionary={}
var _forest_hour:=INF
var _forest_sun:Color
var _forest_energy:float
var _forest_shadow_opacity:float
var full_direct_shadows:=true
var projected_sun := ProjectedSun.new()
var _opening_gain := 0.0
var _diffuse_opening := Vector4.ZERO
const LIGHTING_MIX_CONTROLS := {
	&"sun": ["Direct sunlight", 2.],
	&"sun_pockets": ["Sunlight pockets", 1.5],
	&"sun_opening": ["Sunlit openings", 1.],
	&"projected_sun": ["Projected sunlight", 1.],
	&"projected_sun_position": ["Projected sunlight placement", 1.],
	&"projected_sun_softness": ["Projected sunlight softness", 1.],
	&"moon": ["Moonlight", 2.],
	&"sky": ["Ambient sky", 2.],
	&"sky_chroma": ["Sky color", 1.],
	&"twilight_sky_chroma": ["Sắc ánh sáng hắt chạng vạng", 1.],
	&"twilight_ambient": ["Hạ ánh nền chạng vạng", 1.],
	&"night_sky_fill": ["Ánh sáng hắt ban đêm", 1.],
	&"dawn_sky_transition": ["Ánh sáng hắt rạng sáng", 1.],
	&"daylight_balance": ["Daylight color balance", 1.],
	&"player_sky": ["Player sky fill", 2.],
	&"player_bounce": ["Player reflected sunlight (preview)", 1.],
	&"foot_contact": ["Player ground contact (preview)", 1.],
	&"grass_sky": ["Grass sky fill", 1.],
	&"turf_ambient_color": ["Sắc ánh hắt trên cỏ lúc tối", 1.],
	&"dawn_turf_ambient": ["Ánh hắt trên cỏ rạng sáng", 1.],
	&"dawn_turf_color": ["Sắc cỏ trong bóng rạng sáng", 1.],
	&"grass_shade_color": ["Grass shade color", 1.],
	&"diffuse_openings": ["Sunlit diffuse fill", 1.],
	&"regional_sky": ["Local cliff skylight (preview)", 1.],
	&"daylight_bounce": ["Daylight terrain bounce (preview)", 1.],
	&"stone_diffuse_contrast": ["Stone face lighting transition (preview)", 1.],
	&"stone_detail_softness": ["Stone texture softness", 1.],
	&"night_spatial_sky": ["Night terrain bounce (preview)", 1.],
	&"night_stone_blue_softness": ["Dịu sắc lam trên đá ban đêm", 1.],
	&"dawn_stone_sky_color": ["Sắc ánh trời trên đá rạng sáng", 1.],
	&"night_stone_fill_balance": ["Cân bằng sắc đá ban đêm", 1.],
	&"night_stone_top_cool": ["Sắc xanh trên mặt đá", 1.],
	&"grass_root_tone": ["Night grass root tone", 1.],
	&"grass_night_albedo": ["Độ dịu lá cỏ ban đêm", 1.],
	&"twilight_grass_albedo": ["Độ dịu lá cỏ chạng vạng", 1.],
	&"lantern_grass_tone": ["Sắc đèn hông trên cỏ", 1.],
	&"grass_shadow_reach": ["Grass shadow reach", 1.],
	&"stone_twilight_color": ["Stone twilight color", 1.],
	&"twilight_shadow_color": ["Twilight shadow color", 1.],
	&"cool_shadow_detail": ["Cool shadow detail", 1.],
	&"spruce_sky": ["Forest canopy sky", 1.],
	&"tree_shade": ["Tree shade depth", 1.],
	&"twilight_ground_ambient": ["Ánh hắt mặt đất lúc chạng vạng", 1.],
	&"twilight_crown": ["Ánh hắt trên tán lúc chạng vạng", 1.],
	&"oak_leaf_tint": ["MD2 oak leaf tint", 1.],
	&"shadow": ["Shadow strength", 1.],
	&"shadow_softness": ["Shadow softness", 1.5],
	&"lantern": ["Hip lantern", 2.],
	&"evening_lantern": ["Đèn hông chạng vạng", 1.],
	&"lantern_lift": ["Lantern height", 1.5],
	&"lantern_air": ["Lantern in mist", 2.],
	&"lantern_glow": ["Lantern glow", 2.],
	&"night_glare_control": ["Giảm chói đèn đêm", 1.],
	&"fog": ["Fog density", 2.],
	&"near_haze": ["Near haze density", 2.],
	&"near_haze_depth": ["Near haze depth", 1.],
	&"local_mist": ["Local mist volume (preview)", 1.],
	&"cliff_mist": ["Cliff mist depth (preview)", 1.],
	&"night_cliff_mist": ["Night cliff mist", 1.],
	&"forest_near_scatter": ["Forest mist depth light", 1.],
	&"sunlit_mist": ["Canopy sunlight in mist", DirectionalAir.MAX_GAIN],
	&"scatter": ["Fog brightness", 2.],
	&"night_mist_light": ["Night mist light", 1.],
	&"night_depth_scatter": ["Ánh xanh trong sương xa", 1.],
	&"night_far_air": ["Chiều sâu sương đêm", 1.],
	&"twilight_depth_scatter": ["Ánh tán xạ xa chạng vạng", 1.],
	&"twilight_far_air": ["Ánh sương sau tán cây", 1.],
	&"twilight_far_air_color": ["Sắc lạnh của sương xa", 1.],
	&"twilight_far_optical": ["Mật độ lớp sương xa", 1.],
	&"dawn_mist_source": ["Ánh sáng sương rạng sáng", 1.],
	&"evening_mist_profile": ["Sương hoàng hôn", 1.],
	&"evening_key_response": ["Ánh trực tiếp lúc chạng vạng", 1.],
	&"sunrise_key_response": ["Nắng chuyển lúc bình minh", 1.],
	&"sunrise_elevation": ["Góc nắng rạng sáng", 1.],
	&"forest_accents": ["Forest glow accents", 1.375],
	&"forest_daylight_accents": ["Forest daylight accents", 1.],
	&"sculk_surface": ["Sculk phát sáng", 1.],
	&"forest_replay_emission": ["Ánh bệ đá trong rừng", 1.],
	&"forest_replay_halo": ["Quầng sáng bệ đá", 1.],
	&"forest_replay_bounce": ["Ánh hắt quanh bệ đá", 1.],
	&"forest_replay_surface_bounce": ["Ánh hắt theo mặt đá", 1.],
	&"forest_replay_placement": ["Vị trí bệ đá", 1.],
	&"canopy_player_cue": ["Dáng nhân vật sau tán", 1.],
	&"crown_ambient_depth": ["Chiều sâu bóng trên tán", 1.],
	&"forest_path_light": ["Forest path light", 1.],
	&"forest_path_placement": ["Vị trí đèn lối rừng", 1.],
	&"forest_path_beam": ["Path light beam", 1.],
	&"forest_path_air": ["Path light in mist", 1.],
	&"forest_path_air_beam": ["Hướng đèn trong sương", 1.],
	&"bloom": ["Bloom", 2.],
	&"bloom_spread": ["Bloom spread", 2.],
	&"bloom_diffusion": ["Độ mềm bloom", 1.],
	&"night_soft_bloom": ["Ánh tán mềm ban đêm", 1.],
	&"twilight_soft_bloom": ["Ánh tán mềm chạng vạng", 1.],
	&"world_outline_strength": ["World Outline", 4.],
	&"world_outline_width": ["Độ dày viền", 4.],
	&"daylight_haze": ["Daylight haze softness", 1.],
	&"daylight_haze_spill": ["Light spread into shade", 1.],
	&"humid_light": ["Humid light diffusion", 1.],
	&"humid_depth": ["Diffusion by depth (preview)", 1.],
	&"tree_wind": ["Tree canopy wind", CrownWind.MAX_STRENGTH],
	&"night_path_chroma": ["Night path color", 1.],
	&"exposure": ["Local exposure", 1.],
	&"daylight_shadow_lift": ["Daylight shadow lift", 1.],
	&"twilight_shadow_lift": ["Giữ chiều sâu vùng râm", 1.],
	&"grade": ["Reference finish", 1.],
}
const LIGHTING_MIX_PATH := "user://world_map_lighting_mix.cfg"
const LIGHTING_MIX_VERSION := 94
const NIGHT_MIST_MAX_GAIN := 4.0
const PATH_AIR_MAX_SCALE := .24
const PATH_BEAM_AIM_XZ := Vector2(-24.0, 18.0)
const DAYLIGHT_SHADOW_SOFTNESS := 1.15
const NEAR_HAZE_FADE_START := .86
const KEY_LUMA := Vector3(.2126, .7152, .0722)
const MOON_TINT := Color("#b6cdf5")
var moonlight_enabled := true
var night_reference_atmosphere := true
var _night_reference_toggle: CheckButton
const BALANCED_ATMOSPHERE := {
	&"projected_sun": 0.,
	&"sunlit_mist": 0.,
	&"daylight_haze": 0.,
	&"daylight_haze_spill": 0.,
	&"sky_chroma": .65,
	&"grade": .55,
	&"exposure": .9,
	&"player_sky": 1.25,
	&"grass_sky": 0.,
	&"spruce_sky": 0.,
	&"tree_shade": 0.,
	&"forest_daylight_accents": 0.,
	&"forest_path_air": 0.,
	&"forest_path_beam": 0.,
	&"lantern_grass_tone": 0.,
	&"oak_leaf_tint": 0.,
	&"near_haze": 1.,
}
const BALANCED_DAY_REFERENCE_FINISH := .75
var _lighting_mix: Dictionary = {}
var _lighting_sliders: Dictionary = {}
var _balanced_preview := false
var _balanced_toggle: CheckButton
const SceneLightingMix = preload("res://scripts/scene_lighting_mix.gd")
var _scene_mix_button: Button
var _additional_mix_buttons: Array[Button] = []
var _near_haze_toggle: CheckButton
var _save_mix_button: Button
var _vignette:ColorRect
var point_response=preload("res://scripts/world_map_point_response.gd").new()
var captured_lantern_dawn:=true
var _lantern_dawn_toggle:CheckButton
## Resting emitter height above the rendered player root, measured in the idle comparison.
const LANTERN_REST_HEIGHT_M := 0.65
## Additional height calibrated to the two captured light-to-face separations.
const LANTERN_OVERHEAD_LIFT_M := 2.06
## Mobile HDR fit from the captured visible lamp core and locked gameplay comparisons.
const LANTERN_EMISSION_GAIN := 16.
var lantern_overhead := true
var _lantern_overhead_toggle: CheckButton
static var _point_kernel_owner:WeakRef
var _point_kernel_camera := Vector3.INF
var _point_lights:Dictionary={}
var point_kernel_state:=Vector4.ZERO
var _lantern_grass_tone := 0.0
var _dawn_turf_color := 0.0
var path_beam_state := Vector4.ZERO
var point_soft_state:=Vector2.ZERO
var player_soft_source:=false
var _soft_source_toggle:CheckButton
var source_point_cutoff:=true
var _point_cutoff_toggle:CheckButton
var source_warm_light:=false
var _warm_kernel_toggle:CheckButton
var noninverse_player_light:=true
var _point_response_toggle:CheckButton
var _player_light:OmniLight3D
var _evening_lantern_bounds := Vector2.ZERO
var _atmosphere_picker:OptionButton
var _legacy_sky_button:CheckButton
var mist:Node3D
var directional_air := DirectionalAir.new()
var player_contact: Node
var spatial_mist:=true
var near_haze_enabled: bool:
	get: return float(_lighting_mix.get(&"near_haze", _lighting_scale_default(&"near_haze"))) > 0.
	set(value):
		if value != near_haze_enabled:
			set_lighting_scale(&"near_haze", 1. if value else 0.)
var phase_air=preload("res://scripts/world_map_phase_air.gd").new()
var measured_atmosphere:=true
var coupled_bloom:=true
var coherent_bloom:=true
var measured_bloom_response:=true
var _shape_toggle:CheckButton
var source_bloom_shape:=false
var bloom_response=preload("res://scripts/world_map_bloom_response.gd").new()
var gentle_noon:=true
var grade_review:Node
var phase_finish:Node
var hdr_air:=true
var _hdr_owned:=false
var _hdr_saved:=false
var _hdr_viewport:Viewport
var captured_scatter:=true
var shadowed_scatter:=true
var air_light=preload("res://scripts/world_map_air_light.gd").new()
var _mist_sample:Dictionary={}
var _day:Dictionary={}
var _environment:Environment
var _time_applied:=false
var _environment_edit_depth:=0
var _settings := preload("res://scripts/world_map_settings.gd").new()
var _mix_before_drag: Dictionary = {}
var _hint:Label
var _elapsed:=0.
var _cycle_button:CheckButton
var _exposure_button:CheckButton
var _player_material_note:Label
var _terrain_light_note:Label
var _fps_label:Label
var _fps_elapsed:=0.
const ENV_FIELDS:=["ambient_light_color","ambient_light_energy","background_color","tonemap_exposure","adjustment_saturation","adjustment_contrast","fog_light_color","fog_density","fog_depth_begin","fog_depth_end","fog_depth_curve","fog_light_energy","glow_enabled","glow_intensity","glow_bloom","glow_hdr_threshold"]

func make_player()->Node3D:
	private_primary = PlayerFactory.uses_private_player()
	var selected := PlayerFactory.create(private_primary)
	if selected.process_mode == Node.PROCESS_MODE_DISABLED:
		unavailable_reason = "Primary A&S/MD2 + Sabre requires the private editor workspace. No reference assets are included in builds."
	return selected

func setup(world:Node3D)->void:
	level=world;process_priority=-10
	if not private_primary:
		_build_basic_settings()
		return
	_setup_point_lighting()
	projected_sun.setup()
	RenderingServer.global_shader_parameter_set("gaf_sun_opening_gain", 0.)
	RenderingServer.global_shader_parameter_set("gaf_diffuse_opening", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("gaf_replay_bounce", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("gaf_replay_surface", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("gaf_replay_surface_field", null)
	RenderingServer.global_shader_parameter_set("gaf_path_beam",Vector4.ZERO)
	if level.player.get("primary_ready")!=true and unavailable_reason.is_empty():
		unavailable_reason="Private A&S/MD2 + Sabre data missing. Set MD2_RESEARCH_ROOT to the private research folder and restart."
	level.terrain_sky.set_enabled(false)
	if level.grove == null or not level.grove.source_oaks:
		level.set_grove_visible(false,level.player.global_position)
	if level.player.has_method("setup_world_vegetation"):plants=level.player.setup_world_vegetation(level)
	if level.look.local_exposure_available():
		level.look.set_local_exposure(true)
		level.look._exposure_effect.set_review_strength(bounded_exposure_strength())
	if level.player.has_method("setup_world_audio"):level.player.setup_world_audio(level)
	set_audio_enabled(false)
	_capture_day()
	_setup_atmosphere()
	if mist != null:
		directional_air.setup(level, self)
		if directional_air.available():
			mist.effect.directional_grid = directional_air.texture
			mist.effect.directional_provider = directional_air.parameters
	player_contact = PlayerContact.new()
	add_child(player_contact)
	player_contact.setup(level)
	_build_ui()
	set_source_terrain(true)
	_refresh_lantern_glow()
	level.get_node("HUD/Help").hide();level.get_node("HUD/Status").hide()
	DisplayServer.window_set_title("GameAssetFactory · Overworld Showcase · A&S / MD2 Sabre · L HUD")
	print("WORLD_MAP_SHOWCASE_READY ",JSON.stringify({"primary_ready":unavailable_reason.is_empty(),"private_external":true,"hour":hour,"experimental_terrain_sky":false}))

func setup_flat_lab(world: Node3D) -> void:
	level = world
	_flat_lab = true
	process_priority = -10
	if forest_active():
		_setup_point_lighting()
		projected_sun.setup()
	_capture_day()
	_setup_atmosphere()
	_create_atmosphere_overlay(level.get_node("HUD"))
	_refresh_lantern_glow()
	apply_time()
	_update_mist()

func _setup_point_lighting() -> void:
	_point_kernel_owner = weakref(self)
	RenderingServer.frame_pre_draw.connect(_sync_point_camera)
	get_tree().node_added.connect(_track_point_light)
	for light in get_tree().root.find_children("*", "Light3D", true, false):
		_track_point_light(light)

func _setup_atmosphere() -> void:
	if forest.available():
		_evening_lantern_bounds = Vector2(forest.sample(point_response.EVENING_START).player_light_weight,
			forest.sample(point_response.EVENING_END).player_light_weight)
		_player_light=OmniLight3D.new();_player_light.name="AtmospherePlayerLight";_player_light.shadow_enabled=false
		_player_light.omni_range=forest.player_range;_player_light.omni_attenuation=2.;_player_light.position.y=1.4
		level.player.add_child(_player_light);_player_light.hide()
		mist=preload("res://scripts/world_map_atmosphere_volume.gd").new();level.get_node("Camera3D").add_child(mist);mist.setup();mist.material_provider=_mist_materials;mist.medium_state=_mist_state;mist.path_light_provider=_path_air_source;mist.compositor_owned=func(c):return c==level.look._exposure_compositor
	grade_review=preload("res://scripts/world_map_grade_review.gd").new();add_child(grade_review);grade_review.setup(self)
	phase_finish=PHASE_FINISH.new();add_child(phase_finish);phase_finish.setup(self)

func _capture_day()->void:
	_environment=level.get_node("WorldEnvironment").environment
	_day.clear()
	for field:String in ENV_FIELDS:_day[field]=_environment.get(field)
	var sun:DirectionalLight3D=level.get_node("Sun")
	_day.sun_rotation=sun.rotation_degrees;_day.sun_color=sun.light_color;_day.sun_energy=sun.light_energy
	_day.sun_shadow_opacity=sun.shadow_opacity
	_time_applied=false
	_forest_expected.clear();_forest_hour=INF

func is_day_anchor()->bool:return is_equal_approx(hour,12.)

func set_audio_enabled(value:bool)->void:
	audio_enabled=value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),not value)
	var actor=level.player
	if actor.get("reference_audio")!=null:actor.reference_audio.enabled=value
	if level.heavy_landing_audio != null:level.heavy_landing_audio.set_surface_landing_enabled(value)
	if actor.get("environment_audio")!=null and actor.environment_audio.audio!=null:
		actor.environment_audio.audio.ambient_enabled=value
		actor.environment_audio.audio.footsteps_enabled=value;actor.environment_audio.audio.rustle_enabled=value

func _restore_day()->void:
	sunrise_elevation_active = false
	key_response_active=false
	key_direction_active=false
	sky_response_active=false
	mist_source_active=false
	if phase_finish!=null:phase_finish.restore_environment()
	if grade_review!=null:grade_review.release()
	if not _time_applied or _day.is_empty():return
	for field:String in ENV_FIELDS:_environment.set(field,_day[field])
	var sun:DirectionalLight3D=level.get_node("Sun")
	sun.rotation_degrees=_day.sun_rotation;sun.light_color=_day.sun_color;sun.light_energy=_day.sun_energy
	sun.shadow_opacity=_day.sun_shadow_opacity
	_time_applied=false
	_forest_expected.clear();_forest_hour=INF
	if _vignette!=null:_vignette.hide()
	if _player_light!=null:_player_light.hide()
	if mist!=null:mist.hide()
	_mist_sample.clear()

func set_spatial_mist(value:bool)->void:
	_restore_day();spatial_mist=value;apply_time()
	_update_mist()

func set_measured_atmosphere(value:bool)->void:
	measured_atmosphere=value
	_restore_day();apply_time();_update_mist()

static func noon_direct_scale(time:float)->float:
	if not is_finite(time):return 1.
	var h:=fposmod(time,24.)
	var weight:=smoothstep(7.,12.,h) if h<=12. else 1.-smoothstep(12.,16.5,h)
	return lerpf(1.,GENTLE_NOON_DIRECT_SCALE,weight)

func set_gentle_noon(value:bool)->void:
	gentle_noon=value
	if level==null or level.look==null or level.look.stage!=2:return
	_restore_day();apply_time()
	if level.terrain_light!=null:level.terrain_light.bind(true)
	if level.player_light!=null:level.player_light.refresh(true)
	level.look._refresh_ground_bounce();_update_mist()

func set_captured_key_response(value:bool)->void:
	captured_key_response=value
	if level==null or level.look==null or level.look.stage!=2:return
	_restore_day();apply_time()
	if level.terrain_light!=null:level.terrain_light.bind(true)
	if level.player_light!=null:level.player_light.refresh(true)
	level.look._refresh_ground_bounce();_update_mist()

func set_captured_key_direction(value:bool)->void:
	captured_key_direction=value
	if level==null or level.look==null or level.look.stage!=2:return
	_restore_day();apply_time()
	if level.terrain_light!=null:level.terrain_light.bind(true)
	if level.player_light!=null:level.player_light.refresh(true)
	level.look._refresh_ground_bounce();_update_mist()

func _apply_captured_direction(sun:DirectionalLight3D)->void:
	key_direction_active=false
	if not captured_key_direction or not direction_response.available()or is_day_anchor()or _day.is_empty():return
	var noon:=Basis.from_euler(Vector3(_day.sun_rotation)*(PI/180.),sun.rotation_order).z.normalized()
	var direction:Vector3=direction_response.sample(hour,noon)
	if direction==Vector3.ZERO:return
	sun.rotation=Basis.looking_at(-direction,Vector3.UP).get_euler(sun.rotation_order)
	key_direction_active=true

func set_captured_sky_response(value:bool)->void:
	captured_sky_response=value
	if level==null or level.look==null or level.look.stage!=2:return
	_restore_day();apply_time()
	if level.ambient!=null:level.ambient.refresh()
	if level.terrain_light!=null:level.terrain_light.bind(true)
	if level.player_light!=null:level.player_light.refresh(true)
	level.look._refresh_ground_bounce();_update_mist()

func _apply_captured_sky(env:Environment)->void:
	sky_response_active=false
	if not captured_sky_response or not sky_response.available()or is_day_anchor():return
	var noon:=forest.sample(12.)
	var base:Color=Color(_day.ambient_light_color).srgb_to_linear()
	var source:=Vector3(base.r,base.g,base.b);var luma:=Vector3(.2126,.7152,.0722)
	var tinted:Vector3=source*noon.ambient_tint
	tinted*=source.dot(luma)/maxf(tinted.dot(luma),.000001)
	var rgb:Vector3=tinted*_sample_sky_response()
	if not rgb.is_finite()or minf(rgb.x,minf(rgb.y,rgb.z))<0.:return
	var peak:=maxf(1.,maxf(rgb.x,maxf(rgb.y,rgb.z)))
	env.ambient_light_color=Color(rgb.x/peak,rgb.y/peak,rgb.z/peak).linear_to_srgb()
	env.ambient_light_energy=float(_day.ambient_light_energy)*float(noon.ambient_energy_scale)*peak
	sky_response_active=true

func _sample_sky_response() -> Vector3:
	var reference := reference_hour()
	var pinned: Vector3 = sky_response.sample(reference)
	var strength := _lighting_scale(&"dawn_sky_transition")
	if _balanced_preview or strength <= 0. or hour >= 4.5 or hour <= reference:
		return pinned
	# Advance the sky source only. Fog and bloom use their existing reference phase.
	return pinned.lerp(sky_response.sample(hour), strength)

func _night_sky_fill_multiplier() -> float:
	if _balanced_preview or not sky_response_active or atmosphere_review != "combined":
		return 1.0
	# The captured sky supplies the phase and color. Calibrate only the scene's
	# diffuse fill relative to the hip light, with the existing moon transition.
	var amount := _lighting_scale(&"night_sky_fill") * moonlight_weight(hour)
	return lerpf(1.0, 3.5, amount)

func _apply_sky_chroma(env: Environment) -> void:
	var manual := lerpf(1., _lighting_scale(&"sky_chroma"), PHASE_FINISH.phase_weight(hour))
	var scale := manual * lerpf(1., .82, _daylight_color_balance_weight())
	if scale == 1.:
		return
	var rgb := env.ambient_light_color.srgb_to_linear()
	var luma := Vector3(rgb.r, rgb.g, rgb.b).dot(Vector3(.2126, .7152, .0722))
	env.ambient_light_color = Color(luma, luma, luma).lerp(rgb, scale).linear_to_srgb()

func _apply_twilight_sky(env: Environment) -> void:
	if not sky_response_active or _balanced_preview or hour <= 19.0 or hour >= 20.0:
		return
	var color := env.ambient_light_color.srgb_to_linear()
	var rgb := Vector3(color.r, color.g, color.b)
	var adjusted: Vector3 = sky_response.twilight_color(rgb, hour, _lighting_scale(&"twilight_sky_chroma"))
	if adjusted == rgb:
		return
	var peak := maxf(1.0, adjusted[adjusted.max_axis_index()])
	env.ambient_light_color = Color(adjusted.x / peak, adjusted.y / peak, adjusted.z / peak).linear_to_srgb()
	env.ambient_light_energy *= peak

func _apply_captured_key(sun:DirectionalLight3D)->void:
	key_response_active=false
	if not captured_key_response or not key_response.available()or is_day_anchor():return
	var rgb:=_captured_key_rgb(hour)*(noon_direct_scale(hour)if gentle_noon else 1.)
	var peak:=maxf(rgb.x,maxf(rgb.y,rgb.z))
	if peak<=0. or not rgb.is_finite():return
	sun.light_color=Color(rgb.x/peak,rgb.y/peak,rgb.z/peak).linear_to_srgb();sun.light_energy=peak
	key_response_active=true

func _captured_key_rgb(time:float)->Vector3:
	var noon:=forest.sample(12.)
	var base:Color=Color(_day.sun_color).srgb_to_linear()
	var reference:Vector3=Vector3(base.r,base.g,base.b)*noon.key_color_scale*float(_day.sun_energy)*float(noon.key_scale)
	var evening_strength := 0.0 if _balanced_preview else _lighting_scale(&"evening_key_response")
	return reference * key_response.sample_evening(time, evening_strength)

func set_moonlight_enabled(value:bool)->void:
	if moonlight_enabled==value:return
	moonlight_enabled=value
	_forest_hour=INF
	apply_time()
	_update_mist()

static func moonlight_weight(time:float)->float:
	if not is_finite(time):return 0.
	var h:=fposmod(time,24.)
	return 1.-smoothstep(3.5,4.5,h) if h<12. else smoothstep(19.5,21.,h)

func reference_hour() -> float:
	if not night_reference_atmosphere or phase_air.anchors.is_empty() or not sky_response.available():
		return hour
	var midnight := 24. if hour > 12. else 0.
	return fposmod(lerpf(hour, midnight, moonlight_weight(hour)), 24.)

func set_night_reference_atmosphere(value: bool) -> void:
	if night_reference_atmosphere == value:
		return
	night_reference_atmosphere = value
	if _night_reference_toggle != null:
		_night_reference_toggle.set_pressed_no_signal(value)
	if level == null:
		return
	_forest_hour = INF
	apply_time()
	level.look._refresh_ground_bounce()
	_update_mist()

func _apply_key_mix(sun:DirectionalLight3D)->void:
	var weight:=moonlight_weight(hour) if moonlight_enabled else 0.
	var sunlight:=_lighting_scale(&"sun")
	if weight<=0.:
		sun.light_energy*=sunlight
		return
	var source:=sun.light_color.srgb_to_linear()
	var solar:=Vector3(source.r,source.g,source.b)*sun.light_energy*sunlight
	var tint:=MOON_TINT.srgb_to_linear()
	var moon:=Vector3(tint.r,tint.g,tint.b)
	# The native midnight key anchors luminance. The cool color and schedule
	# are original art choices. A single directional light owns both phases.
	var night_luma:=_captured_key_rgb(0.).dot(KEY_LUMA) if key_response.available() else float(_day.sun_energy)*.012
	moon*=night_luma*_lighting_scale(&"moon")/moon.dot(KEY_LUMA)
	var rgb:=solar.lerp(moon,weight)
	var peak:=maxf(rgb.x,maxf(rgb.y,rgb.z))
	sun.light_energy=peak
	if peak>0.:
		sun.light_color=Color(rgb.x/peak,rgb.y/peak,rgb.z/peak).linear_to_srgb()
	var noon_rotation:=Vector3(_day.sun_rotation)*(PI/180.)
	var noon_direction:=Basis.from_euler(noon_rotation,sun.rotation_order).z.normalized()
	var direction:Vector3=direction_response.sample(0.,noon_direction) if captured_key_direction else Vector3.ZERO
	if direction==Vector3.ZERO:
		var midnight:=palette.sample(0.)
		var noon:=palette.sample(12.)
		var rotation:=noon_rotation+Vector3(midnight.pitch-noon.pitch,midnight.yaw-noon.yaw,0.)*(PI/180.)
		direction=Basis.from_euler(rotation,sun.rotation_order).z
	# Move the shadow direction only after most of the sunlight has faded.
	var direction_mix:=smoothstep(.65,1.,weight)
	if direction_mix>0.:
		direction=sun.basis.z.normalized().slerp(direction,direction_mix).normalized()
		sun.rotation=Basis.looking_at(-direction,Vector3.UP).get_euler(sun.rotation_order)

func _apply_sunrise_key(sun: DirectionalLight3D) -> void:
	if _balanced_preview or atmosphere_review != "combined" or not captured_key_response or not key_response.sunrise_available():
		return
	var weight := .65 * _lighting_scale(&"sunrise_key_response") * smoothstep(3.5, 4.0, hour) * (1.0 - smoothstep(7.0, 9.0, hour))
	if weight <= 0.0:
		return
	var color := sun.light_color.srgb_to_linear()
	var current := Vector3(color.r, color.g, color.b) * sun.light_energy
	var reference := _captured_key_rgb(12.0) * _lighting_scale(&"sun")
	# The WorldMap clock placement and partial blend are art calibration.
	var rgb := current.lerp(reference * key_response.sample_sunrise(hour), weight)
	var peak := maxf(rgb.x, maxf(rgb.y, rgb.z))
	if peak > 0.0:
		sun.light_color = Color(rgb.x / peak, rgb.y / peak, rgb.z / peak).linear_to_srgb()
		sun.light_energy = peak

func _apply_sunrise_elevation(sun: DirectionalLight3D) -> void:
	sunrise_elevation_active = false
	if _balanced_preview or atmosphere_review != "combined" or not key_direction_active \
			or not key_response.sunrise_elevation_available() or hour <= 4.5 or hour >= 8.5:
		return
	var weight := _lighting_scale(&"sunrise_elevation") * smoothstep(4.5, 5.5, hour)
	weight *= lerpf(0.50, 0.30, smoothstep(6.0, 7.0, hour)) * (1.0 - smoothstep(7.0, 8.5, hour))
	if weight <= 0.0:
		return
	var noon := Basis.from_euler(Vector3(_day.sun_rotation) * (PI / 180.0), sun.rotation_order).z
	var target: float = key_response.sample_sunrise_up(hour) * noon.y / direction_response.anchors[-1].y
	var direction := sun.basis.z
	var up := lerpf(direction.y, clampf(target, 0.0, noon.y), weight)
	if is_equal_approx(up, direction.y):
		return
	var horizontal := Vector3(direction.x, 0.0, direction.z).normalized()
	var adjusted := horizontal * sqrt(1.0 - up * up) + Vector3.UP * up
	sun.rotation = Basis.looking_at(-adjusted, Vector3.UP).get_euler(sun.rotation_order)
	sunrise_elevation_active = true


func set_source_bloom_shape(value:bool)->void:
	source_bloom_shape=value;set_coupled_bloom(coupled_bloom)

func set_measured_bloom_response(value:bool)->void:
	measured_bloom_response=value;set_coupled_bloom(coupled_bloom)

func night_soft_bloom_weight() -> float:
	if _balanced_preview or atmosphere_review != "combined" or not coupled_bloom \
		or not measured_bloom_response or not bloom_response.available():
		return 0.0
	return _lighting_scale(&"night_soft_bloom") * moonlight_weight(hour)

func twilight_finish_weight() -> float:
	if _balanced_preview or atmosphere_review != "combined" or not sky_response.twilight_available():
		return 0.0
	return _twilight_window()

func _twilight_window() -> float:
	# WorldMap times assigned to the measured evening sequence.
	return smoothstep(19.0, 19.5, hour) * (1.0 - smoothstep(20.0, 21.0, hour))

func twilight_soft_bloom_weight() -> float:
	if not coupled_bloom or not measured_bloom_response or not bloom_response.available():
		return 0.0
	return _lighting_scale(&"twilight_soft_bloom") * twilight_finish_weight()

func set_coupled_bloom(value:bool)->void:
	coupled_bloom=value
	if level.look._exposure_effect!=null:
		var enabled:bool=value and forest_active() and atmosphere_review in ["haze","combined"]
		level.look._exposure_effect.set_air_bloom(enabled)
		var response:float=bloom_response.sample(reference_hour())if enabled and measured_bloom_response else 1.
		# Keep the original main Bloom control and allow it to turn the contribution off.
		var strength := lerpf(1.0, 1.7, night_soft_bloom_weight())
		var twilight := twilight_soft_bloom_weight()
		strength *= lerpf(1.0, 1.35, twilight)
		level.look._exposure_effect.set_air_bloom_response(response * _lighting_scale(&"bloom") * strength if enabled else response)
		var spread := lerpf(1., _lighting_scale(&"bloom_spread"), PHASE_FINISH.phase_weight(hour)) if enabled else 1.
		level.look._exposure_effect.set_air_bloom_spread(spread * lerpf(1.0, 1.6, twilight) * lerpf(1.0, .84, _night_glare_weight()))
		var shape_weight:float=phase_finish.phase_weight(hour)if phase_finish!=null and phase_finish.requested else 0.
		if level.look._exposure_effect.has_method("set_bloom_shape"):
			level.look._exposure_effect.set_bloom_shape(source_bloom_shape and enabled and coherent_bloom,shape_weight)

func set_coherent_bloom(value:bool)->void:
	coherent_bloom=value
	if level!=null and level.look._exposure_effect!=null:level.look._exposure_effect.set_coherent_bloom_source(value)

func set_source_grade(value:bool)->void:
	if value and phase_finish!=null:phase_finish.set_requested(false)
	if grade_review!=null:grade_review.set_requested(value)

func set_hdr_air(value:bool)->void:
	hdr_air=value;_update_hdr_air()

func _update_hdr_air()->void:
	if level==null:return
	var viewport:Viewport=level.get_viewport()
	var rd:=RenderingServer.get_rendering_device()
	var usage:=RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	var wanted:bool=hdr_air and forest_active() and rd!=null and rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,usage)
	if wanted and not _hdr_owned:
		_hdr_viewport=viewport;_hdr_saved=viewport.use_hdr_2d;_hdr_owned=true
		viewport.use_hdr_2d=true
	elif not wanted and _hdr_owned:
		viewport.use_hdr_2d=_hdr_saved;_hdr_owned=false

func _exit_tree()->void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_point_camera):
		RenderingServer.frame_pre_draw.disconnect(_sync_point_camera)
	if _point_kernel_owner!=null and _point_kernel_owner.get_ref()==self:
		projected_sun.release()
		RenderingServer.global_shader_parameter_set("gaf_sun_opening_gain", 0.)
		if not _flat_lab:
			RenderingServer.global_shader_parameter_set("gaf_diffuse_opening", Vector4.ZERO)
			forest_replay.publish_bounce(0.0)
			forest_replay.release_surface()
		RenderingServer.global_shader_parameter_set("gaf_point_kernel",Vector4.ZERO);_point_kernel_owner=null
		RenderingServer.global_shader_parameter_set("gaf_point_soft",Vector2.ZERO)
		RenderingServer.global_shader_parameter_set("gaf_point_mixed",false)
		RenderingServer.global_shader_parameter_set("gaf_path_beam",Vector4.ZERO)
		RenderingServer.global_shader_parameter_set("gaf_lantern_grass_tone",0.0)
		_lantern_grass_tone = 0.0
		RenderingServer.global_shader_parameter_set("gaf_dawn_turf_color", 0.0)
		_dawn_turf_color = 0.0
	if grade_review!=null:grade_review.release()
	if _hdr_owned and is_instance_valid(_hdr_viewport):_hdr_viewport.use_hdr_2d=_hdr_saved

func _update_mist()->void:
	mist_source_active=false
	_update_player_falloff()
	_update_hdr_air()
	set_coherent_bloom(coherent_bloom)
	if level!=null and level.look._exposure_effect!=null:
		_apply_bounded_exposure_mix()
		set_coupled_bloom(coupled_bloom)
	if mist==null:return
	var env:Environment=level.get_node("WorldEnvironment").environment
	if forest_active() and atmosphere_review in ["haze","combined"] and level.look._exposure_effect!=null:
		var state:Dictionary=level.look._exposure_effect.snapshot()
		env.glow_enabled=not(coupled_bloom and state.frames>0 and str(state.error).is_empty())
		_forest_expected.glow_enabled=env.glow_enabled
	mist.visible=forest_active() and spatial_mist and atmosphere_review in ["haze","combined"] and env.fog_enabled and not _mist_sample.is_empty()
	if not mist.visible:return
	var ready:bool=mist.effect.snapshot().ready and mist.failure().is_empty()
	env.fog_density=0. if ready else float(_mist_sample.fog_opacity);_forest_expected.fog_density=env.fog_density
	if not mist.failure().is_empty():
		env.fog_density=float(_mist_sample.fog_opacity);_forest_expected.fog_density=env.fog_density;mist.hide();return
	var camera:Camera3D=level.get_node("Camera3D")
	var local_phase := 0.
	if atmosphere_review == "combined" and not _balanced_preview and level.view_mode == "gameplay":
		local_phase = PHASE_FINISH.phase_weight(hour)
	var daylight := _balanced_daylight_weight()
	var fog_gain := _lighting_scale(&"fog") * minf(1., _lighting_scale(&"near_haze"))
	# These daylight and night windows meet at 19:30 with zero strength.
	var night_weight := moonlight_weight(hour) if local_phase > 0. else 0.
	if not _flat_lab:
		mist.set_local_region(level.local_mist_region, _lighting_scale(&"local_mist") * local_phase * daylight * fog_gain)
		if night_weight > 0.:
			mist.set_additional_local_region(level.night_mist_region, _lighting_scale(&"night_cliff_mist") * night_weight * fog_gain)
		else:
			mist.set_additional_local_region(level.additional_mist_region, _lighting_scale(&"cliff_mist") * local_phase * daylight * fog_gain)
	var luma:=Vector3(.2126,.7152,.0722);var ambient:=env.ambient_light_color.srgb_to_linear()
	var sun:DirectionalLight3D=level.get_node("Sun");var key:=sun.light_color.srgb_to_linear()
	var incoming:=Vector3(ambient.r,ambient.g,ambient.b).dot(luma)*env.ambient_light_energy*.75+Vector3(key.r,key.g,key.b).dot(luma)*sun.light_energy*.03
	var rgb:Vector3=_mist_sample.fog_color;var color:=Color(rgb.x,rgb.y,rgb.z).srgb_to_linear()
	var linear:=Vector3(color.r,color.g,color.b)
	if captured_scatter:linear=air_light.scatter_color(linear,hour)
	var sample:=_mist_sample.duplicate()
	var measured := _sample_mist_phase()
	if not measured.is_empty():
		# Source chromaticity in linear space; retain the approved incident-light energy.
		var source:Vector3=measured.linear_scatter
		linear=source*linear.dot(luma)/maxf(source.dot(luma),.0001)
		sample.volume_density*=measured.density_ratio
		sample.height_falloff=measured.height_falloff_m
		sample.fog_begin=measured.start_m
	sample.linear_scatter_rgb=linear
	sample.scatter_energy=clampf(incoming,.015,.18)/maxf(linear.dot(luma),.0001)
	_apply_mist_source(sample,measured,linear)
	sample.scatter_energy *= _lighting_scale(&"scatter")
	if atmosphere_review == "combined" and not measured.is_empty():
		# Scale only the existing cool source. Optical depth and the warm emitter
		# stay independent, so the distant haze can lift without hiding the actor.
		var night_mix := moonlight_weight(hour) * _lighting_scale(&"night_mist_light")
		sample.scatter_energy *= lerpf(1.0, NIGHT_MIST_MAX_GAIN, night_mix)
		var distant_night := _night_far_air_weight(night_weight)
		sample.depth_scatter = _mist_depth_scatter(night_weight, distant_night)
		sample.depth_scatter_color = _mist_depth_scatter_color(linear, distant_night)
		sample.depth_optical = _mist_depth_optical()
	sample.player_light_weight *= _lighting_scale(&"lantern") * _lighting_scale(&"lantern_air")
	var near_scale := _lighting_scale(&"near_haze")
	if near_scale > 0. and not measured.is_empty() and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var strength: float = NEAR_HAZE_EXTINCTION * measured.density_ratio * PHASE_FINISH.phase_weight(hour) * near_scale
		strength *= _lighting_scale(&"fog")
		sample.near_layer = Vector3(NEAR_HAZE_ENTRY_M, strength, level.spawn_position.y + NEAR_HAZE_REFERENCE_HEIGHT_M)
		var depth_mix := _lighting_scale(&"near_haze_depth")
		if depth_mix > 0.:
			sample.near_fade_start = lerpf(.4, NEAR_HAZE_FADE_START, depth_mix)
		if strength > 0.0 and not _flat_lab and atmosphere_review == "combined" and level.grove != null and level.grove.spruce_visible():
			var gain := _lighting_scale(&"forest_near_scatter") * FOREST_NEAR_SCATTER_MAX_GAIN
			if gain > 0.0:
				sample.near_scatter = Vector3(FOREST_NEAR_SCATTER_CENTER.x, FOREST_NEAR_SCATTER_CENTER.y, gain)
	var emitter:Vector3=level.presentation.player_position()
	var lantern=level.player.get("lantern")
	if lantern!=null and lantern.ready_private:
		var origin := _lantern_light_origin(lantern.emitter_position())
		_position_lantern_light(origin)
		emitter=origin-Vector3.UP*1.4
	mist.publish(sample,emitter,level.spawn_position.y-1.,level.look.elapsed,camera.projection==Camera3D.PROJECTION_ORTHOGONAL,forest.player_range)

func _night_far_air_weight(night_weight: float) -> float:
	if not captured_mist_source or atmosphere_review != "combined" or _balanced_preview:
		return 0.0
	return night_weight * (1.0 - _twilight_window()) * _lighting_scale(&"night_far_air")

func _mist_depth_scatter(night_weight: float, distant_night: float = 0.0) -> float:
	var night := maxf(night_weight * _lighting_scale(&"night_depth_scatter"), 2.4 * distant_night)
	if _balanced_preview or atmosphere_review != "combined" or not captured_mist_source \
			or phase_air.evening_anchors.is_empty():
		return night
	# Reuse the depth ramp of the existing camera medium and blend just its source light.
	var gain := lerpf(2.4, 6.0, _lighting_scale(&"twilight_far_air"))
	var twilight := gain * _lighting_scale(&"twilight_depth_scatter") * _twilight_window()
	return maxf(night, twilight)

func _mist_depth_optical() -> float:
	if _balanced_preview or not captured_mist_source or atmosphere_review != "combined" \
			or phase_air.evening_anchors.is_empty():
		return 0.0
	# Fit the distant transmission to the Forest comparison without moving the near boundary.
	return .85 * _twilight_window() * _lighting_scale(&"twilight_far_optical")

func _mist_depth_scatter_color(source: Vector3, distant_night: float = 0.0) -> Vector3:
	if _balanced_preview or not captured_mist_source or atmosphere_review != "combined":
		return Vector3.ZERO
	const LUMA := Vector3(.2126, .7152, .0722)
	var offset := Vector3.ZERO
	if not phase_air.evening_anchors.is_empty() and _lighting_scale(&"twilight_depth_scatter") > 0.0:
		var weight := .4 * _twilight_window() * _lighting_scale(&"twilight_far_air_color")
		if weight > 0.0:
			var cooler := source * Vector3(.87, .65, 1.38)
			var cooler_luma := cooler.dot(LUMA)
			if cooler_luma > 0.0:
				offset = (cooler * (source.dot(LUMA) / cooler_luma) - source) * weight
	if distant_night > 0.0:
		# Forest GPU haze chromaticities. Retain the local profile's source luminance.
		var dawn := smoothstep(0.0, 2.5, hour) if hour < 12.0 else 0.0
		var color := Vector3(.550, 1.0, 1.294).lerp(Vector3(1.022, 1.0, .922), dawn)
		offset = offset.lerp(color * (source.dot(LUMA) / color.dot(LUMA)) - source, distant_night)
	return offset

func set_captured_mist_source(value:bool)->void:
	captured_mist_source=value;_update_mist()

func _sample_mist_phase() -> Dictionary:
	if not measured_atmosphere:
		return {}
	var reference := reference_hour()
	var measured: Dictionary = phase_air.sample(reference)
	if measured.is_empty() or not captured_mist_source or atmosphere_review != "combined" or _balanced_preview:
		return measured
	phase_air.blend_evening(measured, hour, _lighting_scale(&"evening_mist_profile"))
	var strength := _lighting_scale(&"dawn_mist_source")
	if strength <= 0. or hour >= 4.5 or hour <= reference:
		return measured
	var dawn: Dictionary = phase_air.sample(hour)
	# Advance the light source while retaining the existing optical profile.
	var pinned: Vector3 = measured.linear_scatter
	measured.linear_scatter = pinned.lerp(dawn.linear_scatter, strength)
	return measured

func _apply_mist_source(sample:Dictionary,measured:Dictionary,linear:Vector3)->void:
	# Relative source coefficients only. Clock, extinction and spatial transport
	# remain original adapters; this is not absolute native fog radiometry.
	if not captured_mist_source or not measured_atmosphere or measured.is_empty()or atmosphere_review!="combined"or is_day_anchor()or _day.is_empty():return
	var noon:Dictionary=forest.sample(12.)
	var reference:Dictionary=phase_air.sample(12.)
	if noon.is_empty()or reference.is_empty():return
	var luma:=Vector3(.2126,.7152,.0722)
	var ambient:Color=Color(_day.ambient_light_color).srgb_to_linear()
	var key:Color=Color(_day.sun_color).srgb_to_linear()
	# Noon ambient tint preserves luminance; key color/energy peak normalization
	# also preserves their linear product. Derive the anchor without changing time.
	var incoming:=Vector3(ambient.r,ambient.g,ambient.b).dot(luma)*float(_day.ambient_light_energy)*float(noon.ambient_energy_scale)*.75
	var noon_key_scale:=float(noon.key_scale)*(noon_direct_scale(12.)if gentle_noon else 1.)
	incoming+=(Vector3(key.r,key.g,key.b)*noon.key_color_scale).dot(luma)*float(_day.sun_energy)*noon_key_scale*.03
	var source:Vector3=measured.linear_scatter
	var anchor:Vector3=reference.linear_scatter
	var denominator:=anchor.dot(luma)*linear.dot(luma)
	if not source.is_finite()or not is_finite(incoming)or not is_finite(denominator)or denominator<=.00000001:return
	var energy:=source.dot(luma)*clampf(incoming,.015,.18)/denominator
	if not is_finite(energy)or energy<0.:return
	sample.scatter_energy=energy
	mist_source_active=true

func set_source_point_cutoff(value:bool)->void:
	source_point_cutoff=value;_publish_point_cutoff()

func set_captured_lantern_dawn(value:bool)->void:
	if captured_lantern_dawn==value:return
	captured_lantern_dawn=value
	_forest_hour=INF
	apply_time()
	_update_mist()

func set_player_soft_source(value:bool)->void:
	player_soft_source=value;_publish_point_cutoff()

func set_source_warm_light(value:bool)->void:
	source_warm_light=value;_update_player_falloff()

func set_noninverse_player_light(value:bool)->void:
	noninverse_player_light=value;_update_player_falloff()

func _update_player_falloff()->void:
	if _player_light==null:return
	var verified:bool=noninverse_player_light and forest_active()and point_response.available()and is_equal_approx(_player_light.omni_range,point_response.radius_m)
	var decay:=0. if verified else 2.
	if _player_light.omni_attenuation!=decay:_player_light.omni_attenuation=decay
	if mist!=null:mist.recovered_point_kernel=verified and source_warm_light and point_response.kernel_available()
	_publish_point_cutoff()

func _track_point_light(node:Node)->void:
	if level != null and node is Light3D and not node is DirectionalLight3D:
		_point_lights[node.get_instance_id()] = weakref(node)

func _point_scope_supported() -> bool:
	for key in _point_lights.keys():
		var light: Light3D = _point_lights[key].get_ref()
		if light==null:_point_lights.erase(key);continue
		if light == _player_light or not light.is_inside_tree() or light.get_world_3d() != level.get_world_3d() \
			or not light.is_visible_in_tree() or light.light_energy <= 0.0 or (light.light_cull_mask & 1) == 0:
			continue
		if not forest_path_light.is_compatible_secondary(light) or _player_light.light_color.b <= 0.0:
			return false
	return true

func _point_receiver_scope()->bool:
	if level==null or level.look==null:return false
	if not level.look.direct_clouds_active()or not level.look.player_adapter_enabled or not level.look.player_cloud_enabled or not level.look.player_effects_available():return false
	if ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_vertex_shading"):return false
	if plants!=null and plants.visible and not plants.grass_lighting_enabled:return false
	return true

func _publish_point_cutoff()->void:
	if _point_kernel_owner==null or _point_kernel_owner.get_ref()!=self:return
	var receiver_scope := _player_light != null and forest_active() and _point_scope_supported() and _point_receiver_scope()
	var eligible:bool=receiver_scope and source_point_cutoff and noninverse_player_light and point_response.kernel_available()and _player_light.omni_attenuation==0. and _player_light.visible and _player_light.light_energy>0. and is_equal_approx(_player_light.omni_range,point_response.radius_m)
	var point:Vector3=_player_light.global_position if _player_light!=null else Vector3.ZERO
	point_kernel_state=Vector4(point.x,point.y,point.z,_player_light.omni_range if eligible else 0.)
	var secondary: OmniLight3D = forest_path_light.light
	var secondary_active := receiver_scope and is_instance_valid(secondary) and secondary.is_visible_in_tree() \
		and secondary.light_energy > 0.0 and (secondary.light_cull_mask & 1) != 0
	RenderingServer.global_shader_parameter_set("gaf_point_kernel",point_kernel_state)
	RenderingServer.global_shader_parameter_set("gaf_point_mixed",eligible and secondary_active)
	var tone := _lighting_scale(&"lantern_grass_tone") if eligible and atmosphere_review == "combined" else 0.0
	if tone != _lantern_grass_tone:
		_lantern_grass_tone = tone
		RenderingServer.global_shader_parameter_set("gaf_lantern_grass_tone",tone)
	var beam_strength := _lighting_scale(&"forest_path_beam") if secondary_active else 0.0
	var beam := Vector4.ZERO
	if beam_strength > 0.0:
		# PIX establishes the inclination. Aim its horizontal component along
		# our path, whose orientation is independent of the captured map.
		var position := secondary.global_position
		var back := (Vector2(position.x, position.z) - PATH_BEAM_AIM_XZ).normalized()
		beam = Vector4(back.x * sqrt(.5), sqrt(.5), back.y * sqrt(.5), beam_strength)
	if beam != path_beam_state:
		path_beam_state = beam
		RenderingServer.global_shader_parameter_set("gaf_path_beam",beam)
	point_soft_state=point_response.soft_settings if eligible and player_soft_source and point_response.soft_available()else Vector2.ZERO
	RenderingServer.global_shader_parameter_set("gaf_point_soft",point_soft_state)

func _sync_point_camera() -> void:
	if _point_kernel_owner == null or _point_kernel_owner.get_ref() != self:
		return
	# The gameplay camera follows the rendered actor after the light update.
	# Publish its final position so the shader's camera guard also passes while moving.
	var camera_position: Vector3 = level.get_node("Camera3D").global_position
	if camera_position != _point_kernel_camera:
		_point_kernel_camera = camera_position
		RenderingServer.global_shader_parameter_set("gaf_point_kernel_camera", camera_position)
	if not _flat_lab:
		_sync_diffuse_opening()

func _sync_diffuse_opening() -> void:
	var state := Vector4.ZERO
	var gain := _lighting_scale(&"diffuse_openings")
	if gain > 0. and not _balanced_preview and atmosphere_review == "combined" and forest_active() \
		and level.terrain_light != null and level.terrain_light.is_active():
		gain *= PHASE_FINISH.phase_weight(hour) * _balanced_daylight_weight()
		var sun: DirectionalLight3D = level.get_node("Sun")
		if gain > 0. and sun.is_visible_in_tree() and sun.shadow_enabled and sun.light_energy > 0.:
			var direction := sun.global_basis.z.normalized()
			state = Vector4(direction.x, direction.y, direction.z, gain)
	if state != _diffuse_opening:
		_diffuse_opening = state
		RenderingServer.global_shader_parameter_set("gaf_diffuse_opening", state)

func set_lantern_overhead(value: bool) -> void:
	if lantern_overhead == value:
		return
	lantern_overhead = value
	if _lantern_overhead_toggle != null:
		_lantern_overhead_toggle.set_pressed_no_signal(value)
	_refresh_lantern_position()

func _refresh_lantern_position() -> void:
	if level == null:
		return
	var lantern = level.player.get("lantern")
	if lantern != null and lantern.ready_private:
		sync_lantern_emitter(lantern.emitter_position())

func _refresh_lantern_glow() -> void:
	if level == null or not forest.available() or RenderingServer.get_current_rendering_method() != "mobile":
		return
	var lantern = level.player.get("lantern")
	if lantern != null and lantern.ready_private:
		lantern.set_emission_gain(LANTERN_EMISSION_GAIN * _lighting_scale(&"lantern_glow") * lerpf(1.0, .82, _night_glare_weight()))

func _night_glare_weight() -> float:
	if _balanced_preview or not forest_active() or atmosphere_review != "combined":
		return 0.0
	return moonlight_weight(hour) * _lighting_scale(&"night_glare_control")

func _lantern_light_origin(hip: Vector3) -> Vector3:
	if not lantern_overhead:
		return hip
	var lift := LANTERN_OVERHEAD_LIFT_M * _lighting_scale(&"lantern_lift")
	# The overhead pool follows the rendered player while the visible hip lantern swings.
	return level.presentation.player_position() + Vector3.UP * (LANTERN_REST_HEIGHT_M + lift)

func _position_lantern_light(origin: Vector3) -> void:
	if _player_light == null:
		return
	_player_light.top_level = true
	_player_light.light_cull_mask = 1
	_player_light.global_position = origin

func sync_lantern_emitter(point:Vector3)->void:
	if not point.is_finite():return
	var origin := _lantern_light_origin(point)
	_position_lantern_light(origin)
	if mist!=null and mist.visible:mist.set_warm_emitter(origin)
	_publish_point_cutoff()

func air_field()->Dictionary:
	var result:Dictionary=air_light.field()
	if not shadowed_scatter:result.valid=false
	return result

func _path_air_source() -> PackedFloat32Array:
	var gain := _lighting_scale(&"forest_path_air")
	var lamp: OmniLight3D = forest_path_light.light
	if gain <= 0.0 or not forest_active() or atmosphere_review != "combined" \
		or not is_instance_valid(lamp) or not lamp.is_visible_in_tree() or lamp.light_energy <= 0.0:
		return PackedFloat32Array()
	var position := lamp.global_position
	var rgb := lamp.light_color.srgb_to_linear()
	var beam := path_beam_state
	return PackedFloat32Array([position.x, position.y, position.z, lamp.omni_range,
		rgb.r, rgb.g, rgb.b, lamp.light_energy * PATH_AIR_MAX_SCALE * gain,
		beam.x, beam.y, beam.z, beam.w * _lighting_scale(&"forest_path_air_beam")])

func _mist_state(ready:bool,error:String)->void:
	if mist==null or not mist.visible or _mist_sample.is_empty():return
	# Called late, AFTER configure invalidates a resized field in this same frame.
	var env:Environment=level.get_node("WorldEnvironment").environment
	env.fog_density=0. if ready and error.is_empty() else float(_mist_sample.fog_opacity)
	_forest_expected.fog_density=env.fog_density

func _mist_materials()->Array:
	var result:Array=level.look.materials.values()
	result.append_array(level.look._direct_actor_materials)
	if _flat_lab:
		return result
	if plants!=null:result.append_array(plants.materials)
	for chunk:Dictionary in level.geometry._cutaway_chunks:result.append_array(chunk.materials)
	if grove_mist_enabled and level.grove != null:
		result.append_array(level.grove.mist_receivers(PHASE_FINISH.phase_weight(hour)))
	return result

func set_grove_mist(enabled: bool) -> void:
	grove_mist_enabled = enabled
	if _grove_mist_toggle != null:
		_grove_mist_toggle.set_pressed_no_signal(enabled)

func set_forest_spruce_visible(enabled: bool) -> void:
	var grove = level.grove
	if grove == null or not grove.spruce_available():
		return
	var collider := level.player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider == null:
		collider = level.player.get_node_or_null("BodyCollision") as CollisionShape3D
	var capsule := collider.shape as CapsuleShape3D if collider != null else null
	if capsule != null and grove.set_spruce_visible(enabled, level.player.global_position, capsule):
		if enabled:
			level.look.refresh_grove_lighting()
			grove.update_focus(level.get_node("Camera3D"), level.player.global_position, level.view_mode == "gameplay")
	if _spruce_toggle != null:
		_spruce_toggle.set_pressed_no_signal(grove.spruce_visible())
	_sync_forest_night_lights()

func set_source_terrain(enabled: bool) -> bool:
	if not private_primary:
		return false
	if enabled and _source_terrain_tiles == null:
		_source_terrain_tiles = preload("res://scripts/world_map_source_terrain.gd").load_tiles()
	enabled = enabled and _source_terrain_tiles != null
	var bound: Dictionary[ShaderMaterial, bool] = {}
	for item: Array in level.look.terrain_materials:
		var material: ShaderMaterial = item[3]
		if bound.has(material):
			continue
		bound[material] = true
		material.set_shader_parameter("use_source_terrain", enabled)
		material.set_shader_parameter("source_terrain_tiles", _source_terrain_tiles if enabled else null)
	level.geometry.reset_cutaway_materials()
	level.geometry.update_cutaway(level.player.position, level.get_node("Camera3D").position, level.view_mode == "gameplay")
	if _source_terrain_toggle != null:
		_source_terrain_toggle.set_pressed_no_signal(enabled)
	var stone_detail: HSlider = _lighting_sliders.get(&"stone_detail_softness")
	if stone_detail != null:
		stone_detail.editable = _stone_detail_editable()
	return enabled

func forest_active()->bool:
	return private_primary and level!=null and level.look.stage==2 and level.view_mode=="gameplay" and atmosphere_review!="previous" and forest.available()

func set_atmosphere_review(mode:String)->void:
	if not mode in ["previous","haze","lighting","combined"]:return
	_restore_day();atmosphere_review=mode;_forest_expected.clear();apply_time()
	if mode!="previous" and level!=null and level.terrain_sky.enabled:level.terrain_sky.set_enabled(false)
	if level!=null:level.look._refresh_ground_bounce()

func set_full_direct_shadows(value:bool)->void:
	full_direct_shadows=value
	if _time_applied and forest_active() and atmosphere_review in ["lighting","combined"]:
		_apply_direct_shadow_opacity(level.get_node("Sun"))

func _lighting_scale_default(effect: StringName) -> float:
	if effect == &"world_outline_width":
		return 1.
	if effect == &"world_outline_strength":
		return 0.
	if effect == &"dawn_sky_transition":
		return .35
	if effect == &"twilight_sky_chroma":
		return .5
	if effect in [&"grass_night_albedo", &"twilight_grass_albedo"]:
		return .55
	if effect == &"dawn_mist_source":
		return .65
	if effect == &"night_stone_fill_balance":
		return .48
	if effect == &"night_stone_top_cool":
		return .12
	if effect in [&"sculk_surface", &"forest_path_placement", &"forest_path_air_beam", &"night_depth_scatter"]:
		return 0.
	if effect == &"forest_daylight_accents":
		return .65
	if effect == &"daylight_haze":
		return .65
	if effect == &"sun_opening":
		return .75
	if effect == &"twilight_shadow_color":
		return .65
	if effect == &"cool_shadow_detail":
		return 0.
	if effect in [&"daylight_bounce", &"stone_diffuse_contrast", &"stone_detail_softness", &"projected_sun_position", &"projected_sun_softness", &"bloom_diffusion"]:
		return 0.
	if effect in [&"forest_path_light", &"forest_near_scatter", &"grass_shade_color", &"stone_twilight_color"]:
		return .7
	if effect in [&"humid_light", &"humid_depth", &"diffuse_openings", &"local_mist", &"regional_sky", &"cliff_mist", &"night_spatial_sky"]:
		return 0.
	if effect == &"night_cliff_mist":
		return .75
	if effect == &"sunlit_mist":
		return .24
	if effect == &"foot_contact":
		return 0.
	if effect == &"player_bounce":
		return 0.
	if effect == &"projected_sun":
		return .40
	if effect == &"night_path_chroma":
		return .75
	if effect == &"grass_root_tone":
		return .85
	if effect == &"forest_path_beam":
		return .65
	if effect in [&"night_mist_light", &"forest_path_air"]:
		return .5
	if effect == &"shadow_softness":
		return DAYLIGHT_SHADOW_SOFTNESS
	if effect == &"tree_shade":
		return .85
	if effect == &"spruce_sky":
		return .5
	if effect == &"tree_wind":
		return CrownWind.DEFAULT_STRENGTH
	return 1.

func _lighting_scale(effect: StringName) -> float:
	var default := _lighting_scale_default(effect)
	if _balanced_preview:
		return BALANCED_ATMOSPHERE.get(effect, default)
	return _lighting_mix.get(effect, default)

func set_balanced_atmosphere_preview(enabled: bool) -> void:
	if _balanced_preview == enabled:
		return
	_balanced_preview = enabled
	_refresh_lighting_mix()

func balanced_shadow_weight() -> float:
	if not _balanced_preview or atmosphere_review not in ["lighting", "combined"] or not forest_active():
		return 0.
	# Keep the approved Noon and night filtering. This is a Godot look blend.
	return PHASE_FINISH.phase_weight(hour) * _balanced_daylight_weight()

func _balanced_daylight_weight() -> float:
	return smoothstep(5.5, 7., hour) * (1. - smoothstep(16.5, 19.5, hour))

func _daylight_color_balance_weight() -> float:
	if _balanced_preview or atmosphere_review != "combined" or not forest_active():
		return 0.
	return _lighting_scale(&"daylight_balance") * PHASE_FINISH.phase_weight(hour) * _balanced_daylight_weight()

func shadow_softness_mix_scale() -> float:
	if _balanced_preview or not forest_active() or atmosphere_review not in ["lighting", "combined"]:
		return 1.
	var weight := PHASE_FINISH.phase_weight(hour) * _balanced_daylight_weight()
	return lerpf(1., _lighting_scale(&"shadow_softness"), weight)

func sunlight_pockets_weight() -> float:
	if not forest_active() or atmosphere_review not in ["lighting", "combined"]:
		return 0.
	return .65 * _lighting_scale(&"sun_pockets") * PHASE_FINISH.phase_weight(hour) * _balanced_daylight_weight()

func refresh_daylight_shading() -> void:
	if _point_kernel_owner == null or _point_kernel_owner.get_ref() != self:
		return
	var phase := 0.0
	if forest_active() and atmosphere_review in ["lighting", "combined"] and level.look.direct_clouds_active():
		phase = PHASE_FINISH.phase_weight(hour) * _balanced_daylight_weight()
	projected_sun.set_weight(_lighting_scale(&"projected_sun") * phase)
	var shift := Vector2.ZERO if _flat_lab else level.projected_sun_shift as Vector2
	projected_sun.set_shift(shift * _lighting_scale(&"projected_sun_position"))
	projected_sun.set_softness(0. if _balanced_preview else _lighting_scale(&"projected_sun_softness"))
	var gain := .64 * _lighting_scale(&"sun_opening") * phase if not _balanced_preview else 0.
	if gain != _opening_gain:
		_opening_gain = gain
		RenderingServer.global_shader_parameter_set("gaf_sun_opening_gain", gain)
	var slider: HSlider = _lighting_sliders.get(&"projected_sun")
	if slider != null:
		slider.editable = not _balanced_preview and projected_sun.available()
	var placement: HSlider = _lighting_sliders.get(&"projected_sun_position")
	if placement != null:
		placement.editable = _projected_placement_available()
	var softness: HSlider = _lighting_sliders.get(&"projected_sun_softness")
	if softness != null:
		softness.editable = not _balanced_preview and projected_sun.softness_available()

func _projected_placement_available() -> bool:
	return not _balanced_preview and projected_sun.available() and level != null \
		and level.projected_sun_shift.is_finite() and level.projected_sun_shift != Vector2.ZERO

func local_exposure_mix_scale() -> float:
	if forest_active() and atmosphere_review in ["haze", "combined"]:
		var scale := _lighting_scale(&"exposure")
		return lerpf(1., scale, PHASE_FINISH.phase_weight(hour)) if _balanced_preview else scale
	return 1.

func local_exposure_shadow_lift() -> float:
	if _balanced_preview:
		return 1.
	var daylight := smoothstep(5.5, 7., hour) * (1. - smoothstep(16.5, 19., hour))
	var twilight := twilight_finish_weight() * _lighting_scale(&"twilight_shadow_lift")
	return lerpf(1., _lighting_scale(&"daylight_shadow_lift"), daylight) * lerpf(1., .94, twilight)

func bounded_exposure_strength() -> float:
	return LOCAL_EXPOSURE_STRENGTH * local_exposure_mix_scale()

func reference_finish_mix_scale() -> float:
	var base := _lighting_scale(&"grade")
	if _balanced_preview:
		return lerpf(base, BALANCED_DAY_REFERENCE_FINISH, _balanced_daylight_weight())
	return base * lerpf(1., .77, _daylight_color_balance_weight())

func player_sky_fill_mix_scale() -> float:
	if forest_spatial_sky_context():
		return lerpf(1., _lighting_scale(&"player_sky"), PHASE_FINISH.phase_weight(hour))
	return 1.

func grass_sky_fill_mix_scale() -> float:
	if forest_spatial_sky_context():
		return _lighting_scale(&"grass_sky") * PHASE_FINISH.phase_weight(hour)
	return 0.

func grass_shade_color_mix() -> Vector3:
	if _balanced_preview or atmosphere_review != "combined" or not forest_spatial_sky_context():
		return Vector3.ZERO
	var strength := _lighting_scale(&"grass_shade_color") * PHASE_FINISH.phase_weight(hour) * _balanced_daylight_weight()
	var tint := Vector2(.80, 1.24).lerp(Vector2(.84, 1.14), smoothstep(7., 16.5, hour))
	return Vector3(tint.x, tint.y, strength) if strength > 0. else Vector3.ZERO

func night_stone_blue_softness() -> float:
	if _balanced_preview or atmosphere_review != "combined" or not forest_spatial_sky_context() \
			or not captured_sky_response or not sky_response.available() or not moonlight_enabled:
		return 0.0
	return moonlight_weight(hour) * _lighting_scale(&"night_stone_blue_softness")

func dawn_stone_sky_color() -> float:
	if _balanced_preview or atmosphere_review != "combined" or not forest_spatial_sky_context() \
			or not captured_sky_response or not sky_response.available() or not moonlight_enabled:
		return 0.0
	return _dawn_shadow_weight() * _lighting_scale(&"dawn_stone_sky_color")

func _dawn_shadow_weight() -> float:
	return smoothstep(0.0, 2.5, hour) * (1.0 - smoothstep(2.5, 4.5, hour))

func _publish_dawn_turf_color() -> void:
	if _point_kernel_owner == null or _point_kernel_owner.get_ref() != self:
		return
	var strength := 0.0
	if not _balanced_preview and atmosphere_review == "combined" and forest_spatial_sky_context() \
			and captured_sky_response and sky_response.available() and moonlight_enabled \
			and (_flat_lab or (plants != null and plants.grass_light.active)) and is_instance_valid(_player_light):
		strength = _dawn_shadow_weight() * _lighting_scale(&"dawn_turf_color")
	if strength != _dawn_turf_color:
		_dawn_turf_color = strength
		RenderingServer.global_shader_parameter_set("gaf_dawn_turf_color", strength)

func turf_ambient_color() -> Vector3:
	if _balanced_preview or atmosphere_review != "combined" or not forest_spatial_sky_context() \
			or not captured_sky_response or not sky_response.available() or plants == null or not plants.grass_light.active:
		return Vector3.ONE
	# PIX confirms a shared incident color on paired receivers. These gains are calibrated to the WorldMap palette.
	var twilight := Vector3.ONE.lerp(Vector3(1.4, 1.75, .88), twilight_finish_weight())
	var night := moonlight_weight(hour) if moonlight_enabled else 0.0
	var gain := twilight.lerp(Vector3(.9, 1.7, .88), night)
	var base := Vector3.ONE.lerp(gain, .65 * _lighting_scale(&"turf_ambient_color"))
	# The matched Forest 30/32 receivers shift away from blue in the early dawn
	# transition. These bounded gains are tuned for the WorldMap materials.
	var dawn := smoothstep(0., 2.5, hour) * (1. - smoothstep(2.5, 4.5, hour))
	return base * Vector3.ONE.lerp(Vector3(1.75, .79, .82),
		.8 * dawn * night * _lighting_scale(&"dawn_turf_ambient"))

func twilight_ground_ambient_scale() -> float:
	if not forest_spatial_sky_context() or not captured_sky_response or plants == null or not plants.grass_light.active:
		return 1.0
	# Calibrated on the same three WorldMap views, with fog and direct lights fixed.
	return lerpf(1.0, .55, twilight_finish_weight() * _lighting_scale(&"twilight_ground_ambient"))

func grass_root_tone_mix() -> float:
	return _lighting_scale(&"grass_root_tone") * _night_grass_weight()

func grass_night_albedo_mix() -> float:
	if _balanced_preview or atmosphere_review != "combined" or not forest_active():
		return 0.0
	return _blend_grass_albedo(moonlight_weight(hour))

func _blend_grass_albedo(night: float) -> float:
	var night_albedo := _lighting_scale(&"grass_night_albedo") * night
	if twilight_finish_weight() <= 0.0:
		return night_albedo
	# Use the same blade response as at night and hand it over as moonlight rises.
	var twilight := _lighting_scale(&"twilight_grass_albedo") * smoothstep(19.0, 19.5, hour)
	return night_albedo + twilight * (1.0 - night)

func _night_grass_weight() -> float:
	if _balanced_preview or not forest_active() or atmosphere_review != "combined":
		return 0.0
	return moonlight_weight(hour)

func grass_shadow_height_scale() -> float:
	var strength := _lighting_scale(&"grass_shadow_reach") * twilight_color_weight()
	if strength <= 0. or not key_direction_active or not direction_response.available() or _day.is_empty():
		return 1.
	if moonlight_enabled:
		strength *= 1. - moonlight_weight(hour)
	var sun: DirectionalLight3D = level.get_node("Sun")
	var noon := Basis.from_euler(Vector3(_day.sun_rotation) * (PI / 180.), sun.rotation_order).z.normalized()
	var up := sun.global_basis.z.normalized().y
	if up <= .001 or up >= .999 or noon.y <= .001:
		return 1.
	var source_up: float = clampf(up * direction_response.anchors[-1].y / noon.y, .001, .999)
	# At a common grass height, horizontal shadow reach is height * cot(elevation).
	var game_reach := sqrt(1. - up * up) / up
	var source_reach := sqrt(1. - source_up * source_up) / source_up
	return lerpf(1., clampf(source_reach / game_reach, .5, 1.), strength)

func _sync_twilight_crown() -> void:
	if level == null or level.grove == null:
		return
	var amount := 0.0
	var depth := 0.0
	if forest_active() and captured_sky_response:
		# The sampled crown sky dropped to roughly 14% at the dusk anchor.
		amount = .86 * twilight_finish_weight() * _lighting_scale(&"twilight_crown")
		if level.grove.source_oaks and sky_response.available() and atmosphere_review == "combined" and not _balanced_preview:
			var night := moonlight_weight(hour)
			depth = lerpf(0.32 * twilight_finish_weight(), 0.62, night) * _lighting_scale(&"crown_ambient_depth")
	level.grove.set_crown_dusk_occlusion(amount)
	level.grove.set_crown_ambient_depth(depth)

func _sync_oak_leaf_tint() -> void:
	if level == null or level.grove == null:
		return
	var strength := 0.
	if forest_active() and atmosphere_review == "combined" and level.grove.visible:
		strength = _lighting_scale(&"oak_leaf_tint") * PHASE_FINISH.phase_weight(hour)
	level.grove.set_source_leaf_tint(strength)

func _apply_bounded_exposure_mix() -> void:
	if phase_finish != null and phase_finish.active:
		return
	var effect = level.look._exposure_effect
	var strength := bounded_exposure_strength()
	if effect != null and effect._review_strength != strength:
		effect.set_review_strength(strength)

func set_lighting_scale(effect: StringName, value: float) -> void:
	if not LIGHTING_MIX_CONTROLS.has(effect) or not is_finite(value):
		return
	var scale := clampf(value, 0., LIGHTING_MIX_CONTROLS[effect][1])
	if effect == &"world_outline_width":
		scale = clampf(roundf(scale), 1., 4.)
	if effect in [&"forest_path_placement", &"forest_replay_placement"]:
		scale = roundf(scale)
	if scale == float(_lighting_mix.get(effect, _lighting_scale_default(effect))):
		return
	_lighting_mix[effect] = scale
	_refresh_lighting_mix(effect)

func reset_lighting_mix() -> void:
	_balanced_preview = false
	_lighting_mix.clear()
	_refresh_lighting_mix()

func _mix_snapshot() -> Dictionary:
	var strengths := {}
	for effect: StringName in LIGHTING_MIX_CONTROLS:
		strengths[effect] = float(_lighting_mix.get(effect, _lighting_scale_default(effect)))
	return {"strengths": strengths, "balanced": _balanced_preview}

func _remember_mix_edit(before: Dictionary) -> void:
	if before != _mix_snapshot():
		_settings.remember_edit(_restore_mix_snapshot.bind(before))

func _restore_mix_snapshot(snapshot: Dictionary) -> void:
	_lighting_mix = snapshot.strengths
	_balanced_preview = snapshot.balanced
	_refresh_lighting_mix()

func _begin_mix_drag() -> void:
	_mix_before_drag = _mix_snapshot()

func _end_mix_drag(_changed: bool) -> void:
	if _mix_before_drag.is_empty():
		return
	_remember_mix_edit(_mix_before_drag)
	_mix_before_drag = {}

func apply_scene_lighting_mix(preset: SceneLightingMix) -> bool:
	if preset == null or preset.strengths.is_empty() or _balanced_preview:
		return false
	for effect: StringName in preset.strengths:
		var strength: float = preset.strengths[effect]
		if not LIGHTING_MIX_CONTROLS.has(effect) or not is_finite(strength) \
				or strength < 0. or strength > float(LIGHTING_MIX_CONTROLS[effect][1]):
			return false
		if effect in [&"forest_path_placement", &"forest_replay_placement"] and strength != roundf(strength):
			return false
	_lighting_mix.merge(preset.strengths, true)
	_refresh_lighting_mix()
	return true

func save_lighting_mix(path: String = LIGHTING_MIX_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("recipe", "version", LIGHTING_MIX_VERSION)
	for effect: StringName in LIGHTING_MIX_CONTROLS:
		config.set_value("strengths", String(effect), float(_lighting_mix.get(effect, _lighting_scale_default(effect))))
	var temporary_path := path + ".tmp"
	var error := config.save(temporary_path)
	if error == OK:
		error = DirAccess.rename_absolute(temporary_path, path)
	if error != OK and FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(temporary_path)
	return error

func load_lighting_mix(path: String = LIGHTING_MIX_PATH) -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		return error
	var version: Variant = config.get_value("recipe", "version", 0)
	if not version is int or version < 1 or version > LIGHTING_MIX_VERSION:
		return ERR_FILE_UNRECOGNIZED
	var restored := {}
	for effect: StringName in LIGHTING_MIX_CONTROLS:
		var from_older_recipe: bool = (version == 1 and effect == &"grade") \
			or (version < 3 and effect == &"sky_chroma") or (version < 4 and effect == &"player_sky") \
			or (version < 5 and effect in [&"near_haze", &"bloom_spread"]) \
			or (version < 7 and effect == &"moon") \
			or (version < 8 and effect in [&"lantern_lift", &"lantern_air"]) \
			or (version < 9 and effect == &"lantern_glow") \
			or (version < 10 and effect == &"shadow_softness") \
			or (version < 11 and effect == &"sun_pockets")
		var missing_value := _lighting_scale_default(effect) if from_older_recipe else -1.
		if version < 12 and effect == &"daylight_balance":
			missing_value = 0. # Keep saved looks as they were before this calibration.
		if version < 6 and effect == &"grass_sky":
			missing_value = 0.
		if version < 14 and effect == &"oak_leaf_tint":
			missing_value = 0.
		if version < 15 and effect == &"spruce_sky":
			missing_value = 0.
		if version < 16 and effect == &"humid_light":
			missing_value = 0.
		if version < 17 and effect == &"tree_wind":
			missing_value = CrownWind.DEFAULT_STRENGTH
		if version < 18 and effect == &"night_path_chroma":
			missing_value = 0.
		if version < 19 and effect == &"night_mist_light":
			missing_value = 0.
		if version < 20 and effect == &"forest_accents":
			missing_value = 0.
		if version < 21 and effect == &"forest_path_light":
			missing_value = 0.
		if version < 22 and effect == &"forest_near_scatter":
			missing_value = 0.
		if version < 23 and effect == &"grass_shade_color":
			missing_value = 0.
		if version < 24 and effect == &"stone_twilight_color":
			missing_value = 0.
		if version < 25 and effect == &"twilight_shadow_color":
			missing_value = 0.
		if version < 26 and effect == &"grass_shadow_reach":
			missing_value = 0.
		if version < 27 and effect == &"forest_path_air":
			missing_value = 0.
		if version < 28 and effect == &"forest_path_beam":
			missing_value = 0.
		if version < 29 and effect == &"grass_root_tone":
			missing_value = 0.
		if version < 30 and effect == &"sunlit_mist":
			missing_value = 0.
		if version < 31 and effect == &"foot_contact":
			missing_value = 0.
		if version < 32 and effect == &"player_bounce":
			missing_value = 0.
		if version < 33 and effect == &"projected_sun":
			missing_value = 0.
		if version < 34 and effect == &"humid_depth":
			missing_value = 0.
		if version < 37 and effect == &"tree_shade":
			missing_value = 0.
		if version < 38 and effect == &"forest_daylight_accents":
			missing_value = 0.
		if version < 39 and effect == &"daylight_haze_spill":
			missing_value = 0.
		if version < 40 and effect == &"daylight_shadow_lift":
			missing_value = 1.
		if version < 42 and effect == &"local_mist":
			missing_value = 0.
		if version < 43 and effect == &"regional_sky":
			missing_value = 0.
		if version < 44 and effect == &"cliff_mist":
			missing_value = 0.
		if version < 45 and effect in [&"night_spatial_sky", &"night_stone_fill_balance"]:
			missing_value = 0.
		if version < 85 and effect == &"night_cliff_mist":
			missing_value = 0.
		if version < 47 and effect == &"daylight_bounce":
			missing_value = 0.
		if version < 48 and effect == &"stone_diffuse_contrast":
			missing_value = 0.
		if version < 49 and effect == &"stone_detail_softness":
			missing_value = 0.
		if version < 50 and effect == &"projected_sun_position":
			missing_value = 0.
		if version < 51 and effect == &"bloom_diffusion":
			missing_value = 0.
		if version < 52 and effect == &"sculk_surface":
			missing_value = 0.
		if version < 53 and effect in [&"world_outline_strength", &"world_outline_width"]:
			missing_value = _lighting_scale_default(effect)
		if version < 54 and effect == &"projected_sun_softness":
			missing_value = 0.
		if version < 55 and effect == &"cool_shadow_detail":
			missing_value = 0.
		if version < 56 and effect == &"forest_path_placement":
			missing_value = 0.
		if version < 57 and effect == &"forest_path_air_beam":
			missing_value = 0.
		if version < 58 and effect == &"night_depth_scatter":
			missing_value = 0.
		if version < 59 and effect == &"night_stone_top_cool":
			missing_value = 0.
		if version < 60 and effect == &"dawn_sky_transition":
			missing_value = 0.
		if version < 61 and effect == &"grass_night_albedo":
			missing_value = 0.
		if version < 62 and effect == &"dawn_mist_source":
			missing_value = 0.
		if version < 63 and effect == &"lantern_grass_tone":
			missing_value = 0.
		if version < 64 and effect == &"night_sky_fill":
			missing_value = 0.
		if version < 65 and effect == &"night_soft_bloom":
			missing_value = 0.
		if version < 66 and effect == &"evening_mist_profile":
			missing_value = 0.
		if version < 67 and effect == &"evening_key_response":
			missing_value = 0.
		if version < 68 and effect == &"twilight_sky_chroma":
			missing_value = 0.
		if version < 69 and effect in [&"twilight_ambient", &"twilight_soft_bloom"]:
			missing_value = 0.
		if version < 70 and effect == &"twilight_grass_albedo":
			missing_value = 0.
		if version < 71 and effect == &"twilight_depth_scatter":
			missing_value = 0.
		if version < 72 and effect == &"evening_lantern":
			missing_value = 0.
		if version < 73 and effect == &"twilight_crown":
			missing_value = 0.
		if version < 74 and effect == &"twilight_ground_ambient":
			missing_value = 0.
		if version < 75 and effect in [&"twilight_shadow_lift", &"twilight_far_air"]:
			missing_value = 0.
		if version < 76 and effect == &"twilight_far_air_color":
			missing_value = 0.
		if version < 77 and effect == &"twilight_far_optical":
			missing_value = 0.
		if version < 78 and effect == &"forest_replay_emission":
			missing_value = 0.
		if version < 79 and effect == &"forest_replay_bounce":
			missing_value = 0.
		if version < 86 and effect == &"forest_replay_placement":
			missing_value = 0.
		if version < 87 and effect == &"forest_replay_surface_bounce":
			missing_value = 0.
		if version < 88 and effect == &"forest_replay_halo":
			missing_value = 0.
		if version < 89 and effect == &"night_far_air":
			missing_value = 0.
		if version < 90 and effect == &"dawn_turf_color":
			missing_value = 0.
		if version < 91 and effect == &"dawn_stone_sky_color":
			missing_value = 0.
		if version < 92 and effect == &"sunrise_key_response":
			missing_value = 0.
		if version < 93 and effect == &"sunrise_elevation":
			missing_value = 0.
		if version < 94 and effect == &"night_glare_control":
			missing_value = 0.
		if version < 80 and effect == &"canopy_player_cue":
			missing_value = 0.
		if version < 84 and effect == &"night_stone_blue_softness":
			missing_value = 0.
		if version < 83 and effect == &"dawn_turf_ambient":
			missing_value = 0.
		if version < 82 and effect == &"turf_ambient_color":
			missing_value = 0.
		if version < 81 and effect == &"crown_ambient_depth":
			missing_value = 0.
		if version < 41 and effect == &"diffuse_openings":
			missing_value = 0.
		if version < 36 and effect == &"daylight_haze":
			missing_value = 0.
		if version < 35 and effect == &"sun_opening":
			missing_value = 0.
		if (version < 13 and effect == &"near_haze_depth") or (version < 5 and effect == &"near_haze"):
			missing_value = 0.
		var value: Variant = config.get_value("strengths", String(effect), missing_value)
		var maximum: float = LIGHTING_MIX_CONTROLS[effect][1]
		if not (value is int or value is float) or not is_finite(value) or value < 0. or value > maximum:
			return ERR_INVALID_DATA
		if effect == &"world_outline_width" and (value < 1. or value != roundf(value)):
			return ERR_INVALID_DATA
		if effect in [&"forest_path_placement", &"forest_replay_placement"] and value != roundf(value):
			return ERR_INVALID_DATA
		restored[effect] = float(value)
	_lighting_mix = restored
	_balanced_preview = false
	_refresh_lighting_mix()
	return OK

func _refresh_lighting_mix(changed_effect: StringName = &"") -> void:
	if _balanced_toggle != null:
		_balanced_toggle.set_pressed_no_signal(_balanced_preview)
	if _near_haze_toggle != null:
		_near_haze_toggle.set_pressed_no_signal(near_haze_enabled or _balanced_preview)
		_near_haze_toggle.disabled = _balanced_preview
	if _save_mix_button != null:
		_save_mix_button.disabled = _balanced_preview
	if _scene_mix_button != null:
		_scene_mix_button.disabled = _balanced_preview
	for button in _additional_mix_buttons:
		button.disabled = _balanced_preview
	for effect: StringName in _lighting_sliders:
		var slider: HSlider = _lighting_sliders[effect]
		slider.editable = not _balanced_preview and (effect != &"sunlit_mist" or directional_air.available())
		if effect in [&"dawn_sky_transition", &"night_sky_fill"]:
			slider.editable = slider.editable and sky_response.available()
		if effect == &"dawn_mist_source":
			slider.editable = slider.editable and not phase_air.anchors.is_empty()
		if effect in [&"evening_mist_profile", &"twilight_depth_scatter", &"twilight_far_air", &"twilight_far_air_color", &"twilight_far_optical"]:
			slider.editable = slider.editable and not phase_air.evening_anchors.is_empty()
		if effect == &"sunrise_key_response":
			slider.editable = slider.editable and key_response.sunrise_available()
		if effect == &"sunrise_elevation":
			slider.editable = slider.editable and key_response.sunrise_elevation_available() and direction_response.available()
		if effect == &"evening_key_response":
			slider.editable = slider.editable and key_response.evening_available()
		if effect == &"evening_lantern":
			slider.editable = slider.editable and point_response.evening_available()
		if effect in [&"twilight_sky_chroma", &"twilight_ambient", &"twilight_crown"]:
			slider.editable = slider.editable and sky_response.twilight_available()
		if effect == &"crown_ambient_depth":
			slider.editable = slider.editable and is_instance_valid(level.grove) and level.grove.source_oaks and sky_response.available()
		if effect in [&"dawn_turf_ambient", &"dawn_turf_color"]:
			slider.editable = slider.editable and sky_response.available() and plants != null and plants.grass_light.active
		if effect in [&"twilight_grass_albedo", &"twilight_ground_ambient", &"turf_ambient_color"]:
			slider.editable = slider.editable and sky_response.twilight_available() and plants != null and plants.grass_light.active
		if effect == &"twilight_shadow_lift":
			slider.editable = slider.editable and phase_finish != null and phase_finish.available() and sky_response.twilight_available()
		if effect == &"twilight_soft_bloom":
			slider.editable = slider.editable and sky_response.twilight_available() and bloom_response.available()
		if effect == &"sculk_surface":
			slider.editable = slider.editable and sculk_surface.available(level)
		if effect in [&"forest_replay_emission", &"forest_replay_bounce"]:
			slider.editable = slider.editable and forest_replay.available(level)
		if effect == &"forest_replay_placement":
			slider.editable = slider.editable and forest_replay.available(level) and forest_replay.has_step_site(level)
		if effect == &"forest_replay_halo":
			slider.editable = slider.editable and forest_replay.available(level) and forest_replay.has_step_site(level)
		if effect == &"forest_replay_surface_bounce":
			slider.editable = slider.editable and forest_replay.surface_available(level)
		if effect == &"canopy_player_cue":
			slider.editable = slider.editable and level.canopy_player_cue.available(level)
		if effect == &"forest_path_placement":
			slider.editable = slider.editable and level.forest_path_light_offset.is_finite() \
				and not level.forest_path_light_offset.is_zero_approx()
		if effect == &"foot_contact":
			slider.editable = slider.editable and player_contact.available()
		if effect == &"projected_sun":
			slider.editable = slider.editable and projected_sun.available()
		if effect == &"projected_sun_position":
			slider.editable = _projected_placement_available()
		if effect == &"projected_sun_softness":
			slider.editable = slider.editable and projected_sun.softness_available()
		if effect == &"regional_sky":
			slider.editable = _regional_sky_editable()
		if effect == &"daylight_bounce":
			slider.editable = _day_bounce_editable()
		if effect in [&"night_stone_blue_softness", &"dawn_stone_sky_color"]:
			slider.editable = slider.editable and sky_response.available() and level.terrain_light.installed
		if effect == &"stone_diffuse_contrast":
			slider.editable = _stone_diffuse_editable()
		if effect == &"stone_detail_softness":
			slider.editable = _stone_detail_editable()
		if effect in [&"night_spatial_sky", &"night_stone_fill_balance", &"night_stone_top_cool"]:
			slider.editable = _night_sky_editable()
		if effect == &"cliff_mist":
			slider.editable = slider.editable and level != null and level.additional_mist_region != null
		if effect == &"night_cliff_mist":
			slider.editable = slider.editable and level != null and level.night_mist_region != null
		if effect in [&"daylight_haze", &"daylight_haze_spill", &"humid_depth"]:
			slider.editable = slider.editable and DepthDiffusion.supported(level.get_viewport())
		var scale := _lighting_scale(effect)
		slider.set_value_no_signal(scale)
		slider.get_meta("readout").text = _mix_readout(effect, scale)
	if changed_effect in [&"", &"world_outline_strength", &"world_outline_width"]:
		sync_world_outline()
		if changed_effect != &"":
			return
	if changed_effect in [&"", &"stone_detail_softness"] and level != null and level.look != null:
		level.look.set_stone_detail_softness(_lighting_scale(&"stone_detail_softness"))
		if changed_effect == &"stone_detail_softness":
			return
	if changed_effect in [&"projected_sun", &"projected_sun_position", &"projected_sun_softness", &"sun_opening"]:
		refresh_daylight_shading()
		return
	if changed_effect == &"diffuse_openings":
		return # Published with the final camera and sun before drawing.
	if changed_effect in [&"night_stone_blue_softness", &"dawn_stone_sky_color"]:
		level.terrain_light.bind()
		return
	if changed_effect in [&"regional_sky", &"daylight_bounce", &"stone_diffuse_contrast", &"night_spatial_sky", &"night_stone_fill_balance", &"night_stone_top_cool"]:
		return # Terrain transport refreshes both receivers together.
	if changed_effect in [&"night_soft_bloom", &"twilight_soft_bloom"] and level != null:
		set_coupled_bloom(coupled_bloom)
	if changed_effect in [&"night_soft_bloom", &"twilight_soft_bloom", &"bloom_diffusion", &"daylight_haze", &"daylight_haze_spill", &"humid_light", &"humid_depth"]:
		if phase_finish != null:
			phase_finish.refresh()
		return
	if changed_effect in [&"", &"tree_wind"] and level != null and level.look != null:
		level.look._publish_crown_wind()
		if changed_effect == &"tree_wind":
			return
	if changed_effect in [&"forest_path_beam", &"lantern_grass_tone"]:
		_publish_point_cutoff()
		return
	if changed_effect in [&"forest_path_air", &"forest_path_air_beam", &"sunlit_mist"]:
		return # The volume reads the live fixture and mix immediately before dispatch.
	if changed_effect == &"foot_contact":
		player_contact.refresh()
		return
	if changed_effect == &"night_glare_control":
		_refresh_lantern_glow()
		_sync_forest_night_lights()
		set_coupled_bloom(coupled_bloom)
		return
	if changed_effect == &"night_path_chroma":
		_publish_night_path_chroma()
		return
	if changed_effect == &"stone_twilight_color":
		_publish_stone_twilight_color()
		return
	if changed_effect in [&"twilight_shadow_color", &"cool_shadow_detail"]:
		if phase_finish != null:
			phase_finish.refresh()
		return
	if changed_effect in [&"forest_accents", &"forest_daylight_accents", &"forest_path_light", &"forest_path_placement", &"sculk_surface", &"forest_replay_emission", &"forest_replay_bounce", &"forest_replay_placement", &"forest_replay_surface_bounce", &"forest_replay_halo"]:
		_sync_forest_night_lights()
		return
	if changed_effect == &"canopy_player_cue":
		level.sync_canopy_player_cue()
		return
	if changed_effect == &"dawn_turf_color":
		_publish_dawn_turf_color()
		return
	if changed_effect in [&"twilight_ground_ambient", &"turf_ambient_color", &"dawn_turf_ambient"]:
		level.terrain_light.bind()
		if plants != null:
			plants.grass_light.sync()
		return
	if changed_effect in [&"twilight_crown", &"crown_ambient_depth"]:
		_sync_twilight_crown()
		return
	if changed_effect in [&"", &"oak_leaf_tint"]:
		_sync_oak_leaf_tint()
		if changed_effect == &"oak_leaf_tint":
			return
	if changed_effect in [&"", &"lantern_glow"]:
		_refresh_lantern_glow()
		if changed_effect == &"lantern_glow":
			return
	if not forest_active():
		return
	if changed_effect == &"shadow_softness":
		level.look.refresh_directional_shadow_blur(level.get_node("Sun"))
		return
	if changed_effect == &"sun_pockets":
		level.look.refresh_daylight_cloud_shape()
		return
	if changed_effect == &"lantern_lift":
		_refresh_lantern_position()
		return
	if changed_effect in [&"near_haze", &"near_haze_depth", &"local_mist", &"cliff_mist", &"night_cliff_mist", &"forest_near_scatter", &"bloom_spread", &"lantern_air", &"night_mist_light", &"night_depth_scatter", &"night_far_air", &"twilight_depth_scatter", &"twilight_far_air", &"twilight_far_air_color", &"twilight_far_optical", &"dawn_mist_source", &"evening_mist_profile"]:
		_update_mist()
		return
	if changed_effect in [&"grass_sky", &"grass_shade_color", &"grass_root_tone", &"grass_night_albedo", &"twilight_grass_albedo", &"grass_shadow_reach", &"spruce_sky", &"tree_shade"]:
		return
	if changed_effect in [&"player_sky", &"player_bounce"]:
		if level.player_light != null:
			level.player_light.refresh()
		return
	if changed_effect in [&"exposure", &"daylight_shadow_lift", &"twilight_shadow_lift", &"grade"]:
		_apply_bounded_exposure_mix()
		if phase_finish != null:
			phase_finish.refresh()
		return
	# Re-evaluate the authored preset before applying scales to prevent compounding.
	_forest_hour = INF
	apply_time()
	level.look._refresh_ground_bounce()
	_update_mist()
	if changed_effect == &"daylight_balance" and phase_finish != null:
		phase_finish.refresh()

func _apply_direct_shadow_opacity(sun:DirectionalLight3D)->void:
	var opacity:=float(_day.sun_shadow_opacity)
	if full_direct_shadows and not is_day_anchor():
		opacity=lerpf(opacity,1.,PHASE_FINISH.phase_weight(hour))
	sun.shadow_opacity=opacity * _lighting_scale(&"shadow")
	_forest_shadow_opacity=sun.shadow_opacity

func terrain_ambient_reference()->Color:
	if forest_active() and atmosphere_review in ["lighting","combined"] and not _forest_expected.is_empty():return _day.ambient_light_color
	return Color(-1,-1,-1)

func forest_spatial_sky_context()->bool:
	return forest_active() and atmosphere_review in ["lighting","combined"] and not _forest_expected.is_empty()

func terrain_ambient_matches(color:Color,source:Color)->bool:
	return terrain_ambient_reference().is_equal_approx(source) and _forest_expected.get("ambient_light_color")==color

func _apply_forest(env:Environment,sun:DirectionalLight3D)->void:
	key_response_active=false
	sunrise_elevation_active = false
	key_direction_active=false
	sky_response_active=false
	var p:=forest.sample(hour)
	if captured_lantern_dawn and point_response.dawn_available() and hour<=float(point_response.dawn_profile.latest_source_hour):
		var source:Dictionary=phase_air.sample(hour)
		if not source.is_empty():
			# Use the captured transition fraction, independent of the user's fog slider.
			p.player_light_weight=point_response.dawn_gain(hour,source.density_ratio,p.player_light_weight)
	if not _balanced_preview and atmosphere_review == "combined":
		p.player_light_weight = point_response.evening_lantern_energy(hour, p.player_light_weight,
			_lighting_scale(&"evening_lantern"), _evening_lantern_bounds)
	if atmosphere_review in ["lighting","combined"]:
		var linear:=env.ambient_light_color.srgb_to_linear();var source:=Vector3(linear.r,linear.g,linear.b)
		var tinted:Vector3=source*p.ambient_tint;var luma:=Vector3(.2126,.7152,.0722)
		tinted*=source.dot(luma)/maxf(tinted.dot(luma),.000001)
		env.ambient_light_color=Color(tinted.x,tinted.y,tinted.z).linear_to_srgb()
		env.ambient_light_energy*=p.ambient_energy_scale
		_apply_captured_sky(env)
		_apply_sky_chroma(env)
		_apply_twilight_sky(env)
		var key:=sun.light_color.srgb_to_linear();var rgb:Vector3=Vector3(key.r,key.g,key.b)*p.key_color_scale
		var peak:=maxf(1.,maxf(rgb.x,maxf(rgb.y,rgb.z)))
		sun.light_color=Color(rgb.x/peak,rgb.y/peak,rgb.z/peak).linear_to_srgb();sun.light_energy*=p.key_scale*peak
		if gentle_noon:sun.light_energy*=noon_direct_scale(hour)
		_apply_captured_key(sun)
		_apply_captured_direction(sun)
		env.ambient_light_energy *= _lighting_scale(&"sky") * _night_sky_fill_multiplier()
		if sky_response_active:
			env.ambient_light_energy *= lerpf(1.0, .75, _lighting_scale(&"twilight_ambient") * twilight_finish_weight())
		_apply_key_mix(sun)
		_apply_sunrise_key(sun)
		_apply_sunrise_elevation(sun)
		# In full shade, block the direct beam and leave ambient fill to its own path.
		_apply_direct_shadow_opacity(sun)
		if _player_light!=null:
			var warm:Vector3=p.player_light_color
			_player_light.light_color=Color(warm.x,warm.y,warm.z);_player_light.light_energy=p.player_light_weight
			_player_light.light_energy *= _lighting_scale(&"lantern")
			_player_light.visible=_player_light.light_energy>0.
	if atmosphere_review in ["haze","combined"]:
		p.fog_opacity *= _lighting_scale(&"fog")
		p.volume_density *= _lighting_scale(&"fog")
		var fog:Vector3=p.fog_color
		env.fog_light_color=Color(fog.x,fog.y,fog.z);env.fog_depth_begin=p.fog_begin;env.fog_depth_end=p.fog_end
		env.fog_light_energy *= _lighting_scale(&"scatter")
		env.fog_depth_curve=.8;env.fog_density=p.fog_opacity
		if spatial_mist and mist!=null and mist.failure().is_empty() and mist.effect.snapshot().ready:env.fog_density=0.
		env.glow_enabled=true;env.glow_intensity=float(_day.glow_intensity)*p.glow_scale * _lighting_scale(&"bloom")
		env.glow_bloom=float(_day.glow_bloom)*p.bloom_scale;env.glow_hdr_threshold=.86
		env.adjustment_contrast=float(_day.adjustment_contrast)*p.contrast_scale
		env.adjustment_saturation*=p.saturation_scale
	if _vignette!=null:
		_vignette.visible=atmosphere_review in ["haze","combined"]
		_vignette.material.set_shader_parameter("strength",p.vignette)
	_forest_expected.clear()
	for field:String in ENV_FIELDS:_forest_expected[field]=env.get(field)
	_forest_sun=sun.light_color;_forest_energy=sun.light_energy;_forest_hour=hour
	_forest_shadow_opacity=sun.shadow_opacity
	_mist_sample=p

func begin_environment_edit()->void:
	if not private_primary or _day.is_empty():return
	if _environment_edit_depth==0:_restore_day()
	_environment_edit_depth+=1

func end_environment_edit()->void:
	if _environment_edit_depth==0:return
	_environment_edit_depth-=1
	if _environment_edit_depth==0 and level.look.stage==2:
		_capture_day();apply_time()

func set_hour(value:float)->void:
	hour=fposmod(value,24.);apply_time()
	if _flat_lab:
		_publish_dawn_turf_color()
		_update_mist()
	elif level!=null:
		level.look._refresh_ground_bounce()

func next_shortcut_hour() -> float:
	for phase: float in TIME_SHORTCUT_HOURS:
		if phase > hour + 0.01:
			return phase
	return TIME_SHORTCUT_HOURS[0]

func _choose_hour(value: float) -> void:
	if not is_equal_approx(hour, value):
		_settings.remember_edit(set_hour.bind(hour))
	set_hour(value)

func _publish_night_path_chroma() -> void:
	if level == null or level.look == null:
		return
	var strength := 0.0
	if forest_active() and atmosphere_review in ["lighting", "combined"]:
		strength = moonlight_weight(hour) * _lighting_scale(&"night_path_chroma")
	level.look.set_night_path_chroma(strength)

func twilight_color_weight() -> float:
	if not forest_active() or atmosphere_review != "combined" or _balanced_preview:
		return 0.0
	var dawn := smoothstep(4.5, 5.5, hour) * (1.0 - smoothstep(5.5, 8.0, hour))
	var dusk := smoothstep(16.5, 19.0, hour) * (1.0 - smoothstep(19.0, 20.75, hour))
	return dawn + dusk

func shadow_color_detail_weight() -> float:
	var twilight := twilight_color_weight() * _lighting_scale(&"twilight_shadow_color")
	var strength := _lighting_scale(&"cool_shadow_detail")
	if strength <= 0.0 or not forest_active() or atmosphere_review != "combined" or _balanced_preview:
		return twilight
	var daylight := 0.70 * _balanced_daylight_weight()
	var night := 0.40 * moonlight_weight(hour)
	var phase_target := PHASE_FINISH.phase_weight(hour) * maxf(daylight, night)
	# Share the existing correction so overlapping time windows cannot stack.
	return lerpf(twilight, maxf(twilight, phase_target), strength)

func _publish_stone_twilight_color() -> void:
	if level != null and level.look != null:
		level.look.set_stone_twilight_color(twilight_color_weight() * _lighting_scale(&"stone_twilight_color"))

func _sync_forest_night_lights() -> void:
	if level == null:
		return
	var phase := 0.0
	var day := 0.0
	var replay_phase := 0.0
	var night_strength := _lighting_scale(&"forest_accents")
	var day_strength := _lighting_scale(&"forest_daylight_accents")
	if forest_active() and unavailable_reason.is_empty() and atmosphere_review == "combined" and level.grove != null and level.grove.spruce_visible():
		phase = moonlight_weight(hour)
		day = PHASE_FINISH.phase_weight(hour) * _balanced_daylight_weight()
		if not _balanced_preview:
			replay_phase = forest_replay.evening_weight(hour)
	if day > 0.0 and day_strength > 0.0:
		forest_accents.update(level, day, day_strength)
	else:
		forest_accents.update(level, phase, night_strength)
	sculk_surface.update(level, maxf(day, phase) if not _balanced_preview else 0., _lighting_scale(&"sculk_surface"))
	forest_replay.update(level, replay_phase, _lighting_scale(&"forest_replay_emission"),
		_lighting_scale(&"forest_replay_placement") == 1., _lighting_scale(&"forest_replay_halo") * lerpf(1.0, .67, _night_glare_weight()))
	if _point_kernel_owner != null and _point_kernel_owner.get_ref() == self:
		forest_replay.publish_bounce(_lighting_scale(&"forest_replay_bounce"))
		forest_replay.publish_surface(level, _lighting_scale(&"forest_replay_surface_bounce"))
	var offset: Vector2 = level.forest_path_light_offset if _lighting_scale(&"forest_path_placement") == 1. else Vector2.ZERO
	if forest_path_light.update(level, phase, _lighting_scale(&"forest_path_light"), offset):
		_publish_point_cutoff()

func sync_world_outline() -> void:
	if level == null or level.look == null:
		return
	var strength := _lighting_scale(&"world_outline_strength")
	if level.look.stage != 2 or _balanced_preview:
		strength = 0.
	level.look.set_terrain_outline(strength, _lighting_scale(&"world_outline_width"))

func apply_time()->void:
	if (not private_primary and not _flat_lab) or level==null or level.look==null:
		sky_response_active=false;key_direction_active=false;return
	refresh_daylight_shading()
	if not _flat_lab:
		_publish_night_path_chroma()
		_publish_stone_twilight_color()
		_sync_twilight_crown()
		_sync_forest_night_lights()
		_publish_dawn_turf_color()
	var env:Environment=level.get_node("WorldEnvironment").environment
	if level.look.stage!=2:
		key_response_active=false
		key_direction_active=false
		sky_response_active=false
		if _time_applied:
			_refresh_lantern_glow()
		_time_applied=false;_forest_expected.clear()
		if _vignette!=null:_vignette.hide()
		if _player_light!=null:_player_light.hide()
		return
	if env!=_environment:_capture_day()
	var use_forest:=forest_active()
	var sun:DirectionalLight3D=level.get_node("Sun")
	level.look.refresh_directional_shadow_blur(sun)
	level.look.refresh_daylight_cloud_shape()
	if use_forest and _forest_hour==hour and not _forest_expected.is_empty() and sun.light_color==_forest_sun and sun.light_energy==_forest_energy and sun.shadow_opacity==_forest_shadow_opacity:
		var unchanged:=true
		for field:String in _forest_expected:
			if env.get(field)!=_forest_expected[field]:unchanged=false;break
		if unchanged:return
	_refresh_lantern_glow()
	if _time_applied:_restore_day()
	if is_day_anchor():
		if use_forest:_apply_forest(env,sun);_time_applied=true
		return
	var p:Dictionary=palette.sample(hour);var noon:Dictionary=palette.sample(12.)
	sun.rotation_degrees=Vector3(_day.sun_rotation)+Vector3(p.pitch-noon.pitch,p.yaw-noon.yaw,0)
	sun.light_color=Color(_day.sun_color)*Color(p.key)/Color(noon.key)
	sun.light_energy=float(_day.sun_energy)*float(p.energy)/float(noon.energy)
	env.ambient_light_color=Color(_day.ambient_light_color)*Color(p.ambient)/Color(noon.ambient)
	env.ambient_light_energy=float(_day.ambient_light_energy)*float(p.ambient_energy)/float(noon.ambient_energy)
	env.background_color=p.sky
	env.tonemap_exposure=float(_day.tonemap_exposure)*float(p.exposure)/float(noon.exposure)
	env.adjustment_saturation=float(_day.adjustment_saturation)*float(p.saturation)/float(noon.saturation)
	env.fog_light_color=p.fog
	env.fog_density=float(_day.fog_density)*float(p.fog_amount)/float(noon.fog_amount)
	if use_forest:_apply_forest(env,sun)
	_time_applied=true

func compare_baseline()->void:
	# Day is restored before changing owners. Time preview is intentionally paused
	# in baseline, and resumes at the chosen hour after restoring the combined look.
	if level.look.stage==2:
		var saved:=hour;hour=12.;apply_time();hour=saved
		level.look.set_stage(0)
	else:
		level.look.set_stage(2);_capture_day();apply_time()

func _compare_from_settings() -> void:
	_settings.remember_edit(_restore_comparison_stage.bind(int(level.look.stage)))
	compare_baseline()

func _restore_comparison_stage(previous: int) -> void:
	if previous == level.look.stage:
		return
	if previous == 2 or level.look.stage == 2:
		compare_baseline()
	if previous != level.look.stage:
		level.look.set_stage(previous)

func _update_shape_control()->void:
	for effect: StringName in [&"daylight_haze", &"daylight_haze_spill", &"humid_depth"]:
		var depth_slider: HSlider = _lighting_sliders.get(effect)
		if depth_slider != null:
			depth_slider.editable = not _balanced_preview and DepthDiffusion.supported(level.get_viewport())
	if _lantern_dawn_toggle!=null:
		_lantern_dawn_toggle.disabled=not point_response.dawn_available() or phase_air.anchors.is_empty() or not forest.available()
		_lantern_dawn_toggle.set_pressed_no_signal(captured_lantern_dawn)
	if _player_source_toggle!=null and level.player_light!=null:
		_player_source_toggle.disabled=not level.player_light.source_field.available()or not captured_sky_response
		_player_source_toggle.set_pressed_no_signal(level.player_light.source_field_enabled)
	if _direction_toggle!=null:
		_direction_toggle.disabled=not direction_response.available()or not forest.available()
		_direction_toggle.set_pressed_no_signal(captured_key_direction)
	if _key_response_toggle!=null:
		_key_response_toggle.disabled=not key_response.available()or not forest.available()
		_key_response_toggle.set_pressed_no_signal(captured_key_response)
	if _soft_source_toggle!=null:
		_soft_source_toggle.disabled=not point_response.soft_available()or not forest.available()or not source_point_cutoff or not noninverse_player_light or not _point_receiver_scope()
		_soft_source_toggle.set_pressed_no_signal(player_soft_source)
	if _point_cutoff_toggle!=null:
		_point_cutoff_toggle.disabled=not point_response.kernel_available()or not forest.available()or not noninverse_player_light or not _point_receiver_scope()
		_point_cutoff_toggle.set_pressed_no_signal(source_point_cutoff)
	if _warm_kernel_toggle!=null:
		_warm_kernel_toggle.disabled=not point_response.kernel_available()or not forest.available()or not noninverse_player_light
		_warm_kernel_toggle.set_pressed_no_signal(source_warm_light)
	if _point_response_toggle!=null:
		_point_response_toggle.disabled=not point_response.available()or not forest.available()
		_point_response_toggle.set_pressed_no_signal(noninverse_player_light)
	if _shape_toggle==null:return
	var effect=level.look._exposure_effect if level!=null and level.look!=null else null
	_shape_toggle.disabled=effect==null or not effect.has_method("multiscale_available")or not effect.multiscale_available()or not level.look.local_exposure_active()
	_shape_toggle.set_pressed_no_signal(source_bloom_shape)

func _regional_sky_editable() -> bool:
	return not _balanced_preview and level != null and level.terrain_light != null and level.terrain_light.regional_sky_available()

func _night_sky_editable() -> bool:
	return not _balanced_preview and level != null and level.terrain_light != null and level.terrain_light.night_sky_available()

func _day_bounce_editable() -> bool:
	return not _balanced_preview and level != null and level.terrain_light != null and level.terrain_light.day_bounce_available()

func _stone_diffuse_editable() -> bool:
	return not _balanced_preview and level != null and level.terrain_light != null and level.terrain_light.stone_diffuse_available()

func _stone_detail_editable() -> bool:
	return not _balanced_preview and _source_terrain_toggle != null and _source_terrain_toggle.button_pressed

func _process(delta:float)->void:
	if _flat_lab:
		_update_mist()
		return
	_update_shape_control()
	if not private_primary or level==null:return
	var regional_slider: HSlider = _lighting_sliders.get(&"regional_sky")
	if regional_slider != null:
		regional_slider.editable = _regional_sky_editable()
	var day_bounce_slider: HSlider = _lighting_sliders.get(&"daylight_bounce")
	if day_bounce_slider != null:
		day_bounce_slider.editable = _day_bounce_editable()
	var stone_diffuse_slider: HSlider = _lighting_sliders.get(&"stone_diffuse_contrast")
	if stone_diffuse_slider != null:
		stone_diffuse_slider.editable = _stone_diffuse_editable()
	var night_editable := _night_sky_editable()
	for effect in [&"night_spatial_sky", &"night_stone_fill_balance", &"night_stone_top_cool"]:
		var slider: HSlider = _lighting_sliders.get(effect)
		if slider != null:
			slider.editable = night_editable
	_fps_elapsed+=delta
	if _fps_label!=null and _fps_elapsed>=.5:
		_fps_elapsed=0.
		_fps_label.text="FPS: %d"%Engine.get_frames_per_second()
	_elapsed+=delta
	if cycle_enabled and level.look.stage==2:hour=fposmod(hour+delta*.08,24.)
	apply_time()
	_update_mist()
	_sync_oak_leaf_tint()
	if _hint!=null and unavailable_reason.is_empty():_hint.visible=_elapsed<12. and not panel.visible
	if status!=null and panel.visible:
		_settings.update_phase(hour < 6. or hour >= 20.)
		_atmosphere_picker.select(["previous","haze","lighting","combined"].find(atmosphere_review))
		_legacy_sky_button.set_pressed_no_signal(level.terrain_sky.enabled)
		_terrain_light_note.text="Local field: %s · original GAF transport\nSky RGB retint; sun transport stays Day-guarded."%("active" if level.terrain_light!=null and level.terrain_light.is_active() else "suspended / off")
		var profile_scope:="nine captured phases" if level.look.player_phase_material_enabled and level.look.player_material.phase_verified else "Day-only comparison"
		_player_material_note.text="Same scene light / pose. Material: %s.\nB suspends adapter; F3 also gates direct clouds."%(profile_scope if level.look.player_effects_available() else "suspended outside verified scope")
		_cycle_button.set_pressed_no_signal(cycle_enabled)
		_exposure_button.set_pressed_no_signal(level.look.local_exposure_active())
		var msaa:String=["Off","2×","4×","8×"][level.get_viewport().msaa_3d]
		status.text="%s · %02d:%02d · %s · %d FPS · %s · MSAA %s"%["Tổng hợp" if level.look.stage==2 else "Bản gốc",int(hour),int(fmod(hour,1.)*60.),"Tự chuyển" if cycle_enabled else "Cố định",Engine.get_frames_per_second(),RenderingServer.get_current_rendering_method(),msaa]

static func _mix_readout(effect: StringName, value: float) -> String:
	if effect == &"world_outline_width":
		return "%d px" % roundi(value)
	if effect == &"forest_path_placement":
		return "Lệch lối" if value == 1. else "Gốc"
	if effect == &"forest_replay_placement":
		return "Bậc đá" if value == 1. else "Lối rừng"
	return "%d%%" % roundi(value * 100.)

func _build_lighting_mix(box: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "Lighting mix"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var preset := OptionButton.new()
	preset.name = "LightingMixPreset"
	preset.focus_mode = Control.FOCUS_NONE
	preset.tooltip_text = "Choose which local preset to save or load."
	for slot in range(1, 5):
		preset.add_item("Preset %d" % slot, slot)
	preset.select(0)
	header.add_child(preset)
	var preset_path := func() -> String:
		var slot := preset.get_selected_id()
		return LIGHTING_MIX_PATH if slot == 1 else "user://world_map_lighting_mix_%d.cfg" % slot
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var save := Button.new()
	_save_mix_button = save
	save.name = "LightingMixSave"
	save.text = "Save mix"
	save.tooltip_text = "Save your current slider values to the selected preset."
	save.focus_mode = Control.FOCUS_NONE
	actions.add_child(save)
	var load_button := Button.new()
	load_button.name = "LightingMixLoad"
	load_button.text = "Load mix"
	load_button.tooltip_text = "Apply the selected preset's slider values to the current time."
	load_button.focus_mode = Control.FOCUS_NONE
	actions.add_child(load_button)
	var reset := Button.new()
	reset.text = "Reset mix"
	reset.tooltip_text = "Reset the live slider values without changing saved presets."
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func():
		var before := _mix_snapshot()
		reset_lighting_mix()
		_remember_mix_edit(before))
	actions.add_child(reset)
	var message := Label.new()
	message.name = "SettingsPresetMessage"
	message.hide()
	box.add_child(message)
	var scene_mix: SceneLightingMix = level.scene_lighting_mix
	if scene_mix != null and not scene_mix.strengths.is_empty():
		_scene_mix_button = _make_scene_mix_button(scene_mix, message)
		_scene_mix_button.name = "SceneLightingMix"
		actions.add_sibling(_scene_mix_button)
	for preset_index: int in level.additional_lighting_mixes.size():
		var extra: SceneLightingMix = level.additional_lighting_mixes[preset_index]
		if extra == null or extra.strengths.is_empty():
			continue
		var button := _make_scene_mix_button(extra, message)
		button.set_meta("settings_item_id", "apply-map-mix-%d" % preset_index)
		button.set_meta("settings_item_copy", [extra.display_name, extra.display_name,
			extra.description if not extra.description.is_empty() else "Áp dụng công thức ánh sáng của bản đồ.",
			extra.review_tip if not extra.review_tip.is_empty() else "Dùng Hoàn tác để khôi phục công thức trước."])
		_additional_mix_buttons.append(button)
		box.add_child(button)
	preset.item_selected.connect(func(_index: int): message.hide())
	save.pressed.connect(func():
		var error := save_lighting_mix(preset_path.call())
		message.text = "Preset %d saved on this device." % preset.get_selected_id() if error == OK else "Could not save mix: " + error_string(error)
		message.show())
	load_button.pressed.connect(func():
		var before := _mix_snapshot()
		var error := load_lighting_mix(preset_path.call())
		if error == OK:
			_remember_mix_edit(before)
			message.text = "Preset %d applied." % preset.get_selected_id()
		elif error == ERR_FILE_NOT_FOUND:
			message.text = "Preset %d is empty." % preset.get_selected_id()
		else:
			message.text = "Could not load mix: " + error_string(error)
		message.show())
	for effect: StringName in LIGHTING_MIX_CONTROLS:
		var spec: Array = LIGHTING_MIX_CONTROLS[effect]
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.text = spec[0]
		label.custom_minimum_size.x = 130
		row.add_child(label)
		var slider := HSlider.new()
		slider.accessibility_name = label.text
		slider.tooltip_text = "100% uses the current time preset. Original graphics (B) ignores this mix."
		if effect == &"canopy_player_cue":
			slider.editable = level.canopy_player_cue.available(level)
		if effect == &"crown_ambient_depth":
			slider.editable = is_instance_valid(level.grove) and level.grove.source_oaks and sky_response.available()
		if effect == &"exposure":
			slider.tooltip_text = "Scales local contrast gain. The color grade remains active."
		if effect == &"daylight_shadow_lift":
			slider.tooltip_text = "Try 75% at 07:00 or 16:30 to deepen shaded areas. 100% restores the current look. Requires the humid Forest finish and local exposure."
		if effect == &"moon":
			slider.tooltip_text = "Scales the cool directional night light. Hip lantern, ambient sky, and daytime sunlight are independent."
		if effect == &"grade":
			slider.tooltip_text = "Blend the captured-reference finish with the original palette and tone curve. Local exposure stays active."
		if effect == &"sky_chroma":
			slider.tooltip_text = "Reduce the color of ambient sky light at fixed luminance. Noon uses its approved sky color."
		if effect == &"dawn_sky_transition":
			slider.editable = sky_response.available()
			slider.tooltip_text = "Thử 35% lúc 02:30 để ánh sáng hắt chuyển dần sang rạng sáng. 0% dùng cấu hình gốc."
		if effect == &"dawn_mist_source":
			slider.editable = not phase_air.anchors.is_empty()
			slider.tooltip_text = "Thử 65% lúc 02:30 để xem ánh sáng trong lớp sương xa. 0% dùng cấu hình gốc."
		if effect == &"daylight_balance":
			slider.tooltip_text = "Reduce the blue cast of daytime shadows in Combined mode. 0% restores the previous balance. Noon and night keep their own look."
		if effect == &"player_sky":
			slider.tooltip_text = "Scale sky fill on the player outside noon. Terrain, direct lights, and the fog keep their own settings."
		if effect == &"player_bounce":
			slider.tooltip_text = "Try at 07:00 or 16:30 in the forest. Adds the terrain's sun bounce to the player and Sabre. Requires the verified private forest field. Noon and night keep their approved lighting."
		if effect == &"grass_sky":
			slider.tooltip_text = "Blend the existing grass ambient light with the terrain's baked sky fill at each root. The approved Noon is retained."
		if effect == &"grass_root_tone":
			slider.tooltip_text = "Blend the lower blades towards the nearby terrain hue at night. Leaves the existing grass lighting and shadows active."
		if effect == &"grass_night_albedo":
			slider.tooltip_text = "Thử 55% ở lối rừng ban đêm. 0% dùng màu lá hiện tại."
		if effect == &"grass_shade_color":
			slider.tooltip_text = "Cool the baked sky light on grass beneath the forest canopy. Uses Grass sky fill in Combined mode. Noon and night keep their current lighting."
		if effect == &"diffuse_openings":
			slider.tooltip_text = "Try 100% at 07:00 or 16:30. Adds diffuse fill to grass and terrain in openings. Requires Combined lighting and the local terrain field."
		if effect == &"regional_sky":
			slider.tooltip_text = "Try 40% at the northwest cliff at 07:00 in Combined mode. Lifts diffuse skylight on terrain and nearby grass. 0% restores the original lighting."
		if effect == &"night_spatial_sky":
			slider.tooltip_text = "Try 65% at 22:00 at the northwest cliff. Replaces some sky fill with local bounce on terrain and grass. Requires the private source atlas."
		if effect == &"night_stone_fill_balance":
			slider.tooltip_text = "Mặc định 48%. Thử 0% ở 22:00 để so màu đá tại cùng góc."
		if effect == &"grass_shadow_reach":
			slider.tooltip_text = "Correct the length of grass shadows at dawn and dusk for the captured sun elevation. 0% uses the previous length."
		if effect == &"stone_twilight_color":
			slider.tooltip_text = "Reduce the baked blue tint of stone at dawn and dusk in Combined mode. The source atlas preview uses its own colors."
		if effect == &"twilight_shadow_color":
			slider.tooltip_text = "Recover color in deep blue shadows at dawn and dusk while keeping their brightness. Requires the reference finish in Combined mode."
		if effect == &"spruce_sky":
			slider.tooltip_text = "Reduce sky fill under the private spruce on terrain, grass, and the player. Zero restores the prior fill. Noon fades to zero."
		if effect == &"tree_shade":
			slider.tooltip_text = "Use Forest canopy sky on the trees in daylight. The trunks pick up more shade than the leaves. 0% compares the previous lighting."
		if effect == &"near_haze":
			slider.tooltip_text = "0% disables the near layer. 100% uses the reference-fitted strength. Fog density is the master scale."
		if effect == &"near_haze_depth":
			slider.tooltip_text = "Extend the near haze into the middle distance. 0% restores the previous taper. Requires Near haze density above 0%."
		if effect == &"local_mist":
			slider.tooltip_text = "Scales the map's local fog volume in morning and afternoon. 0% uses the existing mist."
		if effect == &"cliff_mist":
			slider.editable = level.additional_mist_region != null
			slider.tooltip_text = "Adds a thin mist layer across the northwest cliff in daylight. Try 100% at 07:00 or 16:30 in Combined mode."
		if effect == &"night_cliff_mist":
			slider.editable = level.night_mist_region != null
			slider.tooltip_text = "Adds a thin layer of cool air around the northwest cliff at night. Try 65–100% at 22:00 in Combined mode."
		if effect == &"forest_near_scatter":
			slider.tooltip_text = "Add depth between trees by lifting light in the existing near mist. 0% restores the prior light. Requires Combined mode and Near haze density above 0%."
		if effect == &"sunlit_mist":
			slider.editable = directional_air.available()
			slider.tooltip_text = "Try 24% in the forest at 16:30. Scatters sunlight through canopy gaps; fades to zero at noon and night." if slider.editable else "Requires the verified private canopy field and the Mobile renderer."
		if effect == &"foot_contact":
			slider.editable = player_contact.available()
			slider.tooltip_text = "Soft indirect-light contact beneath each boot. Try 75% in the forest. Zero compares the prior look. Noon keeps its approved lighting."
		if effect == &"forest_path_beam":
			slider.tooltip_text = "Aim the fixed forest light downward across the path using the captured angular falloff. Set 0% to compare the previous beam."
		if effect == &"forest_path_air":
			slider.tooltip_text = "Warm the existing mist near the fixed forest lamp. Set 0% for the prior look. Requires Combined mode and Forest path light."
		if effect == &"night_mist_light":
			slider.tooltip_text = "Lift cool scattered light at night in Combined mode. 0% restores the old color intensity. Fog density and the warm lantern are separate."
		if effect == &"forest_accents":
			slider.tooltip_text = "Adjust the private blue mushroom accents along the forest path at night. 0% hides them. The player lantern stays independent."
		if effect == &"forest_daylight_accents":
			slider.tooltip_text = "Adjust the blue mushrooms along the forest path in morning and afternoon. Noon and the night mix keep their own settings."
		if effect == &"forest_path_light":
			slider.tooltip_text = "Adjust the fixed warm light beside the forest path. 0% hides the fixture and its light. Works at night in Combined mode."
		if effect == &"shadow_softness":
			slider.tooltip_text = "Adjust the F1 sunlight filter radius in the morning and afternoon. 100% uses the previous radius. Noon and night keep their existing filter."
		if effect == &"sun_pockets":
			slider.tooltip_text = "Deepen the existing F3 daylight shade on terrain, grass and the player. 0% restores the previous light pattern. Noon and night keep their current lighting."
		if effect == &"sun_opening":
			slider.tooltip_text = "Lift sunlit openings on the ground, grass and player at dawn and in the afternoon. 0% restores the previous response. Requires F3 direct shading."
		if effect == &"projected_sun":
			slider.editable = projected_sun.available()
			slider.tooltip_text = "Try 65% at 07:00 or 16:30. The private Forest projection shapes the sunlight between shadows. Requires F3 direct cloud shading and the verified private reference."
		if effect == &"lantern_lift":
			slider.tooltip_text = "Height above the hip mount when lantern from above is enabled. 100% uses the captured face-to-light distance fit, 66% approximates the previous height."
		if effect == &"lantern_air":
			slider.tooltip_text = "Scales only lantern light scattered by the existing mist. Surface lighting and fog density have separate controls."
		if effect == &"lantern_glow":
			slider.tooltip_text = "Adjusts the glowing lantern glass on Mobile. Around 6% matches its previous brightness. The point light and mist keep their own strengths."
		if effect == &"bloom_spread":
			slider.tooltip_text = "Adjust the base glow radius independently of Bloom brightness. Leaves the approved noon look intact."
		if effect == &"daylight_haze":
			slider.editable = DepthDiffusion.supported(level.get_viewport())
			slider.tooltip_text = "Soften the distant lit mist in the morning and afternoon. 0% restores the prior finish. Requires Mobile Vulkan or D3D12 with sampleable 2× MSAA depth."
		if effect == &"daylight_haze_spill":
			slider.editable = DepthDiffusion.supported(level.get_viewport())
			slider.tooltip_text = "Blend from the earlier daylight haze to light spilling from bright areas into nearby shade. Requires Daylight haze softness."
		if effect == &"humid_light":
			slider.tooltip_text = "Soften lit areas into the surrounding haze. Try 65% at 16:30. Requires Combined mist and the Mobile Forest finish. Noon keeps its approved look."
		if effect == &"humid_depth":
			slider.editable = DepthDiffusion.supported(level.get_viewport())
			slider.tooltip_text = "At 100%, move Humid light diffusion from near surfaces to the distant mist. Try Humid light diffusion at 65% and time 16:30. Requires Mobile Vulkan or D3D12 with sampleable 2× MSAA depth."
		if effect == &"tree_wind":
			slider.tooltip_text = "Adjust sway for the source oaks and spruces. 100% is the previous response, 125% is the new default. Alt+N toggles sway."
		if effect == &"night_path_chroma":
			slider.tooltip_text = "Soften warm dirt color at night using the Forest reference. 0% restores the original path color. Daylight and the source atlas preview keep their own color."
		slider.focus_mode = Control.FOCUS_NONE
		slider.max_value = spec[1]
		slider.step = .01
		if effect == &"world_outline_width":
			slider.min_value = 1.
			slider.step = 1.
		if effect in [&"forest_path_placement", &"forest_replay_placement"]:
			slider.step = 1.
		slider.value = _lighting_scale(effect)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var readout := Label.new()
		readout.custom_minimum_size.x = 48
		readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		readout.text = _mix_readout(effect, slider.value)
		row.add_child(readout)
		slider.set_meta("readout", readout)
		_lighting_sliders[effect] = slider
		slider.value_changed.connect(func(value: float): set_lighting_scale(effect, value))
		slider.drag_started.connect(_begin_mix_drag)
		slider.drag_ended.connect(_end_mix_drag)

func _make_scene_mix_button(mix: SceneLightingMix, message: Label) -> Button:
	var button := Button.new()
	button.text = "Apply " + mix.display_name
	button.tooltip_text = "Áp dụng công thức cho các thanh trượt đang dùng."
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func():
		var before := _mix_snapshot()
		var applied := apply_scene_lighting_mix(mix)
		if applied:
			_remember_mix_edit(before)
		message.text = ("Đã áp dụng " if applied else "Chưa áp dụng được ") + mix.display_name
		message.show())
	return button

func _build_basic_settings() -> void:
	var hud: CanvasLayer = level.get_node("HUD")
	panel = PanelContainer.new()
	panel.name = "ShowcaseOptions"
	hud.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var help := Label.new()
	help.name = "SettingsKeysHelp"
	help.text = level.get_node("HUD/Help").text + "\nL ẩn / hiện HUD"
	box.add_child(help)
	_settings.setup(hud, panel, box, {}, null, false)
	level.get_node("HUD/Help").hide()

func _build_ui()->void:
	var hud:=level.get_node("HUD")
	_fps_label=Label.new();_fps_label.name="ShowcaseFPS";_fps_label.position=Vector2(18,6)
	_fps_label.text="FPS: %d"%Engine.get_frames_per_second();_fps_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_font_size_override("font_size",18)
	_fps_label.add_theme_color_override("font_color",Color.WHITE)
	_fps_label.add_theme_color_override("font_outline_color",Color(0,0,0,.85))
	_fps_label.add_theme_constant_override("outline_size",4);hud.add_child(_fps_label)
	panel=PanelContainer.new();panel.name="ShowcaseOptions";hud.add_child(panel)
	var box:=VBoxContainer.new();panel.add_child(box)
	status=Label.new();box.add_child(status)
	var controls:=Label.new();controls.name="SettingsKeysHelp"
	controls.text="WASD di chuyển · Shift đi chậm · Space nhảy\nChuột trái / E đánh combo · Trên không: đánh xuống\nChuột phải ngắm / đi ngang · Q / C xoay · R về điểm đầu\nLăn chuột thu phóng · V xem toàn bản đồ\nL ẩn / hiện HUD · B so sánh đồ họa gốc\nT chuyển thời điểm · Shift+T tự chuyển ngày / đêm\nF1 bóng mềm · F2 bóng tiếp xúc · F3 bóng mây\nF7 exposure cục bộ · F8 màu ban ngày · F9 mép lá\nF10 nội suy · F11 ánh sáng môi trường · F12 cache địa hình"
	box.add_child(controls)
	var atmosphere:=OptionButton.new();atmosphere.name="AtmosphereComparison";atmosphere.focus_mode=Control.FOCUS_NONE
	_atmosphere_picker=atmosphere
	for label:String in ["Previous atmosphere","Forest entrance · haze / bloom only","Forest entrance · lighting only","Forest entrance · combined"]:atmosphere.add_item(label)
	var modes=["previous","haze","lighting","combined"];atmosphere.select(modes.find(atmosphere_review));box.add_child(atmosphere)
	atmosphere.item_selected.connect(func(index:int):set_atmosphere_review(modes[index]))
	atmosphere.tooltip_text="Forest A1 Day: read live in MD2. Other phases: recovered presets. Fog, bloom and light transfer are original Mobile approximations."
	_build_lighting_mix(box)
	var balanced := CheckButton.new()
	_balanced_toggle = balanced
	balanced.name = "BalancedAtmospherePreview"
	balanced.text = "Balanced atmosphere (preview)"
	balanced.tooltip_text = "Compare near haze, cooler shaded surfaces and softer F1 shadow edges during the day. Turn off to restore your mix."
	balanced.focus_mode = Control.FOCUS_NONE
	balanced.toggled.connect(set_balanced_atmosphere_preview)
	box.add_child(balanced)
	var near_haze := CheckButton.new()
	_near_haze_toggle = near_haze
	near_haze.name = "NearHazePreview"
	near_haze.text = "Air · near haze"
	near_haze.focus_mode = Control.FOCUS_NONE
	near_haze.button_pressed = near_haze_enabled
	near_haze.tooltip_text = "A light layer behind the player before the distant fog. Compare outside noon in Combined or Haze mode."
	near_haze.toggled.connect(func(enabled: bool):
		near_haze_enabled = enabled
	)
	box.add_child(near_haze)
	var grove_mist := CheckButton.new()
	_grove_mist_toggle = grove_mist
	grove_mist.text = "Air · shared grove mist"
	grove_mist.focus_mode = Control.FOCUS_NONE
	grove_mist.button_pressed = grove_mist_enabled
	grove_mist.tooltip_text = "Apply the existing spatial mist to tree bark and crowns when the grove is visible. Fades out at Noon. Turn off to compare."
	grove_mist.toggled.connect(set_grove_mist)
	box.add_child(grove_mist)
	if level.grove != null and level.grove.spruce_available():
		var spruce := CheckButton.new()
		spruce.name = "ForestSpruce"
		spruce.text = "Forest · MD2 tall spruce (Ctrl+G)"
		spruce.focus_mode = Control.FOCUS_NONE
		spruce.button_pressed = level.grove.spruce_visible()
		spruce.toggled.connect(set_forest_spruce_visible)
		box.add_child(spruce)
		_spruce_toggle = spruce
		var shadows := CheckButton.new()
		shadows.name = "ForestSpruceShadows"
		var cover := CheckButton.new()
		cover.text = "Forest · softer player reveal"
		cover.tooltip_text = "Softer edges where trees hide the player. Uses Mobile D3D12 with 2× MSAA."
		cover.focus_mode = Control.FOCUS_NONE
		cover.button_pressed = level.look.grove_reveal_coverage_requested
		cover.toggled.connect(level.look.set_grove_reveal_coverage)
		box.add_child(cover)
		shadows.text = "Forest · spruce shadows"
		shadows.focus_mode = Control.FOCUS_NONE
		shadows.button_pressed = level.grove.spruce_shadows
		shadows.toggled.connect(level.grove.set_spruce_shadows)
		box.add_child(shadows)
	var terrain_atlas := CheckButton.new()
	_source_terrain_toggle = terrain_atlas
	terrain_atlas.text = "Terrain · MD2 atlas"
	terrain_atlas.focus_mode = Control.FOCUS_NONE
	terrain_atlas.tooltip_text = "Use MD2 surface tiles from the private research workspace. Turn this off to compare the previous tiles. B compares the full original graphics."
	terrain_atlas.toggled.connect(set_source_terrain)
	box.add_child(terrain_atlas)
	var gentle:=CheckButton.new();gentle.name="GentleNoon";gentle.text="Light · gentle midday sunlight";gentle.button_pressed=gentle_noon;gentle.focus_mode=Control.FOCUS_NONE;box.add_child(gentle)
	gentle.tooltip_text="18% less direct sunlight at noon, smoothly returning to the previous morning/evening lighting. Ambient and source presets unchanged. OFF compares the previous result."
	gentle.toggled.connect(set_gentle_noon)
	var point_mode:=CheckButton.new();point_mode.name="NoninversePlayerLight";point_mode.text="Light - recovered non-inverse player falloff";point_mode.focus_mode=Control.FOCUS_NONE;point_mode.button_pressed=noninverse_player_light;point_mode.disabled=not point_response.available()or not forest.available();box.add_child(point_mode)
	point_mode.tooltip_text="Native point light has inverse-square falloff OFF. Removes Godot distance^-2 while retaining its range cutoff and existing phase intensity. Not exact native radial cutoff or photometry. OFF restores previous falloff."
	point_mode.toggled.connect(set_noninverse_player_light);_point_response_toggle=point_mode
	var dawn:=CheckButton.new()
	dawn.name="CapturedLanternDawn"
	dawn.text="Light · captured lantern fade at dawn"
	dawn.focus_mode=Control.FOCUS_NONE
	dawn.button_pressed=captured_lantern_dawn
	dawn.tooltip_text="Matches the relative lantern strength in the captured dawn transition. Uses the existing Godot time mapping. Turn off to compare the previous curve."
	dawn.toggled.connect(set_captured_lantern_dawn)
	box.add_child(dawn)
	_lantern_dawn_toggle=dawn
	var overhead := CheckButton.new()
	overhead.name = "LanternOverhead"
	overhead.text = "Light · lantern from above"
	overhead.button_pressed = lantern_overhead
	overhead.focus_mode = Control.FOCUS_NONE
	overhead.tooltip_text = "Raise the light source above the visible hip lantern. Turn off to compare hip-level lighting."
	overhead.toggled.connect(set_lantern_overhead)
	box.add_child(overhead)
	_lantern_overhead_toggle = overhead
	var cutoff:=CheckButton.new();cutoff.name="SourcePointCutoff";cutoff.text="Light - recovered point radial cutoff";cutoff.focus_mode=Control.FOCUS_NONE;cutoff.button_pressed=source_point_cutoff;cutoff.disabled=not point_response.kernel_available()or not forest.available();box.add_child(cutoff)
	cutoff.tooltip_text="Captured8m/power2 squared-radius kernel. Original algebraic correction of Godot's range window for the owned local light; energy/materials unchanged. OFF restores prior non-inverse quartic response. Not full native radiometry or soft source."
	cutoff.toggled.connect(set_source_point_cutoff);_point_cutoff_toggle=cutoff
	var soft:=CheckButton.new();soft.name="PlayerSoftSource";soft.text="Player - finite-source specular (comparison)";soft.focus_mode=Control.FOCUS_NONE;soft.button_pressed=player_soft_source;soft.disabled=not point_response.soft_available();box.add_child(soft)
	soft.tooltip_text="Source-backed point specular broadening only. Does not change diffuse, sunlight, ambient or fog. Full native SSS/radiometry remains unverified."
	soft.toggled.connect(set_player_soft_source);_soft_source_toggle=soft
	var key:=CheckButton.new();key.name="CapturedKeyResponse";key.text="Light - captured direct-key phase response";key.focus_mode=Control.FOCUS_NONE;key.button_pressed=captured_key_response;key.disabled=not key_response.available();box.add_child(key)
	key.tooltip_text="Captured relative direct-light RGB, anchored to the approved Noon. Clock placement/mirrored evening are original. No native lux, sun trajectory or indirect-light claim. OFF restores prior palette."
	key.toggled.connect(set_captured_key_response);_key_response_toggle=key
	var moon:=CheckButton.new()
	moon.name="NightMoonlight"
	moon.text="Light · moonlight at night"
	moon.button_pressed=moonlight_enabled
	moon.focus_mode=Control.FOCUS_NONE
	moon.tooltip_text="Fade sunlight to a cool night key. Turn off to compare the previous evening lighting."
	moon.toggled.connect(set_moonlight_enabled)
	box.add_child(moon)
	var night_air := CheckButton.new()
	night_air.name = "NightReferenceAtmosphere"
	night_air.text = "Air · captured night atmosphere"
	night_air.focus_mode = Control.FOCUS_NONE
	night_air.button_pressed = night_reference_atmosphere
	night_air.disabled = phase_air.anchors.is_empty() or not sky_response.available()
	night_air.tooltip_text = "Use the captured midnight sky, fog, bloom and grade together when the moon phase is fully active."
	night_air.toggled.connect(set_night_reference_atmosphere)
	box.add_child(night_air)
	_night_reference_toggle = night_air
	var direction:=CheckButton.new();direction.name="CapturedKeyDirection";direction.text="Light - captured primary direction (Noon anchored)";direction.focus_mode=Control.FOCUS_NONE;direction.button_pressed=captured_key_direction;direction.disabled=not direction_response.available();box.add_child(direction)
	direction.tooltip_text="Measured primary-light azimuth and relative ground NdotL, anchored to approved Noon. Night uses the primary CB, not fog Sun. Clock, handoff interpolation and Noon normalization are original. OFF restores prior trajectory."
	direction.toggled.connect(set_captured_key_direction);_direction_toggle=direction
	var shadow:=CheckButton.new()
	shadow.name="FullDirectShadows"
	shadow.text="Light - full direct shadows"
	shadow.focus_mode=Control.FOCUS_NONE
	shadow.button_pressed=full_direct_shadows
	shadow.disabled=not forest.available()
	shadow.tooltip_text="Fully blocks direct sunlight in deep shadow outside the Noon blend. Turn off to compare the previous shadow strength."
	box.add_child(shadow)
	shadow.toggled.connect(set_full_direct_shadows)
	var sky_source:=CheckButton.new();sky_source.name="CapturedSkyResponse";sky_source.text="Light - captured sky phase response";sky_source.focus_mode=Control.FOCUS_NONE;sky_source.button_pressed=captured_sky_response;sky_source.disabled=not sky_response.available();box.add_child(sky_source)
	sky_source.tooltip_text="Relative directional-environment angular mean from existing captures, anchored to approved Noon. Retains original spatial visibility; not full Lumen, native hours or absolute irradiance. OFF restores prior ambient palette."
	sky_source.toggled.connect(set_captured_sky_response)
	# Player transport is installed after showcase.setup; enable on its first refresh.
	var actor_source:=CheckButton.new();actor_source.name="ActorSourceField";actor_source.text="Player - spatial sky phase field (experimental)";actor_source.focus_mode=Control.FOCUS_NONE;actor_source.disabled=true;box.add_child(actor_source)
	actor_source.tooltip_text="Original geometry-filtered captured sky response on the existing voxel/reserve model. Noon unchanged; clock and visibility remain approximations. First activation reads 6.4 MB of private CPU data; no extra GPU pass. OFF restores previous actor lighting."
	actor_source.toggled.connect(func(value):level.player_light.set_source_field(value);_update_shape_control());_player_source_toggle=actor_source
	var fog_source:=CheckButton.new();fog_source.name="CapturedMistSource";fog_source.text="Air - captured fog-source phase response";fog_source.focus_mode=Control.FOCUS_NONE;fog_source.button_pressed=captured_mist_source;fog_source.disabled=phase_air.anchors.is_empty();box.add_child(fog_source)
	fog_source.tooltip_text="Relative measured fog-source RGB anchored to approved Noon. Density, local lamp and spatial transport unchanged. Native hours/absolute radiometry not recovered. OFF restores previous incident-light amplitude."
	fog_source.toggled.connect(set_captured_mist_source)
	var warm_kernel:=CheckButton.new();warm_kernel.name="SourceWarmLight";warm_kernel.text="Air - local-light radial source (experimental)";warm_kernel.focus_mode=Control.FOCUS_NONE;warm_kernel.button_pressed=source_warm_light;warm_kernel.disabled=not point_response.kernel_available()or not forest.available();box.add_child(warm_kernel)
	warm_kernel.tooltip_text="Verified point-light squared-radius kernel transferred into our original Mobile mist. Only warm incoming light changes; extinction/noise/amplitude unchanged. Native full volumetric transport remains approximate. OFF restores prior linear-radius source."
	warm_kernel.toggled.connect(set_source_warm_light);_warm_kernel_toggle=warm_kernel
	var volume:=CheckButton.new();volume.text="Spatial mist · world height / patches";volume.button_pressed=spatial_mist;volume.focus_mode=Control.FOCUS_NONE;box.add_child(volume)
	volume.toggled.connect(set_spatial_mist)
	var measured:=CheckButton.new();measured.text="Air · measured night / dawn / day";measured.button_pressed=measured_atmosphere;measured.focus_mode=Control.FOCUS_NONE;box.add_child(measured);measured.toggled.connect(set_measured_atmosphere)
	var bloom_air:=CheckButton.new();bloom_air.text="Air · exposure-shaped soft light";bloom_air.button_pressed=coupled_bloom;bloom_air.focus_mode=Control.FOCUS_NONE;box.add_child(bloom_air);bloom_air.toggled.connect(set_coupled_bloom)
	var response:=CheckButton.new();response.name="MeasuredBloomResponse";response.text="Air - measured bloom response (all phases)";response.button_pressed=measured_bloom_response;response.disabled=not bloom_response.available();response.focus_mode=Control.FOCUS_NONE;box.add_child(response)
	response.tooltip_text="Relative bloom gain from nine captured Forest pipelines. Preserves approved Noon gain and existing shape; original clock placement and mirrored evening. Not native radiometry or the full six-scale kernel. OFF restores previous fixed response."
	response.toggled.connect(set_measured_bloom_response)
	var shape:=CheckButton.new();shape.name="SourceBloomShape";shape.text="Air - six-scale spread (experimental)";shape.focus_mode=Control.FOCUS_NONE;shape.button_pressed=source_bloom_shape;box.add_child(shape)
	shape.tooltip_text="Private captured numeric kernels in an original six-level pyramid. Energy normalized; source-relative intensity is separate. Original viewport mapping and phase fade preserve Noon. Higher pass/bandwidth cost; OFF pending validation."
	shape.toggled.connect(set_source_bloom_shape);_shape_toggle=shape;_update_shape_control()
	var source_order:=CheckButton.new();source_order.name="BloomSourceOrder";source_order.text="Air - raw downsample before exposure (experimental)";source_order.focus_mode=Control.FOCUS_NONE;source_order.button_pressed=phase_finish.source_order;box.add_child(source_order)
	source_order.tooltip_text="Original source-order reconstruction with existing exposure statistics. Same intensity; preserved Noon. Mutually exclusive with six-scale spread. Quarter-resolution/phase blend remain approximations."
	source_order.toggled.connect(phase_finish.set_source_order);phase_finish.source_order_toggle=source_order
	var coherent_toggle:=CheckButton.new();coherent_toggle.text="Air · consistent scene / bloom exposure";coherent_toggle.button_pressed=coherent_bloom;coherent_toggle.focus_mode=Control.FOCUS_NONE;coherent_toggle.tooltip_text="Use the same bounded exposure gain for scene and bloom source, before filtering. OFF restores previous source equation. Original Mobile formula, not full native Unreal local exposure.";box.add_child(coherent_toggle);coherent_toggle.toggled.connect(set_coherent_bloom)
	var grade_toggle:=CheckButton.new();grade_toggle.text="Air · private Forest phase LUTs (experimental)";grade_toggle.focus_mode=Control.FOCUS_NONE;grade_toggle.button_pressed=false;grade_toggle.disabled=not grade_review.available();grade_toggle.tooltip_text="Eight captured Forest LUTs at unity input gain; original clock interpolation/mirrored evening. Replaces final grade, not lighting. HDR/F7 only; OFF by default. Native radiometry/clock unresolved.";box.add_child(grade_toggle);grade_toggle.toggled.connect(set_source_grade)
	var finish_toggle:=CheckButton.new();finish_toggle.name="PhaseFinish";finish_toggle.text="Air · humid Forest finishing (Noon preserved)";finish_toggle.button_pressed=phase_finish.requested;finish_toggle.disabled=not phase_finish.available();finish_toggle.focus_mode=Control.FOCUS_NONE;box.add_child(finish_toggle)
	finish_toggle.tooltip_text="Original phase bridge: recovered-shaped exposure and private grading, smoothly returning to the approved Noon. Rendering units/clock are original mappings; phone cost unverified. OFF restores the previous finish."
	finish_toggle.toggled.connect(phase_finish.set_requested);phase_finish.toggle=finish_toggle;phase_finish.source_toggle=grade_toggle
	var edges:=CheckButton.new();edges.name="DisplayEdges";edges.text="Air - display-edge softness (experimental)";edges.focus_mode=Control.FOCUS_NONE;edges.button_pressed=phase_finish.edge_softening;edges.disabled=not phase_finish.available();box.add_child(edges)
	edges.tooltip_text="Independent edge resampling after owned phase grading, before UI. Observed FXAA controls; not bit-exact native code or humidity. Original phase fade preserves Noon. Extra RGB10 target/pass. OFF pending visual review and handset cost."
	edges.toggled.connect(phase_finish.set_edge_softening);phase_finish.edge_toggle=edges
	var hdr_toggle:=CheckButton.new();hdr_toggle.text="Air · preserve HDR highlights (higher bandwidth)";hdr_toggle.button_pressed=hdr_air;hdr_toggle.focus_mode=Control.FOCUS_NONE;box.add_child(hdr_toggle);hdr_toggle.toggled.connect(set_hdr_air)
	var times:=HBoxContainer.new();box.add_child(times)
	for entry:Array in [["Morning",7.],["Day",12.],["Golden",16.5],["Sunset",18.5],["Twilight",19.5],["Night",22.],["Dawn",2.5]]:
		var button:=Button.new();button.text=entry[0];button.focus_mode=Control.FOCUS_NONE;times.add_child(button)
		button.pressed.connect(_choose_hour.bind(float(entry[1])))
	var cycle:=CheckButton.new();cycle.text="Original GAF day/night preview";cycle.focus_mode=Control.FOCUS_NONE;box.add_child(cycle)
	_cycle_button=cycle
	cycle.toggled.connect(func(value:bool):cycle_enabled=value)
	var compare:=Button.new();compare.text="Compare original / combined graphics (B)";compare.focus_mode=Control.FOCUS_NONE;box.add_child(compare);compare.pressed.connect(_compare_from_settings)
	_exposure_button=CheckButton.new();_exposure_button.text="Bounded local exposure (F7)";_exposure_button.focus_mode=Control.FOCUS_NONE;box.add_child(_exposure_button)
	_exposure_button.disabled=not level.look.local_exposure_available()
	_exposure_button.toggled.connect(func(value:bool):
		level.look.set_local_exposure(value)
		if level.look._exposure_effect!=null:level.look._exposure_effect.set_review_strength(bounded_exposure_strength()))
	var experimental:=CheckButton.new();experimental.text="Legacy sky-only · F12 (replaces local GI)";experimental.focus_mode=Control.FOCUS_NONE;box.add_child(experimental)
	_legacy_sky_button=experimental
	experimental.tooltip_text="Experimental older visibility-only comparison. It replaces the default colored terrain indirect lighting; the two systems never stack."
	experimental.toggled.connect(func(value:bool):level.terrain_sky.set_enabled(value))
	var audio:=CheckButton.new();audio.text="Enable test audio (default off)";audio.button_pressed=audio_enabled;audio.focus_mode=Control.FOCUS_NONE;box.add_child(audio)
	audio.toggled.connect(set_audio_enabled)
	var material_modes:=["original","neutral","cloud","roughness","self_light","combined"]
	var material_picker:=OptionButton.new();material_picker.name="PlayerMaterialComparison";material_picker.focus_mode=Control.FOCUS_NONE
	for label:String in ["Original materials (previous player)","Neutral adapter · no new effects","Cloud shading only","Recovered Valorie roughness only","Recovered view self-light only","Combined · current default"]:material_picker.add_item(label)
	material_picker.select(material_modes.find(level.look.player_material_review));box.add_child(material_picker)
	material_picker.item_selected.connect(func(index:int):level.look.set_player_material_review(material_modes[index]))
	for entry in [["player_local_light_enabled","Player · local colored indirect"],["player_reflection_enabled","Player · broad rough reflection"],["player_skin_enabled","Player · skin softness (approximation)"]]:
		var toggle:=CheckButton.new();toggle.name=entry[0];toggle.text=entry[1];toggle.focus_mode=Control.FOCUS_NONE
		toggle.button_pressed=level.look.get(entry[0]);box.add_child(toggle)
		var property:String=entry[0]
		toggle.toggled.connect(func(value:bool):level.look.set(property,value);if level.get("player_light")!=null:level.player_light.refresh(true))
	_player_material_note=Label.new();_player_material_note.name="SettingsPlayerNote";box.add_child(_player_material_note)
	var phase_material:=CheckButton.new();phase_material.name="PlayerPhaseMaterial";phase_material.text="Player · verified material across phases";phase_material.button_pressed=level.look.player_phase_material_enabled;phase_material.disabled=not level.look.player_material.phase_verified;phase_material.focus_mode=Control.FOCUS_NONE;box.add_child(phase_material)
	phase_material.tooltip_text="Nine captured night-to-day draws use identical Valorie shader, skin/MRES and material scalars. OFF restores the previous Day-only scope. Skin wrap remains an original Mobile approximation."
	phase_material.toggled.connect(level.look.set_player_phase_material)
	var phase_sky:=CheckButton.new();phase_sky.name="PlayerPhaseSky";phase_sky.text="Player · phase-aware indirect (all day)";phase_sky.button_pressed=true;phase_sky.focus_mode=Control.FOCUS_NONE;box.add_child(phase_sky)
	phase_sky.tooltip_text="Original spatial sky follows attributed Forest lighting at all hours. Captured material response has a separate control; rotated sunlight never reuses cached Day bounce. OFF restores the previous sky scope."
	phase_sky.toggled.connect(func(value:bool):
		if level.get("player_light")!=null:level.player_light.set_phase_sky(value))
	var terrain_modes:=["previous","materials","lighting","combined"]
	var terrain_picker:=OptionButton.new();terrain_picker.name="TerrainLightComparison";terrain_picker.focus_mode=Control.FOCUS_NONE
	for label:String in ["Previous terrain graphics","PBR materials only","Local colored indirect only","Combined terrain (default)"]:terrain_picker.add_item(label)
	terrain_picker.select(terrain_modes.find(level.look.terrain_review));box.add_child(terrain_picker)
	terrain_picker.item_selected.connect(func(index:int):level.look.set_terrain_review(terrain_modes[index]))
	var terrain_response:=CheckButton.new();terrain_response.name="TerrainVisibilityResponse";terrain_response.text="Terrain · colored corner response"
	terrain_response.button_pressed=level.look.terrain_visibility_response;terrain_response.focus_mode=Control.FOCUS_NONE;box.add_child(terrain_response)
	terrain_response.toggled.connect(level.look.set_terrain_visibility_response)
	var terrain_sheen:=CheckButton.new();terrain_sheen.name="TerrainDielectricResponse";terrain_sheen.text="Terrain · soft dielectric / reflected light";terrain_sheen.button_pressed=level.look.terrain_dielectric_response;terrain_sheen.focus_mode=Control.FOCUS_NONE;box.add_child(terrain_sheen)
	terrain_sheen.toggled.connect(level.look.set_terrain_dielectric_response)
	for entry in [["captured_scatter","Air · captured Forest scatter color"],["shadowed_scatter","Air · terrain-shadowed scattering"]]:
		var toggle:=CheckButton.new();toggle.name=entry[0];toggle.text=entry[1];toggle.button_pressed=get(entry[0]);toggle.focus_mode=Control.FOCUS_NONE;box.add_child(toggle)
		var property:String=entry[0];toggle.toggled.connect(func(value:bool):set(property,value))
	_terrain_light_note=Label.new();_terrain_light_note.name="SettingsTerrainNote";box.add_child(_terrain_light_note)
	if plants!=null:
		var grass_light:=CheckButton.new();grass_light.text="Grass lighting · MD2 study";grass_light.button_pressed=plants.grass_lighting_enabled
		grass_light.focus_mode=Control.FOCUS_NONE;box.add_child(grass_light);grass_light.toggled.connect(plants.set_grass_lighting)
		var splay:=CheckButton.new();splay.text="Grass spread · captured inclinations";splay.button_pressed=plants.grass_splay_enabled
		splay.focus_mode=Control.FOCUS_NONE;box.add_child(splay);splay.toggled.connect(plants.set_grass_splay)
		var gusts:=CheckButton.new();gusts.text="Grass gusts · recovered MD2 wind";gusts.button_pressed=plants.recovered_wind_enabled
		gusts.focus_mode=Control.FOCUS_NONE;box.add_child(gusts);gusts.toggled.connect(plants.set_recovered_wind)
		var density:=CheckButton.new();density.text="Dense grass only · native card scale";density.button_pressed=plants.dense_grass_review
		density.focus_mode=Control.FOCUS_NONE;box.add_child(density);density.toggled.connect(plants.set_dense_review)
		for option:String in ["wind_enabled","interactions_enabled"]:
			var toggle:=CheckButton.new();toggle.text="Grass wind" if option=="wind_enabled" else "Player grass / flower interaction"
			toggle.button_pressed=true;toggle.focus_mode=Control.FOCUS_NONE;box.add_child(toggle)
			toggle.toggled.connect(func(value:bool):plants.set(option,value))
	panel.hide()
	_hint=Label.new();_hint.name="ShowcaseHint";_hint.position=Vector2(18,34);_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_hint.text="WASD di chuyển · Space nhảy · Chuột trái / E đánh · L ẩn / hiện HUD"
	if not unavailable_reason.is_empty():_hint.text=unavailable_reason;_hint.modulate=Color(1.,.6,.35)
	hud.add_child(_hint)
	_create_atmosphere_overlay(hud)
	_settings.setup(hud, panel, box, _lighting_sliders, status, true)
	panel.visibility_changed.connect(func():
		if not panel.is_visible_in_tree():
			_end_mix_drag(false))

func _create_atmosphere_overlay(hud: CanvasLayer) -> void:
	_vignette=ColorRect.new();_vignette.name="AtmosphereVignette";_vignette.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_vignette.z_index=-20
	var material:=ShaderMaterial.new();material.shader=preload("res://materials/world_map_atmosphere_vignette.gdshader");_vignette.material=material
	var atmosphere_layer := CanvasLayer.new()
	atmosphere_layer.name = "AtmosphereOverlay"
	atmosphere_layer.layer = hud.layer - 1
	level.add_child(atmosphere_layer)
	atmosphere_layer.add_child(_vignette);_vignette.hide()

func handle_hud_key(event: InputEventKey) -> bool:
	if event.physical_keycode == KEY_L:
		if _settings.search.has_focus() and not event.ctrl_pressed:
			return false
		_settings.toggle_hud()
		return true
	if event.physical_keycode == KEY_ESCAPE:
		return _settings.handle_escape()
	return false

func handle_key(event:InputEventKey)->bool:
	if not private_primary:return false
	if event.physical_keycode == KEY_G and event.ctrl_pressed and level.grove != null and level.grove.spruce_available():
		set_forest_spruce_visible(not level.grove.spruce_visible())
		return true
	if event.physical_keycode==KEY_G and not event.shift_pressed and plants!=null:
		plants.visible=not plants.visible
		if not plants.visible:plants.reset()
		return true
	if event.physical_keycode==KEY_B:_compare_from_settings();return true
	if event.physical_keycode==KEY_T:
		if event.shift_pressed:
			var previous := cycle_enabled
			_settings.remember_edit(func(): cycle_enabled = previous)
			cycle_enabled=not cycle_enabled
		else:
			_choose_hour(next_shortcut_hour())
		return true
	return false
