extends Node
## Third, opt-in mode of the original lab. All environment resources and camera
## remain owned by that lab; no old rifle/private actor is constructed here.
const Actor=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd")
const Effects=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/effects.gd")
const GrassField=preload("res://scenes/dev/actions_stuff_research/grass_md2_v001/grass_field.gd")
const Lighting=preload("res://scenes/dev/actions_stuff_research/lighting_md2_v001/lighting.gd")
const ReferenceAudio=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const RenderPresenter=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/render_presenter.gd")
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
var movement_panel:PanelContainer
var movement_label:Label
var camera_label:Label
var _launch_camera:Dictionary={}
var render_presenter:Node
var native_pixels:=true
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
	_launch_camera={"azimuth":lab.azimuth,"elevation":lab.elevation,"size":lab.camera_size}
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
		reference_audio.setup(research_root);actor.attack_accepted_timed.connect(reference_audio.trigger_attack)
		reference_audio.timeline_provider=func()->float:return actor.simulation_clock
		if actor.using_original_source:reference_audio.clip_play_rates={"Attack1":1.2,"Attack2":1.2,"Attack3":1.}
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
	if actor.using_original_source:
		render_presenter=RenderPresenter.new();render_presenter.name="SourceRenderPresentation";add_child(render_presenter);render_presenter.setup(actor)
	apply_visual_clarity()
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
	var hints:=Label.new();hints.text=("WASD normal7 · Shift slow Walk · Space jump" if actor.using_original_source else "WASD walk · Shift run · Space jump")+"\nLMB / E: combo · in air: downward attack\nRMB: combat strafe + mouse ground aim\nQ / C: turn · Middle drag: orbit · Wheel: zoom\nR reset · V overview · F3 meter · F4 zero · F8 camera";box.add_child(hints)
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
	_build_movement_panel()
func _build_movement_panel()->void:
	movement_panel=PanelContainer.new();movement_panel.name="MovementMeasurements";canvas.add_child(movement_panel)
	movement_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT);movement_panel.offset_left=-420;movement_panel.offset_right=-18;movement_panel.offset_top=-350;movement_panel.offset_bottom=-18
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.035,.045,.9);style.set_content_margin_all(9);style.set_corner_radius_all(5);movement_panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new();movement_panel.add_child(box)
	var heading:=Label.new();heading.text="MOVEMENT METER · actual physics travel";heading.add_theme_font_size_override("font_size",12);box.add_child(heading)
	movement_label=Label.new();movement_label.add_theme_font_size_override("font_size",12);box.add_child(movement_label)
	camera_label=Label.new();camera_label.add_theme_font_size_override("font_size",12);box.add_child(camera_label)
	var row:=HBoxContainer.new();box.add_child(row)
	var zero:=_button("Reset meter · F4",row);zero.pressed.connect(actor.reset_movement_measurements)
	var save:=_button("Save JSON",row);save.tooltip_text="Save aggregate measurements in private Research; no animation/mesh export.";save.pressed.connect(func():
		var path:=save_measurements();save.text="Saved" if not path.is_empty() else "Save failed";save.tooltip_text=path;print("SABRE_MOVEMENT_SAVED ",path))
	var hide:=_button("Hide · F3",row);hide.pressed.connect(func():movement_panel.hide())
	row=HBoxContainer.new();box.add_child(row);var camera_reset:=_button("Reset launch camera · F8",row);camera_reset.pressed.connect(reset_camera)
	if actor.using_original_source:
		row=HBoxContainer.new();box.add_child(row)
		var pixels:=CheckButton.new();pixels.text="Native pixels100%";pixels.button_pressed=true;pixels.focus_mode=Control.FOCUS_NONE;row.add_child(pixels);pixels.toggled.connect(set_native_pixels)
		var smooth:=CheckButton.new();smooth.text="Smooth display";smooth.button_pressed=true;smooth.focus_mode=Control.FOCUS_NONE;row.add_child(smooth);smooth.toggled.connect(func(value:bool):render_presenter.enabled=value)
func set_native_pixels(value:bool)->void:
	native_pixels=value;apply_visual_clarity()
func apply_visual_clarity()->void:
	if not actor.using_original_source:return
	var scale:=1.
	if not native_pixels and lab.md2_lighting!=null:
		scale=float(lab.md2_lighting.original_view.scale) if lab.md2_lighting.original else float(Lighting.TIERS[lab.md2_lighting.quality].scale)
	if not is_equal_approx(lab.get_viewport().scaling_3d_scale,scale):lab.get_viewport().scaling_3d_scale=scale
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
	apply_visual_clarity()
	if render_presenter!=null:render_presenter.prepare(Engine.get_physics_interpolation_fraction())
	if render_presenter!=null:effects.present(render_presenter.display_clock,render_presenter.display_marker(actor.marker_base).origin,render_presenter.display_marker(actor.marker_tip).origin)
	else:effects.present()
	lab._update_camera(delta,display_position())
	var label:String="Original MD2 player + Sabre (private)" if actor.using_original_source else actor.appearance_label
	status.text="%s\n%s · %.2f units/s\nCombo %d / 3 · accepted %d · ready gates %d"%[label,("REVIEW: "+action_caption(actor.review_clip) if not actor.review_clip.is_empty() else action_caption(actor.active_clip)),actor.current_speed,actor.combo.index+1,actor.accepted_count,actor.impact_count]
	if movement_panel.visible:
		var m:Dictionary=actor.movement_measurements()
		var left:String="—" if m.sole_speed[0]<0. else "%.2f"%m.sole_speed[0]
		var right:String="—" if m.sole_speed[1]<0. else "%.2f"%m.sole_speed[1]
		var response:String="—" if m.response_95<0. else "%d ms"%roundi(m.response_95*1000.)
		movement_label.text="Speed %.2f / target %.2f u/s · peak %.2f\nPath %.2f · net %.2f units · %.1f s\nGait %.2f cycles/s · %.3fx · total %.2f\nStart95 %s · stop %.3fu / %.3fs\nSole candidates L %s / R %s u/s\nSole motion includes rolling; native rates unverified"%[m.speed,m.target_speed,m.peak_speed,m.distance,m.net_distance,m.elapsed,m.cycle_hz,m.play_rate,m.gait_cycles,response,m.stop_distance,m.stop_seconds,left,right]
		var c:=camera_measurements()
		camera_label.text="Camera adapter · %s %.2f\nYaw %.2f° · elevation %.2f° · arm %.2fu\nNative MD2 solo camera values unresolved"%[c.projection,c.orthographic_span,c.azimuth_deg,c.elevation_deg,c.arm_distance]
func camera_measurements()->Dictionary:
	var outward:Vector3=lab.camera.global_basis.z
	var target:Vector3=Vector3(0,.5,0) if lab.grass_overview else lab.camera_anchor
	return {"projection":"orthographic" if lab.camera.projection==Camera3D.PROJECTION_ORTHOGONAL else "perspective","orthographic_span":lab.camera.size,"azimuth_deg":rad_to_deg(atan2(outward.x,outward.z)),"elevation_deg":rad_to_deg(asin(clampf(outward.y,-1.,1.))),"arm_distance":lab.camera.global_position.distance_to(target),"viewport_pixels":[int(lab.get_viewport().get_visible_rect().size.x),int(lab.get_viewport().get_visible_rect().size.y)],"horizontal_response_adapter":lab.CAMERA_HORIZONTAL_RESPONSE,"vertical_response_adapter":lab.CAMERA_VERTICAL_RESPONSE,"air_up_zone_adapter":lab.CAMERA_AIR_UP_ZONE,"air_down_zone_adapter":lab.CAMERA_AIR_DOWN_ZONE,"overview":lab.grass_overview,"native_md2_solo_verified":false}
func reset_camera()->void:
	lab.azimuth=float(_launch_camera.azimuth);lab.elevation=float(_launch_camera.elevation);lab.camera_size=float(_launch_camera.size);lab.grass_overview=false;lab.orbiting=false;lab._camera_initialized=false;lab._update_camera(1./60.,display_position())
func save_measurements()->String:
	var path:String=actor.save_movement_measurements()
	if path.is_empty():return ""
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));report["camera"]=camera_measurements()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));return path
func display_position()->Vector3:
	return render_presenter.display_actor if render_presenter!=null else actor.global_position
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
		elif code==KEY_F3 and event.pressed:movement_panel.visible=not movement_panel.visible
		elif code==KEY_F4 and event.pressed:actor.reset_movement_measurements()
		elif code==KEY_F8 and event.pressed:reset_camera()
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
	if render_presenter!=null:render_presenter.reset_history()
	if reference_audio!=null:reference_audio.reset()
	if lab.grass_field!=null:lab.grass_field.reset()
	lab._camera_initialized=false;lab._update_camera()
func _exit_tree()->void:
	if actor!=null:actor.release_inputs()
