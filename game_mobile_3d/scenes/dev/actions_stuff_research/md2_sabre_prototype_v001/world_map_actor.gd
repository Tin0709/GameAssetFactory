extends "res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd"
## Map adapter only. Source controller, clips and skeleton remain unchanged.
const FX=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/effects.gd")
const AUDIO=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const PRESENTER=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/render_presenter.gd")
var lantern:Node3D
var _idle_wait:=0.
var _inspect_age:=0.
var _inspecting:=false
var is_dead:=false
var aerial_melee_enabled := true
var _default_weapon_clips: Dictionary
var _default_weapon_gait: RefCounted
var smooth_step_active:=false
var jump_active:bool:
	get:return _jump_stage in ["JumpTakeoff","JumpAirborne"]
var _landed:bool:
	get:return _jump_stage=="JumpLanding"
var render_presenter:Node
var reference_audio:Node
var environment_audio:Node3D
var primary_ready:=false
var _left:=false
var _e:=false
var _right:=false
var _q:=false
var _c:=false

func _ready()->void:
	prefer_private_skin=true
	super._ready()
	primary_ready=using_original_source and hybrid_motion!=null
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_priority=-20
	effects=FX.new();effects.name="SabreEffects";effects.top_level=true
	add_child(effects);effects.global_transform=Transform3D.IDENTITY
	if using_original_source:
		render_presenter=PRESENTER.new();render_presenter.name="SourceRenderPresentation"
		add_child(render_presenter);render_presenter.setup(self)
		reference_audio=AUDIO.new();reference_audio.name="PrivateReferenceAudio";add_child(reference_audio)
		var research:=OS.get_environment("MD2_RESEARCH_ROOT")
		if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
		reference_audio.setup(research)
		attack_accepted_timed.connect(reference_audio.trigger_attack)
		reference_audio.timeline_provider=func()->float:return simulation_clock
		reference_audio.clip_play_rates={"Attack1":1.2,"Attack2":1.2,"Attack3":1.,"AirAttack":combo.air_attack_play_rate}
		for key:String in clips:
			var alias:String=clips[key].get("audio_alias","")
			if not alias.is_empty():reference_audio.clip_aliases[key]=alias
		reference_audio.is_event_valid=func(serial:int)->bool:return combo.serial==serial and combo.active() and review_clip.is_empty()
	if primary_ready:
		lantern=preload("res://scripts/world_map_player_lantern.gd").new();lantern.name="PrivateHipLantern"
		model.add_child(lantern);lantern.setup(self)
		presentation_reset.connect(func():_idle_wait=0.;_inspect_age=0.;_inspecting=false)
	if not primary_ready:
		push_error("Primary A&S/MD2+Sabre is unavailable. External private source/hybrid data required; fallback is NOT the selected player.")
		set_physics_process(false);set_process_input(false);set_process_unhandled_input(false)

func _select_clip()->String:
	var selected:=super._select_clip()
	if selected!="Idle" or _move_requested or not _grounded or not review_clip.is_empty():
		_idle_wait=0.;_inspecting=false;_inspect_age=0.;return selected
	if _inspecting:return "InspectWeapon"
	if _idle_wait>=6. and clips.has("InspectWeapon"):
		_inspecting=true;_inspect_age=0.;return "InspectWeapon"
	return selected

func _animate(delta:float)->void:
	if _inspecting:
		_inspect_age+=delta
		if clips.has("InspectWeapon") and _inspect_age>=float(clips.InspectWeapon.duration):
			_inspecting=false;_inspect_age=0.;_idle_wait=-8.
	else:_idle_wait+=delta
	super._animate(delta)

func _live_movement_input_enabled() -> bool:
	return not (get_viewport().gui_get_focus_owner() is LineEdit)

func _physics_process(delta:float)->void:
	if is_dead:
		if not is_on_floor():
			velocity.y -= gravity * delta
			move_and_slide()
			physics_pose_ready.emit()
		return
	var camera:=get_viewport().get_camera_3d()
	if camera!=null:set_movement_camera_basis(camera.global_basis)
	turn_axis=float(_q)-float(_c);combat_requested=_right or _q or _c;has_aim_point=false
	if _right and not (_q or _c) and camera!=null:
		var mouse:=get_viewport().get_mouse_position()
		var hit:Variant=Plane(Vector3.UP,global_position.y).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
		if hit!=null:aim_point=hit;has_aim_point=true
	super._physics_process(delta)

func _process(_delta:float)->void:
	if render_presenter==null:return
	var world:=get_parent().get_parent()
	render_presenter.enabled=world.presentation.enabled
	render_presenter.prepare(Engine.get_physics_interpolation_fraction())
	effects.present(render_presenter.display_clock,render_presenter.display_marker(marker_base).origin,render_presenter.display_marker(marker_tip).origin)

func showcase_display_position()->Vector3:
	return render_presenter.display_actor if render_presenter!=null else global_position

func setup_world_audio(world:Node3D)->void:
	if not primary_ready:return
	var script=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/world_map_audio.gd")
	environment_audio=script.new();environment_audio.name="ShowcaseAmbientAudio"
	world.add_child(environment_audio)
	var research:=OS.get_environment("MD2_RESEARCH_ROOT")
	if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
	environment_audio.setup(world,research)

func setup_world_vegetation(world:Node3D)->Node3D:
	if not primary_ready:return null
	var script=load("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/world_map_plants.gd")
	var plants:Node3D=script.new();plants.name="PrivateGrassFlowers"
	world.add_child(plants);plants.setup_world(world)
	return plants

func cancel_jump()->void:
	_reset_map_actor_at(global_position)

func set_weapon_locomotion(profile: Dictionary) -> void:
	var use_source := not profile.is_empty()
	if weapon_source_locomotion == use_source:
		return
	if _default_weapon_clips.is_empty():
		_default_weapon_gait = source_gait
		for slot: String in profile.clips:
			_default_weapon_clips[slot] = clips[slot]
	var replacements: Dictionary = profile.clips if use_source else _default_weapon_clips
	for slot: String in replacements:
		clips[slot] = replacements[slot]
	source_gait = profile.gait if use_source else _default_weapon_gait
	weapon_source_locomotion = use_source
	# The logical state may stay Idle or Run while its assigned clip changes.
	active_clip = ""
	_idle_wait = 0.0
	_inspecting = false
	_inspect_age = 0.0
	if foot_placement != null:
		foot_placement.clear()
	if novelty_jump != null:
		novelty_jump.cancel()

func attack(value: bool) -> void:
	if value and not aerial_melee_enabled and not _grounded:
		return
	super.attack(value)

func enter_lab_defeat() -> void:
	is_dead = true
	set_process_input(false)
	set_process_unhandled_input(false)
	# Reset the pose, combo and presentation at the point of defeat.
	_reset_map_actor_at(global_position, visual.rotation.y)

func drop_for_lab(height: float) -> bool:
	if not is_on_floor():
		return false
	_reset_map_actor_at(global_position + Vector3.UP * height, visual.rotation.y)
	_floor_initialized = true
	return true

func _reset_map_actor_at(at: Vector3, yaw: float = 0.0) -> void:
	reset_actor();global_position=at;velocity=Vector3.ZERO
	visual.rotation.y = yaw
	if hybrid_motion != null:
		hybrid_motion.facing.reset(yaw)
	if effects!=null:effects.reset()
	_left=false;_e=false;_right=false;_q=false;_c=false
	if reference_audio!=null:reference_audio.reset()
	reset_physics_interpolation();presentation_reset.emit()

func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_left=false;_e=false;_right=false;_q=false;_c=false;release_inputs()

func _input(event:InputEvent)->void:
	# Releases must reach the controller even when options consume the press.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT:
			note_input_source(&"LMB",false,&"_input");_left=false;attack(_e)
		elif event.button_index==MOUSE_BUTTON_RIGHT:_right=false;combat_requested=false
	if event is InputEventKey and not event.pressed:
		var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_E:note_input_source(&"E",false,&"_input");_e=false;attack(_left)
		elif code==KEY_Q:_q=false
		elif code==KEY_C:_c=false

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventKey and not event.echo:
		var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_E:
			note_input_source(&"E",event.pressed,&"_unhandled_input");_e=event.pressed;attack(_e or _left)
			get_viewport().set_input_as_handled()
		elif code==KEY_Q:_q=event.pressed
		elif code==KEY_C:_c=event.pressed
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			note_input_source(&"LMB",event.pressed,&"_unhandled_input");_left=event.pressed;attack(_left or _e)
			get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_RIGHT:_right=event.pressed
