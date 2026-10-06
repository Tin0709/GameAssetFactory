extends "res://tests/validate_weapon_sprint_d3.gd"
func run() -> void:
	level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	player=level.player;v=player.visual;b=player.get_node("WeaponBehavior");gun=player.get_node("Pistol")
	enemy=preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp=100000;level.get_node("Actors").add_child(enemy);enemy.current_hp=100000
	enemy.set_physics_process(false);level.combat.register_zombie(enemy)
	await ticks(20);monitor=true
	for weapon in [1,2]:
		await ready(weapon);move_sprint(true);await ticks(65)
		check(b.state==b.State.STOWED and v.socket.current_attachment==&"back","Natural sprint stow %d"%weapon)
		for direction in [["move_forward"],["move_forward","move_left"],["move_right"],["move_backward","move_right"],["move_left"]]:
			for action in ["move_right","move_forward","move_backward","move_left"]:Input.action_release(action)
			for action in direction:Input.action_press(action)
			await ticks(18)
			check(player.fast_sprinting and b.state==b.State.STOWED,"Turn/diagonal remains stowed sprint")
			check(v.socket.instances[weapon].transform.is_equal_approx(v.socket.back_canonical()),"Turn/diagonal keeps stable visual mount")
			check(not gun.can_fire(),"Turn/diagonal fire gate unchanged")
		move_sprint(false);near=false;await ticks(30)
		check(b.state==b.State.STOWED,"No threat exit stays stowed")
	for jump in v.socket.transport_jumps:check(jump.position_m<.00001 and jump.rotation_rad<.0015,"No live reparent pop")
	check(clock_error<.000001 and root_travel==0 and fire_during_sprint==0,"Live clocks/root/fire unchanged")
	var report={"checks":checks,"failures":failures,"clock_error":clock_error,"root_travel":root_travel,"sprint_shots":fire_during_sprint}
	FileAccess.open("res://tests/back_carry_d31_live_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("D31_LIVE=",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
