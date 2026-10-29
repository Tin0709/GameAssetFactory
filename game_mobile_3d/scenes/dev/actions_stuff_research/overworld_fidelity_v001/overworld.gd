extends "res://scenes/dev/actions_stuff_research/walk_run_test.gd"
## One private map, existing lab/controller/lighting. Never changes the base scene.
const Bundle=preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/private_bundle.gd")
const Meadow=preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/meadow.gd")
const EnvAudio=preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/environment_audio.gd")
const DayFoundation=preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/graphics_owner.gd")
var graphics_foundation:Node
var private_bundle=Bundle.new()
var environment_audio:Node3D
var meadow:Node3D
var meadow_status:Label
var error_text:=""
var _status_clock:=0.
var hud_visible:=true

func _build_environment()->void:
	# Same inherited floor/contact solver, bounded to24m. Skip its old grass/grid.
	var original_blocks:int=grass_field_blocks;var original_enabled:bool=grass_field_enabled
	grass_field_blocks=24;grass_field_enabled=true
	super._build_environment()
	# Preserve the floor solver while keeping fast jumps on boundary rocks inside.
	for shape:CollisionShape3D in get_node("FieldBoundary").get_children():
		shape.shape.size.y=8.;shape.position.y=3.
	grass_field_blocks=original_blocks;grass_field_enabled=original_enabled

func _ready()->void:
	if private_bundle.read(Bundle.default_path()).is_empty():
		error_text=private_bundle.error;_error_ui();return
	# Skip only old geometry; shared lighting still sees its unchanged settings.
	grass_field_enabled=false
	super._ready()
	if player==null:error_text="Existing Sabre player failed to load.";_error_ui();return
	meadow=Meadow.new();meadow.name="PrivateOverworldMeadow";add_child(meadow);meadow.setup(player,private_bundle);grass_field=meadow
	camera.far=maxf(150.,grass_field_blocks*4.)
	if md2_lighting!=null:md2_lighting.grass_field=meadow
	environment_audio=EnvAudio.new();environment_audio.name="PrivateOverworldAudio";add_child(environment_audio);environment_audio.setup(player,meadow,private_bundle)
	sabre_mode.panel.hide();sabre_mode.movement_panel.hide();sabre_mode.refresh_reflections()
	var appearance:OptionButton=sabre_mode.panel.find_child("AppearanceSelector",true,false)
	for connection:Dictionary in appearance.item_selected.get_connections():appearance.item_selected.disconnect(connection.callable)
	appearance.item_selected.connect(func(index:int):
		sabre_mode.release_inputs();get_tree().set_meta("md2_sabre_private_skin_selected",index==0);get_tree().change_scene_to_file(scene_file_path))
	_build_meadow_ui()
	graphics_foundation=DayFoundation.new();graphics_foundation.name="OverworldDayFoundation";add_child(graphics_foundation);graphics_foundation.setup(self)
	get_window().title="GameAssetFactory — Overworld Day Foundation / Sabre"
	print("OVERWORLD_PLAYABLE_READY")

func _process(delta:float)->void:
	if not error_text.is_empty():return
	super._process(delta)
	_status_clock+=delta
	if _status_clock>.5 and meadow_status!=null:
		_status_clock=0.
		var s:Dictionary=meadow.snapshot()
		meadow_status.text="%d plants/blocks · %d batches · %d species\n%.1f m/s · %d FPS · steps %d / rustles %d"%[s.instances,s.batches,s.species,player.current_speed,Engine.get_frames_per_second(),environment_audio.event_count.grass+environment_audio.event_count.dirt+environment_audio.event_count.stone,environment_audio.event_count.rustle]
		if environment_audio.rejected_count>0:meadow_status.text+="\nWARNING: %d audio files unavailable"%environment_audio.rejected_count

func _unhandled_input(event:InputEvent)->void:
	if not error_text.is_empty():return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_H:
		set_hud_visible(not hud_visible);get_viewport().set_input_as_handled();return
	if graphics_foundation!=null and graphics_foundation.input(event):get_viewport().set_input_as_handled();return
	super._unhandled_input(event)

func set_hud_visible(value:bool)->void:
	hud_visible=value;get_node("OverworldControls").visible=value;sabre_mode.canvas.visible=value
	if md2_lighting!=null:md2_lighting.ui.visible=value
	if graphics_foundation!=null and graphics_foundation.available:
		md2_lighting.ui.hide();graphics_foundation.ui.visible=value

func _update_camera(delta:float=0.,render_position:Variant=null)->void:
	var original_blocks:int=grass_field_blocks
	if grass_overview:grass_field_blocks=32
	super._update_camera(delta,render_position)
	grass_field_blocks=original_blocks
	if graphics_foundation!=null:graphics_foundation.apply_camera()

func _build_meadow_ui()->void:
	var layer:=CanvasLayer.new();layer.name="OverworldControls";add_child(layer)
	var panel:=PanelContainer.new();panel.position=Vector2(18,18);layer.add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.045,.035,.87);style.set_corner_radius_all(6);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=10;style.content_margin_bottom=10;panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",4);panel.add_child(box)
	var title:=Label.new();title.text="OVERWORLD · PRIVATE FIDELITY STUDY";title.add_theme_font_size_override("font_size",15);box.add_child(title)
	var hint:=Label.new();hint.text="WASD run · Shift walk · Space jump\nLMB / E Sabre · R reset · V overview · H hide UI";hint.add_theme_font_size_override("font_size",12);box.add_child(hint)
	_toggle(box,"Wind",true,func(on:bool):meadow.wind_enabled=on)
	_toggle(box,"Player vegetation interaction",true,func(on:bool):meadow.interactions_enabled=on)
	_toggle(box,"Ambient audio",true,func(on:bool):environment_audio.ambient_enabled=on)
	_toggle(box,"Footsteps + contact rustle",true,func(on:bool):environment_audio.footsteps_enabled=on;environment_audio.rustle_enabled=on;environment_audio.reset_contacts())
	_trim(box,"Ambience trim",func(db:float):environment_audio.ambience_gain_db=db)
	_trim(box,"Footstep / rustle trim",func(db:float):environment_audio.effects_gain_db=db)
	var controls:=Button.new();controls.text="Player / animation controls";controls.focus_mode=Control.FOCUS_NONE;box.add_child(controls)
	controls.pressed.connect(func():sabre_mode.panel.visible=not sabre_mode.panel.visible;sabre_mode.panel.position=Vector2(18,290))
	meadow_status=Label.new();meadow_status.add_theme_font_size_override("font_size",11);box.add_child(meadow_status)
	var evidence:=Label.new();evidence.text="Original source assets/audio · recreated wind/mix";evidence.add_theme_font_size_override("font_size",10);evidence.modulate=Color(.72,.82,.71);box.add_child(evidence)

func _toggle(box:Node,label:String,value:bool,callback:Callable)->void:
	var button:=CheckButton.new();button.text=label;button.button_pressed=value;button.focus_mode=Control.FOCUS_NONE;box.add_child(button);button.toggled.connect(callback)

func _trim(box:Node,title:String,callback:Callable)->void:
	var row:=HBoxContainer.new();box.add_child(row)
	var label:=Label.new();label.text=title;label.add_theme_font_size_override("font_size",11);label.custom_minimum_size.x=145;row.add_child(label)
	var slider:=HSlider.new();slider.min_value=-18.;slider.max_value=6.;slider.step=1.;slider.value=0.;slider.custom_minimum_size.x=105;slider.focus_mode=Control.FOCUS_NONE;row.add_child(slider)
	var value:=Label.new();value.text="0 dB";value.add_theme_font_size_override("font_size",11);row.add_child(value)
	slider.value_changed.connect(func(db:float):value.text="%+.0f dB"%db;callback.call(db))

func _error_ui()->void:
	var label:=Label.new();label.text="Private Overworld unavailable\n"+error_text+"\nRun Open Overworld Meadow.cmd from MD2 Research.";label.position=Vector2(30,30);add_child(label);push_error(error_text)
