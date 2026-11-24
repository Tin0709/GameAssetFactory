extends SceneTree

const ContactSparks := preload("res://scripts/mechanic_lab_contact_sparks.gd")
const HealthBars := preload("res://scripts/mechanic_lab_health_bars.gd")

class FlashMonitor extends Node:
	var zombie: CharacterBody3D
	var actor: CharacterBody3D
	var hit := false
	var pose_time := -1.0
	var values: Array[float] = []
	var sparks: MultiMeshInstance3D
	var numbers: MultiMeshInstance3D
	var light: OmniLight3D
	var spark_counts: Array[int] = []
	var first_body_clock := INF
	var first_flash_clock := INF
	var first_streak_clock := INF
	var first_health_clock := INF
	var first_number_clock := INF
	var first_number_age := INF

	func _process(_delta: float) -> void:
		if hit:
			var mesh := zombie.get("_mesh") as MeshInstance3D
			var parameter: Variant = mesh.get_instance_shader_parameter("hit_flash")
			var weight := float(parameter) if parameter != null else 0.0
			values.append(weight)
			var clock: float = actor.render_presenter.display_clock
			if weight > 0.0 and is_inf(first_body_clock):
				first_body_clock = clock
			if is_inf(first_health_clock) and zombie._feedback._health_ratio < 1.0:
				first_health_clock = clock
			if is_inf(first_number_clock) and numbers.multimesh.visible_instance_count > 0:
				first_number_clock = clock
				first_number_age = numbers._numbers.front().age
			if light.visible and light.light_energy > 0.0 and is_inf(first_flash_clock):
				first_flash_clock = clock
			if sparks != null:
				var count := sparks.multimesh.visible_instance_count
				spark_counts.append(count)
				if count > 0 and is_inf(first_streak_clock):
					first_streak_clock = clock

	func sample_pose() -> void:
		if hit and pose_time < 0.0:
			pose_time = actor.effects.clock

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("FAIL ", description)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func attack(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)

func check_hit(fatal: bool) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group := lab.get_node("Zombies")
	await ticks(13)
	lab.get_node("HUD/BaseZombieToggle").button_pressed = fatal
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	check(group.get_child_count() == 1, "A verified zombie spawns")
	if group.get_child_count() != 1:
		lab.free()
		return
	var zombie = group.get_child(0)
	var monitor := FlashMonitor.new()
	monitor.zombie = zombie
	monitor.actor = lab.player
	monitor.sparks = lab.get_node_or_null("ContactSparks/Streaks") as MultiMeshInstance3D
	monitor.numbers = lab.get_node("CombatEffects/ZombieDamageNumbers") as MultiMeshInstance3D
	monitor.light = lab.get_node("CombatImpactLight")
	check(monitor.sparks != null, "Lab initializes the private source spark renderer")
	monitor.process_priority = 100
	lab.add_child(monitor)
	group.sabre_contact.connect(func(_point, _direction, _clip, _index, _serial, _lethal): monitor.hit = true)
	lab.player.physics_pose_ready.connect(monitor.sample_pose)
	await ticks(38)
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(36)
	var visible: Array[float] = monitor.values.filter(func(weight: float): return weight > 0.0)
	check(not visible.is_empty() and is_equal_approx(visible[0], 1.0),
		"First displayed hit frame uses full body flash (fatal: %s)" % fatal)
	check(not monitor.values.is_empty() and is_zero_approx(monitor.values.back())
		and zombie._mesh.material_overlay == null and not zombie.is_processing(),
		"The temporary overlay clears and stops updating (fatal: %s)" % fatal)
	check(zombie.health == (0 if fatal else 36) and zombie.ragdoll.running == fatal,
		"Flash leaves damage and ragdoll handoff intact (fatal: %s)" % fatal)
	check(not monitor.spark_counts.is_empty() and monitor.spark_counts.max() >= 6
		and monitor.spark_counts.max() <= 12 and monitor.spark_counts.back() == 0,
		"Body contact starts a bounded spark burst that fades (fatal: %s)" % fatal)
	check(monitor.pose_time >= 0.0 and is_finite(monitor.first_streak_clock)
		and monitor.first_streak_clock >= monitor.pose_time
		and is_equal_approx(monitor.first_flash_clock, monitor.first_streak_clock),
		"Grounded contact light and sparks begin together on the displayed contact pose (fatal: %s)" % fatal)
	check(is_finite(monitor.first_body_clock) and is_equal_approx(monitor.first_body_clock, monitor.first_streak_clock),
		"The body flash begins with sparks on the displayed contact pose (fatal: %s)" % fatal)
	check(is_finite(monitor.first_health_clock) and is_equal_approx(monitor.first_health_clock, monitor.first_streak_clock),
		"The overhead health updates on the displayed contact pose (fatal: %s)" % fatal)
	check((zombie._feedback.bar_slot < 0) == fatal,
		"The contact presentation removes the bar only for a lethal hit")
	check(is_finite(monitor.first_number_clock) and is_equal_approx(monitor.first_number_clock, monitor.first_streak_clock)
		and is_zero_approx(monitor.first_number_age),
		"The damage number starts at age zero on the displayed contact pose (fatal: %s)" % fatal)
	print("MELEE_FEEDBACK_ONSET fatal=", fatal, " bar=", monitor.first_health_clock - monitor.pose_time,
		" glyphs=", monitor.first_number_clock - monitor.pose_time, " spark=", monitor.first_streak_clock - monitor.pose_time)
	print("BODY_FLASH_ONSET fatal=", fatal, " body=", monitor.first_body_clock - monitor.pose_time,
		" spark=", monitor.first_streak_clock - monitor.pose_time)
	print("BODY_FLASH fatal=", fatal, " samples=", monitor.values.slice(0, 11))
	lab.free()

func run() -> void:
	await check_hit(false)
	await check_hit(true)
	await check_melee_feedback_order()
	await check_crowd_sparks()
	await check_blade_contact_spark_origin()
	await check_gauntlet_contact_spark_origins()
	await check_flash_during_render_hitch()
	await check_body_flash_release()
	await check_splash_flash_strength()
	await check_crowd_splash_visibility()
	await check_damage_numbers_during_render_hitch()
	await check_overlapping_damage_number_positions()
	await check_damage_number_bar_clearance()
	if DisplayServer.get_name() != "headless":
		await check_health_bar_visibility()
	print("MECHANIC_LAB_HIT_FLASH failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_melee_feedback_order() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.set_process(false)
	var group := lab.get_node("Zombies")
	var numbers = lab.get_node("CombatEffects/ZombieDamageNumbers")
	for cancel_pending: bool in [true, false]:
		lab.reset_player()
		await ticks(12)
		lab.get_node("HUD/SpawnZombie").pressed.emit()
		var target = group.get_child(0)
		target.set_physics_process(false)
		target.global_position = lab.player.global_position + lab.player.visual.global_basis.z * 1.3
		attack(true)
		await ticks(2)
		attack(false)
		for i in 35:
			await physics_frame
			if not lab._pending_melee_feedback.is_empty():
				break
		if lab._pending_melee_feedback.is_empty():
			check(false, "A real Sabre hit queues feedback for the displayed pose")
			lab.free()
			return
		var visual: Dictionary = lab._pending_melee_feedback.front()
		check(target.health == target.max_health - 12 and target._feedback._health_ratio == 1.0
			and numbers._numbers.is_empty(),
			"The simulation takes damage before the overhead cues are eligible")
		if cancel_pending:
			lab.reset_player()
			lab._process(0.0)
			check(is_equal_approx(target._feedback._health_ratio, float(target.health) / target.max_health)
				and numbers._numbers.is_empty() and lab._pending_melee_feedback.is_empty(),
				"Reset reconciles already committed HP without emitting an old damage number")
		else:
			var struck_origin: Vector3 = visual.origin
			target.global_position += Vector3.RIGHT * 0.8
			group.strike_bolt({"collider": target, "position": target.combat_center()}, Vector3.BACK, 1801)
			var remaining: int = target.health
			check(remaining == target.max_health - 20 and numbers._numbers.size() == 1,
				"A later projectile presents its confirmed damage immediately")
			lab.player.render_presenter.prepare(1.0)
			lab._process(0.0)
			check(is_equal_approx(target._feedback._health_ratio, float(remaining) / target.max_health),
				"A pending older melee cue cannot restore health removed by a later projectile")
			var melee_numbers: Array = numbers._numbers.filter(func(number): return number.ascii_digits.get_string_from_ascii() == "12")
			check(numbers._numbers.size() == 2 and melee_numbers.size() == 1
				and Vector3(melee_numbers[0].origin).distance_to(struck_origin) < 0.13,
				"Both numbers draw and the deferred one stays anchored where the melee hit landed")
		target.free()
	lab.free()

func check_health_bar_visibility() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(320, 320)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	viewport.add_child(camera)
	camera.make_current()
	var centre := Vector3.UP * HealthBars.BAR_HEIGHT
	camera.position = centre + Vector3.BACK * 6.0
	camera.look_at(centre)
	var near_owner := Node3D.new()
	var far_owner := Node3D.new()
	viewport.add_child(near_owner)
	viewport.add_child(far_owner)
	near_owner.position.z = 2.0
	var bars := HealthBars.new()
	viewport.add_child(bars)
	var foreground := bars.add_bar(near_owner)
	var near_colour: Color = (await read_health_viewport(viewport)).get_pixel(160, 160)
	var background := bars.add_bar(far_owner)
	bars.set_bar_health(background, 0.0, 0.0)
	var overlap: Color = (await read_health_viewport(viewport)).get_pixel(160, 160)
	check(near_colour.r > 0.5 and near_colour.is_equal_approx(overlap),
		"A full near health bar stays visible when the farther depleted bar is added after it")
	bars.remove_bar(background)
	bars.remove_bar(foreground)
	near_owner.position.z = 3.82
	bars.add_bar(near_owner)
	var focus := centre + Vector3.BACK * 6.0
	camera.position = focus + Vector3.RIGHT * 6.0
	camera.look_at(focus)
	var edge := await read_health_viewport(viewport)
	bars.extra_cull_margin = 1.0
	var reference := await read_health_viewport(viewport)
	# The centre is outside the frame, but part of the rotated quad projects inside.
	check(reference.get_pixel(311, 160).a > 0.5 and edge.get_data() == reference.get_data(),
		"A partly visible health bar is rendered when its centre is outside the viewport")
	viewport.free()

func read_health_viewport(viewport: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func check_damage_numbers_during_render_hitch() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var numbers = lab.get_node("CombatEffects/ZombieDamageNumbers")
	var origin: Vector3 = lab.player.global_position + Vector3.UP * 2.4
	numbers.add_number(8, origin, Vector3.ZERO)
	numbers.present(0.0)
	numbers.present(0.50)
	for i in 100:
		numbers.add_number(100, origin + Vector3.RIGHT * i * 0.05, Vector3.ZERO)
	numbers.present(0.22)
	check(numbers.multimesh.visible_instance_count == 300 and numbers._numbers.size() == 100,
		"A long frame expires the earlier number while displaying all 300 new digits")
	check(numbers._numbers.all(func(number): return number.age == 0.0 and number.centre == number.origin),
		"New numbers begin at the hit position before their pop and rise")
	check(numbers._numbers.filter(func(number): return not number.layout_offset.is_zero_approx()).size() <= 48,
		"A hundred-hit burst draws every digit and limits how many numbers are repositioned")
	var farthest = numbers._numbers.front()
	var nearest = numbers._numbers.back()
	lab.camera.rotation.y += PI
	numbers.present(0.0)
	check(numbers._numbers.front() == nearest and numbers._numbers.back() == farthest,
		"Damage numbers update their depth order when the camera reverses")
	numbers.present(1.0 / 30.0)
	check(numbers._numbers.all(func(number): return number.age > 0.0 and number.centre.y > number.origin.y),
		"New numbers rise on the next frame")
	numbers.present(0.70)
	check(numbers.multimesh.visible_instance_count == 0 and numbers._numbers.is_empty(),
		"The last numbers expire and stop updating")
	lab.camera.rotation = Vector3.ZERO
	for i in 64:
		numbers.add_number(i + 10, origin + Vector3.RIGHT * (i % 4) * 0.08, Vector3.ZERO)
	var queued: Array = numbers._numbers.duplicate()
	numbers.present(0.0)
	check(numbers._numbers == queued,
		"Overlapping numbers at the same depth draw in hit order")
	var first_frame: Array = numbers._numbers.duplicate()
	numbers.present(0.0)
	check(numbers._numbers == first_frame and numbers.multimesh.visible_instance_count == 128,
		"An unchanged view keeps the same ordering of stacked damage glyphs")
	lab.camera.rotate_y(PI * 0.5)
	numbers.present(0.0)
	lab.camera.rotation = Vector3.ZERO
	numbers.present(0.0)
	check(numbers._numbers == queued, "Returning to equal depth restores the original hit order")
	lab.free()

func check_overlapping_damage_number_positions() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var numbers = lab.get_node("CombatEffects/ZombieDamageNumbers")
	var camera: Camera3D = lab.camera
	var origin: Vector3 = lab.player.global_position + Vector3.UP * 2.4
	var side := camera.global_basis.x
	for value in [10, 11, 12]:
		numbers.add_number(value, origin, Vector3.ZERO)
	numbers.add_number(13, origin + side * 3.0, Vector3.ZERO)
	numbers.present(0.0)
	var born := damage_number_rectangles(numbers, camera)
	check(numbers.multimesh.visible_instance_count == 8,
		"Every hit retains its two damage digits")
	var separated: Vector3 = origin + side * 3.0
	var projected := Vector2(separated.dot(side), separated.dot(camera.global_basis.y))
	check(born.any(func(frame): return frame.get_center().distance_to(projected) < 0.0001),
		"A separated number keeps its exact hit anchor")
	check(damage_number_overlaps(born) == 0, "Simultaneous overlapping hits get separate positions")
	numbers.present(0.0)
	check(damage_number_rectangles(numbers, camera) == born, "The same camera keeps the assigned positions")
	numbers.present(0.09)
	check(damage_number_overlaps(damage_number_rectangles(numbers, camera)) == 0,
		"The pop reaches its peak without the numbers crossing each other")
	var assigned := {}
	for number in numbers._numbers:
		assigned[number.hit_order] = number.layout_offset
	numbers.add_number(14, origin, Vector3.ZERO)
	numbers.present(0.0)
	for number in numbers._numbers:
		if assigned.has(number.hit_order):
			check(number.layout_offset == assigned[number.hit_order], "A later hit does not move earlier numbers")
	lab.free()

func check_damage_number_bar_clearance() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group = lab.get_node("Zombies")
	await ticks(13)
	check(group.spawn(lab.player, Basis.IDENTITY, lab.get_node("CombatEffects")),
		"The damage layout fixture spawns an adult zombie")
	if group.get_child_count() != 1:
		lab.free()
		return
	var zombie: CharacterBody3D = group.get_child(0)
	zombie.set_physics_process(false)
	zombie.global_position = lab.player.global_position + lab.player.visual.global_basis.z * 1.4
	attack(true)
	await ticks(2)
	attack(false)
	var numbers = lab.get_node("CombatEffects/ZombieDamageNumbers")
	for i in 60:
		await process_frame
		if not numbers._numbers.is_empty():
			break
	check(numbers._numbers.size() == 1 and zombie.health == 36 and zombie._feedback.bar_slot >= 0,
		"A real Sabre hit displays two damage digits and retains the target's bar")
	if numbers._numbers.size() == 1:
		var camera: Camera3D = lab.camera
		var bar_point: Vector3 = zombie._feedback.to_global(Vector3.UP * HealthBars.BAR_HEIGHT)
		var bar_centre := Vector2(bar_point.dot(camera.global_basis.x), bar_point.dot(camera.global_basis.y))
		var size := Vector2(0.86, 0.165)
		var bar_rect := Rect2(bar_centre - size * 0.5, size)
		var birth := damage_number_rectangles(numbers, camera)[0]
		var offset: Vector2 = numbers._numbers[0].layout_offset
		numbers.present(0.09)
		var pop := damage_number_rectangles(numbers, camera)[0]
		check(not birth.intersects(bar_rect) and not pop.intersects(bar_rect),
			"The born number and its pop keep the target's bar readable")
		check(numbers._numbers[0].layout_offset == offset and offset.length() <= 1.25,
			"The placement stays attached to that hit without jumping during the pop")
		print("DAMAGE_BAR_CLEARANCE birth=", birth.intersection(bar_rect).get_area(),
			" pop=", pop.intersection(bar_rect).get_area(), " offset=", offset)
	lab.free()

func damage_number_rectangles(numbers, camera: Camera3D) -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	if DisplayServer.get_name() == "headless":
		# The dummy renderer doesn't retain per-instance transforms.
		for number in numbers._numbers:
			var centre := Vector2(number.centre.dot(camera.global_basis.x), number.centre.dot(camera.global_basis.y))
			centre += number.layout_offset
			var size := Vector2(32.0 + 24.5, 32.0) * 0.0144 * 1.16
			rectangles.append(Rect2(centre - size * 0.5, size))
		return rectangles
	for slot in range(0, numbers.multimesh.visible_instance_count, 2):
		var bounds := Rect2()
		for i in 2:
			var pose: Transform3D = numbers.multimesh.get_instance_transform(slot + i)
			var point: Vector3 = numbers.to_global(pose.origin)
			var centre := Vector2(point.dot(camera.global_basis.x), point.dot(camera.global_basis.y))
			var size: Vector2 = Vector2.ONE * numbers.DIGIT_SIZE * numbers.NUMBER_PIXEL_SIZE * pose.basis.x.length()
			var quad := Rect2(centre - size * 0.5, size)
			bounds = quad if i == 0 else bounds.merge(quad)
		rectangles.append(bounds)
	return rectangles

func damage_number_overlaps(rectangles: Array[Rect2]) -> int:
	var overlaps := 0
	for i in rectangles.size():
		for j in range(i):
			overlaps += int(rectangles[i].intersects(rectangles[j]))
	return overlaps

func check_crowd_sparks() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var sparks := lab.get_node("ContactSparks") as ContactSparks
	var renderer := sparks.get_node("Streaks") as MultiMeshInstance3D
	var group := lab.get_node("Zombies")
	var origin: Vector3 = lab.player.global_position + Vector3.UP
	var nearest: Array[Vector3] = []
	for i in 5:
		nearest.append(origin + Vector3.RIGHT * (0.8 * (i + 1)))
	for reversed in [false, true]:
		lab.reset_player()
		for i in 100:
			var rank := 100 - i if reversed else i + 1
			group.sabre_contact.emit(origin + Vector3.RIGHT * (0.8 * rank),
				Vector3.RIGHT, "Attack3", 2, 1700, false)
		sparks._process(0.25)
		check(renderer.multimesh.visible_instance_count == 45,
			"A hitch before the first presentation still shows all selected contacts")
		sparks._process(1.0 / 30.0)
		var counts := [0, 0, 0, 0, 0]
		var ages_match := true
		for particle in sparks._particles:
			if particle.age >= particle.lifetime:
				continue
			ages_match = ages_match and is_equal_approx(particle.age, 1.0 / 30.0)
			for i in nearest.size():
				if particle.origin.distance_squared_to(nearest[i]) < 0.22 ** 2:
					counts[i] += 1
		check(ages_match and counts == [9, 9, 9, 9, 9] and renderer.multimesh.visible_instance_count == 45,
			"A 100-contact burst is still visible one frame after the hitch (far first: %s)" % reversed)
	lab.reset_player()
	group.sabre_contact.emit(origin, Vector3.RIGHT, "Attack3", 2, 1701, false)
	sparks._process(0.0)
	sparks._process(0.10)
	check(renderer.multimesh.visible_instance_count == 9, "Earlier streaks are visible before the hitch")
	group.sabre_contact.emit(origin + Vector3.RIGHT, Vector3.RIGHT, "Attack3", 2, 1702, false)
	sparks._process(0.25)
	check(renderer.multimesh.visible_instance_count == 9,
		"A hitch expires the previous burst while showing the new contact")
	lab.reset_player()
	sparks.queue_contact(origin, Vector3.RIGHT, origin, lab.player.render_presenter.display_clock + 1.0)
	sparks._process(0.0)
	check(renderer.multimesh.visible_instance_count == 0 and sparks.is_processing(),
		"A future contact stays queued while the renderer catches up")
	lab.reset_player()
	await process_frame
	await process_frame
	check(renderer.multimesh.visible_instance_count == 0 and not sparks.is_processing(),
		"Reset clears the crowd sparks and stops their frame callback")
	var quality := lab.get_node_or_null("HUD/ImpactFxPanel/Rows/ContactSparkQuality") as OptionButton
	check(quality != null, "The Lab exposes a control for the contact spark budget")
	if quality != null:
		check(quality.selected == 0, "The Lab starts with the approved contact spark budget")
		var low := quality.get_item_index(1)
		quality.select(low)
		quality.item_selected.emit(low)
		for rank in range(100, 0, -1):
			group.sabre_contact.emit(origin + Vector3.RIGHT * (0.8 * rank),
				Vector3.RIGHT, "Attack3", 2, 1703, false)
		sparks._process(0.0)
		var counts := [0, 0, 0]
		for particle in sparks._particles:
			if particle.age < particle.lifetime:
				for i in counts.size():
					if particle.origin.distance_squared_to(nearest[i]) < 0.22 ** 2:
						counts[i] += 1
		check(counts == [6, 6, 6] and renderer.multimesh.visible_instance_count == 18,
			"Reduced quality shows six sparks at each of the three nearest contacts")
		lab.reset_player()
		quality.select(0)
		quality.item_selected.emit(0)
		var future: float = lab.player.render_presenter.display_clock + 1.0
		for point in nearest:
			sparks.queue_contact(point, Vector3.RIGHT, origin, future)
		quality.select(low)
		quality.item_selected.emit(low)
		sparks._process(0.0)
		check(renderer.multimesh.visible_instance_count == 0 and sparks._pending.size() == 3,
			"Reducing quality keeps future sparks deferred at the three nearest contacts")
	lab.reset_player()
	var rows := lab.get_node("HUD/ImpactFxPanel/Rows")
	var opacity := rows.get_node("Opacity/Slider") as HSlider
	var duration := rows.get_node("Duration/Slider") as HSlider
	opacity.value = 0.0
	duration.value = 50.0
	group.sabre_contact.emit(origin, Vector3.RIGHT, "Attack3", 2, 1704, false)
	sparks._process(0.0)
	sparks._process(0.04)
	var active := sparks._particles.filter(func(particle): return particle.age < particle.lifetime)
	check(not sparks.visible and active.size() == 6 and active.all(func(particle): return is_equal_approx(particle.age, 0.08)),
		"Hidden melee streaks still age twice as fast at half duration")
	opacity.value = 55.0
	check(sparks.visible and is_equal_approx(renderer.multimesh.mesh.material.get_shader_parameter("opacity_scale"), 0.55),
		"Live opacity restores visibility without respawning streaks")
	lab.free()

func check_blade_contact_spark_origin() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group = lab.get_node("Zombies")
	var sparks := lab.get_node("ContactSparks") as ContactSparks
	for baby in [false, true]:
		lab.reset_player()
		await ticks(12)
		lab._select_weapon(lab.Weapon.SWORD if baby else lab.Weapon.SABRE)
		if not group.spawn(lab.player, Basis.IDENTITY, lab.get_node("CombatEffects"), false, baby):
			check(false, "The blade-contact fixture spawns a source zombie")
			break
		var zombie = group.get_child(0)
		zombie.set_physics_process(false)
		var forward: Vector3 = lab.player.visual.global_basis.z
		zombie.global_position = lab.player.global_position + forward * 1.4
		var centres: Array[Vector3] = []
		group.sabre_contact.connect(func(point, _direction, _clip, _index, _serial, _lethal):
			centres.append(point), CONNECT_ONE_SHOT)
		attack(true)
		await ticks(2)
		attack(false)
		for i in 36:
			await physics_frame
			if not centres.is_empty() and sparks._streaks.visible_instance_count > 0:
				break
		check(centres.size() == 1 and sparks._streaks.visible_instance_count == 9,
			"A real grounded blade strike emits one nine-streak burst (baby: %s)" % baby)
		if not centres.is_empty():
			var capsule: CapsuleShape3D = zombie._live_capsule
			var centre := centres[0]
			var axis := Vector3.UP * (capsule.height * 0.5 - capsule.radius)
			var spark_origin := Vector3.ZERO
			var count := 0
			for spark in sparks._particles:
				if spark.age < spark.lifetime:
					spark_origin += spark.origin - spark.velocity.normalized() * 0.21
					count += 1
			if count > 0:
				spark_origin /= count
				var axis_point := Geometry3D.get_closest_point_to_segment(spark_origin, centre - axis, centre + axis)
				var distance := spark_origin.distance_to(axis_point)
				check(absf(distance - capsule.radius) < 0.001,
					"The spark origin is on the victim capsule (baby: %s)" % baby)
				var light: OmniLight3D = lab.get_node("CombatImpactLight")
				var light_error := light.global_position.distance_to(spark_origin)
				check(light.visible and light_error < 0.001,
					"The grounded blade lights the same capsule point as its streaks (baby: %s)" % baby)
				print("BLADE_SPARK_ORIGIN baby=", baby, " radius=", capsule.radius, " distance=", distance,
					" light_error_m=", light_error)
		zombie.free()
	lab.free()

func check_gauntlet_contact_spark_origins() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group := lab.get_node("Zombies")
	var sparks := lab.get_node("ContactSparks") as ContactSparks
	for basic: bool in [false, true]:
		lab.reset_player()
		await ticks(12)
		lab._select_weapon(lab.Weapon.BASIC_GAUNTLETS if basic else lab.Weapon.GAUNTLETS)
		if not group.spawn(lab.player, Basis.IDENTITY, lab.get_node("CombatEffects"), false, basic):
			check(false, "The Gauntlets fixture spawns its real target")
			break
		var target = group.get_child(0)
		target.set_physics_process(false)
		target.global_position = lab.player.global_position + lab.player.visual.global_basis.z * 1.34
		target.health = 100
		var centres: Array[Vector3] = []
		var frames: Array[int] = []
		var expected: Array[Vector3] = []
		var shown: Array[Vector3] = []
		var directions: Array[Vector3] = []
		var light_positions: Array[Vector3] = []
		var short_bursts: Array[bool] = []
		var record_hit := func(point: Vector3, _direction, _clip, index: int, _serial, _lethal):
			if index == centres.size():
				centres.append(point)
				frames.append(Engine.get_physics_frames())
		group.sabre_contact.connect(record_hit)
		var measure_pose := func():
			if expected.size() == centres.size() or frames.back() != Engine.get_physics_frames():
				return
			var index := expected.size()
			var left := index == 2
			var glove: MeshInstance3D
			if basic:
				glove = lab._basic_gauntlet_mounts[0 if left else 1]
			else:
				glove = lab._left_gauntlet if left else lab._right_gauntlet
			var socket := glove.get_parent() as BoneAttachment3D
			var skeleton: Skeleton3D = lab.player.skeleton
			var box := glove.get_aabb()
			var knuckle := box.get_center()
			knuckle.z = box.end.z
			var fist := skeleton.global_transform * skeleton.get_bone_global_pose(socket.bone_idx) * glove.transform * knuckle
			var capsule: CapsuleShape3D = target._live_capsule
			var half_axis := capsule.height * 0.5 - capsule.radius
			var centre := centres[index]
			var axis_point := centre
			axis_point.y = clampf(fist.y, centre.y - half_axis, centre.y + half_axis)
			expected.append(axis_point + (fist - axis_point).normalized() * capsule.radius)
			if index == 1:
				check(absf(lab.player.animation_player.current_animation_position - 0.30) < 0.035
					and fist.y < 2.0, "The uppercut hits as the right glove rises through torso height")
		lab.player.physics_pose_ready.connect(measure_pose)
		var measure_birth := func():
			if shown.size() >= expected.size():
				return
			var origin := Vector3.ZERO
			var axis := Vector3.ZERO
			var compact := true
			var count := 0
			for spark in sparks._particles:
				if spark.age < spark.lifetime and is_zero_approx(spark.age):
					var direction: Vector3 = spark.velocity.normalized()
					origin += spark.origin - direction * 0.21
					axis += direction
					compact = compact and spark.length < 0.15 and spark.lifetime < 0.165
					count += 1
			if count == 9:
				shown.append(origin / count)
				var facing: Basis = lab.player.visual.global_basis.orthonormalized()
				directions.append(facing.inverse() * axis.normalized())
				light_positions.append(lab.get_node("CombatImpactLight").global_position)
				short_bursts.append(compact)
		process_frame.connect(measure_birth)
		attack(true)
		for i in 160:
			await physics_frame
			if shown.size() == 3:
				break
		attack(false)
		check(expected.size() == 3 and shown.size() == 3, "Three real punches emit three separate bursts")
		for i in mini(expected.size(), shown.size()):
			var error := shown[i].distance_to(expected[i])
			check(error < 0.001, "Gauntlets hit %s emits from the capsule surface nearest the punching hand" % (i + 1))
			check(short_bursts[i], "Gauntlets hit %d uses short, compact contact streaks" % (i + 1))
			check(light_positions[i].distance_to(expected[i]) < 0.001,
				"Gauntlets hit %d lights the same surface point as its streaks" % (i + 1))
			var direction := directions[i]
			match i:
				0:
					check(direction.z > 0.60 and direction.x > 0.17, "The jab streaks fan forward with the right fist")
				1:
					check(direction.y > 0.85, "The uppercut streaks fan upward with the right fist")
				2:
					check(direction.x < -0.50 and direction.z > 0.40, "The finisher streaks fan across the body with the left fist")
			print("GAUNTLET_SPARK_ORIGIN basic=", basic, " attack=", i + 1, " error_m=", error, " direction=", direction)
		process_frame.disconnect(measure_birth)
		lab.player.physics_pose_ready.disconnect(measure_pose)
		group.sabre_contact.disconnect(record_hit)
		target.free()
	lab.free()

func check_splash_flash_strength() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var group = lab.get_node("Zombies")
	for baby in [false, true]:
		if not group.spawn(lab.player, Basis.IDENTITY, lab.get_node("CombatEffects"), false, baby):
			check(false, "The hit flash fixture spawns a source zombie")
			break
		var zombie = group.get_child(group.get_child_count() - 1)
		var point: Vector3 = zombie.combat_center()
		var health: int = zombie.health
		var strike := {"damage": 3 if baby else 10, "range_m": 2.5, "angle": 20.0, "strength": 500.0, "stagger": 12.0}
		var splash_damage := 1 if baby else 3
		var mesh := zombie._mesh as MeshInstance3D
		group._apply_contact(zombie, point, "Attack1", 0, 1705, strike, Vector3.RIGHT, true, point)
		check(zombie.health == health - splash_damage and is_equal_approx(float(mesh.get_instance_shader_parameter("hit_flash")), 0.3),
			"Splash keeps the weaker body flash at the actual hit (baby: %s)" % baby)
		zombie._process(0.12)
		check(is_equal_approx(float(mesh.get_instance_shader_parameter("hit_flash")), 0.3),
			"A delayed first render keeps the splash peak (baby: %s)" % baby)
		zombie._process(0.02)
		check(is_equal_approx(float(mesh.get_instance_shader_parameter("hit_flash")), 0.3),
			"Splash keeps its weaker amplitude as the clock advances (baby: %s)" % baby)
		group._apply_contact(zombie, point, "Attack1", 0, 1706, strike, Vector3.RIGHT, false, point)
		group._apply_contact(zombie, point, "Attack1", 0, 1707, strike, Vector3.RIGHT, true, point)
		check(is_equal_approx(float(mesh.get_instance_shader_parameter("hit_flash")), 1.0),
			"Splash cannot lower a direct flash that hasn't been displayed (baby: %s)" % baby)
		zombie._process(0.0)
		zombie._process(0.12)
		group._apply_contact(zombie, point, "Attack1", 0, 1708,
			strike.merged({"damage": 200}, true), Vector3.RIGHT, true, point)
		check(zombie.health == 0 and is_equal_approx(float(mesh.get_instance_shader_parameter("hit_flash")), 0.3),
			"A lethal splash retains the weaker flash during the ragdoll handoff (baby: %s)" % baby)
		zombie.free()
	lab.free()


func check_crowd_splash_visibility() -> void:
	for size: int in [4, 12]:
		var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
		root.add_child(lab)
		current_scene = lab
		await ticks(12)
		var group = lab.get_node("Zombies")
		var basis: Basis = lab.player.visual.global_basis
		var origin: Vector3 = lab.player.global_position
		var zombies: Array[CharacterBody3D] = []
		for i in size:
			if not group.spawn(lab.player, Basis.IDENTITY, lab.get_node("CombatEffects"), false, i % 2 == 1):
				break
			var zombie: CharacterBody3D = group.get_child(i)
			zombie.set_physics_process(false)
			var offset := Vector3((i % 4 - 1.5) * 0.42, 0.0, 1.28 + (i / 4) * 0.38)
			zombie.global_position = origin + basis * offset
			zombie.health = 100
			zombie.max_health = 100
			zombies.append(zombie)
		check(zombies.size() == size, "The real sweep fixture spawns %d mixed zombies" % size)
		var peaks: Array[float] = []
		var capture := func():
			if not peaks.is_empty():
				return
			var shown: Array[float] = []
			for zombie in zombies:
				var weight := float(zombie._mesh.get_instance_shader_parameter(&"hit_flash"))
				if weight > 0.0:
					shown.append(weight)
			if shown.size() == size:
				peaks.assign(shown)
		process_frame.connect(capture)
		attack(true)
		await ticks(2)
		attack(false)
		await ticks(34)
		process_frame.disconnect(capture)
		var direct := zombies.filter(func(zombie): return zombie.health == 88)
		var splash := zombies.filter(func(zombie): return zombie.health == 96)
		check(direct.size() == 1 and splash.size() == size - 1, "The Sabre sweep keeps every damage amount")
		check(peaks.size() == size, "All %d zombies show first contact feedback" % size)
		if peaks.size() == size:
			check(absf(peaks.max() - 1.0) < 0.001, "The primary target keeps the full body flash")
			var expected := 0.30 if size == 4 else 0.22
			check(absf(peaks.min() - expected) < 0.008,
				"The %d-target sweep has a legible secondary flash" % size)
			print("CROWD_FLASH_PEAK actors=", size, " direct=", peaks.max(), " splash=", peaks.min())
		lab.free()


func check_body_flash_release() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group := lab.get_node("Zombies")
	for baby: bool in [false, true]:
		for lethal: bool in [false, true]:
			check(group.spawn(lab.player, Basis.IDENTITY, lab.get_node("CombatEffects"), false, baby),
				"The direct flash release fixture spawns its target")
			var zombie = group.get_child(group.get_child_count() - 1)
			var mesh: MeshInstance3D = zombie._mesh
			zombie.take_hit(zombie.health if lethal else 1, Vector3.FORWARD)
			check(mesh.get_instance_shader_parameter(&"hit_flash") == 1.0,
				"A direct hit displays the full first flash")
			zombie._process(0.2)
			zombie._process(2.0 / 60.0)
			var middle := float(mesh.get_instance_shader_parameter(&"hit_flash"))
			if lethal:
				check(middle > 0.95, "A lethal flash keeps the bright hold during the launch")
			else:
				check(middle > 0.55 and middle < 0.78, "A surviving zombie starts revealing its skin during the hit")
			zombie._process(3.0 / 60.0)
			check(mesh.get_instance_shader_parameter(&"hit_flash") == 0.0 and not zombie.is_processing(),
				"Direct hit flash still finishes within the existing duration")
			print("BODY_FLASH_RELEASE baby=", baby, " lethal=", lethal, " middle=", middle)
			zombie.free()
	lab.free()

func check_flash_during_render_hitch() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var group := lab.get_node("Zombies")
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = group.get_child(0)
	var mesh := zombie._mesh as MeshInstance3D
	var original_skin := mesh.material_override
	var mobile := RenderingServer.get_current_rendering_method() == &"mobile"
	var original_hdr := root.use_hdr_2d
	if mobile:
		root.use_hdr_2d = false
	zombie.take_hit(1, Vector3.RIGHT)
	check((mesh.material_override != original_skin and mesh.material_overlay == null) if mobile
		else mesh.material_override == original_skin and mesh.material_overlay != null,
		"Mobile flashes with a single skin surface; other renderers retain the overlay")
	if mobile:
		check(mesh.get_instance_shader_parameter(&"flash_red") == 2.0,
			"Mobile clamps the red of the old overlay before blending into a normalized target")
	zombie._process(0.10)
	zombie._process(1.0 / 60.0)
	check(float(mesh.get_instance_shader_parameter(&"hit_flash")) > 0.9,
		"A render hitch before the first displayed frame does not consume the zombie flash")
	zombie._process(0.10)
	check(mesh.material_override == original_skin and mesh.material_overlay == null and not zombie.is_processing(),
		"A render hitch after the first displayed frame restores the ordinary zombie skin")
	if mobile:
		root.use_hdr_2d = true
		zombie.take_hit(1, Vector3.RIGHT)
		check(mesh.get_instance_shader_parameter(&"flash_red") == 3.2,
			"An HDR target retains the full red of the old flash")
		root.use_hdr_2d = original_hdr
	lab.free()
