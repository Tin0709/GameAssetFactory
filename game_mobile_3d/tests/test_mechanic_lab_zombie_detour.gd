extends SceneTree

const LAB := preload("res://scenes/dev/MechanicLab.tscn")
const ZOMBIE := preload("res://scripts/mechanic_lab_zombie.gd")

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func add_wall(lab: Node3D, point: Vector3, size: Vector3, yaw: float, frozen := false) -> PhysicsBody3D:
	var wall: PhysicsBody3D
	if frozen:
		var body := RigidBody3D.new()
		body.freeze = true
		wall = body
	else:
		wall = StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	wall.add_child(collider)
	wall.position = point
	wall.rotation.y = yaw
	lab.add_child(wall)
	return wall

func spawn_detour_group(lab: Node3D, member_count: int, baby_chaser := false) -> Node3D:
	var zombies := lab.get_node("Zombies")
	var effects := lab.get_node("CombatEffects") as Node3D
	for i in member_count:
		if not zombies.spawn(lab.player, Basis.IDENTITY, effects, true, baby_chaser and i == 0):
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

func check_sight_after_crowd_dies() -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var group := spawn_detour_group(lab, ZOMBIE.CROWD_RETRY_MIN_ZOMBIES)
	if group == null:
		lab.free()
		return
	var chaser := group.get_child(0) as ZOMBIE
	chaser.set_physics_process(false)
	chaser.position = Vector3(0.0, 0.02, -4.0)
	chaser.animation.play(ZOMBIE.IDLE, 0.0)
	chaser.animation.advance(0.0)
	await physics_frame
	var stride := roundi(Engine.physics_ticks_per_second / ZOMBIE.LAB_CROWD_SIGHT_HZ)
	while Engine.get_physics_frames() % stride == chaser._crowd_slot % stride:
		await physics_frame

	var known: Vector3 = lab.player.global_position
	chaser._target_aggressive = true
	chaser._target_visible = true
	chaser._last_seen_position = known
	lab.player.global_position += Vector3.RIGHT * 0.4
	chaser._physics_process(1.0 / Engine.physics_ticks_per_second)
	if chaser._last_seen_position != known:
		failures.append("A living crowd still uses its staggered sight schedule")

	for i in range(1, group.get_child_count()):
		var member := group.get_child(i) as ZOMBIE
		member.take_hit(member.health, Vector3.RIGHT)
	chaser._physics_process(1.0 / Engine.physics_ticks_per_second)
	if chaser._last_seen_position != lab.player.global_position:
		failures.append("Retained corpses do not delay the last living zombie's sight check")
	print("LAB_CROWD_AFTER_DEATH children=", group.get_child_count(),
		" immediate=", chaser._last_seen_position == lab.player.global_position)
	lab.free()

func check_detour(member_count: int, yaw: float, block_right: bool,
		block_with_zombie := false, brief_occlusion := false, frozen_wall := false) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := spawn_detour_group(lab, member_count)
	if zombies == null:
		lab.free()
		return
	var heading := Basis(Vector3.UP, yaw)
	add_wall(lab, heading * Vector3(0.0, 0.35, -2.25), Vector3(2.5, 0.7, 0.3), yaw, frozen_wall)
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
		failures.append("Visible chaser should walk around the wall and reach melee with %d members, yaw %s, frozen %s"
			% [member_count, rad_to_deg(yaw), frozen_wall])
	if block_right and crossing_x >= 0.0:
		failures.append("A blocked right side should send the chaser around the left edge")
	if not hits.all(func(damage): return damage == ZOMBIE.MELEE_DAMAGE):
		failures.append("Detouring should preserve the normal melee hit")
	print("LAB_VISIBLE_DETOUR members=", member_count, " yaw=", rad_to_deg(yaw),
		" zombie_blocker=", block_with_zombie, " frozen_wall=", frozen_wall, " cross_x=", crossing_x,
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

func check_short_static_detour(member_count: int, yaw: float, wall_width: float,
		target_offset: Vector3, latest_hit_tick: int) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var heading := Basis(Vector3.UP, yaw)
	lab.player.position = heading * target_offset
	var zombies := spawn_detour_group(lab, member_count)
	if zombies == null:
		lab.free()
		return
	add_wall(lab, heading * Vector3(0.0, 0.35, -2.25), Vector3(wall_width, 0.7, 0.3), yaw)
	var chaser := zombies.get_child(0) as ZOMBIE
	chaser.position = heading * Vector3(0.0, 0.02, -4.2)
	chaser.animation.play(ZOMBIE.IDLE)
	chaser.animation.advance(0.0)
	var chosen_x := INF
	var crossing_x := INF
	var hit_tick := -1
	var hits: Array[int] = []
	chaser.melee_hit.connect(func(damage): hits.append(damage))
	for tick in 300:
		await physics_frame
		if not is_finite(chosen_x) and chaser._chase_detour.is_finite():
			chosen_x = (heading.inverse() * chaser._chase_detour).x
		var local := heading.inverse() * chaser.global_position
		if not is_finite(crossing_x) and local.z > -2.25:
			crossing_x = local.x
		if not hits.is_empty():
			hit_tick = tick
			break
	if chosen_x >= 0.0 or crossing_x >= -wall_width * 0.5 or hits != [ZOMBIE.MELEE_DAMAGE] \
			or hit_tick > latest_hit_tick:
		failures.append("The nearer side of the %s m static wall should lead to a timely melee hit" % wall_width)
	print("LAB_SHORT_STATIC_DETOUR members=", member_count, " width=", wall_width,
		" chosen_x=", chosen_x, " cross_x=", crossing_x, " hit_tick=", hit_tick, " hits=", hits)
	lab.free()
	await physics_frame

func check_route_to_last_sighting(member_count: int, yaw: float, baby_chaser: bool,
		wall_width := 1.4, target_distance := 0.0) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := spawn_detour_group(lab, member_count, baby_chaser)
	if zombies == null:
		lab.free()
		return
	var heading := Basis(Vector3.UP, yaw)
	lab.player.position += heading.z * target_distance
	var chaser := zombies.get_child(0) as ZOMBIE
	chaser.position = heading * Vector3(0.0, 0.02, -3.3)
	chaser.animation.play(ZOMBIE.IDLE)
	chaser.animation.advance(0.0)
	for tick in 64:
		await physics_frame
		if chaser._target_aggressive:
			break
	var last_seen := chaser._last_seen_position
	add_wall(lab, heading * Vector3(0.0, 1.25, -1.8), Vector3(wall_width, 2.5, 0.30), yaw)
	for tick in 6:
		await physics_frame
		if not chaser._target_visible:
			break
	var lost_sight := chaser._target_aggressive and not chaser._target_visible
	lab.player.position += heading.z * 0.4
	var routed_while_hidden := false
	var used_last_sighting := true
	var hidden_hits := 0
	var hits: Array[int] = []
	chaser.melee_hit.connect(func(damage): hits.append(damage))
	for tick in 300:
		await physics_frame
		if not chaser._target_visible:
			routed_while_hidden = routed_while_hidden or chaser._chase_detour.is_finite()
			used_last_sighting = used_last_sighting and chaser._last_seen_position == last_seen
			hidden_hits = hits.size()
		if not hits.is_empty():
			break
	var expected := ZOMBIE.BABY_MELEE_DAMAGE if baby_chaser else ZOMBIE.MELEE_DAMAGE
	if not lost_sight or not routed_while_hidden or not used_last_sighting or hidden_hits > 0 or hits != [expected]:
		failures.append("A recent sighting should permit a detour and a hit only after the zombie sees the player again")
	print("LAB_LAST_SIGHT_ROUTE members=", member_count, " baby=", baby_chaser, " wall_width=", wall_width, " lost=", lost_sight,
		" routed=", routed_while_hidden, " remembered=", used_last_sighting, " hidden_hits=", hidden_hits,
		" hits=", hits)
	lab.free()
	await physics_frame

func check_floor_edge_pursuit(member_count: int, yaw: float, corner: bool) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := spawn_detour_group(lab, member_count)
	if zombies == null:
		lab.free()
		return
	var chaser := zombies.get_child(0) as ZOMBIE
	var floor_body := lab.get_node("Ground") as StaticBody3D
	floor_body.rotation.y = yaw
	var heading := Basis(Vector3.UP, yaw)
	chaser.position = heading * Vector3(47.0, 0.02, 47.0 if corner else 0.0)
	chaser.animation.play(ZOMBIE.IDLE)
	chaser.animation.advance(0.0)
	lab.player.position = heading * Vector3(53.2, 0.02, 53.2 if corner else 0.0)
	var hits: Array[int] = []
	chaser.melee_hit.connect(func(damage): hits.append(damage))
	var farthest := -INF
	var lost_floor := false
	for i in 150:
		await physics_frame
		if not is_instance_valid(chaser):
			failures.append("A chaser pursued the target off the Lab platform")
			lab.free()
			return
		var position := heading.inverse() * chaser.global_position
		farthest = maxf(farthest, maxf(position.x, position.z))
		lost_floor = lost_floor or (i > 2 and not chaser.is_on_floor())
	var waiting := chaser._living_state(chaser.animation.current_animation) == ZOMBIE.IDLE
	if lost_floor or farthest < 49.46 or farthest > 49.61 or not waiting \
			or not chaser._target_aggressive or not hits.is_empty():
		failures.append("A partial pursuit should stop at supported ground and preserve real melee range")
	lab.player.position = heading * Vector3(46.5, 0.02, 46.5 if corner else 0.0)
	for i in 190:
		await physics_frame
		if not hits.is_empty():
			break
	if hits != [ZOMBIE.MELEE_DAMAGE]:
		failures.append("The chaser should resume pursuit when the player returns to the platform")
	print("LAB_EDGE_PURSUIT members=", member_count, " farthest=", farthest,
		" lost_floor=", lost_floor, " idle=", waiting, " returned_hits=", hits)
	lab.free()
	await physics_frame

func check_active_crowd_at_floor_edge() -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	lab.player_health = 10000
	var zombies := lab.get_node("Zombies")
	lab.get_node("HUD/SpawnCrowd").pressed.emit()
	for i in 120:
		await process_frame
		if zombies.get_child_count() == 100:
			break
	if zombies.get_child_count() != 100:
		failures.append("The edge fixture must have 100 living zombies")
		lab.free()
		return
	for i in 100:
		var member := zombies.get_child(i) as ZOMBIE
		member.position = Vector3(48.0 - floorf(i / 10.0) * 1.15, 0.02, (i % 10 - 4.5) * 1.05)
		member._roam_origin = member.position
		member._reset_roam()
		member.animation.play(ZOMBIE.IDLE)
		member.animation.advance(0.0)
	lab.player.position = Vector3(53.2, 0.02, 0.0)
	var approach_health: int = lab.player_health
	for i in 240:
		await physics_frame
	var supported := zombies.get_child_count() == 100 and zombies.get_children().all(
		func(member: ZOMBIE) -> bool: return member.is_on_floor() and member.position.x < 50.0)
	if not supported or lab.player_health != approach_health:
		failures.append("The active crowd should stay supported at the edge without hitting a distant target")
	var return_health: int = lab.player_health
	lab.player.position = Vector3(45.9, 0.02, 0.0)
	for i in 240:
		await physics_frame
	var damage: int = return_health - lab.player_health
	if zombies.get_child_count() != 100 or damage <= 0 or damage % ZOMBIE.MELEE_DAMAGE != 0:
		failures.append("All 100 zombies should remain and resume normal attacks after the player returns")
	print("LAB_EDGE_CROWD supported=", supported, " alive=", zombies.get_child_count(), " damage=", damage)
	lab.free()
	await physics_frame

func check_direct_approach_after_cover_opens(member_count: int, yaw: float) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := spawn_detour_group(lab, member_count)
	if zombies == null:
		lab.free()
		return
	var heading := Basis(Vector3.UP, yaw)
	lab.player.global_position = Vector3(0.0, 0.02, 0.0)
	# The 36 cm gap fits the player's 30 cm radius but not the zombie's 43 cm radius.
	add_wall(lab, heading * Vector3(0.0, 1.5, 0.45), Vector3(5.0, 3.0, 0.18), yaw)
	var cover := add_wall(lab, heading * Vector3(0.0, 0.35, -2.25), Vector3(2.5, 0.7, 0.30), yaw)
	var chaser := zombies.get_child(0) as ZOMBIE
	chaser.position = heading * Vector3(0.0, 0.02, -4.2)
	chaser.animation.play(ZOMBIE.IDLE, 0.0)
	chaser.animation.advance(0.0)
	var damage: Array[int] = []
	chaser.melee_hit.connect(func(amount: int): damage.append(amount))
	for tick in 150:
		await physics_frame
		if chaser._chase_detour.is_finite():
			break
	if not chaser._chase_detour.is_finite():
		failures.append("The fixture must start a detour around the front cover")
		lab.free()
		return
	cover.free()
	await physics_frame
	chaser._prepare_lab_path_sweep()
	var space := chaser.get_world_3d().direct_space_state
	var ray: Vector3 = (lab.player.global_position - chaser.global_position).slide(Vector3.UP)
	var approach := ray.move_toward(Vector3.ZERO, chaser._melee_approach)
	var blocked_center := not chaser._lab_path_end_clear(space, ray)
	var clear_approach := chaser._lab_path_end_clear(space, approach) and chaser._lab_path_fraction(space, approach) >= 1.0
	for tick in 5:
		await physics_frame
	var resumed := not chaser._chase_detour.is_finite() and chaser._target_visible
	if not blocked_center or not clear_approach:
		failures.append("The central point must be obstructed while the melee approach clears the wall")
	if not resumed:
		failures.append("The zombie should drop its detour when the route to melee reach opens")
	for tick in 180:
		await physics_frame
		if not damage.is_empty():
			break
	if damage != [ZOMBIE.MELEE_DAMAGE]:
		failures.append("The restored direct route must still produce the normal melee hit")
	print("LAB_DIRECT_APPROACH members=", member_count, " yaw=", rad_to_deg(yaw),
		" blocked_center=", blocked_center, " clear_approach=", clear_approach, " resumed=", resumed, " hits=", damage)
	lab.free()
	await physics_frame

func check_v_corner_escape(member_count: int) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := spawn_detour_group(lab, member_count)
	if zombies == null:
		lab.free()
		return
	var yaw := 0.15118330717087
	var heading := Basis(Vector3.UP, yaw)
	var chaser := zombies.get_child(0) as ZOMBIE
	lab.player.position = heading * Vector3(-0.892124, 0.02, 0.645718)
	chaser.position = heading * Vector3(-0.622533, 0.02, -4.5)
	chaser.animation.play(ZOMBIE.IDLE, 0.0)
	chaser.animation.advance(0.0)
	var corner := Vector3(-0.093521, 0.0, -2.12)
	for end: Vector3 in [Vector3(-2.585104, 0.0, -3.993645), Vector3(2.028336, 0.0, -3.993645)]:
		var side := end - corner
		var center := heading * ((corner + end) * 0.5)
		center.y = 0.215
		add_wall(lab, center, Vector3(side.length(), 0.43, 0.22), yaw + atan2(-side.z, side.x))
	var damage: Array[int] = []
	chaser.melee_hit.connect(func(amount: int): damage.append(amount))
	var took_detour := false
	var hit_tick := -1
	for tick in 570:
		await physics_frame
		took_detour = took_detour or chaser._chase_detour.is_finite()
		if not damage.is_empty():
			hit_tick = tick
			break
	if not took_detour or damage != [ZOMBIE.MELEE_DAMAGE]:
		failures.append("A zombie that returns to the same V corner should take a longer detour and reach melee")
	print("LAB_V_CORNER_ESCAPE members=", member_count, " hit_tick=", hit_tick, " damage=", damage)
	lab.free()
	await physics_frame



func add_open_back_recess(lab: Node3D, heading: Basis, yaw: float) -> PhysicsBody3D:
	var front := add_wall(lab, heading * Vector3(0.0, 0.2, -2.10), Vector3(1.9, 0.4, 0.22), yaw)
	for side: float in [-1.0, 1.0]:
		add_wall(lab, heading * Vector3(side * 0.86, 0.2, -3.36), Vector3(0.22, 0.4, 2.61), yaw)
	return front

func check_open_back_recess(member_count: int, yaw: float, baby_chaser := false) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := spawn_detour_group(lab, member_count, baby_chaser)
	if zombies == null:
		lab.free()
		return
	var heading := Basis(Vector3.UP, yaw)
	var chaser := zombies.get_child(0) as ZOMBIE
	lab.player.position = Vector3(0.0, 0.02, 0.0)
	chaser.position = heading * Vector3(0.0, 0.02, -3.9)
	chaser.animation.play(ZOMBIE.IDLE, 0.0)
	chaser.animation.advance(0.0)
	add_open_back_recess(lab, heading, yaw)
	var damage: Array[int] = []
	chaser.melee_hit.connect(func(amount: int): damage.append(amount))
	var backed_out := false
	var crossing := INF
	var hit_tick := -1
	var chosen_routes := 0
	var was_detouring := false
	for tick in 540:
		await physics_frame
		var point := heading.inverse() * chaser.global_position
		backed_out = backed_out or point.z < -4.9
		if not is_finite(crossing) and point.z > -2.10:
			crossing = point.x
		var detouring := chaser._chase_detour.is_finite()
		chosen_routes += int(detouring and not was_detouring)
		was_detouring = detouring
		if not damage.is_empty():
			hit_tick = tick
			break
	var expected_damage := ZOMBIE.BABY_MELEE_DAMAGE if baby_chaser else ZOMBIE.MELEE_DAMAGE
	if not backed_out or not is_finite(crossing) or absf(crossing) < 1.12 or damage != [expected_damage]:
		failures.append("A zombie with a visible target should escape a dead end through its open side and reach melee")
	print("LAB_OPEN_BACK members=", member_count, " yaw=", rad_to_deg(yaw), " baby=", baby_chaser,
		" backed_out=", backed_out, " crossing=", crossing, " hit=", hit_tick,
		" routes=", chosen_routes, " final=", heading.inverse() * chaser.global_position)
	lab.free()
	await physics_frame


func check_recess_after_occlusion(member_count: int, yaw: float, baby: bool, closed := false) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := spawn_detour_group(lab, member_count, baby)
	if zombies == null:
		lab.free()
		return
	var heading := Basis(Vector3.UP, yaw)
	lab.player.position = heading * Vector3(0.0 if baby else 0.90, 0.02, 0.0)
	var chaser := zombies.get_child(0) as ZOMBIE
	chaser.position = heading * Vector3(0.0, 0.02, -3.9)
	chaser.animation.play(ZOMBIE.IDLE, 0.0)
	chaser.animation.advance(0.0)
	var front := add_open_back_recess(lab, heading, yaw)
	if closed:
		add_wall(lab, heading * Vector3(0.0, 1.5, -4.70), Vector3(1.9, 3.0, 0.24), yaw)
	var damage: Array[int] = []
	chaser.melee_hit.connect(func(amount: int): damage.append(amount))
	var approached := false
	for tick in 100:
		await physics_frame
		if chaser._target_visible and chaser._target_aggressive and chaser.is_on_wall():
			approached = true
			break
	var known := chaser._last_seen_position
	front.free()
	add_wall(lab, heading * Vector3(0.0, 1.5, -2.10), Vector3(1.9, 3.0, 0.22), yaw)
	lab.player.position += heading.z * 0.45
	var queued_retreat := false
	var backed_out := false
	var reacquired := false
	var remembered := true
	var hidden_hits := 0
	var hit_tick := -1
	for tick in 236:
		await physics_frame
		if chaser._target_aggressive and not chaser._target_visible:
			remembered = remembered and chaser._last_seen_position == known
			queued_retreat = queued_retreat or chaser._chase_detour_next.is_finite()
			backed_out = backed_out or chaser.global_position.dot(heading.z) < -4.9
			hidden_hits = damage.size()
		elif queued_retreat and chaser._target_visible:
			reacquired = true
		if not damage.is_empty():
			hit_tick = tick
			break
		if not chaser._target_aggressive:
			break
	var expected := ZOMBIE.BABY_MELEE_DAMAGE if baby else ZOMBIE.MELEE_DAMAGE
	if not approached or not remembered or hidden_hits > 0:
		failures.append("The occluded recess tracks only the confirmed sighting and cannot hit the hidden target")
	if closed:
		if queued_retreat or not damage.is_empty() or chaser._target_aggressive:
			failures.append("A sealed recess should wait for the sighting to expire")
	elif not queued_retreat or not backed_out or not reacquired or damage != [expected]:
		failures.append("An open recess should allow a retreat while hidden and melee only after reacquiring sight")
	print("LAB_REMEMBERED_RECESS members=", member_count, " yaw=", rad_to_deg(yaw), " baby=", baby,
		" closed=", closed, " route=", queued_retreat, " backed_out=", backed_out, " remembered=", remembered,
		" reacquired=", reacquired, " hit_tick=", hit_tick, " hits=", damage, " hidden_hits=", hidden_hits)
	lab.free()
	await physics_frame

func check_last_sighting_at_two_faces(member_count: int) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	lab.get_node("Zombies")._spawn_serial = 6039
	var zombies := spawn_detour_group(lab, member_count, true)
	if zombies == null:
		lab.free()
		return
	var chaser := zombies.get_child(0) as ZOMBIE
	var rng := RandomNumberGenerator.new()
	rng.seed = 683874
	var yaw := rng.randf_range(-PI * 0.6, PI * 0.6)
	var heading := Basis(Vector3.UP, yaw)
	var tip := rng.randf_range(-0.7, 0.7)
	var apex := Vector3(tip, 0.0, -1.7)
	var left := Vector3(tip - rng.randf_range(0.72, 2.87), 0.0, rng.randf_range(-4.7, -3.25))
	var right := Vector3(tip + rng.randf_range(0.72, 2.87), 0.0, rng.randf_range(-4.7, -3.25))
	var rear := Vector3(tip + rng.randf_range(-2.15, 2.15), 0.0, rng.randf_range(-5.3, -3.5))
	var rear_end := rear + Vector3(rng.randf_range(0.5, 1.5), 0.0, rng.randf_range(-0.9, 0.9))
	for edge: Array in [[left, apex, 0.42], [apex, right, 0.42], [rear, rear_end, 0.40]]:
		var offset: Vector3 = edge[1] - edge[0]
		var center: Vector3 = heading * ((edge[0] + edge[1]) * 0.5)
		center.y = edge[2] * 0.5
		add_wall(lab, center, Vector3(offset.length(), edge[2], 0.19), yaw + atan2(-offset.z, offset.x))
	chaser.position = heading * Vector3(rng.randf_range(-0.7, 0.7), 0.02, -4.98)
	lab.player.position = heading * Vector3(rng.randf_range(-0.65, 0.65), 0.02, 0.0)
	chaser.rotation.y = yaw
	chaser.animation.play(ZOMBIE.IDLE)
	chaser.animation.advance(0.0)
	var damage: Array[int] = []
	chaser.melee_hit.connect(func(amount: int): damage.append(amount))
	var known := Vector3.INF
	var hidden_tick := -1
	var reacquired_tick := -1
	var routed_hidden := false
	var remembered := true
	var saw_two_faces := false
	for tick in 230:
		await physics_frame
		if not known.is_finite() and chaser.is_on_wall() and chaser._target_aggressive and chaser._target_visible:
			known = chaser._last_seen_position
			add_wall(lab, heading * Vector3(0.0, 1.3, -0.8), Vector3(1.3, 2.6, 0.19), yaw)
			lab.player.position += heading.z * 0.18
		if known.is_finite() and not chaser._target_visible and reacquired_tick < 0:
			if hidden_tick < 0:
				hidden_tick = tick
			if not chaser._target_aggressive:
				break
			remembered = remembered and chaser._last_seen_position == known and damage.is_empty()
			saw_two_faces = saw_two_faces or chaser.get_slide_collision_count() >= 2
			routed_hidden = routed_hidden or chaser._chase_detour_next.is_finite()
		elif hidden_tick >= 0 and reacquired_tick < 0 and chaser._target_visible:
			reacquired_tick = tick
		if not damage.is_empty():
			break
	if hidden_tick < 0 or not saw_two_faces or not remembered or not routed_hidden \
			or reacquired_tick <= hidden_tick or damage != [ZOMBIE.BABY_MELEE_DAMAGE]:
		failures.append("A Baby Zombie blocked on two faces should reach its remembered route and only hit after reacquiring sight")
	print("LAB_TWO_FACE_SIGHTING members=", member_count, " hidden_tick=", hidden_tick,
		" two_faces=", saw_two_faces, " routed_hidden=", routed_hidden, " remembered=", remembered,
		" reacquired_tick=", reacquired_tick, " hits=", damage)
	lab.free()
	await physics_frame


func run() -> void:
	if OS.get_cmdline_user_args().has("--last-sighting-two-faces"):
		await check_last_sighting_at_two_faces(1)
		await check_last_sighting_at_two_faces(100)
		print("LAB_LAST_SIGHTING_TWO_FACES failures=", failures)
		quit(0 if failures.is_empty() else 1)
		return
	await check_open_back_recess(1, 0.0)
	await check_open_back_recess(100, deg_to_rad(31.0), true)
	await check_recess_after_occlusion(1, 0.0, false)
	await check_recess_after_occlusion(100, deg_to_rad(31.0), true)
	await check_recess_after_occlusion(100, deg_to_rad(-17.0), true)
	await check_recess_after_occlusion(100, deg_to_rad(31.0), true, true)
	await check_v_corner_escape(1)
	await check_v_corner_escape(100)
	await check_short_static_detour(1, 0.0, 2.5, Vector3(-1.25, 0.02, 3.5), 232)
	await check_short_static_detour(1, 0.0, 4.1, Vector3(-0.8, 0.02, 0.0), 225)
	await check_direct_approach_after_cover_opens(1, 0.0)
	await check_direct_approach_after_cover_opens(100, deg_to_rad(27.0))
	await check_detour(1, 0.0, false)
	await check_detour(100, deg_to_rad(27.0), true)
	await check_detour(100, deg_to_rad(27.0), true, false, false, true)
	await check_detour(100, 0.0, true, true)
	await check_detour(100, deg_to_rad(27.0), true, false, true)
	await check_connected_side(1, 0.0, 1.0)
	await check_connected_side(100, deg_to_rad(27.0), -1.0)
	await check_connected_side(1, deg_to_rad(52.0), 1.0)
	await check_route_to_last_sighting(1, 0.0, false)
	await check_route_to_last_sighting(100, deg_to_rad(27.0), true)
	await check_route_to_last_sighting(1, deg_to_rad(27.0), false, 5.2, 1.7)
	await check_route_to_last_sighting(100, deg_to_rad(27.0), true, 7.6, 1.7)
	await check_living_blocker(2, 0.0)
	await check_living_blocker(100, deg_to_rad(38.0))
	await check_living_blocker(100, deg_to_rad(-27.0), true)
	await check_floor_edge_pursuit(1, 0.0, false)
	await check_floor_edge_pursuit(100, deg_to_rad(27.0), true)
	await check_active_crowd_at_floor_edge()
	await check_paired_blocker_release()
	await check_sight_after_crowd_dies()
	await check_last_sighting_at_two_faces(1)
	print("LAB_ZOMBIE_DETOUR failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_living_blocker(member_count: int, yaw: float, opens := false) -> void:
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
	var moved_tick := -1
	var rejoin_ticks := -1
	var hits: Array[int] = []
	chaser.melee_hit.connect(func(damage): hits.append(damage))
	for tick in 210:
		await physics_frame
		if not is_finite(first_waypoint) and chaser._chase_detour.is_finite():
			first_waypoint = (heading.inverse() * chaser._chase_detour).x
			if opens:
				blocker.global_position += heading.x * 3.0
				moved_tick = tick
		if moved_tick >= 0 and rejoin_ticks < 0 and not chaser._chase_detour.is_finite():
			rejoin_ticks = tick - moved_tick
		var local := heading.inverse() * chaser.global_position
		if not is_finite(crossing_x) and local.z > -2.5:
			crossing_x = local.x
		if not hits.is_empty():
			break
	if not is_finite(first_waypoint) or not is_finite(crossing_x) or hits != [ZOMBIE.MELEE_DAMAGE]:
		failures.append("A chaser should reach melee after finding an open route past a living blocker")
	if opens and (rejoin_ticks < 1 or rejoin_ticks > 8 or absf(crossing_x) > 0.45):
		failures.append("A chaser should return promptly to the direct path when the blocker moves")
	if not opens and absf(crossing_x) < 0.7:
		failures.append("A chaser must go around a stationary capsule with clearance")
	print("LAB_LIVING_DETOUR members=", member_count, " yaw=", rad_to_deg(yaw), " waypoint_x=", first_waypoint,
		" crossing_x=", crossing_x, " rejoin_ticks=", rejoin_ticks, " hits=", hits,
		" final=", heading.inverse() * chaser.global_position)
	lab.free()
	await physics_frame

func check_paired_blocker_release() -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var zombies := spawn_detour_group(lab, 100)
	if zombies == null:
		lab.free()
		return
	for x in [-1.06, 1.06]:
		add_wall(lab, Vector3(x, 0.35, -2.8), Vector3(0.2, 0.7, 5.2), 0.0)
	var follower := zombies.get_child(0) as ZOMBIE
	var left := zombies.get_child(1) as ZOMBIE
	var right := zombies.get_child(2) as ZOMBIE
	left.position = Vector3(-0.34, 0.02, -2.0)
	right.position = Vector3(0.34, 0.02, -2.0)
	follower.position = Vector3(0.0, 0.02, -3.8)
	follower.animation.play(ZOMBIE.IDLE, 0.0)
	follower.animation.advance(0.0)
	var hits: Array[int] = []
	follower.melee_hit.connect(func(damage): hits.append(damage))
	for tick in 90:
		await physics_frame
	var skipped := 0
	var samples := follower.ragdoll.sample_count
	for tick in 48:
		await physics_frame
		skipped += int(follower._skipped_blocked_step)
	var pose_steps := follower.ragdoll.sample_count - samples
	if skipped != 42 or pose_steps != 48:
		failures.append("A persistent two-zombie jam should make six retries and keep all 48 pose samples")
	var stride := maxi(1, roundi(Engine.physics_ticks_per_second / ZOMBIE.PACKED_WALK_RETRY_HZ))
	if Engine.get_physics_frames() % stride == follower._crowd_slot % stride:
		await physics_frame
	var release := left if follower._blocking_zombie_id == right.get_instance_id() else right
	var origin := follower.global_position
	release.global_position.x += signf(release.global_position.x) * 3.0
	PhysicsServer3D.body_set_state(release.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, release.global_transform)
	await physics_frame
	var woke := not follower._skipped_blocked_step
	if not woke:
		failures.append("Moving the second zombie should resume collision checks off schedule")
	for tick in 125:
		await physics_frame
		if not hits.is_empty():
			break
	var progress := follower.global_position.z - origin.z
	if progress <= 0.4 or hits != [ZOMBIE.MELEE_DAMAGE]:
		failures.append("After release the chaser should advance and land a normal hit")
	print("LAB_PAIRED_BLOCKER skipped=", skipped, " pose_steps=", pose_steps, " woke=", woke,
		" progress_m=", progress, " hits=", hits)
	lab.free()
	await physics_frame
