extends CharacterBody3D
## AnimationPlayer supplies the raw/source pose; the optional grounded gameplay
## adapters redirect legs and stabilize spine/head. Review bypasses both.
## The expression controller writes only the two face morph scalars.
signal attack_accepted(index:int,clip:String,serial:int)
signal attack_accepted_timed(index:int,clip:String,serial:int,simulation_time:float)
signal impact_ready(index:int,base:Vector3,tip:Vector3,serial:int)
signal source_locomotion_event(notify:String,clip:String,source_seconds:float,simulation_seconds:float)
signal physics_pose_ready
signal presentation_reset
const Model=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/assets/Sabre_Character_Authored.glb")
const Combo=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/combo_state.gd")
const DirectionAdapter=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/locomotion_direction.gd")
const MovementMeter=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/movement_meter.gd")
const BodyStability=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/locomotion_stability.gd")
const SourceTransition=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/source_transition.gd")
const MANIFEST:="res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/assets/manifest.json"
const GAITS:=["Walk","Run","StrafeLeft","StrafeRight","CombatWalk","CombatRun","CombatStrafeLeft","CombatStrafeRight"]
# User-accepted jump study; native launch/scale recovered, full trajectory pending.
const SOURCE_JUMP_APEX_SECONDS:=.25
const SOURCE_MOVING_LAND_SECONDS:=.05
const COMBAT_STEP_DISTANCE:=.45 # Reconstructed interval; no native value recovered.
const COMBAT_STEP_TIMEOUT:=.30
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
var body_stability_enabled:=true
var body_stability:RefCounted
var source_transition:RefCounted
var cadence_label:=""
var current_speed:=0.
var walk_speed:=2.16
var run_speed:=6.0372
var acceleration:=48.
var deceleration:=42.
var air_acceleration:=48.
var air_deceleration:=42.
var ground_turn_rate:=12.
var runtime_locomotion_profile:Dictionary={}
var source_locomotion_event_count:=0
var last_source_locomotion_event:Dictionary={}
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
var _heavy_slam_active:=false
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
var _gait_resume_phase:=0.
var _step_seen:=-1
var _step_distance:=0.
var _step_elapsed:=0.
var _step_ready:=false

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
		# Table baseline; an external, owner-verified live profile can refine the
		# ground response without placing recovered configuration in the project.
		# Slow Walk and stride references remain disclosed study adapters.
		walk_speed=2.;run_speed=700./100.;coyote_time=.155
		gravity=2.*jump_height/(SOURCE_JUMP_APEX_SECONDS*SOURCE_JUMP_APEX_SECONDS)
		# Preserve the prior aerial strike/flight relationship as the jump is sped
		# up: time scales with sqrt(g). This1.6x is an adapter, not an MD2 rate.
		combo.air_attack_play_rate=sqrt(gravity/15.)
		# Public DT_MeleePropertyDefinition#44 Sabre variants, not a global speedup.
		combo.attack_play_rates=[1.2,1.2,1.]
		combo.movement_breaks_enabled=true
		air_acceleration=acceleration;air_deceleration=deceleration
		runtime_locomotion_profile=read_runtime_locomotion_profile(private_model_path().get_base_dir().path_join("MD2_Locomotion_Runtime.json"))
		if not runtime_locomotion_profile.is_empty():
			var ground:Dictionary=runtime_locomotion_profile.ground
			var units:float=runtime_locomotion_profile.units.centimetres_per_godot_unit
			run_speed=float(ground.speed_cm_s)/units
			acceleration=float(ground.acceleration_cm_s2)/units
			deceleration=float(ground.braking_deceleration_cm_s2)/units
			ground_turn_rate=deg_to_rad(float(ground.yaw_deg_s))
		cadence_label=("Live player700 /100 =7 units/s · ground settings recovered" if not runtime_locomotion_profile.is_empty() else "Table700 /100 =7 units/s · live profile absent")+"\nGait travel/stride adapter · native evaluator rate unresolved"
		direction_adapter=DirectionAdapter.new();direction_adapter.setup(skeleton,model)
	combo.setup(clips)
	animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key:String in clips:
		var animation:=animation_player.get_animation(clips[key].action)
		assert(animation!=null,"Missing authored action "+key)
		animation.loop_mode=Animation.LOOP_LINEAR if clips[key].loop else Animation.LOOP_NONE
	if using_original_source:
		source_transition=SourceTransition.new();source_transition.setup(skeleton)
		body_stability=BodyStability.new();body_stability.setup(skeleton,animation_player,clips)
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
static func read_runtime_locomotion_profile(path:String)->Dictionary:
	# This optional selected-value sidecar stays alongside the private source.
	# All-or-nothing validation prevents a partial/stale profile changing motion.
	if not path.is_absolute_path() or not FileAccess.file_exists(path):return {}
	var project_root:=ProjectSettings.globalize_path("res://").replace("\\","/").simplify_path().trim_suffix("/").to_lower()+"/"
	if path.replace("\\","/").simplify_path().to_lower().begins_with(project_root):return {}
	var decoder:=JSON.new()
	if decoder.parse(FileAccess.get_file_as_string(path))!=OK:return {}
	var decoded:Variant=decoder.data
	if not decoded is Dictionary:return {}
	var data:Dictionary=decoded
	if data.get("schema","")!="md2-private-locomotion-runtime/1" or not data.get("ground") is Dictionary or not data.get("units") is Dictionary:return {}
	var unit:Variant=data.units.get("centimetres_per_godot_unit")
	if not (unit is float or unit is int) or not is_finite(float(unit)) or float(unit)!=100.:return {}
	for key:String in ["speed_cm_s","acceleration_cm_s2","braking_deceleration_cm_s2","yaw_deg_s"]:
		var value:Variant=data.ground.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value)<=0.:return {}
	return data
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
	combo.movement_requested=using_original_source and was_grounded and _move_requested
	if combo.phase==&"step":
		if jump_pressed or not was_grounded:combo.cancel()
		else:
			if _step_seen!=combo.step_serial:
				_step_seen=combo.step_serial;_step_distance=0.;_step_elapsed=0.;_step_ready=false
			# Finish BEFORE movement: a strike cannot start on a moving physics frame.
			if _step_ready or not _move_requested:combo.finish_step()
	# Source attacks are full-body/in-place. An unqueued recovery can yield to
	# movement; a held/buffered combo keeps its authored feet, without fake travel.
	if using_original_source and was_grounded and _move_requested and combo.phase==&"recovery" and not combo.held and combo.buffer_until<combo.clock-.0000001:combo.cancel()
	if using_original_source and not was_grounded and combo.phase==&"air_attack":_heavy_slam_active=true
	_time_since_grounded=0. if was_grounded else _time_since_grounded+delta
	var speed:=run_speed if _run_requested else walk_speed
	var desired:=stick.limit_length()*speed
	var ground_anchor:bool=using_original_source and combo.active() and was_grounded and not jump_pressed
	if ground_anchor:desired=Vector2.ZERO
	elif not using_original_source and combo.active() and was_grounded:desired*=.22 # Authored fallback unchanged.
	var response_acceleration:=air_acceleration if using_original_source and not was_grounded else acceleration
	var response_deceleration:=air_deceleration if using_original_source and not was_grounded else deceleration
	var planar:=Vector2.ZERO if ground_anchor else Vector2(velocity.x,velocity.z).move_toward(desired,(response_deceleration if stick.is_zero_approx() else response_acceleration)*delta)
	# Public GA_HeavyJumpAttack GravityMultiplier2; native base jump remains unknown.
	var gravity_factor:=2. if _heavy_slam_active else 1.
	velocity=Vector3(planar.x,-.2 if was_grounded else velocity.y-gravity*gravity_factor*delta,planar.y)
	if jump_pressed and (was_grounded or (using_original_source and _time_since_grounded<=coyote_time)):
		combo.cancel();velocity.y=sqrt(2.*gravity*jump_height)-(gravity*delta*.5 if using_original_source else 0.);_jump_stage="JumpTakeoff";_jump_time=0.
		_heavy_slam_active=false
		_time_since_grounded=INF # Consume the coyote opportunity; no second air jump.
	var taking_step:bool=combo.phase==&"step"
	var before_move:=global_position
	move_and_slide();_grounded=is_on_floor() and velocity.y<=0.
	if taking_step:
		_step_distance+=Vector2(global_position.x-before_move.x,global_position.z-before_move.z).length();_step_elapsed+=delta
		_step_ready=_step_distance>=COMBAT_STEP_DISTANCE or _step_elapsed>=COMBAT_STEP_TIMEOUT-.0000001
	if _grounded:_heavy_slam_active=false
	# Source pose duration does not define physical flight. The apex (including
	# an interrupted ascent at a ceiling) owns the transition into the air loop.
	if using_original_source and not _grounded and _jump_stage=="JumpTakeoff" and velocity.y<=0.:
		_jump_stage="JumpAirborne";_jump_time=0.
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
		var turn_rate:=ground_turn_rate if _grounded else 12.
		visual.rotation.y+=clampf(wrapf(facing-visual.rotation.y,-PI,PI),-turn_rate*delta,turn_rate*delta)
	if combat_requested!=_previous_combat:
		_transition="" if using_original_source else ("ReadyEnter" if combat_requested else "ReadyExit");_transition_time=0.;_previous_combat=combat_requested
	var left:=delta
	_gait_cycles_this_tick=0.
	while left>.00000001:
		var step:=minf(left,1./120.)
		if combo.active():step=minf(step,combo.remaining()/combo.playback_rate())
		if step<.00000001:combo.advance(.00000001);continue
		_animate(step);left-=step
	var soles:Array=direction_adapter.observe_soles(global_position.y,_grounded and review_clip.is_empty() and not combo.active()) if direction_adapter!=null else []
	movement_meter.sample(delta,global_position,desired.length(),_move_requested,_gait_cycles_this_tick,soles)
	physics_pose_ready.emit()

func _animate(delta:float)->void:
	if body_stability!=null:body_stability.restore()
	if direction_adapter!=null:direction_adapter.restore()
	simulation_clock+=delta;expression_clock+=delta
	var selected:=_select_clip()
	_play(selected)
	_playback_speed=1.
	if review_clip.is_empty() and combo.active():_playback_speed=combo.playback_rate()
	if review_clip.is_empty() and selected in GAITS:
		var nominal:float=(run_stride_speed if selected in ["Run","CombatRun"] else walk_stride_speed) if using_original_source else (run_speed if _run_requested else walk_speed)
		_playback_speed=maxf(0.,current_speed/nominal) if using_original_source else clampf(current_speed/nominal,.25,1.25)
	if source_transition!=null:source_transition.restore()
	var source_before:=animation_player.current_animation_position
	animation_player.advance(delta*_playback_speed)
	if source_transition!=null:source_transition.apply(delta)
	if review_clip.is_empty() and selected in GAITS:
		_dispatch_locomotion_events(selected,source_before,delta*_playback_speed,delta)
		_gait_cycles_this_tick+=delta*_playback_speed/float(clips[selected].duration)
		_gait_resume_phase=fposmod(animation_player.current_animation_position/float(clips[selected].duration),1.)
	if not review_clip.is_empty():
		_review_time+=delta
		var duration:float=clips[review_clip].duration
		_review_time=fposmod(_review_time,duration) if review_loop else minf(_review_time,duration)
	else:
		combo.advance(delta)
		if not _jump_stage.is_empty():
			_jump_time+=delta
			if not using_original_source and _jump_stage=="JumpTakeoff" and _jump_time>=float(clips.JumpTakeoff.duration):_jump_stage="JumpAirborne";_jump_time-=float(clips.JumpTakeoff.duration)
			elif _jump_stage=="JumpLanding":
				var moving_release:bool=using_original_source and _grounded and _move_requested and _jump_time>=SOURCE_MOVING_LAND_SECONDS
				if moving_release or _jump_time>=float(clips.JumpLanding.duration):_jump_stage="";_jump_time=0.
		_transition_time+=delta
		if not _transition.is_empty() and _transition_time>=float(clips[_transition].duration):_transition=""
	if body_stability!=null:
		if body_stability_enabled and review_clip.is_empty() and _grounded and not combo.active() and (selected in GAITS or selected in ["Idle","CombatReady"]):body_stability.apply(selected,delta,selected in GAITS)
		else:body_stability.deactivate()
	if direction_adapter!=null:
		var settling:bool=selected in ["Idle","CombatReady"] and absf(direction_adapter.current_yaw)>.0001
		if locomotion_direction_enabled and review_clip.is_empty() and _grounded and not combo.active() and (selected in GAITS or settling):
			direction_adapter.apply(velocity,delta)
		else:direction_adapter.deactivate()
	_refresh_markers()
	_apply_face(delta)
	for event:Dictionary in combo.drain_events():
		if event.kind=="accepted":
			accepted_count+=1;attack_accepted.emit(event.index,event.clip,event.serial)
			attack_accepted_timed.emit(event.index,event.clip,event.serial,simulation_clock-(combo.clock-float(event.at)))
		elif event.kind=="impact":impact_count+=1;impact_ready.emit(event.index,marker_base.global_position,marker_tip.global_position,event.serial)
	if effects!=null:
		var active:=false
		if combo.phase in [&"attack",&"air_attack"] and review_clip.is_empty():
			var window:Array=clips[combo.clip()].vfx_window
			active=combo.time>=float(window[0]) and combo.time<=float(window[1])
		effects.sample(delta,active,marker_base.global_position,marker_tip.global_position,combo.serial)

func _dispatch_locomotion_events(selected:String,before:float,advanced:float,wall_delta:float)->void:
	# Exact stored notify keys on our selected source clock. This hook does not
	# reproduce UE graph weights, surface selection or the native audio system.
	if advanced<=0. or runtime_locomotion_profile.is_empty():return
	var sources:Variant=runtime_locomotion_profile.get("locomotion_events",{})
	if not sources is Dictionary:return
	var record:Variant=sources.get(String(clips[selected].source_name),{})
	if not record is Dictionary or not record.get("events") is Array:return
	var duration:float=clips[selected].duration
	var stored_duration:Variant=record.get("duration")
	if not (stored_duration is float or stored_duration is int) or not is_finite(float(stored_duration)) or absf(float(stored_duration)-duration)>.001:return
	var end:=before+advanced
	for cycle in range(floori(before/duration),mini(floori(end/duration)+1,129)):
		for entry:Variant in record.events:
			if not entry is Dictionary or not entry.get("time") is float or not entry.get("name") is String:continue
			var source_time:float=entry.time
			if not is_finite(source_time) or source_time<0. or source_time>=duration:continue
			var crossed:=cycle*duration+source_time
			if crossed<=before+.0000001 or crossed>end+.0000001:continue
			var at:=simulation_clock-wall_delta+(crossed-before)/advanced*wall_delta
			source_locomotion_event_count+=1
			last_source_locomotion_event={"name":entry.name,"clip":selected,"source_seconds":source_time,"simulation_seconds":at}
			source_locomotion_event.emit(entry.name,selected,source_time,at)

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
	var resume_step:bool=using_original_source and review_clip.is_empty() and combo.phase==&"step" and key in GAITS
	var phase:=fposmod(animation_player.current_animation_position/float(clips[active_clip].duration),1.) if preserve_phase else (_gait_resume_phase if resume_step else 0.)
	var transition_blend:=.08 if preserve_phase else blend
	if resume_step and not preserve_phase:
		# Gait advances by distance; an80ms source-clock blend would consume most
		# of this short step. Give locomotion the legs within its first20% travel.
		var stride_ref:=run_stride_speed if key in ["Run","CombatRun"] else walk_stride_speed
		transition_blend=minf(blend,COMBAT_STEP_DISTANCE/stride_ref*.2)
	if source_transition!=null:
		if review_clip.is_empty():
			# Retain established aerial/combat handoff durations while removing
			# cadence scaling from locomotion transitions. Source clocks unchanged.
			var rate:float=combo.playback_rate() if combo.active() else 1.
			source_transition.begin(transition_blend/rate)
		else:source_transition.clear()
	# glTF import drops channels that remain equal to the bone rest. A new clip
	# must begin from those defaults, rather than retaining a prior clip's pupil
	# or weapon helper pose. Snapshot the outgoing handoff BEFORE this reset.
	if using_original_source:skeleton.reset_bone_poses()
	active_clip=key;animation_player.play(clips[key].action,0. if source_transition!=null else transition_blend);animation_player.advance(0.)
	if preserve_phase or resume_step:animation_player.seek(phase*float(clips[key].duration),true)
	if source_transition!=null:source_transition.apply(0.)
func attack(value:bool)->void:
	if value:resume_gameplay()
	combo.attack(value,not _grounded)
func review(key:String)->void:
	if not clips.has(key):return
	if body_stability!=null:body_stability.deactivate()
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
func set_body_stability(value:bool)->void:
	body_stability_enabled=value
	if not value and body_stability!=null:body_stability.deactivate()
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
	if body_stability!=null:body_stability.deactivate()
	if direction_adapter!=null:direction_adapter.deactivate()
	if source_transition!=null:source_transition.clear()
	release_inputs();combo.cancel();global_position=Vector3.ZERO;velocity=Vector3.ZERO;current_speed=0.
	review_clip="";active_clip="";_jump_stage="";_jump_time=0.;_heavy_slam_active=false;_transition="";_transition_time=0.;_grounded=false;_floor_initialized=false;_previous_combat=false
	accepted_count=0;impact_count=0
	source_locomotion_event_count=0;last_source_locomotion_event={}
	_last_run_gait=false
	_gait_resume_phase=0.;_step_seen=-1;_step_distance=0.;_step_elapsed=0.;_step_ready=false
	_time_since_grounded=INF
	visual.rotation.y=0.
	# Rebase the direction adapter AFTER resetting the visual's world heading.
	# Otherwise its first new step starts from the previous life's heading.
	if direction_adapter!=null:direction_adapter.deactivate()
	expression_clock=0.;simulation_clock=0.;focus_value=0.;blink_value=0.;_forced_blink=0.
	_play("Idle",0.);_apply_face(0.);reset_physics_interpolation()
	reset_movement_measurements()
	presentation_reset.emit()
func reset_movement_measurements()->void:
	movement_meter.reset(global_position,_move_requested)
func movement_measurements()->Dictionary:
	var report:Dictionary=movement_meter.snapshot()
	if using_original_source:report.merge({"jump_apex_time_adapter":SOURCE_JUMP_APEX_SECONDS,"moving_landing_release_adapter":SOURCE_MOVING_LAND_SECONDS,"heavy_slam_gravity_multiplier":2.,"effective_gravity":gravity*(2. if _heavy_slam_active else 1.),"jump_phase":_jump_stage})
	report.merge({"clip":active_clip,"play_rate":_playback_speed,"world_velocity":[velocity.x,velocity.y,velocity.z],"walk_speed":walk_speed,"run_speed":run_speed,"walk_stride_reference":walk_stride_speed,"run_stride_reference":run_stride_speed,"source_table_speed":700 if using_original_source else null,"unit_conversion":"100UU per Godot metre; local effective MD2 runtime unverified" if using_original_source else "authored fallback","acceleration_setting":acceleration,"deceleration_setting":deceleration,"turn_rate_adapter":12.,"attack_travel_adapter":.22,"coyote_time":coyote_time,"jump_height_adapter":jump_height,"gravity_adapter":gravity,"native_runtime_parameters_recovered":false})
	if using_original_source:report.merge({"attack_travel_adapter":0.,"body_stability_enabled":body_stability_enabled,"retained_body_oscillation_adapter":BodyStability.RETAINED_OSCILLATION,"body_stability_strength":body_stability.strength},true)
	if not runtime_locomotion_profile.is_empty():
		report.merge({"native_runtime_parameters_recovered":true,"unit_conversion":"Live owned player native cm /100 per Godot metre","ground_response_source":"Live reflected component configuration; moving MD2 trace pending","turn_rate_adapter":null,"ground_yaw_rate_deg_s":rad_to_deg(ground_turn_rate),"air_acceleration_adapter":air_acceleration,"air_deceleration_adapter":air_deceleration,"native_animation_evaluator_rate_verified":false,"native_ground_motion_trace_verified":false},true)
		report.merge({"source_locomotion_event_count":source_locomotion_event_count,"last_source_locomotion_event":last_source_locomotion_event.duplicate(),"source_notify_scope":"Stored source times on selected clip; graph weights/surface and native event behavior unresolved"})
	if source_transition!=null:report.merge({"transition_wall_seconds":source_transition.duration,"transition_elapsed_seconds":source_transition.elapsed,"transition_clock":"wall time, independent of source cadence"})
	var actual:=get_real_velocity();var travelling:=Vector2(actual.x,actual.z).length()>.01
	var travel_heading:=atan2(actual.x,actual.z)
	var body_forward:=visual.global_basis*Vector3(0,0,1);var body_heading:=atan2(body_forward.x,body_forward.z)
	report.merge({"source_phase":animation_player.current_animation_position/float(clips[active_clip].duration) if not active_clip.is_empty() else 0.,"body_travel_angle_deg":absf(rad_to_deg(wrapf(body_heading-travel_heading,-PI,PI))) if travelling else null,"legs_travel_angle_deg":absf(rad_to_deg(wrapf(direction_adapter.current_world_yaw-travel_heading,-PI,PI))) if travelling and direction_adapter!=null else null})
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
