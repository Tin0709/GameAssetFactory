extends SceneTree
var level: Node3D
var v: Node3D
func _initialize() -> void:call_deferred("run")
func tick(n: int) -> void:
	for i in n:await physics_frame
func image_capture(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/carry_c2_%s.png"%label)
func run() -> void:
	level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level)
	level.player.get_node("WeaponBehavior").enabled=false # Historical pose/gameplay baseline, without D0 behavior.
	current_scene=level;level.select_test_weapon(1)
	var player=level.player
	v=player.visual;player.get_node("Pistol").enabled=false
	await tick(20)
	# --live leaves the real game scene interactive with M4A1 already equipped.
	if "--live" in OS.get_cmdline_user_args():
		player.get_node("Pistol").enabled=true
		return
	var camera: Camera3D=level.get_node("Camera3D")
	player.set_physics_process(false);player.position=Vector3(0,0.02,0)
	for weapon in [1,2]:
		player.equip_test_weapon(weapon);await tick(20)
		for state in ["idle","run"]:
			v.set_process(false)
			v.move_weight=1.0 if state=="run" else 0.0;v.run_weight=v.move_weight
			v.weapon_hold_weight=1.0;v.long_gun_weight=1.0
			v.authored_run_time=0.083333;v._evaluate(0.0)
			v.current_state=&"Run" if state=="run" else &"Idle"
			level.update_status()
			for angle in ["gameplay","front","side"]:
				camera.position=Vector3(12,15,16) if angle=="gameplay" else (Vector3(3,2.5,6) if angle=="front" else Vector3(-6,2.2,0.4))
				if angle=="gameplay":camera.rotation_degrees=Vector3(-36.3158864,36.8698976,0)
				else:camera.look_at(Vector3(0,1.0,0))
				camera.size=14.5 if angle=="gameplay" else 3.0
				await image_capture("%d_%s_%s"%[weapon,state,angle])
				if angle=="gameplay":
					camera.size=3.4;await image_capture("%d_%s_gameplay_close"%[weapon,state])
			v.set_process(true)
	quit()


