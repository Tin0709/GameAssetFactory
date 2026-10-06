extends SceneTree
var level: Node3D
var player: CharacterBody3D
var v: Node3D
var b: Node
var gun: Node3D
var enemy: Node3D
var nearby:=false
var distance:=3.0
var checks:=0
var failures: Array[String]=[]
var monitor_clock:=false
var clock_error:=0.0
var rendered:=false
var ids: Array[int]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func tick(n: int) -> void:
	for i in n:
		if not player.is_dead and player.current_speed>3.0 and i%10==0:player.position=Vector3(0,0.02,-3)
		enemy.global_position=player.global_position+Vector3(0,0,distance if nearby else 40.0)
		var before: float=v.authored_run_time
		await physics_frame
		if monitor_clock:
			clock_error=maxf(clock_error,absf(wrapf(v.authored_run_time-before-1.6/60.0,-v.run.clip.length/2,v.run.clip.length/2)))
func capture(label: String,back: bool=false) -> void:
	if not rendered:return
	monitor_clock=false
	var camera: Camera3D=level.get_node("Camera3D")
	var original:=camera.transform;var original_size:=camera.size
	camera.position=player.position+Vector3(-3,2.6,-5) if back else player.position+Vector3(3,3.5,5)
	camera.look_at(player.position+Vector3(0,1.0,0));camera.size=3.3
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/weapon_d0_%s.png"%label)
	camera.transform=original;camera.size=original_size
	await tick(1);monitor_clock=true
func release() -> void:
	for action in ["move_left","move_right","move_forward","move_backward","sprint"]:Input.action_release(action)
func run() -> void:
	rendered="--capture" in OS.get_cmdline_user_args()
	level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	player=level.player;v=player.visual;b=player.get_node("WeaponBehavior");gun=player.get_node("Pistol")
	v.authored_long_gun_holster=false # Explicit D0 foundation regression fixture.
	gun.cooldown=1000.0;level.combat.audio.minimum_event_interval=1000000.0
	enemy=preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp=100000;level.get_node("Actors").add_child(enemy)
	enemy.current_hp=100000;enemy.set_physics_process(false);level.combat.register_zombie(enemy)
	for instance in v.socket.instances:ids.append(instance.get_instance_id())
	await tick(25);monitor_clock=true
	for weapon in [1,2,0]:
		player.equip_test_weapon(weapon);nearby=false;release();await tick(25)
		var stow: StringName=&"hip" if weapon==0 else &"back"
		check(b.state==b.State.STOWED and v.socket.current_attachment==stow,"No threat stows category %d"%weapon)
		check(v.weapon_hold_weight==0.0 and v.long_gun_weight==0.0,"Stowed upper layer releases %d"%weapon)
		for name in ["Arm.L","Arm.R"]:
			var bone: int=v.skeleton.find_bone(name)
			check(absf(v.skeleton.get_bone_pose_rotation(bone).dot(v.idle.rotation(bone,v.idle_time)))>0.999999,"Stowed original Idle arms %s"%name)
		check(not gun.can_fire(),"Stowed cannot fire")
		await capture("%d_stowed"%weapon,true)
		distance=gun.target_range*1.1;nearby=true;await tick(5)
		check(b.state==b.State.STOWED,"Outer band does not acquire %d"%weapon)
		distance=3.0;await tick(5)
		check(b.state==b.State.DRAWING and v.socket.current_attachment==stow,"Draw starts without instant hand teleport %d"%weapon)
		check(not gun.can_fire(),"Drawing cannot fire")
		# Losing the enemy while drawing finishes first, then starts grace.
		nearby=false;await tick(ceili(b.transition_duration()*60)+2)
		check(b.state==b.State.READY and v.socket.current_attachment==&"hand","Drawing completes despite lost enemy %d"%weapon)
		await tick(20)
		check(b.state==b.State.READY,"Grace remains READY %d"%weapon)
		nearby=true;await tick(5)
		check(b.state==b.State.READY and b.grace_elapsed==0.0,"Return during grace cancels holster %d"%weapon)
		await capture("%d_ready"%weapon)
		distance=gun.target_range*1.1;await tick(100)
		check(b.state==b.State.READY and b.grace_elapsed==0.0,"Retention band prevents flicker %d"%weapon)
		nearby=false;await tick(92)
		check(b.state==b.State.HOLSTERING and v.socket.current_attachment==&"hand","Grace requests holster before handoff %d"%weapon)
		check(not gun.can_fire(),"Holstering cannot fire")
		nearby=true;distance=3.0;await tick(2)
		check(b.state==b.State.READY,"Holster pre-handoff interruption recovers READY %d"%weapon)
		nearby=false;await tick(92)
		await tick(ceili(b.transition_duration()*60*0.5)+1)
		check(v.socket.current_attachment==stow,"Placeholder holster event uses correct socket %d"%weapon)
		var stale: int=b.request_id
		nearby=true;await tick(2)
		check(b.state==b.State.DRAWING,"Holster post-handoff interruption requests Draw %d"%weapon)
		b.weapon_attach_to_hand(stale)
		check(v.socket.current_attachment==stow,"Stale transition event rejected %d"%weapon)
		await tick(ceili(b.transition_duration()*60)+2)
		check(b.is_ready(),"Interrupted holster finishes Draw %d"%weapon)
		nearby=false;await tick(150)
		check(b.state==b.State.STOWED,"Final holster completes %d"%weapon)
	# Locomotion keeps running while the whole behavioral sequence repeats.
	player.equip_test_weapon(1)
	Input.action_press("move_backward");Input.action_press("sprint");await tick(25)
	nearby=true;distance=3.0;await tick(40)
	check(v.current_state==&"Run" and player.current_speed>6.2,"Run continues through Draw")
	for name in ["Root","Hips","Leg.L","Leg.R"]:
		var bone: int=v.skeleton.find_bone(name)
		check(v.skeleton.get_bone_pose_position(bone).distance_to(v.run.position(bone,v.authored_run_time))<0.00001 and absf(v.skeleton.get_bone_pose_rotation(bone).dot(v.run.rotation(bone,v.authored_run_time)))>0.999999,"Run lower body unchanged %s"%name)
	for weapon in [2,0,1]:
		var phase: float=v.authored_run_time
		player.equip_test_weapon(weapon)
		check(phase==v.authored_run_time,"Switch never resets locomotion")
		Input.action_release("move_backward");Input.action_press("move_right");await tick(20)
		check(v.current_state==&"Run" and b.state==b.State.READY,"Moving switch/turn stays READY")
		for i in 3:
			check(v.socket.instances[i].get_instance_id()==ids[i],"Same weapon instance retained")
			if i!=weapon:check(v.socket.instances[i].get_parent()==v.socket and not v.socket.instances[i].visible,"Inactive weapon safely returned/hidden")
		Input.action_release("move_right");Input.action_press("move_backward")
	nearby=false;await tick(150)
	check(v.current_state==&"Run" and b.state==b.State.STOWED,"Run continues through Holster")
	for name in ["Arm.L","Arm.R"]:
		var bone: int=v.skeleton.find_bone(name)
		check(absf(v.skeleton.get_bone_pose_rotation(bone).dot(v.run.rotation(bone,v.authored_run_time)))>0.999999,"Stowed original Run arm motion")
	check(clock_error<0.00001,"Continuous Run clock throughout state/direction/switch transitions")
	release();await tick(25)
	# Future authored-event mode must wait for explicit handoff and completion.
	b.placeholder_transitions=false;nearby=true;await tick(5)
	var token: int=b.request_id
	await tick(40);check(b.state==b.State.DRAWING,"Authored mode never timer-completes Draw")
	b.draw_finished(token);check(b.state==b.State.DRAWING,"Draw completion requires handoff event")
	b.weapon_attach_to_hand(token);b.draw_finished(token);check(b.is_ready(),"Explicit Blender-style Draw events")
	nearby=false;await tick(95)
	token=b.request_id;b.weapon_attach_to_back(token);b.holster_finished(token)
	check(b.state==b.State.STOWED,"Explicit Blender-style Holster events")
	b.placeholder_transitions=true;nearby=true;await tick(5)
	# Switching during a transition rejects old events and binds the new category.
	token=b.request_id;player.equip_test_weapon(0)
	b.weapon_attach_to_hand(token)
	check(b.state==b.State.DRAWING and v.socket.current_attachment==&"hip","Switch during Draw restarts correct category, stale event ignored")
	await tick(30);check(b.is_ready(),"Switched pistol finishes drawing")
	# Firing still uses current projectile profile/muzzle and existing speed gate.
	for weapon in 3:
		player.equip_test_weapon(weapon);gun.cooldown=0.0
		var shots: int=gun.shot_count
		Input.action_press("move_right");await tick(40)
		check(gun.shot_count>shots and player.current_speed>0.0 and player.current_speed<=3.0,"READY moving firing works %d"%weapon)
		check(v.socket.muzzle_position().is_equal_approx(v.socket.muzzles[weapon].global_position),"Muzzle reference survives reparent %d"%weapon)
		release();await tick(20)
	nearby=false;await tick(92)
	check(b.state==b.State.HOLSTERING,"Switch fixture starts holstering")
	player.equip_test_weapon(0);await tick(2)
	check(b.state==b.State.STOWED and v.socket.current_attachment==&"hip" and v.socket.instances[2].get_parent()==v.socket and not v.socket.instances[2].visible,"Switch while holstering cleans old weapon/socket")
	v.set_weapon_equipped(false);await tick(4)
	check(not v.socket.instances[0].visible and not gun.can_fire(),"Explicit unequip hides stowed weapon and disables fire")
	player.equip_test_weapon(0);await tick(4)
	check(v.socket.instances[0].visible and v.socket.current_attachment==&"hip","Re-equip restores same stowed weapon")
	# Death freezes an attachment consistently and invalidates transition tokens.
	nearby=false;await tick(150);nearby=true;await tick(4)
	token=b.request_id;player.is_dead=true;await tick(4)
	var parent_before=v.socket.instances[v.socket.equipped].get_parent()
	b.weapon_attach_to_hand(token);b.draw_finished(token)
	check(b.suspended and b.state in [b.State.STOWED,b.State.READY] and v.socket.instances[v.socket.equipped].get_parent()==parent_before and not gun.can_fire(),"Death cancels transition safely")
	player.is_dead=false;nearby=false;await tick(150)
	nearby=true;await tick(4);token=b.request_id
	player.set_physics_process(false);await tick(4)
	check(b.suspended and not gun.can_fire(),"Disabled player suspends behavior/firing")
	b.weapon_attach_to_hand(token)
	check(b.state==b.State.STOWED,"Disabled player's stale event cannot mutate attachment")
	player.set_physics_process(true);nearby=false;await tick(150)
	# Query is shared: no duplicate registry search for repeated same-tick reads.
	var scans: int=gun.target_scan_count
	for i in 10:gun.nearest_target();gun.awareness_target(true)
	check(gun.target_scan_count-scans<=1,"Awareness/movement/fire share cached registry query")
	check(v.skeleton.get_bone_count()==12 and v.find_children("*","Skeleton3D",true,false).size()==1,"Required Carrier plus legacy socket; no skeletons duplicated")
	check(v.run_animation_speed_scale==1.6 and player.run_speed==6.25 and player.walk_speed==4.25,"Approved cadence/speeds preserved")
	var report={"checks":checks,"failures":failures,"clock_error_seconds":clock_error,"rendered":rendered,"placeholder":true,"categories":["PISTOL","LONG_GUN","LONG_GUN"],"draw_radii_m":[8,10,6],"retain_radii_m":[9.6,12,7.2],"grace_seconds":b.holster_grace_seconds}
	var file:=FileAccess.open("res://tests/weapon_behavior_d0_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WEAPON_D0="+JSON.stringify(report));quit(0 if failures.is_empty() else 1)
