extends SceneTree
## Real physics/process regression, complementary to exact deterministic poses.
var level: Node3D
var player: CharacterBody3D
var v: Node3D
var b: Node
var gun: Node3D
var enemy: Node3D
var near := false
var checks := 0
var failures: Array[String] = []
var clock_error := 0.0
var monitoring := false
func _initialize() -> void: call_deferred("run")
func check(condition: bool, label: String) -> void:
	checks+=1
	if not condition: failures.append(label);push_error(label)
func ticks(count: int) -> void:
	for i in count:
		if i%10==0 and player.current_speed>3: player.position=Vector3(0,0.02,-3)
		enemy.global_position=player.global_position+Vector3(0,0,3 if near else 40)
		var before: float=v.authored_run_time
		await physics_frame
		if monitoring: clock_error=maxf(clock_error,absf(wrapf(v.authored_run_time-before-1.6/60.0,-v.run.clip.length/2,v.run.clip.length/2)))
func run() -> void:
	level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	player=level.player;v=player.visual;b=player.get_node("WeaponBehavior");gun=player.get_node("Pistol")
	enemy=preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp=100000;level.get_node("Actors").add_child(enemy);enemy.current_hp=100000
	enemy.set_physics_process(false);level.combat.register_zombie(enemy)
	for weapon in [1,2]:
		player.equip_test_weapon(weapon);gun.cooldown=1000
		for phase in [0.0,0.25,0.5,0.75]:
			# D3: READY is prepared before sprint; sprint itself now requests the
			# same D2 authored transport instead of a manual mid-sprint restart.
			near=true
			b.weapon_attach_to_hand();b._set_state(b.State.READY);b.grace_elapsed=0
			await ticks(10)
			v.authored_run_time=phase*v.run.clip.length
			Input.action_press("move_right");Input.action_press("sprint")
			monitoring=true
			await ticks(15)
			check(player.current_speed>6.0,"Real controller runs at unchanged 6.25m/s")
			check(b.state==b.State.HOLSTERING and v.socket.current_attachment==&"carrier","Real-process trajectory active")
			Input.action_release("move_right");Input.action_press("move_forward")
			await ticks(35)
			check(b.state==b.State.STOWED and v.socket.current_attachment==&"back","Real-process completion releases carrier")
			check(player.current_speed>6.0 and not gun.can_fire(),"Direction change continues running during transition")
			check(v.skeleton.get_bone_global_pose(v.skeleton.find_bone("Root")).origin.length()<0.000001,"No visual root motion")
			monitoring=false;near=false;Input.action_release("move_forward");Input.action_release("sprint")
			await ticks(25)
	# Natural Idle grace timer, not forced start.
	player.equip_test_weapon(1);gun.cooldown=1000;near=true
	await ticks(42);check(b.is_ready(),"Threat naturally draws M4")
	near=false;await ticks(95)
	check(b.state==b.State.HOLSTERING and v.holster_active,"Actual no-threat grace starts authored Idle holster")
	near=true;await ticks(12)
	check(b.state==b.State.HOLSTERING,"Real threat waits for safe holster finish")
	await ticks(35);check(b.state==b.State.DRAWING,"Real threat queues forward placeholder Draw")
	await ticks(36);check(b.is_ready(),"Real resumed threat returns READY")
	for weapon in [1,2]:
		player.equip_test_weapon(weapon);gun.cooldown=0;var shots: int=gun.shot_count
		await ticks(12);check(gun.shot_count>shots,"Actual READY fires weapon profile %d"%weapon)
	near=false;gun.cooldown=1000;await ticks(100)
	check(b.state==b.State.HOLSTERING,"Natural holster fixture for switch")
	var token: int=b.request_id;player.equip_test_weapon(0);b.weapon_attach_to_back(token)
	await ticks(4);check(not v.holster_active and v.socket.current_attachment==&"hip","Live switch rejects stale event")
	check(clock_error<0.00001,"Real Run clock remains continuous at 1.60")
	var report={"checks":checks,"failures":failures,"clock_error_seconds":clock_error,"weapons":["M4A1","Shotgun"],"phases":[0,25,50,75],"run_speed":player.run_speed,"runtime_scale":v.run_animation_speed_scale}
	FileAccess.open("res://tests/holster_d2_live_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("D2_LIVE=",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
