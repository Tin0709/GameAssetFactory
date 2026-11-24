extends SceneTree

var failures: Array[String] = []
var attacks: Array[String] = []
var damage: Array[int] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func attack(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var weapon := lab.get_node("HUD/Weapon") as OptionButton
	if weapon.disabled or weapon.item_count < 3:
		check(false, "MechanicLab offers Curved Greatsword alongside Sabre and Sword")
		finish(lab)
		return
	check(weapon.get_item_text(2) == "Curved Greatsword", "The third option identifies the source weapon")
	var original_gait: RefCounted = lab.player.source_gait
	var original_idle: String = lab.player.clips.Idle.action
	var research := OS.get_environment("MD2_RESEARCH_ROOT")
	OS.set_environment("MD2_RESEARCH_ROOT", ProjectSettings.globalize_path("res://"))
	weapon.select(2)
	weapon.item_selected.emit(2)
	check(weapon.selected == 0, "An invalid private asset root leaves the Sabre equipped")
	if research.is_empty():
		OS.unset_environment("MD2_RESEARCH_ROOT")
	else:
		OS.set_environment("MD2_RESEARCH_ROOT", research)
	weapon.select(2)
	weapon.item_selected.emit(2)
	check(weapon.selected == 2, "Curved Greatsword loads from the verified private assets")
	await check_locomotion(lab)
	lab.reset_player()
	await ticks(12)
	lab.player.attack_accepted.connect(func(_index, clip, _serial): attacks.append(clip))
	var group := lab.get_node("Zombies") as Node3D
	var spawn := lab.get_node("HUD/SpawnZombie") as Button
	spawn.pressed.emit()
	spawn.pressed.emit()
	if group.get_child_count() != 2:
		check(false, "Two zombies are available for the combo and splash")
		finish(lab)
		return
	var target = group.get_child(0)
	target.set_physics_process(false)
	target.position = Vector3(0.0, 0.0, 1.3)
	target.health = 100
	var distant_target = group.get_child(1)
	distant_target.set_physics_process(false)
	distant_target.position = Vector3(0.65, 0.0, 4.5)
	distant_target.health = 100
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var combat_audio := lab.get_node("CombatAudio")
	var swing_audio = lab.player.reference_audio
	check(not toggle.button_pressed and not swing_audio.enabled, "Combat audio defaults to off")
	toggle.button_pressed = true
	var swing_count: int = swing_audio.played_count
	var hit_count: int = combat_audio._next_choice.get(&"curved_hit", 0)
	var shake_contacts: Array[int] = []
	var sampled_contacts: Array[Dictionary] = []
	var hit_choices: Array[int] = []
	group.sabre_contact.connect(func(point, _direction, clip, index, serial, _lethal):
		if clip != "AirAttack" and point.distance_to(target.global_position) < 2.0:
			damage.append(target.health)
			hit_choices.append(combat_audio._next_choice.get(&"curved_hit", -1))
			sampled_contacts.append({"tick": Engine.get_physics_frames(), "index": index, "serial": serial}))
	lab.player.physics_pose_ready.connect(func():
		if sampled_contacts.is_empty() or sampled_contacts[-1].tick != Engine.get_physics_frames():
			return
		var contact := sampled_contacts[-1]
		if lab._shake_serial == contact.serial:
			shake_contacts.append(contact.index)
			check(is_equal_approx(lab._shake_sample_time, lab.player.effects.clock),
				"The finisher queues its pulse on the contact pose clock"))
	var displayed_kicks: Array[float] = []
	var sample_camera := func():
		var kick: float = lab.camera.h_offset / lab.camera.size
		if not is_zero_approx(kick):
			displayed_kicks.append(kick)
	process_frame.connect(sample_camera)
	attack(true)
	for i in 140:
		await physics_frame
		if damage.size() >= 3:
			break
	attack(false)
	var recovered := false
	for i in 75:
		await physics_frame
		recovered = recovered or lab.player.active_clip == "NativeCurvedRecovery3"
	check(attacks == ["NativeCurvedAttack1", "NativeCurvedAttack2", "NativeCurvedAttack3"],
		"Held E plays the three source attacks in order")
	check(damage == [80, 60, 30], "The three contacts deal 20, 20 and 30 damage")
	check(distant_target.health == 91, "Only the finisher reaches the distant target for 30% splash")
	process_frame.disconnect(sample_camera)
	check(shake_contacts == [2], "Only the finisher queues a nearby camera shake")
	check(not displayed_kicks.is_empty() and is_equal_approx(displayed_kicks[0], 0.008)
		and displayed_kicks.any(func(kick: float): return kick < 0.0)
		and is_zero_approx(lab.camera.h_offset),
		"The first displayed kick has full strength, reverses and returns to rest")
	check(swing_audio.played_count == swing_count + 3, "Three source swing samples reach the audio voices")
	check(combat_audio._groups.get(&"curved_hit", []).size() == 3
		and hit_choices == [(hit_count + 1) % 3, (hit_count + 2) % 3, hit_count]
		and combat_audio._next_choice.get(&"curved_hit", -1) == hit_count,
		"Three contacts play the Curved Greatsword hitmarker once per strike")
	print("CURVED_SHAKE contacts=", shake_contacts, " first_kick=", displayed_kicks[0] if not displayed_kicks.is_empty() else 0.0)
	toggle.button_pressed = false
	check(recovered and not lab.player.combo.active(), "Release plays the source finisher recovery")
	await check_aerial_attack(lab, group, target, distant_target)
	weapon.select(1)
	weapon.item_selected.emit(1)
	check(weapon.selected == 1 and group.sword_equipped, "The Sword can be equipped again")
	weapon.select(0)
	weapon.item_selected.emit(0)
	check(weapon.selected == 0 and not group.sword_equipped, "The Sabre can be equipped again")
	await ticks(4)
	check(lab.player.animation_player.assigned_animation == original_idle
		and lab.player.source_gait == original_gait,
		"Returning to Sabre restores the original locomotion profile")
	finish(lab)

func check_aerial_attack(lab: Node3D, group: Node3D, primary: Node3D, nearby: Node3D) -> void:
	var actor = lab.player
	var mesh: Mesh = actor.effects.ribbon.mesh
	for blocked: bool in [false, true]:
		lab.reset_player()
		await ticks(12)
		primary.health = 100
		nearby.health = 100
		var origin: Vector3 = actor.global_position
		var forward: Vector3 = actor.visual.global_basis.z
		primary.global_position = origin + forward * 1.50
		nearby.global_position = primary.global_position + actor.visual.global_basis.x * 2.05
		var wall: StaticBody3D
		if blocked:
			wall = StaticBody3D.new()
			wall.transform = Transform3D(Basis.looking_at(forward, Vector3.UP, true), origin + forward * 0.92 + Vector3.UP * 2.5)
			var box := BoxShape3D.new()
			box.size = Vector3(6.0, 5.0, 0.20)
			var collider := CollisionShape3D.new()
			collider.shape = box
			wall.add_child(collider)
			lab.add_child(wall)
			await physics_frame
		var touchdown: Array[int] = []
		var impacts: Array[int] = []
		var land := func(_point, _direction, _serial, _fall):
			touchdown.append(Engine.get_physics_frames())
		var contact := func(_point, _direction, clip, _index, _serial, _lethal):
			if clip == "AirAttack":
				impacts.append(Engine.get_physics_frames())
		actor.heavy_jump_landed.connect(land)
		group.sabre_contact.connect(contact)
		check(not lab.get_node("HUD/DropMedium").disabled, "The Curved Greatsword enables the Lab drop buttons")
		check(actor.drop_for_lab(3.0), "The Curved Greatsword fixture starts a drop")
		await ticks(3)
		attack(true)
		await ticks(3)
		attack(false)
		check(actor.combo.phase == &"air_attack" and actor.clips.AirAttack.source_name == "Player_2H_Medium_JumpAttack",
			"The aerial press uses the two-handed source pose")
		var early_feedback := false
		var first_ribbon := INF
		var furthest := -INF
		var shake_frame := -1
		var resume := -1.0
		for i in int(1.33 * Engine.physics_ticks_per_second):
			await physics_frame
			if touchdown.is_empty():
				early_feedback = early_feedback or primary.health != 100 or nearby.health != 100 or not actor.effects.samples.is_empty()
			elif not actor.effects.samples.is_empty() and is_inf(first_ribbon):
				first_ribbon = actor.effects.samples[0].time
			if shake_frame < 0 and lab._shake_serial == actor.combo.serial:
				shake_frame = Engine.get_physics_frames()
			if resume < 0.0 and actor.combo.phase == &"air_attack" and actor.combo.movement_allowed():
				resume = actor.combo.time
			if mesh.get_surface_count() > 0:
				for vertex: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					furthest = maxf(furthest, (vertex - origin).dot(forward))
		check(not early_feedback, "The Curved Greatsword does not slash or damage targets before landing")
		check(touchdown.size() == 1 and shake_frame > 0, "One landing schedules the camera shake")
		check(resume >= 0.712 and resume <= 0.713 + 1.0 / Engine.physics_ticks_per_second
			and not actor.combo.active(), "The two-handed landing releases movement before the end of recovery")
		if blocked:
			check(impacts.is_empty() and primary.health == 100 and nearby.health == 100,
				"The landing cannot damage targets through a solid wall")
			check(furthest <= 0.8201, "The landing ribbon cannot extend through a solid wall")
			wall.free()
		else:
			check(touchdown.size() == 1 and impacts.size() == 2 and impacts.all(func(tick): return tick > touchdown[0]),
				"One landing resolves both targets after physical touchdown")
			check(primary.health == 80 and nearby.health == 94, "The standard sword uses 20 direct and 6 splash damage")
			check(is_finite(first_ribbon) and furthest > 2.0, "The landing shows the forward blade ribbon")
		print("CURVED_AIR blocked=", blocked, " touchdown=", touchdown, " impacts=", impacts,
			" ribbon=", first_ribbon, " extent=", furthest, " shake=", shake_frame, " resume=", resume)
		actor.heavy_jump_landed.disconnect(land)
		group.sabre_contact.disconnect(contact)

func check_locomotion(lab: Node) -> void:
	var actor = lab.player
	await ticks(6)
	check(String(actor.animation_player.assigned_animation).ends_with("/NativeCurvedIdle"),
		"The equipped Curved Greatsword uses the captured two-handed idle")
	for i in 400:
		await physics_frame
		if String(actor.animation_player.assigned_animation).ends_with("/NativeCurvedInspectWeapon"):
			break
	check(String(actor.animation_player.assigned_animation).ends_with("/NativeCurvedInspectWeapon"),
		"Idle inspection shows the source two-handed weapon gesture")
	actor.scripted_input = true
	actor.requested_direction = Vector2(0.0, -1.0)
	actor.requested_run = false
	await ticks(24)
	check(String(actor.animation_player.assigned_animation).ends_with("/NativeCurvedWalk")
		and not actor.hybrid_motion.owns_pose, "Walking uses the two-handed gait pose")
	actor.requested_run = true
	await ticks(30)
	check(String(actor.animation_player.assigned_animation).ends_with("/NativeCurvedRun")
		and not actor.hybrid_motion.owns_pose, "Running uses the two-handed gait pose")
	check(is_equal_approx(actor.source_gait.state(2.8).weight, 1.0 / 9.0)
		and is_equal_approx(actor.source_gait.state(8.4).weight, 1.0),
		"The composed gait has the original walk and run sample positions")
	actor.requested_direction = Vector2.ZERO
	await ticks(16)
	actor.requested_jump = true
	await ticks(2)
	actor.requested_jump = false
	var airborne_clips: Array[String] = []
	for i in 75:
		await physics_frame
		var clip := String(actor.animation_player.assigned_animation).get_file()
		if clip.begins_with("NativeCurvedJump") and not airborne_clips.has(clip):
			airborne_clips.append(clip)
	check(airborne_clips == ["NativeCurvedJumpTakeoff", "NativeCurvedJumpAirborne", "NativeCurvedJumpLanding"],
		"Jump and landing use the three verified two-handed clips")
	actor.scripted_input = false

func finish(lab: Node) -> void:
	lab.free()
	print("MECHANIC_LAB_CURVED ", JSON.stringify({"attacks": attacks, "target_hp": damage, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
