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
	var light: OmniLight3D
	var spark_counts: Array[int] = []
	var first_flash_clock := INF
	var first_streak_clock := INF

	func _process(_delta: float) -> void:
		if hit:
			var mesh := zombie.get("_mesh") as MeshInstance3D
			values.append(float(mesh.get_instance_shader_parameter("hit_flash")))
			var clock: float = actor.render_presenter.display_clock
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
	check(not monitor.values.is_empty() and is_equal_approx(monitor.values[0], 1.0),
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
	print("BODY_FLASH fatal=", fatal, " samples=", monitor.values.slice(0, 11))
	lab.free()

func run() -> void:
	await check_hit(false)
	await check_hit(true)
	await check_crowd_sparks()
	await check_flash_during_render_hitch()
	await check_damage_numbers_during_render_hitch()
	await check_overlapping_damage_number_positions()
	if DisplayServer.get_name() != "headless":
		await check_health_bar_visibility()
	print("MECHANIC_LAB_HIT_FLASH failures=", failures)
	quit(0 if failures.is_empty() else 1)

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
	numbers._process(0.0)
	numbers._process(0.50)
	for i in 100:
		numbers.add_number(100, origin + Vector3.RIGHT * i * 0.05, Vector3.ZERO)
	numbers._process(0.22)
	check(numbers.multimesh.visible_instance_count == 300 and numbers._numbers.size() == 100,
		"A long frame expires the earlier number while displaying all 300 new digits")
	check(numbers._numbers.all(func(number): return number.age == 0.0 and number.centre == number.origin),
		"New numbers begin at the hit position before their pop and rise")
	var farthest = numbers._numbers.front()
	var nearest = numbers._numbers.back()
	lab.camera.rotation.y += PI
	numbers._process(0.0)
	check(numbers._numbers.front() == nearest and numbers._numbers.back() == farthest,
		"Damage numbers update their depth order when the camera reverses")
	numbers._process(1.0 / 30.0)
	check(numbers._numbers.all(func(number): return number.age > 0.0 and number.centre.y > number.origin.y),
		"New numbers rise on the next frame")
	numbers._process(0.70)
	check(numbers.multimesh.visible_instance_count == 0 and not numbers.is_processing(),
		"The last numbers expire and stop updating")
	lab.camera.rotation = Vector3.ZERO
	for i in 64:
		numbers.add_number(i + 10, origin + Vector3.RIGHT * (i % 4) * 0.08, Vector3.ZERO)
	var queued: Array = numbers._numbers.duplicate()
	numbers._process(0.0)
	check(numbers._numbers == queued,
		"Overlapping numbers at the same depth draw in hit order")
	var first_frame: Array = numbers._numbers.duplicate()
	numbers._process(0.0)
	check(numbers._numbers == first_frame and numbers.multimesh.visible_instance_count == 128,
		"An unchanged view keeps the same ordering of stacked damage glyphs")
	lab.camera.rotate_y(PI * 0.5)
	numbers._process(0.0)
	lab.camera.rotation = Vector3.ZERO
	numbers._process(0.0)
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
	numbers._process(0.0)
	var born := damage_number_rectangles(numbers, camera)
	check(numbers.multimesh.visible_instance_count == 8,
		"Every hit retains its two damage digits")
	var separated: Vector3 = origin + side * 3.0
	var projected := Vector2(separated.dot(side), separated.dot(camera.global_basis.y))
	check(born.any(func(frame): return frame.get_center().distance_to(projected) < 0.0001),
		"A separated number keeps its exact hit anchor")
	check(damage_number_overlaps(born) == 0, "Simultaneous overlapping hits get separate positions")
	numbers._process(0.0)
	check(damage_number_rectangles(numbers, camera) == born, "The same camera keeps the assigned positions")
	numbers._process(0.09)
	check(damage_number_overlaps(damage_number_rectangles(numbers, camera)) == 0,
		"The pop reaches its peak without the numbers crossing each other")
	lab.free()

func damage_number_rectangles(numbers, camera: Camera3D) -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	if DisplayServer.get_name() == "headless":
		# The dummy renderer doesn't retain per-instance transforms.
		for number in numbers._numbers:
			var centre := Vector2(number.centre.dot(camera.global_basis.x), number.centre.dot(camera.global_basis.y))
			centre += number.layout_offset
			var size := Vector2(2.0 + 24.5 / 32.0, 1.0) * 32.0 * 0.0144 * 1.16
			size.x = (32.0 + 24.5) * 0.0144 * 1.16
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
