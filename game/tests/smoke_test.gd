extends Node
## Real physics integration checks; exits nonzero on failure.

var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var world := load("res://scenes/main.tscn").instantiate() as Node2D
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await get_tree().physics_frame
	var player := world.get_node("Actors/Player") as SurvivorPlayer
	check(world.remaining_zombies() == 1, "Arena must immediately spawn a zombie")
	world.get_node("SpawnTimer").wait_time = 0.05
	world.get_node("SpawnTimer").start()
	await get_tree().create_timer(0.12).timeout
	check(world.remaining_zombies() >= 3, "Timer must continuously spawn zombies")
	world.get_node("SpawnTimer").stop()
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.queue_free()
	for node in world.get_children():
		if node is Node2D and node != world.get_node("Actors"):
			node.queue_free()
	await get_tree().physics_frame
	check(get_tree().root.get_node("Sound").get_child_count() == 6, "Six audio hooks must exist")
	check(InputMap.has_action("move_left") and InputMap.has_action("move_up"), "Movement input actions exist")
	Input.action_press("move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cardinal_speed := player.velocity.length()
	Input.action_press("move_down")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(is_equal_approx(player.velocity.length(), cardinal_speed), "Diagonal speed must be normalized")
	Input.action_release("move_right")
	Input.action_release("move_down")
	player.position = Vector2.ZERO
	player.get_node("Pistol").set_physics_process(false)
	var zombie := load("res://scenes/zombie.tscn").instantiate() as SurvivorZombie
	zombie.position = Vector2(140, 0)
	zombie.target = player
	zombie.died.connect(world._on_zombie_died)
	world.get_node("Actors").add_child(zombie)
	await get_tree().create_timer(0.15).timeout
	check(zombie.position.x < 140.0, "Zombie must chase the player")
	check(zombie.get_node("Sprite").animation == &"walk", "Moving zombie must play walk")
	check(zombie.get_node("Sprite").flip_h, "Zombie facing left must flip")
	# Auto-target and fire against two stationary enemies; only the nearer takes damage.
	zombie.set_physics_process(false)
	zombie.position = Vector2(110, 0)
	var far_zombie := load("res://scenes/zombie.tscn").instantiate() as SurvivorZombie
	far_zombie.position = Vector2(240, 0)
	far_zombie.target = player
	world.get_node("Actors").add_child(far_zombie)
	far_zombie.set_physics_process(false)
	player.get_node("Pistol").cooldown = 0.0
	player.get_node("Pistol").set_physics_process(true)
	await get_tree().create_timer(0.3).timeout
	player.get_node("Pistol").set_physics_process(false)
	check(zombie.health == 2, "Automatically aimed bullet must damage nearest zombie")
	check(far_zombie.health == 3, "Farther zombie must not be targeted")
	# Two more real bullets complete the kill and create a pickup.
	for index in range(2):
		var bullet := load("res://scenes/bullet.tscn").instantiate() as Node2D
		bullet.position = Vector2(24, 0)
		bullet.direction = Vector2.RIGHT
		world.add_child(bullet)
		await get_tree().create_timer(0.2).timeout
	check(not is_instance_valid(zombie), "Zombie must be removed at zero HP")
	check(world.kills == 1, "Death signal must reach arena")
	var pickups: Array[Node] = []
	for node in world.get_node("Actors").get_children():
		if node is Area2D:
			pickups.append(node)
	check(pickups.size() == 1, "Death must create one EXP pickup")
	if not pickups.is_empty():
		player.global_position = pickups[0].global_position
	await get_tree().create_timer(0.1).timeout
	check(player.experience == 1, "Physics overlap must collect EXP")
	player.add_experience(20)
	check(player.level == 3 and player.experience == 8 and player.experience_required == 11, "EXP must roll over across multiple levels")
	player.take_damage(10)
	player.take_damage(10)
	check(player.health == 90, "Contact damage invulnerability must prevent repeated damage")
	player.invulnerability = 0.0
	player.take_damage(100)
	check(player.dead and world.get_node("SpawnTimer").is_stopped(), "Death must stop spawning")
	check(world.get_node("HUD/DeathMessage").visible, "Death must show restart instruction")
	var restart_event := InputEventKey.new()
	restart_event.physical_keycode = KEY_R
	restart_event.pressed = true
	Input.parse_input_event(restart_event)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	restart_event.pressed = false
	Input.parse_input_event(restart_event)
	var restarted := get_tree().current_scene as Node2D
	check(restarted != world, "R must reload the arena after death")
	var fresh_player := restarted.get_node("Actors/Player") as SurvivorPlayer
	check(fresh_player.health == 100 and fresh_player.level == 1 and restarted.kills == 0, "Restart must reset player stats and kills")
	print("SMOKE TEST: %d failures" % failures)
	restarted.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)

