extends SceneTree
## Real controller input -> same-tick behavior -> normal animation/events/fire.
var level: Node3D
var player: CharacterBody3D
var v: Node3D
var b: Node
var gun: Node3D
var enemy: Node3D
var near := false
var distance := 3.0
var checks := 0
var failures: Array[String] = []
var cases := {}
var clock_error := 0.0
var monitor := false
var root_travel := 0.0
var fire_during_sprint := 0
var rendered := false
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error(message)
func ticks(count: int) -> void:
	for i in count:
		if i%10==0 and player.current_speed>3: player.position=Vector3(0,0.02,-3)
		enemy.global_position=player.global_position+Vector3(0,0,distance if near else 40)
		var before: float=v.authored_run_time
		var shots: int=gun.shot_count
		await physics_frame
		if monitor: clock_error=maxf(clock_error,absf(wrapf(v.authored_run_time-before-1.6/60,-v.run.clip.length/2,v.run.clip.length/2)))
		if player.fast_sprinting:
			fire_during_sprint += gun.shot_count-shots
			check(not b.is_ready() and not gun.can_fire(),"Sprint gates READY/fire on current controller state")
		root_travel=maxf(root_travel,v.skeleton.get_bone_global_pose(v.skeleton.find_bone("Root")).origin.length())
func move_sprint(active: bool) -> void:
	if active: Input.action_press("move_right");Input.action_press("sprint")
	else:
		for action in ["move_right","move_forward","move_backward","move_left","sprint"]: Input.action_release(action)
func reset(weapon: int) -> void:
	move_sprint(false);near=false;distance=3;await ticks(150)
	player.equip_test_weapon(weapon);gun.cooldown=1000;await ticks(30)
	check(b.state==b.State.STOWED,"Fixture starts stowed category %d"%weapon)
func ready(weapon: int) -> void:
	await reset(weapon);near=true;await ticks(45)
	check(b.is_ready() and v.socket.current_attachment==&"hand","Actual awareness draws READY %d"%weapon)
func capture(label: String, back: bool=false) -> void:
	if not rendered:return
	# Awaiting render frames can advance physics outside ticks(). Do not count
	# those intentional screenshot waits as skipped/reset Run-clock updates.
	var was_monitoring := monitor
	monitor = false
	if label.ends_with("stowed_sprint"):
		while b.state != b.State.STOWED: await ticks(1)
		await ticks(15) # Let the unchanged D2 upper-layer exit blend settle.
	var camera: Camera3D=level.get_node("Camera3D")
	var old:=camera.transform;var old_size:=camera.size
	camera.position=player.position+(Vector3(-3,2.6,-5) if back else Vector3(3,2.8,5))
	camera.look_at(player.position+Vector3(0,1,0));camera.size=2.7
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/weapon_sprint_d3/%s.png"%label)
	camera.transform=old;camera.size=old_size
	await ticks(2)
	monitor = was_monitoring
func run() -> void:
	rendered="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://.validation/weapon_sprint_d3")
	level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	player=level.player;v=player.visual;b=player.get_node("WeaponBehavior");gun=player.get_node("Pistol")
	enemy=preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp=100000;level.get_node("Actors").add_child(enemy);enemy.current_hp=100000
	enemy.set_physics_process(false);level.combat.register_zombie(enemy)
	var ids: Array[int]=[]
	for instance in v.socket.instances:ids.append(instance.get_instance_id())
	await ticks(20);monitor=true
	# Source is intentional movement, not a velocity detector or Shift alone.
	Input.action_press("sprint");await ticks(3)
	check(not player.fast_sprinting,"Shift alone at rest is not sprint")
	Input.action_release("sprint");Input.action_press("move_right");await ticks(20)
	check(not player.fast_sprinting and absf(player.current_speed-4.25)<.01,"Normal movement uses original walk speed")
	move_sprint(false);await ticks(20)
	for weapon in [1,2,0]:
		var stow: StringName=&"hip" if weapon==0 else &"back"
		# A/E: already safe and stowed -> sprint -> safe exit; no repeated request.
		await reset(weapon);var token: int=b.request_id
		move_sprint(true);await ticks(60)
		check(b.state==b.State.STOWED and b.request_id==token and v.socket.current_attachment==stow,"A: stowed sprint does not replay holster %d"%weapon)
		move_sprint(false);await ticks(4)
		check(b.state==b.State.STOWED and b.request_id==token,"E: safe sprint exit stays stowed %d"%weapon)
		# B/C/D/K/L/M: READY threat -> immediate holster, hold stowed -> Draw exit.
		await ready(weapon);await capture("%d_ready"%weapon)
		gun.cooldown=0;var shots: int=gun.shot_count
		move_sprint(true);await ticks(2)
		check(player.fast_sprinting and b.state==b.State.HOLSTERING and b.grace_elapsed==0,"B: immediate sprint stow bypasses grace %d"%weapon)
		check(gun.shot_count==shots,"No shot on sprint onset while speed below firing threshold %d"%weapon)
		check(b.authored_holster==(weapon!=0) and v.holster_active==(weapon!=0),"K/L/M: correct authored/placeholder category %d"%weapon)
		token=b.request_id
		await ticks(16);await capture("%d_transport"%weapon)
		await ticks(32);await capture("%d_stowed_sprint"%weapon,true)
		check(b.state==b.State.STOWED and b.threat_present and v.socket.current_attachment==stow,"C: threat never draws during sprint %d"%weapon)
		check(absf(player.current_speed-6.25)<.01 and v.current_state==&"Run","Run stays at unchanged speed %d"%weapon)
		for name in ["Arm.L","Arm.R"]:
			var bone: int=v.skeleton.find_bone(name)
			var expected:Quaternion=v.run.rotation(bone,v.authored_run_time)
			if v.locomotion_mode==1:
				var turn_clip=v.samples["SprintTurnLeft" if v.reference_turn_amount<0 else "SprintTurnRight"]
				var time:float=v.reference_sample_time("Sprint")
				expected=v.samples.Sprint.rotation(bone,time).slerp(turn_clip.rotation(bone,time),absf(v.reference_turn_amount))
			check(absf(v.skeleton.get_bone_pose_rotation(bone).dot(expected))>.999999,"Stowed sprint restores active gait's free arm %s"%name)
		await ticks(35);check(b.request_id==token,"No enemy/sprint transition flicker %d"%weapon)
		move_sprint(false);await ticks(2)
		check(b.state==b.State.DRAWING and b.request_id==token+1,"D: threat draws immediately on sprint exit %d"%weapon)
		await ticks(40);check(b.is_ready(),"Exit draw completes READY %d"%weapon)
		# F: acquire then lose threat while sprinting; no exit Draw.
		move_sprint(true);await ticks(50);near=false;await ticks(5)
		check(not b.threat_present and b.state==b.State.STOWED,"F: awareness loses departed enemy %d"%weapon)
		token=b.request_id;move_sprint(false);await ticks(4)
		check(b.state==b.State.STOWED and b.request_id==token,"F: absent threat exit does not draw %d"%weapon)
		# G: new threat appears during sprint; record but do not draw.
		move_sprint(true);await ticks(10);near=true;await ticks(10)
		check(b.threat_present and b.state==b.State.STOWED and b.request_id==token,"G: new threat recorded without Draw %d"%weapon)
		move_sprint(false);await ticks(2);check(b.state==b.State.DRAWING,"G: existing threat requests Draw at release %d"%weapon)
		await ticks(40)
		# H: enter sprint halfway through an existing holster; preserve token/time.
		near=false;await ticks(99)
		check(b.state==b.State.HOLSTERING,"H fixture naturally holsters %d"%weapon)
		token=b.request_id;var elapsed: float=b.transition_elapsed
		move_sprint(true);near=true;await ticks(2)
		check(b.request_id==token and b.transition_elapsed>elapsed and b.state==b.State.HOLSTERING,"H: no restart/acceleration with returning threat %d"%weapon)
		await ticks(48);check(b.state==b.State.STOWED,"H: finishes normally under sprint %d"%weapon)
		# I before Draw handoff: keep global transform and reject delayed events.
		await reset(weapon);near=true;await ticks(5)
		check(b.state==b.State.DRAWING and v.socket.current_attachment==stow,"I fixture pre-handoff Draw %d"%weapon)
		var old: int=b.request_id;var before: Transform3D=v.socket.instances[weapon].transform
		move_sprint(true);await ticks(2)
		check(b.state==b.State.STOWED and v.socket.instances[weapon].transform.is_equal_approx(before),"I: cancel pre-handoff without moving weapon %d"%weapon)
		b.weapon_attach_to_hand(old);b.draw_finished(old)
		check(v.socket.current_attachment==stow,"Old Draw events cannot attach hand during sprint %d"%weapon)
		# I after Draw handoff: regular captured-pose Holster; no reverse.
		await reset(weapon);near=true
		await ticks(18 if weapon!=0 else 12)
		check(b.state==b.State.DRAWING and v.socket.current_attachment==(&"carrier" if weapon!=0 else &"hand"),"I fixture post-release Draw %d"%weapon)
		old=b.request_id;move_sprint(true);await ticks(2)
		if weapon!=0:
			check(b.state==b.State.DRAWING and b.authored_draw,"I: released authored Draw finishes forward before Holster %d"%weapon)
		else:
			check(b.state==b.State.HOLSTERING and not b.authored_holster,"I: Pistol retains immediate placeholder Holster")
		b.draw_finished(old);await ticks(65)
		check(b.state==b.State.STOWED and v.socket.current_attachment==stow,"I: post-handoff safely ends stowed %d"%weapon)
		cases[str(weapon)]="A through I, K/L/M passed"
	# J: switch during actual transport and while stowed sprint; no stale mounts.
	await ready(1);move_sprint(true);await ticks(8)
	var stale: int=b.request_id
	for weapon in [2,0,1]:
		var phase: float=v.authored_run_time;player.equip_test_weapon(weapon)
		check(v.authored_run_time==phase,"Switch preserves continuous Run clock")
		b.weapon_attach_to_hand(stale);b.weapon_release_carrier_to_back(stale);await ticks(4)
		check(b.state==b.State.STOWED and v.socket.current_attachment==(&"hip" if weapon==0 else &"back"),"J: correct switched category stowed")
		for i in 3:
			check(v.socket.instances[i].get_instance_id()==ids[i],"No weapon duplication")
			if i!=weapon:check(v.socket.instances[i].get_parent()==v.socket and not v.socket.instances[i].visible,"Inactive weapon cleaned from transport")
		check(v.socket.carrier_socket.get_child_count()==0,"No weapon stranded on Carrier")
	cases["J"]="switching during/stowed sprint passed"
	# Acquired threat keeps existing retention band while stowed under Sprint.
	distance=gun.target_range*1.1;near=true;await ticks(5)
	check(b.threat_present,"Existing acquired threat hysteresis retained while sprint stowed")
	move_sprint(false);await ticks(2);check(b.state==b.State.DRAWING,"Retained threat also draws immediately on release")
	distance=3;await ticks(40)
	for weapon in [1,2,0]:
		player.equip_test_weapon(weapon);gun.cooldown=0;var shots: int=gun.shot_count
		await ticks(10);check(gun.shot_count>shots and b.is_ready(),"Original READY firing profile %d"%weapon)
		gun.cooldown=1000
	# Death/disabled guards still dominate sprint, and invalidate late events.
	move_sprint(true);await ticks(3);var old: int=b.request_id
	player.is_dead=true;await ticks(3);b.weapon_attach_to_hand(old)
	check(b.suspended and not gun.can_fire(),"Dead player suspends sprint transition/fire")
	player.is_dead=false;move_sprint(false);await ticks(10)
	check(clock_error<.00001 and root_travel<.000001 and fire_during_sprint==0,"Clock/root/fire regression")
	check(v.run_animation_speed_scale==1.60 and player.run_speed==6.25 and player.walk_speed==4.25,"Approved cadence/speeds unchanged")
	check(v.skeleton.get_bone_count()==12 and v.find_children("*","Skeleton3D",true,false).size()==1,"Existing single skeleton and sockets unchanged")
	var report={"checks":checks,"failures":failures,"cases":cases,"clock_error_seconds":clock_error,"root_travel":root_travel,"shots_during_sprint":fire_during_sprint,"sprint_source":"controller sprint input AND nonzero movement vector","rendered":rendered}
	var report_path := "res://tests/weapon_sprint_d3_render_validation.json" if rendered else "res://tests/weapon_sprint_d3_validation.json"
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("D3=",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
