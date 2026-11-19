extends SceneTree

const LAB := preload("res://scenes/dev/MechanicLab.tscn")
const ZOMBIE := preload("res://scripts/mechanic_lab_zombie.gd")

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func add_wall(lab: Node3D, point: Vector3, size: Vector3, yaw: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	wall.add_child(collider)
	wall.position = point
	wall.rotation.y = yaw
	lab.add_child(wall)
	return wall

func spawn_detour_group(lab: Node3D, member_count: int) -> Node3D:
	var zombies := lab.get_node("Zombies")
	var effects := lab.get_node("CombatEffects") as Node3D
	for i in member_count:
		if not zombies.spawn(lab.player, Basis.IDENTITY, effects, true):
			failures.append("Could not spawn the detour fixture")
			return null
	for i in member_count:
		var member := zombies.get_child(i) as ZOMBIE
		member.position = Vector3(16.0 + i % 10 * 2.0, 0.02, 12.0 + floorf(i / 10.0) * 2.0)
		member.set_physics_process(i == 0)
	return zombies

func check_brief_occlusion(lab: Node3D, chaser: ZOMBIE, heading: Basis) -> void:
	var start := chaser.global_position
	var known := chaser._last_seen_position
	var waypoint := chaser._chase_detour
	var toward_waypoint := (waypoint - start).normalized()
	# Cover the player beyond the low barrier, leaving the selected side lane open.
	var screen := add_wall(lab, heading * Vector3(0.0, 1.5, -0.95), Vector3(9.0, 3.0, 0.2), heading.get_euler().y)
	for i in 8:
		await physics_frame
		if not chaser._target_visible:
			break
	var stayed_hidden := not chaser._target_visible
	for i in 18:
		lab.player.global_position += heading.x * 0.03
		await physics_frame
		stayed_hidden = stayed_hidden and not chaser._target_visible
	var advance := (chaser.global_position - start).dot(toward_waypoint)
	if not stayed_hidden or not chaser._target_aggressive or chaser._last_seen_position != known:
		failures.append("A brief occlusion must preserve aggression and the last observed position")
	if chaser._chase_detour != waypoint or advance < 0.6:
		failures.append("A brief loss of sight must not discard the open route around the barrier")
	print("LAB_DETOUR_OCCLUSION visible=", not stayed_hidden, " same_waypoint=", chaser._chase_detour == waypoint,
		" advance_m=", advance, " cached=", chaser._last_seen_position)
	screen.free()

func check_detour(member_count: int, yaw: float, block_right: bool,
		block_with_zombie := false, brief_occlusion := false) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := spawn_detour_group(lab, member_count)
	if zombies == null:
		lab.free()
		return
	var heading := Basis(Vector3.UP, yaw)
	add_wall(lab, heading * Vector3(0.0, 0.35, -2.25), Vector3(2.5, 0.7, 0.3), yaw)
	if block_with_zombie:
		var blocker := zombies.get_child(1) as ZOMBIE
		blocker.position = heading * Vector3(0.95, 0.02, -2.84)
	elif block_right:
		add_wall(lab, heading * Vector3(0.95, 0.4, -3.3), Vector3(0.3, 0.8, 2.2), yaw)
	var chaser := zombies.get_child(0) as ZOMBIE
	chaser.position = heading * Vector3(0.0, 0.02, -4.2)
	chaser.animation.play(ZOMBIE.IDLE)
	chaser.animation.advance(0.0)
	var crossing_x := INF
	var hits: Array[int] = []
	var visible_ticks := 0
	var covered := false
	chaser.melee_hit.connect(func(damage): hits.append(damage))
	for i in 240:
		await physics_frame
		if brief_occlusion and not covered and chaser._target_visible and chaser._chase_detour.is_finite():
			covered = true
			await check_brief_occlusion(lab, chaser, heading)
		var local := heading.inverse() * chaser.global_position
		visible_ticks += int(chaser._target_visible)
		if not is_finite(crossing_x) and local.z > -2.25:
			crossing_x = local.x
	if brief_occlusion and not covered:
		failures.append("The brief-occlusion replay must exercise a chosen route")
	if visible_ticks < 220 or absf(crossing_x) < 1.55 or not is_finite(crossing_x) or hits.is_empty():
		failures.append("Visible chaser should walk around the wall and reach melee with %d members, yaw %s"
			% [member_count, rad_to_deg(yaw)])
	if block_right and crossing_x >= 0.0:
		failures.append("A blocked right side should send the chaser around the left edge")
	if not hits.all(func(damage): return damage == ZOMBIE.MELEE_DAMAGE):
		failures.append("Detouring should preserve the normal melee hit")
	print("LAB_VISIBLE_DETOUR members=", member_count, " yaw=", rad_to_deg(yaw),
		" zombie_blocker=", block_with_zombie, " cross_x=", crossing_x,
		" hits=", hits.size(), " visible=", visible_ticks)
	lab.free()
	await physics_frame

func check_connected_side(member_count: int, yaw: float, side: float) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := spawn_detour_group(lab, member_count)
	if zombies == null:
		lab.free()
		return
	var heading := Basis(Vector3.UP, yaw)
	add_wall(lab, heading * Vector3(-2.75 * side, 0.35, -2.25), Vector3(8.0, 0.7, 0.3), yaw)
	add_wall(lab, heading * Vector3(3.28 * side, 0.4, -3.65), Vector3(0.20, 0.8, 2.3), yaw)
	var chaser := zombies.get_child(0) as ZOMBIE
	chaser.position = heading * Vector3(0.0, 0.02, -4.2)
	chaser.animation.play(ZOMBIE.IDLE)
	chaser.animation.advance(0.0)
	var chosen := INF
	var crossed := INF
	var hits: Array[int] = []
	chaser.melee_hit.connect(func(damage): hits.append(damage))
	for i in 190:
		await physics_frame
		if not is_finite(chosen) and chaser._chase_detour.is_finite():
			chosen = (heading.inverse() * chaser._chase_detour).x
		var local := heading.inverse() * chaser.global_position
		if not is_finite(crossed) and local.z > -2.25:
			crossed = local.x
		if not hits.is_empty():
			break
	if not is_finite(chosen) or chosen * side <= 1.55 or not is_finite(crossed) or crossed * side <= 1.55 \
			or hits != [ZOMBIE.MELEE_DAMAGE]:
		failures.append("The short side route should clear the wall and lead to one normal melee hit")
	print("LAB_CONNECTED_SIDE members=", member_count, " yaw=", rad_to_deg(yaw), " side=", side,
		" chosen_x=", chosen, " cross_x=", crossed, " hits=", hits)
	lab.free()
	await physics_frame

func run() -> void:
	await check_detour(1, 0.0, false)
	await check_detour(100, deg_to_rad(27.0), true)
	await check_detour(100, 0.0, true, true)
	await check_detour(100, deg_to_rad(27.0), true, false, true)
	await check_connected_side(1, 0.0, 1.0)
	await check_connected_side(100, deg_to_rad(27.0), -1.0)
	await check_connected_side(1, deg_to_rad(52.0), 1.0)
	await check_living_blocker(2, 0.0)
	await check_living_blocker(100, deg_to_rad(38.0))
	print("LAB_ZOMBIE_DETOUR failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_living_blocker(member_count: int, yaw: float) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := spawn_detour_group(lab, member_count)
	if zombies == null:
		lab.free()
		return
	var heading := Basis(Vector3.UP, yaw)
	var blocker := zombies.get_child(1) as ZOMBIE
	blocker.position = heading * Vector3(0.0, 0.02, -2.5)
	var chaser := zombies.get_child(0) as ZOMBIE
	chaser.position = heading * Vector3(0.0, 0.02, -4.2)
	chaser.animation.play(ZOMBIE.IDLE)
	chaser.animation.advance(0.0)
	var first_waypoint := INF
	var crossing_x := INF
	var hits: Array[int] = []
	chaser.melee_hit.connect(func(damage): hits.append(damage))
	for tick in 210:
		await physics_frame
		if not is_finite(first_waypoint) and chaser._chase_detour.is_finite():
			first_waypoint = (heading.inverse() * chaser._chase_detour).x
		var local := heading.inverse() * chaser.global_position
		if not is_finite(crossing_x) and local.z > -2.5:
			crossing_x = local.x
		if not hits.is_empty():
			break
	if not is_finite(first_waypoint) or not is_finite(crossing_x) or absf(crossing_x) < 0.7 \
			or hits != [ZOMBIE.MELEE_DAMAGE]:
		failures.append("A visible chaser should circle a stationary zombie and land one normal hit")
	print("LAB_LIVING_DETOUR members=", member_count, " yaw=", rad_to_deg(yaw), " waypoint_x=", first_waypoint,
		" crossing_x=", crossing_x, " hits=", hits, " final=", heading.inverse() * chaser.global_position)
	lab.free()
	await physics_frame
