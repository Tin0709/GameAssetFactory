extends "res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd"
## Map adapter only. Source controller, clips and skeleton remain unchanged.
const FX=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/effects.gd")
const AUDIO=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const PRESENTER=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/render_presenter.gd")
var is_dead:=false
var smooth_step_active:=false
var jump_active:bool:
	get:return _jump_stage in ["JumpTakeoff","JumpAirborne"]
var _landed:bool:
	get:return _jump_stage=="JumpLanding"
var render_presenter:Node
var reference_audio:Node
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
	if not primary_ready:
		push_error("Primary A&S/MD2+Sabre is unavailable. External private source/hybrid data required; fallback is NOT the selected player.")
		set_physics_process(false);set_process_input(false);set_process_unhandled_input(false)

func _physics_process(delta:float)->void:
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

func cancel_jump()->void:
	var at:=global_position
	reset_actor();global_position=at;velocity=Vector3.ZERO
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
