extends SceneTree
## Focused production regression contract, written and run RED before integration.
var failures: Array[String]=[]
var checks:=0
var p
var v
var old
var reference_pose_error:=0.0
var legacy_pose_error:=0.0
var clock_error:=0.0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func finish() -> void:
	var result:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"phase_error":clock_error,"legacy_pose_error":legacy_pose_error,"reference_lab_pose_error":reference_pose_error}
	DirAccess.make_dir_recursive_absolute("res://.validation/locomotion_r6p")
	FileAccess.open("res://.validation/locomotion_r6p/focused_validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func run() -> void:
	p=load("res://scenes/characters/CuboidPlayer.tscn").instantiate();root.add_child(p);v=p.visual
	check("locomotion_mode" in v,"Production reference locomotion mode is available")
	check(v.has_method("reference_sample_time"),"Production exposes six samples of one shared phase")
	check(v.samples.has("WalkTurnLeft") and v.samples.has("SprintTurnRight"),"New clips coexist with required production clips")
	if not failures.is_empty():finish();return
	check(v.locomotion_mode==1,"Production defaults to REFERENCE_LOCOMOTION")
	check(p.walk_speed==4.25 and p.run_speed==6.25 and p.combat_move_speed==2.6,"Gameplay speeds unchanged")
	for name in ["Idle","Run","DrawLongGun","HolsterLongGun","LongGunReadyIdle","LongGunReadyRun","Player_Walk"]:check(v.samples.has(name),"Retained animation "+name)
	check(v.find_children("*","Skeleton3D",true,false).size()==1,"One live skeleton")
	var prior=load("res://assets/characters/player_cuboid_animated_v4.glb").instantiate()
	var upgraded=load("res://assets/characters/player_cuboid_animated_v5.glb").instantiate()
	var old_player:AnimationPlayer=prior.find_child("AnimationPlayer",true,false)
	var new_player:AnimationPlayer=upgraded.find_child("AnimationPlayer",true,false)
	for name in old_player.get_animation_list():
		var a:=old_player.get_animation(name);var c:=new_player.get_animation(name)
		check(c!=null and a.length==c.length and a.loop_mode==c.loop_mode and a.get_track_count()==c.get_track_count(),"Prior native clip layout preserved "+name)
		for track in a.get_track_count():
			check(a.track_get_type(track)==c.track_get_type(track) and a.track_get_path(track)==c.track_get_path(track) and a.track_get_key_count(track)==c.track_get_key_count(track),"Prior native tracks preserved")
			for key in a.track_get_key_count(track):check(a.track_get_key_time(track,key)==c.track_get_key_time(track,key) and a.track_get_key_value(track,key)==c.track_get_key_value(track,key),"Prior imported animation keys remain exact")
	prior.free();upgraded.free()
	v.set_process(false);p.get_node("Pistol").set_physics_process(false)
	v.set_weapon_equipped(false)
	var body=load("res://scenes/dev/LocomotionTurningLab.tscn").instantiate();root.add_child(body);body.set_physics_process(false)
	var lab=body.actor;lab.set_review_mode(2)
	for sprint in [false,true]:
		p.fast_sprinting=sprint;v.reference_sprint_weight=1.0 if sprint else 0.0;v.move_weight=1;v.aim_weight=0;v.weapon_hold_weight=0;v.long_gun_weight=0;v.has_target=false;v.recoil_time=100
		for amount in [-1.0,-0.5,0.0,0.5,1.0]:
			for phase_value in [0.0,0.17,0.41,0.72,0.97]:
				v.reference_phase=phase_value;v.reference_turn_amount=amount;v._evaluate(0)
				lab.phase=phase_value;lab.sprint_weight=v.reference_sprint_weight;lab.candidate_turn_amount=amount;lab.evaluate_pose()
				for i in lab.skeleton.get_bone_count():
					var bone_name:String=lab.skeleton.get_bone_name(i);var index:int=v.skeleton.find_bone(bone_name)
					if bone_name=="WeaponCarrier":continue
					var a:Transform3D=v.skeleton.get_bone_global_pose(index);var b:Transform3D=lab.skeleton.get_bone_global_pose(i)
					reference_pose_error=maxf(reference_pose_error,a.origin.distance_to(b.origin))
					check(a.origin.distance_to(b.origin)<0.0001 and absf(a.basis.get_rotation_quaternion().dot(b.basis.get_rotation_quaternion()))>0.999999,"Production reference pose matches approved Lab C")
				for name in ["Walk","WalkTurnLeft","WalkTurnRight","Sprint","SprintTurnLeft","SprintTurnRight"]:
					check(absf(v.reference_sample_time(name)/v.samples[name].clip.length-phase_value)<0.000001,"Shared normalized phase "+name)
	# R5 source is authoritative, assert measured shaping, not just presence of a filter.
	v.reference_turn_amount=0;p.fast_sprinting=false
	v.rotation.y=0;v.update_motion(Vector3.BACK*4.25,null,1.0/60)
	for rate in [-2.5,-1.042,-0.55,0.0,0.55,1.042,2.5]:
		v.reference_yaw_rate=rate;v.reference_turn_amount=0;v.movement_speed=4.25
		v._process(0.10)
		var normalized:=clampf(-rate/1.20,-1,1)
		var shaped:=signf(normalized)*pow(absf(normalized),1.35)
		check(absf(v.reference_turn_amount-shaped*(1-exp(-1)))<0.000001,"Exact R5 C nonlinear/filter response")
	var modes:=[]
	for sign_value in [-1,1]:
		for sprint in [false,true]:
			p.fast_sprinting=sprint;v.rotation.y=2.9;v.reference_turn_amount=0
			for i in 720:
				var angle:float=2.9+sign_value*float(i)*0.015
				v.update_motion(Vector3(sin(angle),0,cos(angle))*(6.25 if sprint else 4.25),null,1.0/120)
				var before:float=v.reference_phase;v._process(1.0/120)
				var expected:=fposmod(before+1.0/120*lerpf(1.0/(16.0/24),1.0/(13.0/24),v.reference_sprint_weight),1)
				clock_error=maxf(clock_error,absf(wrapf(v.reference_phase-expected,-0.5,0.5)))
				if i>150:check(signf(v.reference_turn_amount)==-sign_value,"Circle sign stays character-relative")
			modes.append({"sprint":sprint,"circle_sign":sign_value,"turn":v.reference_turn_amount})
	check(clock_error<0.000001,"Changing direction/Shift does not restart normalized clock")
	var before:float=v.reference_phase;v.start_authored_draw(99);v.cancel_authored_draw();v.start_authored_holster(99);v.cancel_authored_holster()
	check(v.reference_phase==before,"Draw/Holster requests preserve gait phase")
	check(v.ready_run_blend_weight()==0,"Reference never applies Run V7-specific Ready correction")
	# Rollback must remain exact, including old clocks and upper-body layers.
	old=load("res://tests/fixtures/LegacyPlayerR6P.tscn").instantiate();root.add_child(old);old.visual.set_process(false)
	v.set_locomotion_mode(0);v.set_weapon_equipped(true);old.visual.set_weapon_equipped(true)
	for speed in [0.0,2.6,4.25,6.25]:
		for rotation_value in [-2.9,0.0,2.9]:
			for visual in [v,old.visual]:
				visual.rotation.y=rotation_value;visual.movement_speed=speed;visual.run_weight=0.8;visual.move_weight=1 if speed>0 else 0;visual.locomotion_phase=0.31;visual.authored_run_time=0.19;visual.idle_time=0.23;visual.aim_weight=0;visual.long_gun_weight=1;visual.weapon_hold_weight=1;visual.switch_weight=1;visual.living_ready_weight=0;visual.recoil_time=100;visual.lower_rotation=Quaternion.IDENTITY;visual.acceleration=Vector3.ZERO;visual.turn_rate=0;visual.weapon_lag=0;visual.set_bounce(false);visual._evaluate(0)
			for i in v.skeleton.get_bone_count():
				var aa:Transform3D=v.skeleton.get_bone_pose(i);var bb:Transform3D=old.visual.skeleton.get_bone_pose(i)
				legacy_pose_error=maxf(legacy_pose_error,aa.origin.distance_to(bb.origin))
				check(aa.is_equal_approx(bb),"LEGACY preserves previous final pose "+v.skeleton.get_bone_name(i))
	check(v.run_animation_speed_scale==1.60,"Legacy Run V7 cadence retained")
	# Compare the retained final writer with Ready, recoil, lower-body aiming,
	# and nonzero secondary springs active, for every weapon profile.
	for weapon in [0,1,2]:
		for context in [0,1,2]:
			for visual in [v,old.visual]:
				visual.equip_weapon(weapon);visual.weapon_behavior.enabled=false
				visual.movement_speed=2.6 if context==0 else 6.25
				visual.move_weight=1;visual.run_weight=0 if context==0 else 1
				visual.locomotion_phase=0.63;visual.authored_run_time=0.27;visual.idle_time=0.4
				visual.aim_weight=0.7;visual.has_target=true;visual.lower_rotation=Quaternion(Vector3.UP,0.4)
				visual.long_gun_weight=0 if weapon==0 else 1;visual.weapon_hold_weight=1;visual.switch_weight=1
				visual.living_ready_weight=1;visual.ready_move_weight=1;visual.ready_idle_time=0.19
				visual.draw_active=false;visual.draw_exit_time=-1;visual.holster_active=false
				visual.is_firing=context==1;visual.recoil_time=0.035;visual.recoil_gain=1.2
				visual.acceleration=Vector3(1,0,-2);visual.turn_rate=0.3;visual.weapon_lag=0.002
				visual.set_bounce(context==2)
				for spring in [visual.body_spring,visual.chest_spring,visual.head_spring,visual.arm_spring,visual.weapon_spring]:spring.value=Vector3(-0.002,0.003,-0.002)
				visual._evaluate(0)
			for i in v.skeleton.get_bone_count():check(v.skeleton.get_bone_pose(i).is_equal_approx(old.visual.skeleton.get_bone_pose(i)),"LEGACY Ready/recoil/springs remain exact")
	v.set_locomotion_mode(1);var preserved:float=v.reference_phase;v.set_locomotion_mode(0);v.set_locomotion_mode(1)
	check(v.reference_phase==preserved,"Development A/B does not reset clock")
	p.queue_free();old.queue_free();body.queue_free();await process_frame;finish()
