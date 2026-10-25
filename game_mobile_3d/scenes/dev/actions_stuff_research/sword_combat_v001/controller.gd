extends Node3D
## Sole melee event authority. Physical blade sweeps, local clocks, fixed FX pools.
const State=preload("res://scenes/dev/actions_stuff_research/sword_combat_v001/combat_state.gd")
const Effects=preload("res://scenes/dev/actions_stuff_research/sword_combat_v001/effects.gd")
var state=State.new()
var config:Resource
var lab:Node3D
var player:CharacterBody3D
var visual:Node3D
var encounter:Node3D
var effects:Node3D
var equipped:=false
var held_attack:=false
var stamina:=100.
var vitality:=100
var knockout:=0.
var hits:=0
var swings:=0
var blocks:=0
var parries:=0
var dodges:=0
var damage_received:=0
var whiffs:=0
var freeze_remaining:=0.
var camera_kick:=0.
var camera_clock:=0.
var facing:=0.
var roll_direction:=Vector3.FORWARD
var _seen_serial:=-1
var _hit_ids:Dictionary={}
var _swing_hit:=false
var _feedback_given:=false
var _last_base:=Vector3.ZERO
var _last_tip:=Vector3.ZERO
var _blade_initialized:=false
var _rays:=PhysicsRayQueryParameters3D.new()
var _rows:Array[Array]=[]
var _candidates:Array[Array]=[]
var panel:PanelContainer
var status:Label
func setup(scene:Node3D,tuning:Resource)->void:
	lab=scene;player=scene.player;visual=player.visual;encounter=scene.zombie_combat;config=tuning.duplicate()
	state.buffer_seconds=config.buffer_seconds;state.parry_window=config.parry_window
	player.melee_controller=self;visual.melee=self
	effects=Effects.new();effects.name="OriginalSwordEffects";add_child(effects);effects.quality=config.effects_quality;effects.intensity=config.effects_intensity;effects.setup()
	_rays.collision_mask=1;_rays.exclude=[player.get_rid()]
	_build_controls()
func _build_controls()->void:
	var canvas:=CanvasLayer.new();add_child(canvas)
	panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);panel.position=Vector2(-290,-116);panel.size=Vector2(580,100);canvas.add_child(panel)
	var box:=VBoxContainer.new();panel.add_child(box);status=Label.new();status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status.add_theme_font_size_override("font_size",15);box.add_child(status)
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;box.add_child(row)
	for label in ["Tab · Rifle / Sword","E / Click · Attack","RMB · Guard","F · Roll"]:
		var button:=Button.new();button.text=label;button.focus_mode=Control.FOCUS_NONE;row.add_child(button)
		match label:
			"Tab · Rifle / Sword":button.pressed.connect(func():set_equipped(not equipped))
			"E / Click · Attack":button.button_down.connect(func():attack(true));button.button_up.connect(func():attack(false))
			"RMB · Guard":button.button_down.connect(func():guard(true));button.button_up.connect(func():guard(false))
			"F · Roll":button.pressed.connect(roll)
func set_equipped(value:bool)->void:
	if equipped==value:return
	equipped=value;held_attack=false;freeze_remaining=0.;state.cancel();_hit_ids.clear();_blade_initialized=false
	visual.cancel_rifle_recoil();visual.set_rifle_aim(false);visual.auto_aim_target=null;visual.combat_turn_requested=false
	lab._fire_key_held=false;lab._right_aim_held=false;lab.orbiting=false
	lab.rifle_fire.set_trigger(false)
	if lab.rifle_auto_aim!=null:lab.rifle_auto_aim.reset_target()
	visual.sword_equipped=value;visual.sword_model.visible=value;visual.socket.visible=not value;visual.rifle_model.visible=not value
	visual.pose_dirty=true;visual.transition_age=0.;visual.stationary_turn.reset(visual.rotation.y)
	for z in encounter.zombies:
		if is_instance_valid(z) and not z.is_dead:z.attack_damage=12 if value else 0
	if lab.presentation!=null:lab.presentation.reset_history()
func attack(held:bool)->void:
	held_attack=held and equipped
	if held_attack and player.is_on_floor() and knockout<=0.:state.request_attack()
func guard(held:bool)->void:
	if equipped and knockout<=0.:state.request_guard(held)
func roll()->void:
	if not equipped or knockout>0. or not player.is_on_floor() or stamina<config.roll_cost:return
	if not state.request_roll():return
	stamina-=config.roll_cost;dodges+=1
	var stick:Vector2=player.requested_direction if player.scripted_input else Input.get_vector("move_left","move_right","move_forward","move_backward")
	roll_direction=Vector3(stick.x,0,stick.y).normalized() if stick.length()>.1 else forward()
	facing=atan2(roll_direction.x,roll_direction.z)
	effects.dust(player.global_position,1.)
func forward()->Vector3:return Vector3(sin(visual.rotation.y),0,cos(visual.rotation.y))
func _closer(a:Array,b:Array)->bool:return a[0]<b[0]
func _pick_facing()->void:
	var best:=25.;var target:Node3D
	for z in encounter.zombies:
		if not is_instance_valid(z) or z.is_dead:continue
		var d:Vector3=z.global_position-player.global_position;d.y=0.
		if d.length_squared()<best:target=z;best=d.length_squared()
	facing=visual.rotation.y
	if target!=null:
		var d:Vector3=target.global_position-player.global_position;facing=atan2(d.x,d.z)
func before_motion(delta:float)->float:
	if not equipped:return delta
	var paused:=freeze_remaining>0.
	freeze_remaining=maxf(0.,freeze_remaining-delta)
	if knockout>0.:
		knockout=maxf(0.,knockout-delta)
		if knockout==0.:vitality=100;state.cancel()
	stamina=minf(100.,stamina+delta*(config.stamina_regen*.35 if state.state==&"guard" else config.stamina_regen))
	if held_attack and knockout<=0. and player.is_on_floor():
		if state.state==&"ready" or (state.state==&"attack" and state.time>=state.chain_open[state.attack_index]-.05):state.request_attack()
	state.tick(delta,config.attack_speed,paused)
	if state.serial!=_seen_serial:
		if _seen_serial>=0 and _swing_hit==false and swings>0 and not _hit_ids.is_empty():whiffs+=1
		_seen_serial=state.serial;visual.pose_dirty=true;visual.transition_age=0.;_blade_initialized=false
		if state.state==&"attack":
			_pick_facing();_hit_ids.clear();_swing_hit=false;_feedback_given=false;swings+=1;effects.swing(state.attack_index)
		elif state.state==&"guard":_pick_facing()
	if paused:
		# Hold one authoritative endpoint; do not replay previous/current interpolation.
		lab.presentation.previous=lab.presentation.current
		return 0.
	return delta
func motion_velocity(desired:Vector2)->Vector2:
	if not equipped:return desired
	if knockout>0. or state.state==&"hurt":return Vector2.ZERO
	if state.state==&"roll":
		var envelope:=1.-smoothstep(.38,.72,state.time) if state.time>.38 else 1.
		return Vector2(roll_direction.x,roll_direction.z)*config.roll_speed*envelope
	if state.state==&"guard" or state.state==&"parry":return desired*.42
	if state.state==&"attack":
		var drive:=sin(PI*clampf((state.time-.10)/.30,0.,1.))*(1.2 if state.attack_index<2 else 1.65)
		return desired*.35+Vector2(sin(facing),cos(facing))*drive
	return desired
func locks_jump()->bool:return equipped and state.state in [&"attack",&"roll",&"hurt",&"parry"]
static func segment_distance_squared(a:Vector3,b:Vector3,c:Vector3,d:Vector3)->float:
	var u:=b-a;var v:=d-c;var w:=a-c
	var aa:=u.dot(u);var bb:=u.dot(v);var cc:=v.dot(v);var dd:=u.dot(w);var ee:=v.dot(w)
	var den:=aa*cc-bb*bb
	var s:=clampf((bb*ee-cc*dd)/den,0.,1.) if den>.0000001 else 0.
	var t:=clampf((bb*s+ee)/maxf(cc,.0000001),0.,1.)
	s=clampf((bb*t-dd)/maxf(aa,.0000001),0.,1.)
	t=clampf((bb*s+ee)/maxf(cc,.0000001),0.,1.)
	return (a+u*s-c-v*t).length_squared()
func after_pose()->void:
	if not equipped:return
	var sword:Transform3D=visual.sword_world()
	var base:Vector3=sword*visual.sword_base_local;var tip:Vector3=sword*visual.sword_tip_local
	if not _blade_initialized:_last_base=base;_last_tip=tip;_blade_initialized=true
	if state.overlaps_active() and _hit_ids.size()<config.targets_per_swing:
		var span:=maxf(state.time-state.previous_time,.000001)
		var lo:=clampf((state.active_start[state.attack_index]-state.previous_time)/span,0.,1.)
		var hi:=clampf((state.active_end[state.attack_index]-state.previous_time)/span,0.,1.)
		_sweep(_last_base.lerp(base,lo),_last_tip.lerp(tip,lo),_last_base.lerp(base,hi),_last_tip.lerp(tip,hi))
	_last_base=base;_last_tip=tip
func _sweep(a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
	_candidates.clear()
	for z in encounter.zombies:
		if not is_instance_valid(z) or z.is_dead or _hit_ids.has(z.get_instance_id()):continue
		var dist:float=z.global_position.distance_squared_to(player.global_position)
		if dist>config.broadphase_reach*config.broadphase_reach:continue
		var low:Vector3=z.global_position+Vector3(0,.35,0);var high:=low+Vector3(0,1.1,0)
		var rr:float=pow(.30+config.blade_radius,2)
		if minf(minf(segment_distance_squared(a,b,low,high),segment_distance_squared(c,d,low,high)),minf(segment_distance_squared(b,d,low,high),segment_distance_squared((a+c)*.5,(b+d)*.5,low,high)))>rr:continue
		if _candidates.size()==_rows.size():_rows.append([0.,null])
		var row:Array=_rows[_candidates.size()];row[0]=dist;row[1]=z;_candidates.append(row)
	_candidates.sort_custom(_closer)
	for row in _candidates:
		if _hit_ids.size()>=config.targets_per_swing:break
		var z:CharacterBody3D=row[1]
		_rays.from=player.global_position+Vector3(0,1.0,0);_rays.to=z.global_position+Vector3(0,1.0,0)
		if not player.get_world_3d().direct_space_state.intersect_ray(_rays).is_empty():continue
		var direction:=z.global_position-player.global_position;direction.y=0.;direction=direction.normalized()
		var breaking:bool=z.get("poise")!=null and z.poise<=config.poise_damage[state.attack_index]
		var accepted:bool=z.apply_melee_hit(config.damage[state.attack_index],direction,config.poise_damage[state.attack_index],2.8 if state.attack_index==2 else 1.8,config.hit_stop) if z.has_method("apply_melee_hit") else z.take_damage(config.damage[state.attack_index],direction)
		if not accepted:continue
		_hit_ids[z.get_instance_id()]=true;hits+=1;_swing_hit=true
		var point:Vector3=(a+b+c+d)*.25;point=point.lerp(z.global_position+Vector3(0,1.0,0),.6)
		effects.impact(point,direction,state.attack_index==2,breaking)
		if not _feedback_given:
			freeze_remaining=maxf(freeze_remaining,config.finisher_hit_stop if state.attack_index==2 else config.hit_stop)
			camera_kick=maxf(camera_kick,config.finisher_camera_impulse if state.attack_index==2 else config.camera_impulse);_feedback_given=true
func receive_attack(amount:int,direction:Vector3,attacker:Node3D)->bool:
	if not equipped or amount<=0 or knockout>0.:return false
	if state.invulnerable():return false
	var toward:=-direction;toward.y=0.
	var front:=forward().dot(toward.normalized())>cos(deg_to_rad(70.))
	if front and state.state==&"guard":
		if state.can_parry():
			parries+=1;stamina=minf(100.,stamina+12.);state.parried()
			if is_instance_valid(attacker) and attacker.has_method("parry_stagger"):attacker.parry_stagger()
			effects.defense(player.global_position+forward()*.55+Vector3.UP*1.1,true);freeze_remaining=.045;camera_kick=.045;return false
		blocks+=1;stamina=maxf(0.,stamina-config.guard_cost);effects.defense(player.global_position+forward()*.55+Vector3.UP*1.1,false)
		if stamina<=0.:state.hurt(.65);effects.impact(player.global_position+Vector3.UP,forward(),false,true)
		return false
	vitality=maxi(0,vitality-amount);damage_received+=amount;state.hurt();held_attack=false
	visual.flash_hit();visual.hit_impulse(direction);camera_kick=.05
	if vitality==0:knockout=1.4
	return true
func present(delta:float)->void:
	camera_clock+=delta;camera_kick*=exp(-18.*delta)
	if equipped:
		var sword:Transform3D=lab.presentation.display_sword
		effects.set_trail(sword*visual.sword_base_local,sword*visual.sword_tip_local,state.state==&"attack" and state.time>=state.active_start[state.attack_index]-.06 and state.time<=state.active_end[state.attack_index]+.08,state.attack_index==2)
	else:effects.set_trail(Vector3.ZERO,Vector3.ZERO,false)
	status.text=("SWORD · %s · Combo %d/3 · HP %d · Stamina %d · Hits %d · Parries %d"%[state.state.to_upper(),state.attack_index+1,vitality,roundi(stamina),hits,parries]) if equipped else "RIFLE · Infinite ammo · Hold E to aim/fire · Tab equips Sword"
	if knockout>0.:status.text="PRACTICE KNOCKDOWN · recovering…"
func camera_offset()->Vector2:return Vector2(sin(camera_clock*113.),cos(camera_clock*89.))*camera_kick
func reset_combat()->void:
	state.reset();held_attack=false;freeze_remaining=0.;camera_kick=0.;_hit_ids.clear();_blade_initialized=false
	stamina=100.;vitality=100;knockout=0.;hits=0;swings=0;blocks=0;parries=0;dodges=0;damage_received=0;_seen_serial=-1;effects.reset()
