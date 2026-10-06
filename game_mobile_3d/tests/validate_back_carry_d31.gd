extends "res://tests/validate_holster_d2.gd"
## Visual-only fixture: samples the actual sole writer and shared back mount.
var gameplay_camera := Transform3D.IDENTITY
var gameplay_size := 0.0
func sample_collision() -> void:
	if not v.holster_active or case_label.is_empty():return
	var frames := {}; var mesh_frames:Array=[]
	for name in ["Head","Chest","Arm.L","Arm.R"]:
		frames[name]=matrix_array(v.skeleton.global_transform*v.skeleton.get_bone_global_pose(v.skeleton.find_bone(name)))
	for mesh:MeshInstance3D in v.socket.instances[v.socket.equipped].find_children("*","MeshInstance3D",true,false):mesh_frames.append(matrix_array(mesh.global_transform))
	collision_samples.append({"case":case_label,"weapon":v.socket.equipped,"time":b.transition_elapsed,"body":frames,"meshes":mesh_frames})
func shot(label: String, view: String) -> void:
	if not rendered: return
	var camera: Camera3D = level.get_node("Camera3D")
	if view == "gameplay":
		camera.transform = gameplay_camera; camera.size = gameplay_size
	else:
		var offsets = {"rear":Vector3(-3,2.6,-5),"side":Vector3(5,2.2,0),"front":Vector3(3,2.8,5)}
		camera.position = player.position + offsets[view]
		camera.look_at(player.position + Vector3(0,1,0)); camera.size = 2.7
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/back_carry_d31/%s_%s.png" % [label, view])
func run() -> void:
	rendered = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://.validation/back_carry_d31")
	level = preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled = false; level.get_node("Progression").enabled = false
	root.add_child(level); current_scene = level; level.select_test_weapon(1)
	player = level.player; v = player.visual; b = player.get_node("WeaponBehavior"); gun = player.get_node("Pistol")
	gameplay_camera = level.get_node("Camera3D").transform; gameplay_size = level.get_node("Camera3D").size
	level.get_node("HUD").visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED; b.set_physics_process(false); gun.set_physics_process(false); v.set_process(false)
	player.position = Vector3(0,0,-3)
	enemy = preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp = 100000; level.get_node("Actors").add_child(enemy); enemy.current_hp = 100000
	enemy.set_physics_process(false); enemy.visible = false; level.combat.register_zombie(enemy)
	weapon_meshes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/holster_d2_collision_samples.json"))["meshes"]
	for weapon in [1,2]:
		for mode in ["idle","run","sprint"]:
			ready(weapon,0,mode != "idle")
			v.movement_speed = 4.25 if mode == "run" else (6.25 if mode == "sprint" else 0.0)
			v.socket.attach_equipped(&"back"); b._set_state(b.State.STOWED)
			v.weapon_hold_weight = 0.0 # Settled free-arm pose, not READY fixture hold.
			v.run_weight = 1.0 if mode == "sprint" else 0.0
			for i in 32:
				v.authored_run_time = float(i)/32 * v.run.clip.length
				v.locomotion_phase = float(i)/32
				v.idle_time = float(i)/32 * v.idle.clip.length
				v._evaluate(0); v.skeleton.force_update_all_bone_transforms(); v.socket.sync_transport_sockets()
				var chest: Transform3D = v.skeleton.global_transform * v.skeleton.get_bone_global_pose(v.skeleton.find_bone("Chest"))
				var local: Transform3D = chest.affine_inverse() * v.socket.instances[weapon].global_transform
				check(local.origin.distance_to(v.socket.BACK_CARRY_ORIGINS[weapon]) < .00001,"Stable chest-relative carry position")
				check(absf(rad_to_deg(atan2(local.basis.z.y,local.basis.z.x))-20)<.001,"Stable diagonal, no jitter")
				case_label = "%d_%s" % [weapon,mode]
				v.holster_active = true; sample_collision(); v.holster_active = false
				if mode == "sprint" and i in [0,16]:await shot("%d_sprint_contact%d" % [weapon,i],"rear")
				if i == 8:
					for view in ["front","side","rear","gameplay"]: await shot(case_label,view)
		# Inspect the actual authored event and the refined visual settle.
		ready(weapon,0.25,true); case_label = "%d_holster" % weapon; b._begin(b.State.HOLSTERING)
		for i in 45:
			tick()
			if i in [19,27,35,37,41]: await shot("%d_holster_%d" % [weapon,i],"rear")
		for yaw in [-PI/4, PI/4]:
			player.rotation.y = yaw; v._evaluate(0); v.skeleton.force_update_all_bone_transforms(); v.socket.sync_transport_sockets()
			check(v.socket.instances[weapon].transform.is_equal_approx(v.socket.back_canonical()),"Turning retains stable local mount")
			await shot("%d_turn_%s" % [weapon,str(yaw)],"gameplay")
		player.rotation.y = 0
	for jump in v.socket.transport_jumps: check(jump.position_m<.00001 and jump.rotation_rad<.0015,"Continuous handoff")
	FileAccess.open("res://tests/back_carry_d31_collision_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"meshes":weapon_meshes,"samples":collision_samples}))
	var report = {"checks":checks,"failures":failures,"diagonal_degrees":20,"root_travel":root_travel,"handoffs":v.socket.transport_jumps,"rendered":rendered}
	FileAccess.open("res://tests/back_carry_d31_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("D31=",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
