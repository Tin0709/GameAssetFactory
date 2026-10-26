extends CharacterBody3D
## AnimationPlayer supplies the raw/source pose; the optional grounded gameplay
## adapter then redirects only the two legs. Review bypasses that adapter.
## The expression controller writes only the two face morph scalars.
signal attack_accepted(index:int,clip:String,serial:int)
signal impact_ready(index:int,base:Vector3,tip:Vector3,serial:int)
signal physics_pose_ready
signal presentation_reset
const Model=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/assets/Sabre_Character_Authored.glb")
const Combo=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/combo_state.gd")
const DirectionAdapter=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/locomotion_direction.gd")
const MovementMeter=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/movement_meter.gd")
const MANIFEST:="res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/assets/manifest.json"
const GAITS:=["Walk","Run","StrafeLeft","StrafeRight","CombatWalk","CombatRun","CombatStrafeLeft","CombatStrafeRight"]
var combo=Combo.new()
var clips:Dictionary={}
var visual:Node3D
var model:Node3D
var prefer_private_skin:=true
var using_private_skin:=false
var using_original_source:=false
var private_metadata:Dictionary={}
var source_clip_count:=0
var source_alias_count:=0
var appearance_label:="Authored fallback"
var private_model_path_override:=""
var animation_player:AnimationPlayer
var skeleton:Skeleton3D
var face:MeshInstance3D
var marker_grip:Node3D
var marker_base:Node3D
var marker_tip:Node3D
var _weapon_attachment:BoneAttachment3D
var effects:Node3D
var direction_adapter:RefCounted
var locomotion_direction_enabled:=true
var cadence_label:=""
var current_speed:=0.
var walk_speed:=2.16
var run_speed:=6.0372
var acceleration:=48.
var deceleration:=42.
var gravity:=18.
var jump_height:=1.2
var coyote_time:=0.
var _time_since_grounded:=INF
var _movement_right:=Vector2.RIGHT
var _movement_back:=Vector2.DOWN
# Measured source stride references are independent of gameplay target speed.
var walk_stride_speed:=2.
var run_stride_speed:=5.6
var scripted_input:=false
var requested_direction:=Vector2.ZERO
var requested_run:=false
var requested_jump:=false
var combat_requested:=false
var turn_axis:=0.
var aim_point:=Vector3.ZERO
var has_aim_point:=false
var expression_mode:=0 # Auto, Neutral, Focused.
var focus_value:=0.
var blink_value:=0.
var expression_clock:=0.
var review_clip:=""
var review_loop:=true
var active_clip:=""
var simulation_clock:=0.
var accepted_count:=0
var impact_count:=0
var _focus_index:=-1
var _blink_index:=-1
var _forced_blink:=0.
var _jump_held:=false
var _jump_stage:=""
var _jump_time:=0.
var _transition:=""
var _transition_time:=0.
var _review_time:=0.
var _move_requested:=false
var _run_requested:=false
var _last_run_gait:=false
var _grounded:=false
var _floor_initialized:=false
var _previous_combat:=false
var _playback_speed:=1.
var movement_meter=MovementMeter.new()
var _gait_cycles_this_tick:=0.

func _ready()->void:
	collision_layer=2;collision_mask=1;add_to_group("player")
	var shape:=CapsuleShape3D.new();shape.radius=.3;shape.height=2.0
	var collision:=CollisionShape3D.new();collision.name="BodyCollision";collision.shape=shape;collision.position.y=1.;add_child(collision)
	visual=Node3D.new();visual.name="Visual";add_child(visual)
	if prefer_private_skin:
		model=load_private_model(private_model_path())
		using_private_skin=model!=null
	if model==null:model=Model.instantiate()
	if using_private_skin and FileAccess.file_exists(private_model_path().get_basename()+".json"):
		private_metadata=JSON.parse_string(FileAccess.get_file_as_string(private_model_path().get_basename()+".json"))
		using_original_source=private_metadata.get("schema","")=="md2-private-original-source-bundle/1"
	appearance_label=String(private_metadata.get("appearance_label","MD2 Valorie skin / reconstructed motion")) if using_private_skin else "Authored fallback"
	visual.add_child(model)
	for node:Node in model.find_children("*","",true,false):
		if node is AnimationPlayer:animation_player=node
		elif node is Skeleton3D:skeleton=node
		elif node is MeshInstance3D:
			if node.mesh.get_blend_shape_count()>0:face=node
			for surface in node.mesh.get_surface_count():
				var material:=node.mesh.surface_get_material(surface) as BaseMaterial3D
				if material:material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		if node.name=="SabreGrip":marker_grip=node
		elif node.name=="SabreBladeBase":marker_base=node
		elif node.name=="SabreBladeTip":marker_tip=node
	assert(animation_player!=null and skeleton!=null and face!=null,"Authored GLB contains rig, player and face")
	assert(marker_grip!=null and marker_base!=null and marker_tip!=null,"Real exported blade markers are required")
	_weapon_attachment=marker_grip.get_parent() as BoneAttachment3D
	clips=private_metadata.clips if using_original_source else JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)).clips
	if using_original_source:
		var unique_sources:Dictionary={}
		for entry:Dictionary in clips.values():
			unique_sources[entry.source_name]=true
			if entry.get("source_alias_adapter",false):source_alias_count+=1
		source_clip_count=unique_sources.size()
		# Public DT_PlayerDefinition#0: MovementSpeed700, multiplier1, coyote.155.
		# Standard100UU/m conversion; local effective runtime values unverified.
		# Slow Walk and stride references remain disclosed study adapters.
		walk_speed=2.;run_speed=700./100.;coyote_time=.155
		gravity=15. # Existing ballistic approximation; NOT inferred native physics.
		cadence_label="Table700 ×1 /100 =7 units/s · runtime unverified\nGait follows travel/stride · review1x"
		direction_adapter=DirectionAdapter.new();direction_adapter.setup(skeleton,model)
	combo.setup(clips)
	animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key:String in clips:
		var animation:=animation_player.get_animation(clips[key].action)
		assert(animation!=null,"Missing authored action "+key)
		animation.loop_mode=Animation.LOOP_LINEAR if clips[key].loop else Animation.LOOP_NONE
	for index in face.mesh.get_blend_shape_count():
		if face.mesh.get_blend_shape_name(index)=="Focused":_focus_index=index
		elif face.mesh.get_blend_shape_name(index)=="Blink":_blink_index=index
	assert(_focus_index>=0 and _blink_index>=0,"Imported face morph names preserved")
	visual.rotation.y=0. # Authored +Z front initially faces the existing lab camera.
	_play("Idle",0.);_apply_face(0.)
	movement_meter.reset(global_position)

func private_model_path()->String:
	if not private_model_path_override.is_empty():return private_model_path_override
	var research_root:=OS.get_environment("MD2_RESEARCH_ROOT")
	if research_root.is_empty():research_root="C:/Users/ADMIN/Desktop/MD2 Research"
	var source:=research_root.path_join("blender/prototype_sabre/MD2_Valorie_Sabre_Source.glb")
	if FileAccess.file_exists(source) and FileAccess.file_exists(source.get_basename()+".json"):return source
	return research_root.path_join("blender/prototype_sabre/MD2_Valorie_Sabre_Private.glb")
static func load_private_model(path:String)->Node3D:
	# Parse directly into transient in-memory resources. No ResourceSaver,
	# editor importer, texture extraction, or project cache is used for this file.
	if not path.is_absolute_path() or not FileAccess.file_exists(path):return null
	var project_root:=ProjectSettings.globalize_path("res://").replace("\\","/").simplify_path().trim_suffix("/").to_lower()+"/"
	if path.replace("\\","/").simplify_path().to_lower().begins_with(project_root):
		push_warning("Private reference must remain outside the game project");return null
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	state.handle_binary_image_mode=GLTFState.HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED
	var error:=document.append_from_file(path,state)
	if error!=OK:push_warning("External private appearance could not load: "+str(error));return null
	return document.generate_scene(state,120.)

func _physics_process(delta:float)->void:
	var stick:=requested_direction if scripted_input else Input.get_vector("move_left","move_right","move_forward","move_backward")
	if not scripted_input:stick=_movement_right*stick.x+_movement_back*stick.y
	var sprint:=requested_run if scripted_input else Input.is_action_pressed("sprint")
	var jump_down:=requested_jump if scripted_input else Input.is_action_pressed("jump")
	var jump_pressed:=jump_down and not _jump_held;_jump_held=jump_down
	# Human source controls use ordinary full-speed movement, with Shift as a
	# slow study modifier. Explicit scripted Walk/Run and authored controls stay stable.
	_move_requested=not stick.is_zero_approx();_run_requested=(sprint if scripted_input or not using_original_source else not sprint) and _move_requested
	if _move_requested:_last_run_gait=_run_requested
	if _move_requested or jump_pressed:resume_gameplay()
	var was_grounded:=is_on_floor() and velocity.y<=0.
	_time_since_grounded=0. if was_grounded else _time_since_grounded+delta
	var speed:=run_speed if _run_requested else walk_speed
	var desired:=stick.limit_length()*speed
	# Preserve authored full-body attacks. Travel is reduced rather than blending
	# over their legs; this adapter can still exhibit some moving-attack foot slip.
	if combo.active() and was_grounded:desired*=.22
	var planar:=Vector2(velocity.x,velocity.z).move_toward(desired,(deceleration if stick.is_zero_approx() else acceleration)*delta)
	velocity=Vector3(planar.x,-.2 if was_grounded else velocity.y-gravity*delta,planar.y)
	if jump_pressed and (was_grounded or (using_original_source and _time_since_grounded<=coyote_time)):
		combo.cancel();velocity.y=sqrt(2.*gravity*jump_height)-(gravity*delta*.5 if using_original_source else 0.);_jump_stage="JumpTakeoff";_jump_time=0.
		_time_since_grounded=INF # Consume the coyote opportunity; no second air jump.
	move_and_slide();_grounded=is_on_floor() and velocity.y<=0.
	if _grounded and not was_grounded and _floor_initialized and _jump_stage!="JumpLanding":_jump_stage="JumpLanding";_jump_time=0.
	elif not _grounded and _jump_stage.is_empty():_jump_stage="JumpAirborne";_jump_time=0.
	_floor_initialized=_floor_initialized or _grounded
	current_speed=Vector2(get_real_velocity().x,get_real_velocity().z).length()
	var facing:=visual.rotation.y
	if not combo.active():
		if combat_requested:
			if has_aim_point:
				var look:=aim_point-global_position
				if Vector2(look.x,look.z).length()>.1:facing=atan2(look.x,look.z)
			else:facing+=turn_axis*2.8*delta
		elif _move_requested:facing=atan2(stick.x,stick.y)
		visual.rotation.y+=clampf(wrapf(facing-visual.rotation.y,-PI,PI),-12.*delta,12.*delta)
	if combat_requested!=_previous_combat:
		_transition="" if using_original_source else ("ReadyEnter" if combat_requested else "ReadyExit");_transition_time=0.;_previous_combat=combat_requested
	var left:=delta
	_gait_cycles_this_tick=0.
	while left>.00000001:
		var step:=minf(left,1./120.)
		if combo.active():step=minf(step,combo.remaining())
		if step<.00000001:combo.advance(.00000001);continue
		_animate(step);left-=step
	var soles:Array=direction_adapter.observe_soles(global_position.y,_grounded and review_clip.is_empty() and not combo.active()) if direction_adapter!=null else []
	movement_meter.sample(delta,global_position,desired.length(),_move_requested,_gait_cycles_this_tick,soles)
	physics_pose_ready.emit()

func _animate(delta:float)->void:
	if direction_adapter!=null:direction_adapter.restore()
	simulation_clock+=delta;expression_clock+=delta
	var selected:=_select_clip()
	_play(selected)
	_playback_speed=1.
	if review_clip.is_empty() and selected in GAITS:
		var nominal:float=(run_stride_speed if selected in ["Run","CombatRun"] else walk_stride_speed) if using_original_source else (run_speed if _run_requested else walk_speed)
		_playback_speed=maxf(0.,current_speed/nominal) if using_original_source else clampf(current_speed/nominal,.25,1.25)
	animation_player.advance(delta*_playback_speed)
	if review_clip.is_empty() and selected in GAITS:_gait_cycles_this_tick+=delta*_playback_speed/float(clips[selected].duration)
	if not review_clip.is_empty():
		_review_time+=delta
		var duration:float=clips[review_clip].duration
		_review_time=fposmod(_review_time,duration) if review_loop else minf(_review_time,duration)
	else:
		combo.advance(delta)
		if not _jump_stage.is_empty():
			_jump_time+=delta
			if _jump_stage=="JumpTakeoff" and _jump_time>=float(clips.JumpTakeoff.duration):_jump_stage="JumpAirborne";_jump_time-=float(clips.JumpTakeoff.duration)
			elif _jump_stage=="JumpLanding" and _jump_time>=float(clips.JumpLanding.duration):_jump_stage="";_jump_time=0.
		_transition_time+=delta
		if not _transition.is_empty() and _transition_time>=float(clips[_transition].duration):_transition=""
	if direction_adapter!=null:
		var settling:bool=selected in ["Idle","CombatReady"] and absf(direction_adapter.current_yaw)>.0001
		if locomotion_direction_enabled and review_clip.is_empty() and _grounded and not combo.active() and (selected in GAITS or settling):
			direction_adapter.apply(velocity,delta)
		else:direction_adapter.deactivate()
	_refresh_markers()
	_apply_face(delta)
	for event:Dictionary in combo.drain_events():
		if event.kind=="accepted":accepted_count+=1;attack_accepted.emit(event.index,event.clip,event.serial)
		elif event.kind=="impact":impact_count+=1;impact_ready.emit(event.index,marker_base.global_position,marker_tip.global_position,event.serial)
	if effects!=null:
		var active:=false
		if combo.phase in [&"attack",&"air_attack"] and review_clip.is_empty():
			var window:Array=clips[combo.clip()].vfx_window
			active=combo.time>=float(window[0]) and combo.time<=float(window[1])
		effects.sample(delta,active,marker_base.global_position,marker_tip.global_position,combo.serial)

func _refresh_markers()->void:
	skeleton.force_update_all_bone_transforms()
	# Godot's deferred BoneAttachment update runs after the physics callback.
	# Refresh that same imported binding for each substep, retaining its complete
	# pose basis (including source scale/shear) and actual marker child offsets.
	if _weapon_attachment!=null and _weapon_attachment.bone_idx>=0:
		_weapon_attachment.transform=skeleton.get_bone_global_pose(_weapon_attachment.bone_idx)

func _select_clip()->String:
	if not review_clip.is_empty():return review_clip
	if combo.active():return combo.clip()
	if not _jump_stage.is_empty():return _jump_stage
	if _move_requested:
		if combat_requested:
			if using_original_source and _run_requested:return "CombatRun"
			var local:=visual.global_basis.inverse()*velocity
			# This authored rig faces +Z and its anatomical left is +X.
			if absf(local.x)>absf(local.z)*.75:return "CombatStrafeLeft" if local.x>0. else "CombatStrafeRight"
			return "CombatRun" if _run_requested else "CombatWalk"
		return "Run" if _run_requested else "Walk"
	if using_original_source and _grounded and current_speed>.1 and active_clip in GAITS:
		return ("CombatRun" if _last_run_gait else "CombatWalk") if combat_requested else ("Run" if _last_run_gait else "Walk")
	if not _transition.is_empty():return _transition
	return "CombatReady" if combat_requested else "Idle"
func _play(key:String,blend:float=.04)->void:
	var looping:bool=review_loop if not review_clip.is_empty() else bool(clips[key].loop)
	animation_player.get_animation(clips[key].action).loop_mode=Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	if active_clip==key:
		if not review_clip.is_empty() and review_loop and not animation_player.is_playing():animation_player.play(clips[key].action,0.)
		return
	var preserve_phase:bool=using_original_source and review_clip.is_empty() and active_clip in GAITS and key in GAITS
	var phase:=fposmod(animation_player.current_animation_position/float(clips[active_clip].duration),1.) if preserve_phase else 0.
	active_clip=key;animation_player.play(clips[key].action,.08 if preserve_phase else blend);animation_player.advance(0.)
	if preserve_phase:animation_player.seek(phase*float(clips[key].duration),true)
func attack(value:bool)->void:
	if value:resume_gameplay()
	combo.attack(value,not _grounded)
func review(key:String)->void:
	if not clips.has(key):return
	if direction_adapter!=null:direction_adapter.deactivate()
	combo.cancel();release_inputs();review_clip=key;_review_time=0.;active_clip="";_play(key);animation_player.seek(0.,true)
	presentation_reset.emit()
func resume_gameplay()->void:
	if review_clip.is_empty():return
	animation_player.get_animation(clips[review_clip].action).loop_mode=Animation.LOOP_LINEAR if clips[review_clip].loop else Animation.LOOP_NONE
	review_clip="";_review_time=0.;active_clip=""
func force_blink()->void:_forced_blink=.16
func set_locomotion_direction_adapter(value:bool)->void:
	locomotion_direction_enabled=value
	if not value and direction_adapter!=null:direction_adapter.deactivate()
func set_movement_camera_basis(camera_basis:Basis)->void:
	# The installed MD2 WASD reference mod also uses camera-relative input.
	# These vectors are horizontal and orthonormal: diagonals retain unit length.
	var right:=Vector2(camera_basis.x.x,camera_basis.x.z)
	var back:=Vector2(camera_basis.z.x,camera_basis.z.z)
	if right.length_squared()>.0001 and back.length_squared()>.0001:
		_movement_right=right.normalized();_movement_back=back.normalized()
func _apply_face(delta:float)->void:
	var target:=1. if expression_mode==2 or (expression_mode==0 and not using_original_source and (combo.active() or combat_requested)) else 0.
	focus_value=lerpf(focus_value,target,1.-exp(-14.*delta)) if delta>0. else target
	var phase:=fposmod(expression_clock,3.7)
	blink_value=0. if using_original_source else maxf(0.,1.-absf(phase-3.45)/.08)
	if _forced_blink>0.:
		_forced_blink=maxf(0.,_forced_blink-delta);blink_value=maxf(blink_value,1.-absf(_forced_blink-.08)/.08)
	face.set_blend_shape_value(_focus_index,focus_value);face.set_blend_shape_value(_blink_index,blink_value)
func release_inputs()->void:
	combo.release_inputs();combat_requested=false;has_aim_point=false;turn_axis=0.;requested_direction=Vector2.ZERO;requested_run=false;requested_jump=false;_jump_held=false
func reset_actor()->void:
	if direction_adapter!=null:direction_adapter.deactivate()
	release_inputs();combo.cancel();global_position=Vector3.ZERO;velocity=Vector3.ZERO;current_speed=0.
	review_clip="";active_clip="";_jump_stage="";_jump_time=0.;_transition="";_transition_time=0.;_grounded=false;_floor_initialized=false;_previous_combat=false
	accepted_count=0;impact_count=0
	_last_run_gait=false
	_time_since_grounded=INF
	visual.rotation.y=0.;expression_clock=0.;simulation_clock=0.;focus_value=0.;blink_value=0.;_forced_blink=0.
	_play("Idle",0.);_apply_face(0.);reset_physics_interpolation()
	reset_movement_measurements()
	presentation_reset.emit()
func reset_movement_measurements()->void:
	movement_meter.reset(global_position,_move_requested)
func movement_measurements()->Dictionary:
	var report:Dictionary=movement_meter.snapshot()
	report.merge({"clip":active_clip,"play_rate":_playback_speed,"world_velocity":[velocity.x,velocity.y,velocity.z],"walk_speed":walk_speed,"run_speed":run_speed,"walk_stride_reference":walk_stride_speed,"run_stride_reference":run_stride_speed,"source_table_speed":700 if using_original_source else null,"unit_conversion":"100UU per Godot metre; local effective MD2 runtime unverified" if using_original_source else "authored fallback","acceleration_setting":acceleration,"deceleration_setting":deceleration,"turn_rate_adapter":12.,"attack_travel_adapter":.22,"coyote_time":coyote_time,"jump_height_adapter":jump_height,"gravity_adapter":gravity,"native_runtime_parameters_recovered":false})
	return report
func save_movement_measurements()->String:
	var folder:=private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/movement_measurements") if using_private_skin else "user://sabre_movement_measurements"
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:return ""
	var stamp:=Time.get_datetime_string_from_system().replace(":","-")+"-"+str(Time.get_ticks_usec())
	var path:=folder.path_join("movement-"+stamp+".json")
	if FileAccess.file_exists(path):return ""
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return ""
	file.store_string(JSON.stringify(movement_measurements(),"\t"));file.close();return path
