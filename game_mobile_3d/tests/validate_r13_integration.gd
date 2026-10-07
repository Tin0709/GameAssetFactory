extends SceneTree
var level: Node3D
var player: CharacterBody3D
var v: Node3D
var b: Node
var enemy: Node3D
var near := false
var failures: Array[String] = []
var checks := 0
var capture_enabled := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message);push_error(message)
func ticks(n: int) -> void:
	for i in n:
		if player.position.length()>5:player.position=Vector3(0,0.02,1.8)
		enemy.global_position=player.position+Vector3(0,0,3 if near else 40)
		await physics_frame
		check(b.is_ready() or not player.get_node("Pistol").can_fire(),"Fire restricted to READY")
	await process_frame
func move(action: String="", sprint: bool=false) -> void:
	for key in ["move_left","move_right","move_forward","move_backward","sprint"]:Input.action_release(key)
	if action!="":Input.action_press(action)
	if sprint:Input.action_press("sprint")
func capture(label: String, back: bool=false) -> void:
	if not capture_enabled:return
	var camera: Camera3D=level.get_node("Camera3D")
	var old:=camera.transform;var old_size:=camera.size
	var offset:=v.global_basis*(Vector3(-3,2.3,-5) if back else Vector3(3,2.5,5))
	camera.position=player.position+offset;camera.look_at(player.position+Vector3(0,1,0));camera.size=2.7
	level.get_node("HUD").visible=false
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/r13/%s.png"%label)
	level.get_node("HUD").visible=true;camera.transform=old;camera.size=old_size
func run() -> void:
	capture_enabled="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://.validation/r13")
	level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(0)
	player=level.player;v=player.visual;b=player.get_node("WeaponBehavior")
	check(v.has_method("r13_clip_name"),"Missing latest R13 integration")
	if not failures.is_empty():quit(1);return
	level.toggle_animation_test_enemy();enemy=level.animation_test_enemy
	player.get_node("Pistol").cooldown=100000
	var ids=[]
	for instance in v.socket.instances:ids.append(instance.get_instance_id())
	for weapon in [0,1,2]:
		move();near=false;await ticks(240);player.equip_test_weapon(weapon)
		player.get_node("Pistol").cooldown=100000
		await ticks(5)
		var stow: StringName=&"hip" if weapon==0 else &"back"
		check(b.state==b.State.STOWED and v.socket.current_attachment==stow,"Correct new stowed endpoint")
		check(v.socket.instances[weapon].transform.is_equal_approx(v.socket.r13_stow_mounts[weapon]),"Exact Blender stow mount")
		await capture("%d_stowed"%weapon,true)
		for action in ["","move_right","move_left"]:
			move(action);near=true;await ticks(150)
			check(b.is_ready() and v.has_authored_draw(),"Native Draw completes all classes")
			if action=="":
				for name in ["Arm.L","Arm.R"]:
					var bone: int=v.skeleton.find_bone(name)
					var expected: Transform3D=v._r13_pose(v.R13_KINDS[weapon],bone)
					check(absf(v.skeleton.get_bone_pose_rotation(bone).dot(expected.basis.get_rotation_quaternion()))>.99999,"Idle arm must match approved native pose: "+name)
					check(v.skeleton.get_bone_pose_position(bone).distance_to(expected.origin)<0.0001,"Idle shoulder must match approved source")
			await capture("%d_ready_%s"%[weapon,action if action!="" else "idle"])
			near=false;await ticks(105)
			check(b.authored_holster and b.state==b.State.HOLSTERING,"Native Holster all classes")
			await ticks(30);await capture("%d_transport_%s"%[weapon,action if action!="" else "idle"])
			await ticks(110)
			check(b.state==b.State.STOWED and v.socket.current_attachment==stow,"Holster completes while moving/turning")
			near=true;await ticks(145)
			check(b.is_ready(),"Threat reacquired Draw completes")
		move("move_right",true);await ticks(3)
		check(player.fast_sprinting and b.state==b.State.HOLSTERING,"Sprint initiates stow immediately")
		await ticks(145)
		check(b.state==b.State.STOWED and v.socket.current_attachment==stow,"Sprint stows despite threat")
		await capture("%d_sprint_stowed"%weapon,true)
		move("move_left");await ticks(145)
		check(b.is_ready(),"Sprint release draws against threat")
		# Cancel before release, finish forward after release.
		near=false;move();await ticks(240);near=true;await ticks(10)
		move("move_right",true);await ticks(3)
		check(b.state==b.State.STOWED and v.socket.current_attachment==stow,"Sprint cancels pre-release Draw safely")
		move();await ticks(52);move("move_right",true);await ticks(3)
		check(b.state==b.State.DRAWING and v.socket.current_attachment==&"carrier","Released Draw retains Carrier during sprint")
		await ticks(250)
		check(b.state==b.State.STOWED,"Post-release Draw completes then safely stows")
	# Switching while a native clip owns the previous instance.
	move();near=true;await ticks(150);move("move_right",true);await ticks(20)
	var stale: int=b.request_id
	for weapon in [1,0,2]:
		var phase: float=v.reference_phase
		player.equip_test_weapon(weapon)
		check(v.reference_phase==phase,"Weapon switch preserves gait phase")
		b.weapon_draw_to_hand(stale);b.weapon_release_carrier_to_back(stale)
		await ticks(5)
		check(b.state==b.State.STOWED,"Switch during sprint stays stowed")
		for i in 3:
			check(v.socket.instances[i].get_instance_id()==ids[i],"Same weapon instance throughout")
			check(v.socket.instances[i].visible==(i==weapon),"Exactly one visible weapon")
	move();near=false;await ticks(240);player.equip_test_weapon(0)
	player.get_node("Pistol").cooldown=100000;near=true
	while b.state!=b.State.READY:await ticks(1)
	player.equip_test_weapon(1)
	v._evaluate(1.0/60.0)
	check(v.socket.instances[1].transform.is_equal_approx(v.socket.hand_transforms[1]),"Switch immediately after Draw cannot inherit prior weapon mount")
	for handoff in v.socket.transport_jumps:
		check(handoff.position_m<0.0001 and handoff.rotation_rad<0.001,"No handoff position/rotation pop")
	check(AudioServer.is_bus_mute(0),"Test stays silent")
	move()
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"handoffs":v.socket.transport_jumps,"clips":v.r13_samples.keys()}
	FileAccess.open("res://.validation/r13/runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("R13 checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
