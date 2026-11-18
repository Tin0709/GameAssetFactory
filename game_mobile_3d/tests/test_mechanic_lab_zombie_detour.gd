extends SceneTree

const LAB := preload("res://scenes/dev/MechanicLab.tscn")
const ZOMBIE := preload("res://scripts/mechanic_lab_zombie.gd")

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func add_wall(lab: Node3D, point: Vector3, size: Vector3, yaw: float) -> void:
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	wall.add_child(collider)
	wall.position = point
	wall.rotation.y = yaw
	lab.add_child(wall)

func check_detour(member_count: int, yaw: float, block_right: bool) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := lab.get_node("Zombies")
	var effects := lab.get_node("CombatEffects") as Node3D
	for i in member_count:
		if not zombies.spawn(lab.player, Basis.IDENTITY, effects, true):
			failures.append("Could not spawn the detour fixture")
			lab.free()
			return
	for i in member_count:
		var member := zombies.get_child(i) as ZOMBIE
		member.position = Vector3(16.0 + i % 10 * 2.0, 0.02, 12.0 + floorf(i / 10.0) * 2.0)
		member.set_physics_process(i == 0)
	var heading := Basis(Vector3.UP, yaw)
	add_wall(lab, heading * Vector3(0.0, 0.35, -2.25), Vector3(2.5, 0.7, 0.3), yaw)
	if block_right:
		add_wall(lab, heading * Vector3(0.95, 0.4, -3.3), Vector3(0.3, 0.8, 2.2), yaw)
	var chaser := zombies.get_child(0) as ZOMBIE
	chaser.position = heading * Vector3(0.0, 0.02, -4.2)
	chaser.animation.play(ZOMBIE.IDLE)
	chaser.animation.advance(0.0)
	var crossing_x := INF
	var hits: Array[int] = []
	var visible_ticks := 0
	chaser.melee_hit.connect(func(damage): hits.append(damage))
	for i in 240:
		await physics_frame
		var local := heading.inverse() * chaser.global_position
		visible_ticks += int(chaser._target_visible)
		if not is_finite(crossing_x) and local.z > -2.25:
			crossing_x = local.x
	if visible_ticks < 220 or absf(crossing_x) < 1.55 or not is_finite(crossing_x) or hits.is_empty():
		failures.append("Visible chaser should walk around the wall and reach melee with %d members, yaw %s"
			% [member_count, rad_to_deg(yaw)])
	if block_right and crossing_x >= 0.0:
		failures.append("A blocked right side should send the chaser around the left edge")
	if not hits.all(func(damage): return damage == ZOMBIE.MELEE_DAMAGE):
		failures.append("Detouring should preserve the normal melee hit")
	print("LAB_VISIBLE_DETOUR members=", member_count, " yaw=", rad_to_deg(yaw), " cross_x=", crossing_x,
		" hits=", hits.size(), " visible=", visible_ticks)
	lab.free()
	await physics_frame

func run() -> void:
	await check_detour(1, 0.0, false)
	await check_detour(100, deg_to_rad(27.0), true)
	print("LAB_ZOMBIE_DETOUR failures=", failures)
	quit(0 if failures.is_empty() else 1)
