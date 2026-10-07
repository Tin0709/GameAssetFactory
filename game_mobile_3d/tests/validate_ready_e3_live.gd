extends SceneTree
## Natural controller/awareness integration: normal READY moves as Walk, sprint
## stows. Forced READY+Run is tested separately and never labeled gameplay.
var level: Node3D
var p: CharacterBody3D
var v: Node3D
var b: Node
var enemy: Node3D
var near := true
var checks := 0
var failures: Array[String] = []
var clock_error := 0.0
var cases: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text); push_error(text)
func tick(count: int) -> void:
	for i in count:
		# Keep input travel on the existing clear test lane, away from map rocks.
		if i % 6 == 0 and not Input.get_vector("move_left","move_right","move_forward","move_backward").is_zero_approx(): p.position = Vector3(0,0.02,-3)
		enemy.global_position = p.global_position+Vector3(0,0,3 if near else 40)
		var previous: float = v.authored_run_time
		await physics_frame
		clock_error = maxf(clock_error,absf(wrapf(v.authored_run_time-previous-1.6/60,-v.run.clip.length/2,v.run.clip.length/2)))
func release() -> void:
	for action in ["move_forward","move_backward","move_left","move_right","sprint"]: Input.action_release(action)
func run() -> void:
	level = preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled = false; level.get_node("Progression").enabled = false
	root.add_child(level); current_scene = level; level.select_test_weapon(1)
	p = level.player; v = p.visual; b = p.get_node("WeaponBehavior")
	enemy = preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp = 1000000; level.get_node("Actors").add_child(enemy); enemy.current_hp = 1000000
	enemy.set_physics_process(false); level.combat.register_zombie(enemy)
	p.get_node("Pistol").cooldown = 1000000
	for weapon in [1,2]:
		release(); near = false; await tick(155); p.equip_test_weapon(weapon); await tick(12)
		check(b.state == b.State.STOWED, "Safe weapon naturally starts stowed")
		near = true; await tick(60)
		check(b.is_ready() and v.ready_move_weight < 0.001 and v.living_ready_weight > 0.99, "A/I real standing Draw -> living Idle")
		# At one fixed clock instant, actual Living and Legacy must visibly differ.
		v.ready_idle_time = 11.0/24.0; v._evaluate(0)
		var living: Quaternion = v.skeleton.get_bone_pose_rotation(v.chest)
		v.ready_animation_mode = 0; v.living_ready_weight = 0; v._evaluate(0)
		check(living.angle_to(v.skeleton.get_bone_pose_rotation(v.chest)) > 0.001, "Idle A/B changes actual Chest pose")
		v.ready_animation_mode = 1; await tick(12)
		for actions in [["move_forward"],["move_backward"],["move_left"],["move_right"],["move_right","move_forward"],["move_left","move_backward"]]:
			release()
			for action: String in actions: Input.action_press(action)
			await tick(20)
			check(b.is_ready() and not p.fast_sprinting and v.ready_move_weight > 0.99 and v.run_weight < 0.001, "B/C/E/F actual READY movement remains Walk Hold fallback")
			check(p.current_speed <= 2.601, "Enemy combat movement remains capped at 2.6 m/s")
		release(); await tick(20)
		check(v.ready_move_weight < 0.001 and b.is_ready(), "G stop returns to living Idle")
		Input.action_press("move_right"); await tick(18)
		Input.action_press("sprint"); await tick(2)
		check(p.fast_sprinting and b.state == b.State.HOLSTERING and not p.get_node("Pistol").can_fire(), "K sprint uses unchanged authored Holster and firing gate")
		await tick(60)
		check(b.state == b.State.STOWED and v.socket.current_attachment == &"back" and v.living_ready_weight < 0.001 and v.run_weight > 0.99, "Sprint Run stows and has no Ready layer")
		Input.action_release("sprint"); await tick(2)
		check(b.state == b.State.DRAWING and v.draw_active, "L sprint release threat requests unchanged Draw")
		await tick(55)
		check(b.is_ready() and v.ready_move_weight > 0.99 and v.run_weight < 0.001, "J/L natural moving Draw ends at Walk Hold fallback")
		cases.append({"weapon":weapon,"natural_idle_ready":true,"natural_walk_fallback":true,"sprint_stow":true,"natural_moving_draw":"Walk fallback","ready_run":"separate composition diagnostic only"})
		release()
	check(clock_error < 0.00001, "Direction changes and transitions never reset Run clock")
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"clock_error_seconds":clock_error}
	var file := FileAccess.open("res://tests/ready_e3_live_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
