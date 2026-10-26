extends Node
## Third, opt-in mode of the original lab. All environment resources and camera
## remain owned by that lab; no old rifle/private actor is constructed here.
const Actor=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd")
const Effects=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/effects.gd")
const GrassField=preload("res://scenes/dev/actions_stuff_research/grass_md2_v001/grass_field.gd")
const Lighting=preload("res://scenes/dev/actions_stuff_research/lighting_md2_v001/lighting.gd")
const ReferenceAudio=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const SELECTION_META:="md2_sabre_prototype_selected"
const LAB_SCENE:="res://scenes/dev/ActionsStuffWalkRunTest.tscn"
var lab:Node3D
var actor:CharacterBody3D
var effects:Node3D
var reference_audio:Node
var reflection_probe:ReflectionProbe
var reflections_enabled:=true
var canvas:CanvasLayer
var panel:PanelContainer
var status:Label
var actions:OptionButton
var expression:OptionButton
var _right_held:=false
var _left_held:=false
var _e_held:=false
var _q_held:=false
var _c_held:=false

static func install_entry_button(scene:Node3D)->void:
	var layer:=CanvasLayer.new();layer.name="SabrePrototypeEntry";scene.add_child(layer)
	var button:=Button.new();button.name="PlayerSabrePrototypeButton";button.text="Player + Sabre prototype";button.position=Vector2(20,110);button.custom_minimum_size=Vector2(240,34);button.focus_mode=Control.FOCUS_NONE
	layer.add_child(button)
	button.pressed.connect(func():
		scene.get_tree().set_meta(SELECTION_META,true)
		scene.get_tree().change_scene_to_file(LAB_SCENE))
func setup(scene:Node3D)->void:
	lab=scene;process_physics_priority=-10
	lab._build_environment()
	actor=Actor.new();actor.name="SabrePrototypePlayer"
	actor.prefer_private_skin=bool(get_tree().get_meta("md2_sabre_private_skin_selected",true))
	actor.walk_speed=1.8*lab.movement_speed_multiplier;actor.run_speed=5.031*lab.movement_speed_multiplier
	actor.acceleration=40.*lab.movement_speed_multiplier;actor.deceleration=35.*lab.movement_speed_multiplier
	lab.add_child(actor);lab.player=actor
	effects=Effects.new();effects.name="AuthoredSabreEffects";lab.add_child(effects);actor.effects=effects
	if actor.using_private_skin:
		reference_audio=ReferenceAudio.new();reference_audio.name="PrivateReferenceAudio";add_child(reference_audio)
		var research_root:String=actor.private_model_path().get_base_dir().get_base_dir().get_base_dir()
		reference_audio.setup(research_root);actor.attack_accepted.connect(reference_audio.trigger_attack)
		reference_audio.is_event_valid=func(serial:int)->bool:return actor.combo.serial==serial and actor.combo.active() and actor.review_clip.is_empty()
	lab.camera=Camera3D.new();lab.camera.name="GameplayCamera";lab.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	lab.camera.size=lab.camera_size;lab.camera.far=maxf(150.,lab.grass_field_blocks*4.) if lab.grass_field_enabled else 150.;lab.add_child(lab.camera);lab.camera.make_current()
	if lab.grass_field_enabled:
		lab.grass_field=GrassField.new();lab.grass_field.name="MD2GrassField%dx%d"%[lab.grass_field_blocks,lab.grass_field_blocks];lab.add_child(lab.grass_field);lab.grass_field.setup(actor,lab.grass_field_blocks)
		if not lab.grass_vegetation_enabled:
			for child in lab.grass_field.get_children():
				if child.name.begins_with("GrassRegion_"):child.hide()
			lab.grass_field.enabled=false;lab.grass_field.set_process(false);lab.grass_field.set_physics_process(false)
	if lab.md2_lighting_enabled:
		lab.md2_lighting=Lighting.new();lab.md2_lighting.name="GAF_MD2_Lighting_v001";lab.add_child(lab.md2_lighting);lab.md2_lighting.setup(lab,lab.grass_field,not lab.performance_test_enabled)
	if actor.using_private_skin:
		for mesh:MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):mesh.layers=2
		refresh_reflections()
	_build_ui();lab._update_camera()
	print("MD2_SABRE_READY ",JSON.stringify({"clips":actor.clips.size(),"bones":actor.skeleton.get_bone_count(),"markers":[str(actor.marker_grip.get_path()),str(actor.marker_base.get_path()),str(actor.marker_tip.get_path())],"appearance":actor.appearance_label,"motion":"original source tracks with declared semantic aliases" if actor.using_original_source else "reconstructed authored curves"}))
func _build_ui()->void:
	canvas=CanvasLayer.new();canvas.name="SabrePrototypeControls";add_child(canvas)
	panel=PanelContainer.new();panel.position=Vector2(18,18);panel.custom_minimum_size.x=342;canvas.add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.035,.045,.90);style.set_corner_radius_all(5);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=10;style.content_margin_bottom=10;panel.add_theme_stylebox_override("panel",style)
	var theme:=Theme.new();theme.default_font_size=13;panel.theme=theme
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",6);panel.add_child(box)
	var title:=Label.new();title.text="PLAYER + SABRE · "+("original source lab" if actor.using_original_source else "authored prototype");box.add_child(title)
	var appearance:=OptionButton.new();appearance.name="AppearanceSelector";appearance.focus_mode=Control.FOCUS_NONE
	appearance.add_item("Original MD2 player + Sabre (private)");appearance.add_item("Own authored fallback")
	appearance.select(0 if actor.prefer_private_skin else 1);box.add_child(appearance)
	appearance.item_selected.connect(func(index:int):
		release_inputs();get_tree().set_meta("md2_sabre_private_skin_selected",index==0);get_tree().set_meta(SELECTION_META,true);get_tree().change_scene_to_file(LAB_SCENE))
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size=Vector2(318,50);box.add_child(status);lab.hud=status
	if actor.using_original_source:
		var count:=Label.new();count.text="22 semantic states · %d original clips · %d aliases"%[actor.source_clip_count,actor.source_alias_count];box.add_child(count)
		var calibration:=Label.new();calibration.text=actor.cadence_label;calibration.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;calibration.custom_minimum_size.x=318;calibration.add_theme_font_size_override("font_size",11);box.add_child(calibration)
	var hints:=Label.new();hints.text=("WASD normal7 · Shift slow Walk · Space jump" if actor.using_original_source else "WASD walk · Shift run · Space jump")+"\nLMB / E: three-hit combo (hold or tap)\nRMB: combat strafe + mouse ground aim\nQ / C: turn · Middle drag: orbit · Wheel: zoom\nR reset · V grass overview";box.add_child(hints)
	actions=OptionButton.new();actions.name="AuthoredActionSelector";actions.focus_mode=Control.FOCUS_NONE
	for key:String in actor.clips:
		actions.add_item(action_caption(key));actions.set_item_metadata(actions.item_count-1,key)
	box.add_child(actions);actions.item_selected.connect(func(index:int):actor.review(String(actions.get_item_metadata(index))))
	var row:=HBoxContainer.new();box.add_child(row)
	var play:=_button("Review selected",row);play.pressed.connect(func():actor.review(String(actions.get_item_metadata(actions.selected))))
	var resume:=_button("Resume gameplay",row);resume.pressed.connect(actor.resume_gameplay)
	var loop:=CheckButton.new();loop.text="Loop review";loop.button_pressed=true;loop.focus_mode=Control.FOCUS_NONE;box.add_child(loop);loop.toggled.connect(func(value:bool):actor.review_loop=value)
	row=HBoxContainer.new();box.add_child(row)
	expression=OptionButton.new();expression.name="FaceExpressionSelector";expression.focus_mode=Control.FOCUS_NONE
	for label:String in ["Face: Source" if actor.using_original_source else "Face: Auto","Face: Neutral","Face: Focused"]:expression.add_item(label)
	row.add_child(expression);expression.item_selected.connect(func(index:int):actor.expression_mode=index)
	var blink:=_button("Blink",row);blink.pressed.connect(actor.force_blink)
	row=HBoxContainer.new();box.add_child(row)
	var vfx:=CheckButton.new();vfx.text="Blade trails";vfx.button_pressed=true;vfx.focus_mode=Control.FOCUS_NONE;row.add_child(vfx);vfx.toggled.connect(func(value:bool):effects.enabled=value)
	var reset_button:=_button("Reset",row);reset_button.pressed.connect(reset)
	if actor.using_original_source:
		var direction:=CheckButton.new();direction.text="Locomotion direction adapter";direction.button_pressed=actor.locomotion_direction_enabled;direction.focus_mode=Control.FOCUS_NONE;box.add_child(direction);direction.toggled.connect(actor.set_locomotion_direction_adapter)
	if reference_audio!=null:
		var audio:=CheckButton.new();audio.text="Original Sabre samples";audio.tooltip_text="Prototype sample mix and trigger timing; original Wwise graph not recovered.";audio.button_pressed=true;audio.disabled=reference_audio.available_count==0;audio.focus_mode=Control.FOCUS_NONE;box.add_child(audio);audio.toggled.connect(func(value:bool):reference_audio.enabled=value)
	if actor.using_private_skin:
		row=HBoxContainer.new();box.add_child(row)
		var reflect:=CheckButton.new();reflect.name="LocalReflectionCheckbox";reflect.text="Local sky reflections";reflect.button_pressed=true;reflect.focus_mode=Control.FOCUS_NONE;row.add_child(reflect)
		reflect.toggled.connect(func(value:bool):
			reflections_enabled=value
			if value:refresh_reflections()
			elif reflection_probe!=null:reflection_probe.free();reflection_probe=null)
		var refresh:=_button("Refresh",row);refresh.tooltip_text="Refresh the actor-only sky capture after lighting changes.";refresh.pressed.connect(refresh_reflections)
	var note:=Label.new();note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.custom_minimum_size.x=318
	note.text="Original source tracks; ready/strafe states reuse Idle/Walk/Run. Sabre mount/family, input, VFX and audio mix are adapters. Source weapon scale retained; no whiff hitstop." if actor.using_original_source else "New curves informed by measured motion. Sabre assignment/input/VFX timing inferred. Attack travel reduced; no lower-body blend or hitstop."
	note.add_theme_font_size_override("font_size",11);box.add_child(note)
	var back:=_button("Return to original Rifle / Sword lab",box);back.name="ReturnOriginalLabButton";back.pressed.connect(func():
		release_inputs();get_tree().set_meta(SELECTION_META,false);get_tree().change_scene_to_file(LAB_SCENE))
func _button(label:String,parent:Node)->Button:
	var button:=Button.new();button.text=label;button.focus_mode=Control.FOCUS_NONE;parent.add_child(button);return button
func action_caption(key:String)->String:
	if actor.using_original_source and actor.clips[key].get("source_alias_adapter",false):return key+" ("+String(actor.clips[key].source_name).trim_prefix("Player_Master_")+" alias)"
	return key
func refresh_reflections()->void:
	if not reflections_enabled or not actor.using_private_skin:return
	if reflection_probe!=null:reflection_probe.free()
	reflection_probe=ReflectionProbe.new();reflection_probe.name="ActorOnlySkyReflection";reflection_probe.size=Vector3(48,16,48)
	reflection_probe.reflection_mask=2;reflection_probe.cull_mask=1;reflection_probe.blend_distance=2.;reflection_probe.max_distance=32.
	reflection_probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED;reflection_probe.update_mode=ReflectionProbe.UPDATE_ONCE;reflection_probe.enable_shadows=false
	lab.add_child(reflection_probe);reflection_probe.global_position=actor.global_position+Vector3.UP
func _physics_process(_delta:float)->void:
	if actor==null:return
	if actor.using_original_source:actor.set_movement_camera_basis(lab.camera.global_basis)
	if reflection_probe!=null and Vector2(actor.global_position.x-reflection_probe.global_position.x,actor.global_position.z-reflection_probe.global_position.z).length()>12.:refresh_reflections()
	actor.turn_axis=float(_q_held)-float(_c_held)
	actor.combat_requested=_right_held or _q_held or _c_held
	actor.has_aim_point=false
	if _right_held and not (_q_held or _c_held):
		var mouse:Vector2=lab.get_viewport().get_mouse_position()
		var hit:Variant=Plane(Vector3.UP,0.).intersects_ray(lab.camera.project_ray_origin(mouse),lab.camera.project_ray_normal(mouse))
		if hit!=null:actor.aim_point=hit;actor.has_aim_point=true
func present(delta:float)->void:
	effects.present();lab._update_camera(delta,display_position())
	var label:String="Original MD2 player + Sabre (private)" if actor.using_original_source else actor.appearance_label
	status.text="%s\n%s · %.2f units/s\nCombo %d / 3 · accepted %d · ready gates %d"%[label,("REVIEW: "+action_caption(actor.review_clip) if not actor.review_clip.is_empty() else action_caption(actor.active_clip)),actor.current_speed,actor.combo.index+1,actor.accepted_count,actor.impact_count]
func display_position()->Vector3:
	return actor.global_position
func input(event:InputEvent)->void:
	# Release anywhere, including over GUI; only unhandled presses can attack.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT:_left_held=false;actor.attack(_e_held)
		elif event.button_index==MOUSE_BUTTON_RIGHT:_right_held=false;actor.combat_requested=false
		elif event.button_index==MOUSE_BUTTON_MIDDLE:lab.orbiting=false
	if event is InputEventKey and not event.pressed:
		var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_E:_e_held=false;actor.attack(_left_held)
		elif code==KEY_Q:_q_held=false
		elif code==KEY_C:_c_held=false
func unhandled_input(event:InputEvent)->void:
	if event.is_action_pressed("reset_test"):reset();return
	if event is InputEventKey and not event.echo:
		var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_E:_e_held=event.pressed;actor.attack(_e_held or _left_held);get_viewport().set_input_as_handled();return
		if code==KEY_Q:_q_held=event.pressed
		elif code==KEY_C:_c_held=event.pressed
		elif code==KEY_V and event.pressed:lab.grass_overview=not lab.grass_overview;lab._camera_initialized=false
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:_left_held=event.pressed;actor.attack(_left_held or _e_held);get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_RIGHT:_right_held=event.pressed;actor.combat_requested=_right_held
		elif event.button_index==MOUSE_BUTTON_MIDDLE:lab.orbiting=event.pressed
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:lab.camera_size=maxf(3.6,lab.camera_size-.3)
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:lab.camera_size=minf(24.,lab.camera_size+.3)
	if event is InputEventMouseMotion and lab.orbiting:lab.azimuth-=event.relative.x*.006;lab.elevation=clampf(lab.elevation+event.relative.y*.004,.15,.75)
func release_inputs()->void:
	_right_held=false;_left_held=false;_e_held=false;_q_held=false;_c_held=false
	if actor!=null:actor.release_inputs()
	if lab!=null:lab.orbiting=false
	for action:StringName in [&"move_left",&"move_right",&"move_forward",&"move_backward",&"sprint",&"jump"]:Input.action_release(action)
func reset()->void:
	release_inputs();actor.reset_actor();effects.reset()
	if reference_audio!=null:reference_audio.reset()
	if lab.grass_field!=null:lab.grass_field.reset()
	lab._camera_initialized=false;lab._update_camera()
func _exit_tree()->void:
	if actor!=null:actor.release_inputs()
