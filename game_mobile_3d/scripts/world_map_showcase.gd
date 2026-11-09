extends Node
## Owns the unified review, not the private assets or the original controller.
const ORIGINAL=preload("res://scenes/characters/CuboidPlayerJumpGifV004.tscn")
const PRIVATE_ADAPTER="res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/world_map_actor.gd"
const PALETTE=preload("res://scripts/world_map_showcase_palette.gd")
const FOREST=preload("res://scripts/world_map_forest_atmosphere.gd")
const LOCAL_EXPOSURE_STRENGTH:=.12
# User-directed art adjustment; recovered Forest profiles stay untouched.
const GENTLE_NOON_DIRECT_SCALE:=.82
var level:Node3D
var private_primary:=true
var unavailable_reason:=""
var panel:PanelContainer
var status:Label
var hour:=12.
var cycle_enabled:=false
var audio_enabled:=false
var plants:Node3D
var palette:=PALETTE.new()
var forest:=FOREST.new()
var atmosphere_review:="combined"
var _forest_expected:Dictionary={}
var _forest_hour:=INF
var _forest_sun:Color
var _forest_energy:float
var _vignette:ColorRect
var _player_light:OmniLight3D
var _atmosphere_picker:OptionButton
var _legacy_sky_button:CheckButton
var mist:Node3D
var spatial_mist:=true
var phase_air=preload("res://scripts/world_map_phase_air.gd").new()
var measured_atmosphere:=true
var coupled_bloom:=true
var coherent_bloom:=true
var measured_bloom_response:=true
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
var _debug:=false
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
	private_primary=OS.get_environment("GAF_SHOWCASE_PLAYER")!="original"
	if not private_primary:return ORIGINAL.instantiate()
	if OS.has_feature("editor") and ResourceLoader.exists(PRIVATE_ADAPTER):
		return load(PRIVATE_ADAPTER).new()
	unavailable_reason="Primary A&S/MD2 + Sabre requires the private editor workspace. No reference assets are included in builds."
	var placeholder:=ORIGINAL.instantiate()
	placeholder.process_mode=Node.PROCESS_MODE_DISABLED
	return placeholder

func setup(world:Node3D)->void:
	level=world;process_priority=-10
	if not private_primary:return
	if level.player.get("primary_ready")!=true and unavailable_reason.is_empty():
		unavailable_reason="Private A&S/MD2 + Sabre data missing. Set MD2_RESEARCH_ROOT to the private research folder and restart."
	level.terrain_sky.set_enabled(false)
	# Requested bare map: preserve the authored assets and placements for recovery.
	level.set_grove_visible(false,level.player.global_position)
	if level.player.has_method("setup_world_vegetation"):plants=level.player.setup_world_vegetation(level)
	if level.look.local_exposure_available():
		level.look.set_local_exposure(true)
		level.look._exposure_effect.set_review_strength(LOCAL_EXPOSURE_STRENGTH)
	if level.player.has_method("setup_world_audio"):level.player.setup_world_audio(level)
	set_audio_enabled(false)
	_capture_day()
	if forest.available():
		_player_light=OmniLight3D.new();_player_light.name="AtmospherePlayerLight";_player_light.shadow_enabled=false
		_player_light.omni_range=forest.player_range;_player_light.omni_attenuation=2.;_player_light.position.y=1.4
		level.player.add_child(_player_light);_player_light.hide()
		mist=preload("res://scripts/world_map_atmosphere_volume.gd").new();level.get_node("Camera3D").add_child(mist);mist.setup();mist.material_provider=_mist_materials;mist.medium_state=_mist_state;mist.compositor_owned=func(c):return c==level.look._exposure_compositor
	grade_review=preload("res://scripts/world_map_grade_review.gd").new();add_child(grade_review);grade_review.setup(self)
	phase_finish=preload("res://scripts/world_map_phase_finish.gd").new();add_child(phase_finish);phase_finish.setup(self)
	_build_ui()
	level.get_node("HUD/Help").hide();level.get_node("HUD/Status").hide()
	level.get_node("HUD/Help").text="GRAPHICS COMPARISON\nF8 Day finish · F11 directional fill · Shift+F11 actor canopy fill\nF7 local exposure · Shift+F1 ground bounce · F1 soft shadows\nF2 canopy contact · Shift+F2 root soil · F3 direct cloud shading\nF9 leaf edges · Shift+F9 MSAA · F10 pose interpolation\nF12 optional terrain cache · G grass/flowers · L wind/interaction options\nH fog · N terrain wind · Shift+N passage · Alt+N crown wind"
	DisplayServer.window_set_title("GameAssetFactory · Overworld Showcase · A&S / MD2 Sabre · L options")
	print("WORLD_MAP_SHOWCASE_READY ",JSON.stringify({"primary_ready":unavailable_reason.is_empty(),"private_external":true,"hour":hour,"experimental_terrain_sky":false}))

func _capture_day()->void:
	_environment=level.get_node("WorldEnvironment").environment
	_day.clear()
	for field:String in ENV_FIELDS:_day[field]=_environment.get(field)
	var sun:DirectionalLight3D=level.get_node("Sun")
	_day.sun_rotation=sun.rotation_degrees;_day.sun_color=sun.light_color;_day.sun_energy=sun.light_energy
	_time_applied=false
	_forest_expected.clear();_forest_hour=INF

func is_day_anchor()->bool:return is_equal_approx(hour,12.)

func set_audio_enabled(value:bool)->void:
	audio_enabled=value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),not value)
	var actor=level.player
	if actor.get("reference_audio")!=null:actor.reference_audio.enabled=value
	if actor.get("environment_audio")!=null and actor.environment_audio.audio!=null:
		actor.environment_audio.audio.ambient_enabled=value
		actor.environment_audio.audio.footsteps_enabled=value;actor.environment_audio.audio.rustle_enabled=value

func _restore_day()->void:
	if phase_finish!=null:phase_finish.restore_environment()
	if grade_review!=null:grade_review.release()
	if not _time_applied or _day.is_empty():return
	for field:String in ENV_FIELDS:_environment.set(field,_day[field])
	var sun:DirectionalLight3D=level.get_node("Sun")
	sun.rotation_degrees=_day.sun_rotation;sun.light_color=_day.sun_color;sun.light_energy=_day.sun_energy
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

func set_source_bloom_shape(value:bool)->void:
	source_bloom_shape=value;set_coupled_bloom(coupled_bloom)

func set_measured_bloom_response(value:bool)->void:
	measured_bloom_response=value;set_coupled_bloom(coupled_bloom)

func set_coupled_bloom(value:bool)->void:
	coupled_bloom=value
	if level.look._exposure_effect!=null:
		var enabled:bool=value and forest_active() and atmosphere_review in ["haze","combined"]
		level.look._exposure_effect.set_air_bloom(enabled)
		var response:float=bloom_response.sample(hour)if enabled and measured_bloom_response else 1.
		level.look._exposure_effect.set_air_bloom_response(response)
		var shape_weight:float=phase_finish.phase_weight(hour)if phase_finish!=null and phase_finish.active else 0.
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
	if grade_review!=null:grade_review.release()
	if _hdr_owned and is_instance_valid(_hdr_viewport):_hdr_viewport.use_hdr_2d=_hdr_saved

func _update_mist()->void:
	_update_hdr_air()
	set_coherent_bloom(coherent_bloom)
	if level!=null and level.look._exposure_effect!=null:set_coupled_bloom(coupled_bloom)
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
	var luma:=Vector3(.2126,.7152,.0722);var ambient:=env.ambient_light_color.srgb_to_linear()
	var sun:DirectionalLight3D=level.get_node("Sun");var key:=sun.light_color.srgb_to_linear()
	var incoming:=Vector3(ambient.r,ambient.g,ambient.b).dot(luma)*env.ambient_light_energy*.75+Vector3(key.r,key.g,key.b).dot(luma)*sun.light_energy*.03
	var rgb:Vector3=_mist_sample.fog_color;var color:=Color(rgb.x,rgb.y,rgb.z).srgb_to_linear()
	var linear:=Vector3(color.r,color.g,color.b)
	if captured_scatter:linear=air_light.scatter_color(linear,hour)
	var sample:=_mist_sample.duplicate()
	var measured:Dictionary=phase_air.sample(hour) if measured_atmosphere else {}
	if not measured.is_empty():
		# Source chromaticity in linear space; retain the approved incident-light energy.
		var source:Vector3=measured.linear_scatter
		linear=source*linear.dot(luma)/maxf(source.dot(luma),.0001)
		sample.volume_density*=measured.density_ratio
		sample.height_falloff=measured.height_falloff_m
		sample.fog_begin=measured.start_m
	sample.linear_scatter_rgb=linear
	sample.scatter_energy=clampf(incoming,.015,.18)/maxf(linear.dot(luma),.0001)
	var emitter:Vector3=level.presentation.player_position()
	var lantern=level.player.get("lantern")
	if lantern!=null and lantern.ready_private:
		var point:Vector3=lantern.emitter_position()
		if _player_light!=null:_player_light.top_level=true;_player_light.light_cull_mask=1;_player_light.global_position=point
		emitter=point-Vector3.UP*1.4
	mist.publish(sample,emitter,level.spawn_position.y-1.,level.look.elapsed,camera.projection==Camera3D.PROJECTION_ORTHOGONAL,forest.player_range)

func sync_lantern_emitter(point:Vector3)->void:
	if not point.is_finite():return
	if _player_light!=null:
		_player_light.top_level=true;_player_light.light_cull_mask=1;_player_light.global_position=point
	if mist!=null and mist.visible:mist.set_warm_emitter(point)

func air_field()->Dictionary:
	var result:Dictionary=air_light.field()
	if not shadowed_scatter:result.valid=false
	return result

func _mist_state(ready:bool,error:String)->void:
	if mist==null or not mist.visible or _mist_sample.is_empty():return
	# Called late, AFTER configure invalidates a resized field in this same frame.
	var env:Environment=level.get_node("WorldEnvironment").environment
	env.fog_density=0. if ready and error.is_empty() else float(_mist_sample.fog_opacity)
	_forest_expected.fog_density=env.fog_density

func _mist_materials()->Array:
	var result:Array=level.look.materials.values()
	result.append_array(level.look._direct_actor_materials)
	if plants!=null:result.append_array(plants.materials)
	for chunk:Dictionary in level.geometry._cutaway_chunks:result.append_array(chunk.materials)
	return result

func forest_active()->bool:
	return private_primary and level!=null and level.look.stage==2 and level.view_mode=="gameplay" and atmosphere_review!="previous" and forest.available()

func set_atmosphere_review(mode:String)->void:
	if not mode in ["previous","haze","lighting","combined"]:return
	_restore_day();atmosphere_review=mode;_forest_expected.clear();apply_time()
	if mode!="previous" and level!=null and level.terrain_sky.enabled:level.terrain_sky.set_enabled(false)
	if level!=null:level.look._refresh_ground_bounce()

func terrain_ambient_reference()->Color:
	if forest_active() and atmosphere_review in ["lighting","combined"] and not _forest_expected.is_empty():return _day.ambient_light_color
	return Color(-1,-1,-1)

func forest_spatial_sky_context()->bool:
	return forest_active() and atmosphere_review in ["lighting","combined"] and not _forest_expected.is_empty()

func terrain_ambient_matches(color:Color,source:Color)->bool:
	return terrain_ambient_reference().is_equal_approx(source) and _forest_expected.get("ambient_light_color")==color

func _apply_forest(env:Environment,sun:DirectionalLight3D)->void:
	var p:=forest.sample(hour)
	if atmosphere_review in ["lighting","combined"]:
		var linear:=env.ambient_light_color.srgb_to_linear();var source:=Vector3(linear.r,linear.g,linear.b)
		var tinted:Vector3=source*p.ambient_tint;var luma:=Vector3(.2126,.7152,.0722)
		tinted*=source.dot(luma)/maxf(tinted.dot(luma),.000001)
		env.ambient_light_color=Color(tinted.x,tinted.y,tinted.z).linear_to_srgb()
		env.ambient_light_energy*=p.ambient_energy_scale
		var key:=sun.light_color.srgb_to_linear();var rgb:Vector3=Vector3(key.r,key.g,key.b)*p.key_color_scale
		var peak:=maxf(1.,maxf(rgb.x,maxf(rgb.y,rgb.z)))
		sun.light_color=Color(rgb.x/peak,rgb.y/peak,rgb.z/peak).linear_to_srgb();sun.light_energy*=p.key_scale*peak
		if gentle_noon:sun.light_energy*=noon_direct_scale(hour)
		if _player_light!=null:
			var warm:Vector3=p.player_light_color
			_player_light.light_color=Color(warm.x,warm.y,warm.z);_player_light.light_energy=p.player_light_weight
			_player_light.visible=p.player_light_weight>0.
	if atmosphere_review in ["haze","combined"]:
		var fog:Vector3=p.fog_color
		env.fog_light_color=Color(fog.x,fog.y,fog.z);env.fog_depth_begin=p.fog_begin;env.fog_depth_end=p.fog_end
		env.fog_depth_curve=.8;env.fog_density=p.fog_opacity
		if spatial_mist and mist!=null and mist.failure().is_empty() and mist.effect.snapshot().ready:env.fog_density=0.
		env.glow_enabled=true;env.glow_intensity=float(_day.glow_intensity)*p.glow_scale
		env.glow_bloom=float(_day.glow_bloom)*p.bloom_scale;env.glow_hdr_threshold=.86
		env.adjustment_contrast=float(_day.adjustment_contrast)*p.contrast_scale
		env.adjustment_saturation*=p.saturation_scale
	if _vignette!=null:
		_vignette.visible=atmosphere_review in ["haze","combined"]
		_vignette.material.set_shader_parameter("strength",p.vignette)
	_forest_expected.clear()
	for field:String in ENV_FIELDS:_forest_expected[field]=env.get(field)
	_forest_sun=sun.light_color;_forest_energy=sun.light_energy;_forest_hour=hour
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
	if level!=null:level.look._refresh_ground_bounce()

func apply_time()->void:
	if not private_primary or level==null or level.look==null:return
	var env:Environment=level.get_node("WorldEnvironment").environment
	if level.look.stage!=2:
		_time_applied=false;_forest_expected.clear()
		if _vignette!=null:_vignette.hide()
		if _player_light!=null:_player_light.hide()
		return
	if env!=_environment:_capture_day()
	var use_forest:=forest_active()
	var sun:DirectionalLight3D=level.get_node("Sun")
	if use_forest and _forest_hour==hour and not _forest_expected.is_empty() and sun.light_color==_forest_sun and sun.light_energy==_forest_energy:
		var unchanged:=true
		for field:String in _forest_expected:
			if env.get(field)!=_forest_expected[field]:unchanged=false;break
		if unchanged:return
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

func _process(delta:float)->void:
	if not private_primary or level==null:return
	_fps_elapsed+=delta
	if _fps_label!=null and _fps_elapsed>=.5:
		_fps_elapsed=0.
		_fps_label.text="FPS: %d"%Engine.get_frames_per_second()
	_elapsed+=delta
	if cycle_enabled and level.look.stage==2:hour=fposmod(hour+delta*.08,24.)
	apply_time()
	_update_mist()
	if _hint!=null and unavailable_reason.is_empty():_hint.visible=_elapsed<12. and not panel.visible
	if status!=null and panel.visible:
		_atmosphere_picker.select(["previous","haze","lighting","combined"].find(atmosphere_review))
		_legacy_sky_button.set_pressed_no_signal(level.terrain_sky.enabled)
		_terrain_light_note.text="Local field: %s · original GAF transport\nSky RGB retint; sun transport stays Day-guarded."%("active" if level.terrain_light!=null and level.terrain_light.is_active() else "suspended / off")
		var profile_scope:="nine captured phases" if level.look.player_phase_material_enabled and level.look.player_material.phase_verified else "Day-only comparison"
		_player_material_note.text="Same scene light / pose. Material: %s.\nB suspends adapter; F3 also gates direct clouds."%(profile_scope if level.look.player_effects_available() else "suspended outside verified scope")
		_cycle_button.set_pressed_no_signal(cycle_enabled)
		_exposure_button.set_pressed_no_signal(level.look.local_exposure_active())
		var msaa:String=["Off","2×","4×","8×"][level.get_viewport().msaa_3d]
		status.text="%s · %02d:%02d · %s\n%d FPS · %s · MSAA %s\nPrivate reference player; not for distribution"%["Combined" if level.look.stage==2 else "Original graphics",int(hour),int(fmod(hour,1.)*60.),"Cycle" if cycle_enabled else "Paused",Engine.get_frames_per_second(),RenderingServer.get_current_rendering_method(),msaa]

func _build_ui()->void:
	var hud:=level.get_node("HUD")
	_fps_label=Label.new();_fps_label.name="ShowcaseFPS";_fps_label.position=Vector2(18,6)
	_fps_label.text="FPS: %d"%Engine.get_frames_per_second();_fps_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_font_size_override("font_size",18)
	_fps_label.add_theme_color_override("font_color",Color.WHITE)
	_fps_label.add_theme_color_override("font_outline_color",Color(0,0,0,.85))
	_fps_label.add_theme_constant_override("outline_size",4);hud.add_child(_fps_label)
	panel=PanelContainer.new();panel.name="ShowcaseOptions";panel.position=Vector2(18,40)
	panel.custom_minimum_size=Vector2(410,0);hud.add_child(panel)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size=Vector2(440,minf(level.get_viewport().get_visible_rect().size.y-58.,630.));panel.add_child(scroll)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(box)
	var title:=Label.new();title.text="OVERWORLD · A&S / MD2 + SABRE";box.add_child(title)
	status=Label.new();box.add_child(status)
	var controls:=Label.new();controls.text="WASD run · Shift slow walk · Space jump\nLMB / E combo · airborne: downward attack\nRMB aim / strafe · Q / C turn · R reset\nL options · B original graphics · V overview\nT next time · Shift+T auto day/night";box.add_child(controls)
	var atmosphere:=OptionButton.new();atmosphere.name="AtmosphereComparison";atmosphere.focus_mode=Control.FOCUS_NONE
	_atmosphere_picker=atmosphere
	for label:String in ["Previous atmosphere","Forest entrance · haze / bloom only","Forest entrance · lighting only","Forest entrance · combined"]:atmosphere.add_item(label)
	var modes=["previous","haze","lighting","combined"];atmosphere.select(modes.find(atmosphere_review));box.add_child(atmosphere)
	atmosphere.item_selected.connect(func(index:int):set_atmosphere_review(modes[index]))
	atmosphere.tooltip_text="Forest A1 Day: read live in MD2. Other phases: recovered presets. Fog, bloom and light transfer are original Mobile approximations."
	var gentle:=CheckButton.new();gentle.name="GentleNoon";gentle.text="Light · gentle midday sunlight";gentle.button_pressed=gentle_noon;gentle.focus_mode=Control.FOCUS_NONE;box.add_child(gentle)
	gentle.tooltip_text="18% less direct sunlight at noon, smoothly returning to the previous morning/evening lighting. Ambient and source presets unchanged. OFF compares the previous result."
	gentle.toggled.connect(set_gentle_noon)
	var volume:=CheckButton.new();volume.text="Spatial mist · world height / patches";volume.button_pressed=spatial_mist;volume.focus_mode=Control.FOCUS_NONE;box.add_child(volume)
	volume.toggled.connect(set_spatial_mist)
	var measured:=CheckButton.new();measured.text="Air · measured night / dawn / day";measured.button_pressed=measured_atmosphere;measured.focus_mode=Control.FOCUS_NONE;box.add_child(measured);measured.toggled.connect(set_measured_atmosphere)
	var bloom_air:=CheckButton.new();bloom_air.text="Air · exposure-shaped soft light";bloom_air.button_pressed=coupled_bloom;bloom_air.focus_mode=Control.FOCUS_NONE;box.add_child(bloom_air);bloom_air.toggled.connect(set_coupled_bloom)
	var response:=CheckButton.new();response.name="MeasuredBloomResponse";response.text="Air - measured bloom response (all phases)";response.button_pressed=measured_bloom_response;response.disabled=not bloom_response.available();response.focus_mode=Control.FOCUS_NONE;box.add_child(response)
	response.tooltip_text="Relative bloom gain from nine captured Forest pipelines. Preserves approved Noon gain and existing shape; original clock placement and mirrored evening. Not native radiometry or the full six-scale kernel. OFF restores previous fixed response."
	response.toggled.connect(set_measured_bloom_response)
	var shape:=CheckButton.new();shape.name="SourceBloomShape";shape.text="Air - six-scale spread (experimental)";shape.focus_mode=Control.FOCUS_NONE;shape.button_pressed=source_bloom_shape;box.add_child(shape)
	shape.tooltip_text="Private captured numeric kernels in an original six-level pyramid. Energy normalized; source-relative intensity is separate. Original viewport mapping and phase fade preserve Noon. Higher pass/bandwidth cost; OFF pending validation."
	shape.toggled.connect(set_source_bloom_shape)
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
	for entry:Array in [["Morning",7.],["Day",12.],["Golden",16.5],["Night",22.]]:
		var button:=Button.new();button.text=entry[0];button.focus_mode=Control.FOCUS_NONE;times.add_child(button)
		button.pressed.connect(set_hour.bind(float(entry[1])))
	var cycle:=CheckButton.new();cycle.text="Original GAF day/night preview";cycle.focus_mode=Control.FOCUS_NONE;box.add_child(cycle)
	_cycle_button=cycle
	cycle.toggled.connect(func(value:bool):cycle_enabled=value)
	var compare:=Button.new();compare.text="Compare original / combined graphics (B)";compare.focus_mode=Control.FOCUS_NONE;box.add_child(compare);compare.pressed.connect(compare_baseline)
	_exposure_button=CheckButton.new();_exposure_button.text="Bounded local exposure (F7)";_exposure_button.focus_mode=Control.FOCUS_NONE;box.add_child(_exposure_button)
	_exposure_button.disabled=not level.look.local_exposure_available()
	_exposure_button.toggled.connect(func(value:bool):
		level.look.set_local_exposure(value)
		if level.look._exposure_effect!=null:level.look._exposure_effect.set_review_strength(LOCAL_EXPOSURE_STRENGTH))
	var experimental:=CheckButton.new();experimental.text="Legacy sky-only · F12 (replaces local GI)";experimental.focus_mode=Control.FOCUS_NONE;box.add_child(experimental)
	_legacy_sky_button=experimental
	experimental.tooltip_text="Experimental older visibility-only comparison. It replaces the default colored terrain indirect lighting; the two systems never stack."
	experimental.toggled.connect(func(value:bool):level.terrain_sky.set_enabled(value))
	var audio:=CheckButton.new();audio.text="Enable test audio (default off)";audio.button_pressed=audio_enabled;audio.focus_mode=Control.FOCUS_NONE;box.add_child(audio)
	audio.toggled.connect(set_audio_enabled)
	var player_title:=Label.new();player_title.text="PLAYER MATERIAL · independent comparisons";box.add_child(player_title)
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
	_player_material_note=Label.new();_player_material_note.text="Same scene light / pose. Captured material scope below.\nB suspends adapter; F3 also gates direct clouds.";box.add_child(_player_material_note)
	var phase_material:=CheckButton.new();phase_material.name="PlayerPhaseMaterial";phase_material.text="Player · verified material across phases";phase_material.button_pressed=level.look.player_phase_material_enabled;phase_material.disabled=not level.look.player_material.phase_verified;phase_material.focus_mode=Control.FOCUS_NONE;box.add_child(phase_material)
	phase_material.tooltip_text="Nine captured night-to-day draws use identical Valorie shader, skin/MRES and material scalars. OFF restores the previous Day-only scope. Skin wrap remains an original Mobile approximation."
	phase_material.toggled.connect(level.look.set_player_phase_material)
	var phase_sky:=CheckButton.new();phase_sky.name="PlayerPhaseSky";phase_sky.text="Player · phase-aware indirect (all day)";phase_sky.button_pressed=true;phase_sky.focus_mode=Control.FOCUS_NONE;box.add_child(phase_sky)
	phase_sky.tooltip_text="Original spatial sky follows attributed Forest lighting at all hours. Captured material response has a separate control; rotated sunlight never reuses cached Day bounce. OFF restores the previous sky scope."
	phase_sky.toggled.connect(func(value:bool):
		if level.get("player_light")!=null:level.player_light.set_phase_sky(value))
	var terrain_title:=Label.new();terrain_title.text="TERRAIN · material / colored indirect";box.add_child(terrain_title)
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
	_terrain_light_note=Label.new();box.add_child(_terrain_light_note)
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
	_hint.text="WASD · Shift walk · Space jump · LMB / E Sabre · L options"
	if not unavailable_reason.is_empty():_hint.text=unavailable_reason;_hint.modulate=Color(1.,.6,.35)
	hud.add_child(_hint)
	_vignette=ColorRect.new();_vignette.name="AtmosphereVignette";_vignette.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_vignette.z_index=-20
	var material:=ShaderMaterial.new();material.shader=preload("res://materials/world_map_atmosphere_vignette.gdshader");_vignette.material=material
	hud.add_child(_vignette);_vignette.hide()

func handle_key(event:InputEventKey)->bool:
	if not private_primary:return false
	if event.physical_keycode==KEY_G and plants!=null:
		plants.visible=not plants.visible
		if not plants.visible:plants.reset()
		return true
	if event.physical_keycode==KEY_L:
		_debug=not _debug;panel.visible=_debug;_hint.visible=not _debug
		return true
	if event.physical_keycode==KEY_B:compare_baseline();return true
	if event.physical_keycode==KEY_T:
		if event.shift_pressed:cycle_enabled=not cycle_enabled
		else:
			var phases:=[7.,12.,16.5,22.];var next:=7.
			for h:float in phases:
				if h>hour+.01:next=h;break
			set_hour(next)
		return true
	return false
