extends SceneTree

const CrossPollinator := preload("res://scripts/mechanic_lab_cross_pollinator.gd")
const WALK_SOURCES := [
	"Player_Master_Walk", "Player_Master_Walk", "Player_2H_Medium_Walk",
	"Player_Crossbow_Walk", "Player_Master_Walk",
]

var failures := 0
var contacts: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL ", message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func attack(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)

func equip(menu: OptionButton, index: int) -> void:
	menu.select(index)
	menu.item_selected.emit(index)

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var menu := lab.get_node("HUD/Weapon") as OptionButton
	var original_air: Dictionary = lab.player.clips.AirAttack
	check(not menu.disabled and menu.item_count == 5, "Both requested weapons appear in the live selector")
	if menu.item_count != 5:
		quit(1)
		return
	check(menu.get_item_text(3) == "The Cross Pollinator", "The Cross Pollinator is named correctly")
	check(menu.get_item_text(4) == "Prime Enchanter's Gauntlets", "Prime Enchanter's Gauntlets are named correctly")
	await check_weapon_movement(lab, menu)
	await check_crossbow_settle(lab, menu)
	check_crossbow_equip_audio(lab, menu)
	var group := lab.get_node("Zombies")
	group.sabre_contact.connect(func(_p, _d, clip, _i, _s, _k): contacts.append(clip))
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		check(false, "Verified zombie loads")
		quit(1)
		return
	var target = group.get_child(0)
	target.set_physics_process(false)
	target.health = 100
	target.position = Vector3(0.0, 0.0, 5.0)

	equip(menu, 3)
	var ammo := lab.get_node("HUD/CrossbowAmmo") as Label
	var sound := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	sound.button_pressed = true
	var combat_audio = lab.get_node("CombatAudio")
	var fire_samples: Array = combat_audio._groups.get(&"crossbow_fire", [])
	var impact_samples: Array = combat_audio._groups.get(&"crossbow_hit", [])
	var flight_samples: Array = combat_audio._groups.get(&"crossbow_flight", [])
	var embedded := lab._crossbow.get_node_or_null("EmbeddedArrows") as MultiMeshInstance3D
	var sparks := lab._crossbow.get_node_or_null("ArrowImpactSparks") as MultiMeshInstance3D
	check(sparks != null, "Polaris loads its two source impact emitters")
	var burst_sizes: Array[int] = []
	lab._crossbow.bolt_impact.connect(func(_hit: Dictionary, _direction: Vector3, _serial: int) -> void:
		burst_sizes.append(sparks._active_count if sparks != null else 0))
	var muzzle_errors: Array[float] = []
	lab._crossbow.bolt_launched.connect(func(projectile: Node3D) -> void:
		muzzle_errors.append(projectile.global_position.distance_to(lab._crossbow_mount.to_global(CrossPollinator.MUZZLE))))
	check(fire_samples.size() == 3 and impact_samples.size() == 3, "All verified crossbow firing and impact samples load")
	check(flight_samples.size() == 4, "All verified arrow flight samples load")
	check(menu.selected == 3 and ammo.visible and ammo.text.contains("25 / 25"), "Crossbow equips with full ammo")
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(3)
	var flight_voices: Array = combat_audio._voices.filter(func(voice): return voice.stream in flight_samples)
	var active_bolts: Array = lab._crossbow._bolts
	var bolt := active_bolts[0].node as MeshInstance3D if not active_bolts.is_empty() else null
	check(flight_voices.size() == 1 and bolt != null and
		flight_voices[0].global_position.distance_to(bolt.global_position) < 0.01,
		"One spatial flight voice follows the moving bolt")
	check(bolt != null and bolt.scale.is_equal_approx(Vector3.ONE * 0.7),
		"The displayed arrow uses the scale of the live Polaris mesh")
	await ticks(21)
	check(muzzle_errors.size() == 1 and muzzle_errors[0] < 0.0001, "A bolt launches from the fitted muzzle")
	check(not flight_voices.any(func(voice): return voice.playing), "Flight audio stops after the bolt hits")
	check(target.health == 92 and contacts.size() == 1, "A tap shoots one 8-damage bolt at a ranged target")
	check(burst_sizes.size() == 1 and burst_sizes[0] in [8, 9, 10],
		"A living hit spawns a single pair of Polaris spark bursts")
	check(lab._contact_sparks == null or lab._contact_sparks._streaks.visible_instance_count == 0,
		"Polaris does not double up with the generic melee sparks")
	check(embedded != null and embedded.multimesh.visible_instance_count == 0,
		"A living hit does not leave a terrain prop")
	check(combat_audio._next_choice.get(&"crossbow_hit", 0) == 1, "A living hit plays exactly one arrow impact")
	check(ammo.text.contains("24 / 25"), "One projectile consumes one arrow")
	await ticks(115)
	check(ammo.text.contains("25 / 25"), "Ammo refills")

	var barrier := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 2.6, 0.15)
	collider.shape = box
	barrier.add_child(collider)
	barrier.position = Vector3(0.0, 1.3, 2.5)
	lab.add_child(barrier)
	await ticks(2)
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(10)
	check(embedded != null and embedded.multimesh.visible_instance_count == 1,
		"A travelling arrow leaves one embedded prop when it hits a wall")
	check(burst_sizes.size() == 2 and burst_sizes[1] in [8, 9, 10],
		"A wall hit spawns the same two source emitters")
	if embedded != null and DisplayServer.get_name() != "headless":
		var first_pose := embedded.multimesh.get_instance_transform(0)
		await ticks(5)
		var second_pose := embedded.multimesh.get_instance_transform(0)
		check(first_pose.basis.get_scale().is_equal_approx(Vector3.ONE * 0.6)
			and absf(first_pose.origin.z - 2.365) < 0.06,
			"The wall prop uses the source mesh scale and impact offset")
		check(first_pose.basis != second_pose.basis and first_pose.origin.is_equal_approx(second_pose.origin),
			"The embedded arrow rotates around a fixed contact")
		await ticks(49)
	else:
		await ticks(54)
	check(embedded != null and embedded.multimesh.visible_instance_count == 0,
		"The embedded arrow expires at the end of the short Lab display window")
	check(sparks != null and sparks.multimesh.visible_instance_count == 0,
		"Both impact emitters finish within the source lifetime")
	check(target.health == 92 and contacts.size() == 1, "A wall blocks the bolt from hitting the zombie")
	check(combat_audio._next_choice.get(&"crossbow_hit", 0) == 2, "A wall hit plays the next arrow impact")
	check(combat_audio._next_choice.get(&"crossbow_fire", 0) == 2, "Two shots use two different firing samples")
	barrier.position.z = 0.50
	await ticks(2)
	var firing_choices_at_impact: Array[int] = []
	var flight_counts_at_impact: Array[int] = []
	var record_impact := func(_hit: Dictionary, _direction: Vector3, _serial: int) -> void:
		firing_choices_at_impact.append(combat_audio._next_choice.get(&"crossbow_fire", 0))
		flight_counts_at_impact.append(combat_audio._flight_targets.size())
	lab._crossbow.bolt_impact.connect(record_impact)
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(36)
	check(target.health == 92 and muzzle_errors.size() == 2 and ammo.text.contains("23 / 25"),
		"A wall inside muzzle reach stops the bolt and still spends the shot")
	check(firing_choices_at_impact == [0] and flight_counts_at_impact == [0],
		"A muzzle obstruction plays the third firing cue before impact and starts no flight cue")
	check(embedded != null and embedded.multimesh.visible_instance_count == 0,
		"A muzzle clearance block does not leave an embedded arrow")
	barrier.position.z = 2.5
	await ticks(2)
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(36)
	check(firing_choices_at_impact == [0, 1] and flight_counts_at_impact == [0, 0],
		"A travelling bolt stops its flight cue before the impact callback")
	lab._crossbow.bolt_impact.disconnect(record_impact)
	sound.button_pressed = false
	barrier.queue_free()
	check(embedded != null and embedded.multimesh.visible_instance_count == 1,
		"A second wall hit leaves a prop for the reset check")
	lab.reset_player()
	check(embedded != null and embedded.multimesh.visible_instance_count == 0,
		"Reset clears an embedded arrow immediately")
	await check_crossbow_collision_radius(lab)
	await check_crossbow_trail(lab)
	await check_crossbow_impact_burst(lab, sparks)
	await ticks(12)
	target.position = Vector3(2.5, 0.0, 3.0)
	lab.player._q = true
	attack(true)
	await ticks(2)
	attack(false)
	lab.player._q = false
	await ticks(66)
	check(target.health == 92, "Manual facing does not redirect the bolt to an off-axis zombie")

	lab.reset_player()
	await ticks(12)
	target.position = Vector3(0.0, 0.0, 4.0)
	lab.get_node("HUD/DropMedium").pressed.emit()
	await ticks(5)
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(4)
	check(ammo.text.contains("24 / 25"), "Crossbow can fire during a fall")
	await ticks(90)
	check(target.health == 84, "A bolt fired above the melee height limit can hit a zombie on the ground")

	lab.reset_player()
	await ticks(12)
	attack(true)
	await ticks(3)
	Input.action_press("jump")
	await ticks(10)
	Input.action_release("jump")
	attack(false)
	check(not lab.player.is_on_floor() and lab._crossbow.ammo < 24,
		"Holding fire continues after an accepted jump")

	lab.reset_player()
	await ticks(12)
	target.position = Vector3(12.0, 0.0, 5.0)
	attack(true)
	await ticks(250)
	check(ammo.text.contains("0 / 25"), "Holding fire consumes the full magazine")
	check(lab._crossbow._bolts.size() <= 25, "An empty magazine cannot emit extra bolts")
	attack(false)
	await ticks(120)
	check(not ammo.text.contains("0 / 25"), "An empty magazine can recharge")

	equip(menu, 4)
	check(menu.selected == 4 and not ammo.visible, "Gauntlets equip and hide the ranged ammo")
	var punch_hits: Array = combat_audio._groups.get(&"gauntlet_hit", [])
	check(punch_hits.size() == 3 and punch_hits[0] != punch_hits[1] and punch_hits[1] != punch_hits[2],
		"All three distinct MD2 gauntlet hitmarker variants load")
	for i in 3:
		var group_name := StringName("gauntlet_swing_%d" % i)
		var samples: Array = combat_audio._groups.get(group_name, [])
		check(samples.size() == [3, 4, 3][i], "Each gauntlet strike loads its own MD2 sample variants")
		check(combat_audio._next_stream(group_name) != combat_audio._next_stream(group_name),
			"Repeated strikes rotate through different samples")
	check(combat_audio._groups.get(&"gauntlet_jump", []).size() == 3, "The gauntlet dive starts with the source jump variants")
	target.position = Vector3(0.0, 0.0, 1.65)
	target.health = 100
	contacts.clear()
	sound.button_pressed = true
	var hit_choices: Array[int] = []
	var record_punch := func(_p, _d, clip: String, _i, _s, _k) -> void:
		if clip.begins_with("NativeGauntlet"):
			hit_choices.append(combat_audio._next_choice.get(&"gauntlet_hit", -1))
	group.sabre_contact.connect(record_punch)
	attack(true)
	await ticks(68)
	attack(false)
	await ticks(100)
	check(contacts.size() >= 3 and contacts.slice(0, 3) == [
		"NativeGauntletAttack1", "NativeGauntletAttack2", "NativeGauntletAttack3",
	], "Held input plays all three gauntlet strikes in order")
	check(target.health <= 65, "Gauntlet combo applies its own 10/11/14 damage")
	check(hit_choices.slice(0, 3) == [1, 2, 0], "Three consecutive punches cycle through the source hit cues")
	group.sabre_contact.disconnect(record_punch)
	var punch_choice_before_slam: int = combat_audio._next_choice.get(&"gauntlet_hit", -1)
	lab.reset_player()
	await ticks(12)
	sound.button_pressed = true
	var mauler_samples: Array = combat_audio._groups.get(&"mauler_dive", [])
	check(mauler_samples.size() == 3, "All three verified MD2 Mauler Dive samples load")
	check(combat_audio._groups.get(&"gauntlet_slam", []).size() == 4, "The four source gauntlet slam samples load")
	lab.get_node("HUD/DropMedium").pressed.emit()
	await ticks(65)
	check(not combat_audio._next_choice.has(&"mauler_dive"), "An ordinary landing does not play Mauler Dive")
	lab.reset_player()
	await ticks(12)
	target.position = Vector3(0.0, 0.0, 1.6)
	target.health = 100
	lab.get_node("HUD/DropMedium").pressed.emit()
	await ticks(5)
	attack(true)
	await ticks(2)
	attack(false)
	check(not combat_audio._next_choice.has(&"mauler_dive"), "Mauler Dive audio waits for contact")
	check(not combat_audio._next_choice.has(&"gauntlet_slam"), "The gauntlet impact cue waits for contact")
	await ticks(95)
	check(target.health < 100 and contacts.has("AirAttack"), "Gauntlets can hit with their jump slam")
	check(combat_audio._next_choice.get(&"mauler_dive", 0) == 1, "The first slam plays one Mauler Dive cue")
	check(combat_audio._next_choice.get(&"gauntlet_slam", 0) == 1 and
		combat_audio._next_choice.get(&"gauntlet_hit", -1) == punch_choice_before_slam,
		"A jump hit uses the slam cue without doubling it with a punch hit")
	check(lab.player.clips.AirAttack.source_name == "Player_Jump_Gauntlet-Attack_Heavy", "The slam uses the source gauntlet pose")
	target.position = Vector3(12.0, 0.0, 0.0)
	lab.get_node("HUD/DropMedium").pressed.emit()
	await ticks(5)
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(95)
	check(combat_audio._next_choice.get(&"mauler_dive", 0) == 2, "A missed slam advances to the next sample")
	check(combat_audio._next_choice.get(&"gauntlet_slam", 0) == 2, "An empty landing still plays the slam impact")
	sound.button_pressed = false
	lab.get_node("HUD/DropMedium").pressed.emit()
	await ticks(5)
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(95)
	check(combat_audio._next_choice.get(&"mauler_dive", 0) == 2, "The combat mute suppresses Mauler Dive")
	check(combat_audio._next_choice.get(&"gauntlet_slam", 0) == 2, "The combat mute suppresses the slam impact")
	equip(menu, 0)
	check(menu.selected == 0 and lab.player.clips.AirAttack == original_air,
		"Switching back restores the original Sabre")
	lab.queue_free()
	# Let the audio server release stopped voices before a fixed-FPS test exits.
	var audio_end := Time.get_ticks_msec() + 100
	while Time.get_ticks_msec() < audio_end:
		await process_frame
	print("MECHANIC_LAB_REQUESTED_WEAPONS failures=", failures)
	quit(1 if failures else 0)

func check_crossbow_impact_burst(lab: Node3D, sparks: MultiMeshInstance3D) -> void:
	if sparks == null:
		return
	var crossbow = lab._crossbow
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 2.0, 0.1)
	collider.shape = box
	wall.add_child(collider)
	lab.add_child(wall)
	wall.position = Vector3(18.0, 1.25, 3.0)
	await ticks(2)
	for index in 25:
		var origin := Vector3(15.0 + index * 0.25, 1.25, 0.0)
		crossbow.fire(origin, Vector3.BACK, -300 - index, origin)
	await ticks(8)
	check(crossbow._bolts.is_empty() and sparks.multimesh.visible_instance_count in range(200, 251),
		"One batch can draw both emitters for all 25 simultaneous arrow impacts")
	crossbow.reset()
	check(sparks.multimesh.visible_instance_count == 0,
		"Reset clears the whole batch immediately")
	wall.queue_free()

func check_crossbow_trail(lab: Node3D) -> void:
	var crossbow = lab._crossbow
	var ribbon := crossbow.get_node_or_null("ArrowTrail") as MeshInstance3D
	check(ribbon != null, "Polaris has a shared ribbon renderer")
	if ribbon == null:
		return
	check(is_equal_approx(CrossPollinator._trail_opacity(0.2), 0.2)
		and is_equal_approx(CrossPollinator._trail_opacity(0.5), 0.05)
		and is_zero_approx(CrossPollinator._trail_opacity(0.6)),
		"Polaris opacity follows the measured two-segment curve")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 0.1)
	collider.shape = box
	wall.add_child(collider)
	lab.add_child(wall)
	wall.position = Vector3(18.0, 1.25, 4.0)
	await ticks(2)
	var origin := Vector3(18.0, 1.25, 0.0)
	crossbow.fire(origin, Vector3.BACK, -201, origin)
	await ticks(4)
	check(ribbon.visible and crossbow._trails.size() == 1 and crossbow._bolts.size() == 1,
		"A travelling bolt draws a ribbon in the shared renderer")
	await ticks(8)
	check(ribbon.visible and ribbon.mesh.get_surface_count() == 1
		and crossbow._bolts.is_empty() and crossbow._trails.size() == 1,
		"The already-laid ribbon decays after impact")
	if crossbow._trails.size() == 1:
		check(absf(float(crossbow._trails[0].distance) - 3.95) < 0.03,
			"The ribbon stops at the wall surface")
	await ticks(18)
	check(not ribbon.visible and crossbow._trails.is_empty(), "The last ribbon sample expires after 0.30 seconds")
	crossbow.fire(origin, Vector3.BACK, -202, origin)
	crossbow.fire(origin + Vector3.RIGHT * 0.3, Vector3.BACK, -203, origin + Vector3.RIGHT * 0.3)
	await ticks(3)
	check(crossbow._trails.size() == 2 and ribbon.mesh.get_surface_count() == 1,
		"Two arrows share one ribbon draw surface")
	crossbow.reset()
	check(not ribbon.visible and crossbow._trails.is_empty(), "Reset clears the flying ribbon immediately")
	wall.queue_free()

func check_crossbow_collision_radius(lab: Node3D) -> void:
	var crossbow = lab._crossbow
	var target := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.04, 0.8, 0.02)
	collider.shape = box
	target.add_child(collider)
	lab.add_child(target)
	var origin := Vector3(15.0, 2.0, 0.0)
	target.position = origin + Vector3(0.09, 0.0, 2.2)
	var hits: Array[Dictionary] = []
	var record_hit := func(hit: Dictionary, _direction: Vector3, _serial: int) -> void:
		hits.append(hit)
	crossbow.bolt_impact.connect(record_hit)
	await ticks(2)
	crossbow.fire(origin, Vector3.BACK, -101, origin - Vector3.BACK * 0.3)
	await ticks(8)
	check(hits.size() == 1 and hits[0].collider == target and absf(hits[0].position.z - 2.19) < 0.03,
		"The source-size arrow hits a thin obstacle 7 cm from its centre line")
	target.position.x += 0.05
	await ticks(2)
	crossbow.fire(origin, Vector3.BACK, -102, origin - Vector3.BACK * 0.3)
	await ticks(8)
	check(hits.size() == 1, "The arrow misses a thin obstacle 12 cm from its centre line")
	target.position = origin + Vector3(0.09, 0.0, -0.30)
	await ticks(2)
	var active_bolts: int = crossbow._bolts.size()
	crossbow.fire(origin, Vector3.BACK, -103, origin - Vector3.BACK * 0.3)
	check(hits.size() == 2 and hits[1].collider == target and crossbow._bolts.size() == active_bolts,
		"An obstacle already overlapping the clearance sphere blocks the shot before launch")
	crossbow.bolt_impact.disconnect(record_hit)
	crossbow.reset()
	target.queue_free()

func check_weapon_movement(lab: Node3D, menu: OptionButton) -> void:
	var player = lab.player
	player.scripted_input = true
	for index in WALK_SOURCES.size():
		equip(menu, index)
		await ticks(4)
		check(lab._equipped_weapon == index, "Equips weapon %d for movement" % index)
		player.requested_direction = Vector2(0.0, 1.0)
		await ticks(25)
		check(player.active_clip == "Walk" and player.clips.Walk.source_name == WALK_SOURCES[index]
			and not player._use_composed_gait(player.active_clip) and not player.hybrid_motion.owns_pose,
			"Shift walk uses the MD2 source for weapon %d" % index)
		if index == 3:
			player.requested_run = true
			await ticks(25)
			check(player.active_clip == "Run" and player.hybrid_motion.last_kind == "CrossbowRun"
				and player.hybrid_motion.owns_pose, "Crossbow run uses Actions & Stuff")
			var grip := lab._crossbow_mount as MeshInstance3D
			var support_hand: int = player.skeleton.find_bone("J_R_Hand")
			var initial_palm := grip.to_local(player.skeleton.to_global(player.skeleton.get_bone_global_pose(support_hand).origin))
			var support_drift := 0.0
			var lowest_pitch := INF
			var highest_pitch := -INF
			var highest_muzzle := -INF
			var lowest_muzzle := INF
			for frame in 36:
				await physics_frame
				var rail: Vector3 = player.visual.global_basis.inverse() * grip.global_basis.z.normalized()
				var pitch := asin(clampf(rail.y, -1.0, 1.0))
				lowest_pitch = minf(lowest_pitch, pitch)
				highest_pitch = maxf(highest_pitch, pitch)
				var muzzle_height: float = player.visual.to_local(grip.to_global(CrossPollinator.MUZZLE)).y
				highest_muzzle = maxf(highest_muzzle, muzzle_height)
				lowest_muzzle = minf(lowest_muzzle, muzzle_height)
				var palm: Vector3 = player.skeleton.to_global(player.skeleton.get_bone_global_pose(support_hand).origin)
				support_drift = maxf(support_drift, grip.to_local(palm).distance_to(initial_palm))
			check(highest_pitch - lowest_pitch > deg_to_rad(23.0),
				"The crossbow follows the Actions & Stuff run sway")
			check(lowest_muzzle > 0.28 and highest_muzzle < 0.90,
				"The running grip stays in a low carry while swaying (%.3f–%.3f m)" % [lowest_muzzle, highest_muzzle])
			check(support_drift < 0.015,
				"The support hand stays seated on the crossbow throughout the running sway")
			var motion = player.hybrid_motion
			var run_pose: Array[Transform3D] = player.source_gait.sample("Run", 0.66)
			var walk_pose: Array[Transform3D] = player.source_gait.sample("Walk", 0.0)
			var left_shoulder: Vector3 = walk_pose[motion._left_arm].origin
			var right_shoulder: Vector3 = walk_pose[motion._right_arm].origin
			var carry_pose: Array[Transform3D] = motion.crossbow_run_pose(run_pose, 0.66)
			check(carry_pose[motion._left_arm].origin.is_equal_approx(left_shoulder)
				and carry_pose[motion._right_arm].origin.is_equal_approx(right_shoulder),
				"The paired crossbow sway rotates at the two source shoulder anchors")
			var presenter = player.render_presenter
			presenter.prepare(0.5)
			var mesh_index: int = presenter.meshes.find(grip)
			var bone: int = player.skeleton.find_bone("J_L_Hand")
			var socket := grip.get_parent() as BoneAttachment3D
			check(socket.bone_idx == bone and mesh_index >= 0 and
				Vector3(presenter.display_meshes[mesh_index].origin).distance_to(
					Vector3(presenter.display_world[bone].origin)) < 0.20,
				"Crossbow follows the left-hand socket between physics ticks")
			player.requested_run = false
			await ticks(12)
			check(player.active_clip == "Walk" and not player.hybrid_motion.owns_pose,
				"Crossbow returns to MD2 Walk when slowing down")
		player.requested_direction = Vector2.ZERO
		await ticks(26)
	check(lab._left_gauntlet.get_parent().bone_name == "J_L_Arm"
		and lab._right_gauntlet.get_parent().bone_name == "J_R_Arm", "Gauntlets follow both rendered fists")
	equip(menu, 0)
	player.scripted_input = false
	lab.reset_player()
	await ticks(12)

func check_crossbow_settle(lab: Node3D, menu: OptionButton) -> void:
	equip(menu, 3)
	await ticks(14)
	var player = lab.player
	var mount := lab._crossbow_mount as MeshInstance3D
	var rail: Vector3 = player.visual.global_basis.inverse() * mount.global_basis.z.normalized()
	check(rail.y < -0.40, "MD2's source wrist carries the idle crossbow diagonally down")
	attack(true)
	await ticks(2)
	attack(false)
	var idle_mesh := mount.mesh
	var seen_recoil_mesh := false
	var previous := mount.to_global(CrossPollinator.MUZZLE)
	var largest_step := 0.0
	var idle_frames := 0
	var idle_start := -1
	var max_recovery_step := 0.0
	var previous_mesh := mount.mesh
	for frame in 90:
		await physics_frame
		var grip := mount.to_global(CrossPollinator.MUZZLE)
		var scale := mount.global_basis.get_scale()
		check(scale.distance_to(Vector3.ONE) < 0.01, "Crossbow stays full size during recoil and blend-out")
		seen_recoil_mesh = seen_recoil_mesh or mount.mesh != idle_mesh
		if player.active_clip == CrossPollinator.RECOVERY and mount.mesh == previous_mesh:
			max_recovery_step = maxf(max_recovery_step, previous.distance_to(grip))
		if player.active_clip == "Idle":
			if idle_start < 0:
				idle_start = frame
				check(player.source_transition.duration >= 0.25
					and player.source_transition.incoming_weight < 0.05,
					"Crossbow eases into the lowering pose")
			largest_step = maxf(largest_step, previous.distance_to(grip))
			idle_frames += 1
			if idle_frames == 20:
				break
		previous = grip
		previous_mesh = mount.mesh
	check(max_recovery_step < 0.080, "The source recoil lowers smoothly between its authored frames")
	check(idle_start >= 0 and idle_start < 40 and idle_frames == 20
		and largest_step < 0.09 and player.source_transition.incoming_weight == 1.0,
		"The crossbow settles back to idle without snapping the muzzle (%.3f m)" % largest_step)
	check(seen_recoil_mesh and mount.mesh == idle_mesh, "The source recoil mesh swaps back to the carry mesh")
	var weapon_bone: int = player.skeleton.find_bone("J_L_Weapon")
	var weapon_pose: Transform3D = player.skeleton.global_transform * player.skeleton.get_bone_global_pose(weapon_bone)
	check(mount.global_position.distance_to(weapon_pose * Vector3(0, 0.16, 0)) < 0.001
		and mount.global_basis.z.normalized().dot(weapon_pose.basis.z.normalized()) > 0.9999,
		"Idle uses the MD2 weapon socket and its 16 cm offset")
	player.scripted_input = true
	player.attack(true)
	await ticks(3)
	player.attack(false)
	player.requested_direction = Vector2(0, 1)
	player.requested_run = true
	for frame in 45:
		await physics_frame
		if player.active_clip == "Run":
			break
	check(player.active_clip == "Run" and player.source_transition.duration >= 0.16
		and player.source_transition.incoming_weight < 0.05,
		"Releasing a shot while moving blends into the running pose")
	var last_muzzle: Vector3 = player.visual.to_local(mount.to_global(CrossPollinator.MUZZLE))
	var peak_moving_step := 0.0
	for frame in 15:
		await physics_frame
		var muzzle: Vector3 = player.visual.to_local(mount.to_global(CrossPollinator.MUZZLE))
		peak_moving_step = maxf(peak_moving_step, last_muzzle.distance_to(muzzle))
		last_muzzle = muzzle
	check(peak_moving_step < 0.19,
		"The crossbow lowers into the run without a muzzle jump (%.3f m)" % peak_moving_step)
	check(player.hybrid_motion.last_kind == "CrossbowRun" and mount.mesh == idle_mesh,
		"Running after a shot restores the Actions & Stuff carry")
	player.scripted_input = false
	player.requested_direction = Vector2.ZERO
	player.requested_run = false
	equip(menu, 0)
	lab.reset_player()
	await ticks(12)

func check_crossbow_equip_audio(lab: Node3D, menu: OptionButton) -> void:
	var audio = lab.get_node("CombatAudio")
	var sound := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var equip_samples: Array = audio._groups.get(&"crossbow_equip", [])
	var unequip_samples: Array = audio._groups.get(&"crossbow_unequip", [])
	check(equip_samples.size() == 1 and unequip_samples.size() == 1, "Both MD2 crossbow switch cues load")
	sound.button_pressed = true
	equip(menu, 3)
	check(audio._voices.any(func(voice): return voice.playing and voice.stream in equip_samples),
		"Equipping the crossbow plays its source cue")
	equip(menu, 0)
	check(audio._voices.any(func(voice): return voice.playing and voice.stream in unequip_samples),
		"Switching away from the crossbow plays its source cue")
	sound.button_pressed = false
	equip(menu, 3)
	equip(menu, 0)
	check(not audio._voices.any(func(voice): return voice.playing), "Combat mute suppresses weapon switch cues")
