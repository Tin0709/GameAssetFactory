extends SceneTree
## Actual gameplay scene/camera, starts naturally in M4A1 READY.
var level: Node3D
var controls: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	level = preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled = false; level.get_node("Progression").enabled = false
	root.add_child(level); current_scene = level; level.select_test_weapon(1)
	var enemy := preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp = 1000000; level.get_node("Actors").add_child(enemy); enemy.current_hp = 1000000
	enemy.set_physics_process(false); level.combat.register_zombie(enemy)
	controls = preload("res://tests/review_ready_e3_controls.gd").new()
	controls.level = level; controls.enemy = enemy; root.add_child(controls)
	# Review target supplies real awareness; suppress endless shooting only in
	# this standalone visual review. Production firing remains unchanged.
	level.player.get_node("Pistol").cooldown = 1000000
	for i in 60: await physics_frame
	assert(level.player.get_node("WeaponBehavior").is_ready())
	assert(level.player.visual.living_ready_weight > 0.99)
	print("E3 review open: M4A1 READY; V A/B, G labeled diagnostics, C close view")
	if "--smoke" in OS.get_cmdline_user_args(): quit(); return
	DirAccess.make_dir_recursive_absolute("res://.validation/ready_e3/rendered")
	if "--capture" in OS.get_cmdline_user_args():
		await capture_comparisons(); quit(); return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/ready_e3/review_open.png")
func capture_comparisons() -> void:
	var p: CharacterBody3D = level.player
	var v: Node3D = p.visual
	controls.set_diagnostic(1); controls.set_process(false)
	level.get_node("HUD").visible = false
	var camera: Camera3D = level.get_node("Camera3D")
	var measurements := {}
	for weapon in [1,2]:
		p.equip_test_weapon(weapon)
		for view in ["gameplay","detail"]:
			camera.transform = controls.original_camera; camera.size = controls.original_size
			if view == "detail":
				camera.position = p.position+Vector3(3,2.8,5)
				camera.look_at(p.position+Vector3(0,1,0)); camera.size = 3.0
			for context in ["Idle","Run"]:
				v.update_motion(Vector3.RIGHT*6.25 if context == "Run" else Vector3.ZERO,null,1.0/24.0)
				for i in 12: v._process(1.0/24.0)
				var metrics := {"legacy":{"weapon_origin":[],"head":[],"chest":[]},"living":{"weapon_origin":[],"head":[],"chest":[]}}
				for frame in 64:
					v._process(1.0/24.0)
					for mode in [0,1]:
						v.ready_animation_mode = mode; v.living_ready_weight = mode; v._evaluate(0)
						v.skeleton.force_update_all_bone_transforms(); v.socket.on_skeleton_update()
						var label: String = "legacy" if mode == 0 else "living"
						metrics[label].weapon_origin.append(v.socket.instances[weapon].global_position.y)
						for part in ["head","chest"]: metrics[label][part].append(v.skeleton.get_bone_global_pose(v.skeleton.find_bone(part.capitalize())).origin.y)
						await process_frame; await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png("res://.validation/ready_e3/rendered/%d_%s_%s_%s_%03d.png" % [weapon,view,context,label,frame])
				measurements["%d_%s_%s" % [weapon,view,context]] = metrics
	var f := FileAccess.open("res://.validation/ready_e3/rendered/measurements.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(measurements)); f.close()
	print("E3 normal-speed runtime A/B frames captured with same source times")
