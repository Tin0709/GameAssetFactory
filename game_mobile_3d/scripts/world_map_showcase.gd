extends Node
## Owns the unified review, not the private assets or the original controller.
const ORIGINAL=preload("res://scenes/characters/CuboidPlayerJumpGifV004.tscn")
const PRIVATE_ADAPTER="res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/world_map_actor.gd"
const PALETTE=preload("res://scripts/world_map_showcase_palette.gd")
var level:Node3D
var private_primary:=true
var unavailable_reason:=""
var panel:PanelContainer
var status:Label
var hour:=12.
var cycle_enabled:=false
var palette:=PALETTE.new()
var _day:Dictionary={}
var _environment:Environment
var _time_applied:=false
var _debug:=false
var _hint:Label
var _elapsed:=0.
var _cycle_button:CheckButton
var _exposure_button:CheckButton
const ENV_FIELDS:=["ambient_light_color","ambient_light_energy","background_color","tonemap_exposure","adjustment_saturation","fog_light_color","fog_density"]

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
	if level.player.get("primary_ready")!=true:
		unavailable_reason="Private A&S/MD2 + Sabre data missing. Set MD2_RESEARCH_ROOT to the private research folder and restart."
	level.terrain_sky.set_enabled(false)
	if level.look.local_exposure_available():
		level.look.set_local_exposure(true)
		level.look._exposure_effect.set_review_strength(.12)
	if level.player.has_method("setup_world_audio"):level.player.setup_world_audio(level)
	_capture_day()
	_build_ui()
	level.get_node("HUD/Help").hide();level.get_node("HUD/Status").hide()
	level.get_node("HUD/Help").text="GRAPHICS COMPARISON\nF8 Day finish · F11 directional fill · Shift+F11 actor canopy fill\nF7 local exposure · Shift+F1 ground bounce · F1 soft shadows\nF2 canopy contact · Shift+F2 root soil · F3 direct cloud shading\nF9 leaf edges · Shift+F9 MSAA · F10 pose interpolation\nF12 optional terrain cache · G vegetation · Shift+G visit grove\nH fog · N wind · Shift+N passage · Alt+N crown wind"
	DisplayServer.window_set_title("GameAssetFactory · Overworld Showcase · A&S / MD2 Sabre · L options")
	print("WORLD_MAP_SHOWCASE_READY ",JSON.stringify({"primary_ready":unavailable_reason.is_empty(),"private_external":true,"hour":hour,"experimental_terrain_sky":false}))

func _capture_day()->void:
	_environment=level.get_node("WorldEnvironment").environment
	_day.clear()
	for field:String in ENV_FIELDS:_day[field]=_environment.get(field)
	var sun:DirectionalLight3D=level.get_node("Sun")
	_day.sun_rotation=sun.rotation_degrees;_day.sun_color=sun.light_color;_day.sun_energy=sun.light_energy
	_time_applied=false

func is_day_anchor()->bool:return is_equal_approx(hour,12.)

func set_hour(value:float)->void:
	hour=fposmod(value,24.);apply_time()
	if level!=null:level.look._refresh_ground_bounce()

func apply_time()->void:
	if not private_primary or level==null or level.look==null:return
	var env:Environment=level.get_node("WorldEnvironment").environment
	if level.look.stage!=2:
		_time_applied=false;return
	if env!=_environment:_capture_day()
	if is_day_anchor():
		if not _time_applied:return
		for field:String in ENV_FIELDS:env.set(field,_day[field])
		var sun:DirectionalLight3D=level.get_node("Sun")
		sun.rotation_degrees=_day.sun_rotation;sun.light_color=_day.sun_color;sun.light_energy=_day.sun_energy
		_time_applied=false;return
	var p:Dictionary=palette.sample(hour);var noon:Dictionary=palette.sample(12.)
	var sun:DirectionalLight3D=level.get_node("Sun")
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
	_elapsed+=delta
	if cycle_enabled and level.look.stage==2:hour=fposmod(hour+delta*.08,24.)
	apply_time()
	if _hint!=null and unavailable_reason.is_empty():_hint.visible=_elapsed<12.
	if status!=null and panel.visible:
		_cycle_button.set_pressed_no_signal(cycle_enabled)
		_exposure_button.set_pressed_no_signal(level.look.local_exposure_active())
		var msaa:=["Off","2×","4×","8×"][level.get_viewport().msaa_3d]
		status.text="%s · %02d:%02d · %s\n%d FPS · %s · MSAA %s\nPrivate reference player; not for distribution"%["Combined" if level.look.stage==2 else "Original graphics",int(hour),int(fmod(hour,1.)*60.),"Cycle" if cycle_enabled else "Paused",Engine.get_frames_per_second(),RenderingServer.get_current_rendering_method(),msaa]

func _build_ui()->void:
	var hud:=level.get_node("HUD")
	panel=PanelContainer.new();panel.name="ShowcaseOptions";panel.position=Vector2(18,18)
	panel.custom_minimum_size=Vector2(410,0);hud.add_child(panel)
	var box:=VBoxContainer.new();panel.add_child(box)
	var title:=Label.new();title.text="OVERWORLD · A&S / MD2 + SABRE";box.add_child(title)
	status=Label.new();box.add_child(status)
	var controls:=Label.new();controls.text="WASD run · Shift slow walk · Space jump\nLMB / E combo · airborne: downward attack\nRMB aim / strafe · Q / C turn · R reset\nL options · B original graphics · V overview\nT next time · Shift+T auto day/night";box.add_child(controls)
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
		if level.look._exposure_effect!=null:level.look._exposure_effect.set_review_strength(.12))
	var experimental:=CheckButton.new();experimental.text="Optional unfinished terrain sky cache (F12)";experimental.focus_mode=Control.FOCUS_NONE;box.add_child(experimental)
	experimental.toggled.connect(func(value:bool):level.terrain_sky.set_enabled(value))
	var audio:=CheckButton.new();audio.text="Environment + footsteps + Sabre audio";audio.button_pressed=true;audio.focus_mode=Control.FOCUS_NONE;box.add_child(audio)
	audio.toggled.connect(func(value:bool):
		var actor=level.player
		if actor.get("reference_audio")!=null:actor.reference_audio.enabled=value
		if actor.get("environment_audio")!=null and actor.environment_audio.audio!=null:
			actor.environment_audio.audio.ambient_enabled=value
			actor.environment_audio.audio.footsteps_enabled=value;actor.environment_audio.audio.rustle_enabled=value)
	panel.hide()
	_hint=Label.new();_hint.name="ShowcaseHint";_hint.position=Vector2(18,18);_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_hint.text="WASD · Shift walk · Space jump · LMB / E Sabre · L options"
	if not unavailable_reason.is_empty():_hint.text=unavailable_reason;_hint.modulate=Color(1.,.6,.35)
	hud.add_child(_hint)

func handle_key(event:InputEventKey)->bool:
	if not private_primary:return false
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
