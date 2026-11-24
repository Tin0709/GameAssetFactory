extends SceneTree
## Repeatable population benchmark for the existing MechanicLab scene.
## Run with --audio-driver Dummy and user args --population=100 --cycles=1 --combat-audio.
## Add --combo=prime-gauntlets or --combo=curved-greatsword for a held-E workload.

const LAB := preload("res://scenes/dev/MechanicLab.tscn")
const MechanicLab := preload("res://scripts/mechanic_lab.gd")
const Zombies := preload("res://scripts/mechanic_lab_zombies.gd")
const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")
const CombatAudio := preload("res://scripts/mechanic_lab_combat_audio.gd")
const POPULATIONS := [1, 10, 25, 50, 100, 150, 200]
const RENDER_SIZE := Vector2i(960, 540)
const FIXTURE_HP := 10000
const COMBO_SECONDS := 15.0
const COMBO_WEAPONS := {
	"prime-gauntlets": MechanicLab.Weapon.GAUNTLETS,
	"curved-greatsword": MechanicLab.Weapon.CURVED_GREATSWORD,
}

var lab: Node3D
var group: Zombies
var audio: CombatAudio
var dust: MultiMeshInstance3D
var sparks: MultiMeshInstance3D
var numbers: MultiMeshInstance3D
var viewport: RID
var cycle := 0
var population := 0
var phase := ""
var last_frame_us := 0
var first_physics_us := 0
var ticks_in_frame := 0
var max_physics_ticks_per_frame := 0
var phase_started_us := 0
var phase_started_tick := 0
var frame_ms: Array[float] = []
var physics_window_ms: Array[float] = []
var render_cpu_ms: Array[float] = []
var render_gpu_ms: Array[float] = []
var draw_peak := 0
var memory_peak := 0
var gpu_memory_peak := 0
var dust_peak := 0
var sparks_peak := 0
var damage_glyph_peak := 0
var voices_peak := 0
var player_hits := 0
var combo_weapon := ""
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var counts := POPULATIONS.duplicate()
	var cycles := 1
	for arg in args:
		if arg.begins_with("--population="):
			counts = [arg.trim_prefix("--population=").to_int()]
		elif arg.begins_with("--cycles="):
			cycles = arg.trim_prefix("--cycles=").to_int()
		elif arg.begins_with("--combo="):
			combo_weapon = arg.trim_prefix("--combo=")
	if counts[0] not in POPULATIONS or cycles < 1:
		printerr("Use a supported population ", POPULATIONS, " and at least one cycle")
		quit(2)
		return
	if not combo_weapon.is_empty() and not COMBO_WEAPONS.has(combo_weapon):
		printerr("Choose a combo workload from ", COMBO_WEAPONS.keys())
		quit(2)
		return
	var audio_enabled := "--combat-audio" in args
	if audio_enabled and AudioServer.get_driver_name() != "Dummy":
		printerr("The audio workload requires --audio-driver Dummy")
		quit(2)
		return
	lab = LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	root.size = RENDER_SIZE
	group = lab.get_node("Zombies")
	if not group.full_actions_stuff_available or (lab.get_node("HUD/SpawnZombie") as Button).disabled:
		printerr("The population benchmark requires the verified private Lab assets and A&S 1.13")
		quit(2)
		return
	audio = lab.get_node("CombatAudio")
	numbers = lab.get_node_or_null("CombatEffects/ZombieDamageNumbers")
	dust = lab.get_node_or_null("ZombieStepDust")
	sparks = lab.get_node_or_null("ContactSparks/Streaks")
	(lab.get_node("HUD/CombatAudioToggle") as CheckButton).button_pressed = audio_enabled
	group.player_hit.connect(func(_damage: int): player_hits += 1)
	viewport = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	physics_frame.connect(sample_physics_start)
	process_frame.connect(sample_frame)
	var label := "headless" if DisplayServer.get_name() == "headless" else "rendered"
	await wait_ticks(90)
	if not combo_weapon.is_empty():
		var picker := lab.get_node("HUD/Weapon") as OptionButton
		var weapon: int = COMBO_WEAPONS[combo_weapon]
		picker.select(weapon)
		picker.item_selected.emit(weapon)
		if picker.selected != weapon:
			printerr("Could not equip the verified weapon for ", combo_weapon)
			quit(2)
			return
		await wait_ticks(90)
	print("POPULATION_SETUP ", JSON.stringify({
		"populations": counts, "cycles": cycles, "output": label,
		"viewport": [root.size.x, root.size.y], "physics_hz": Engine.physics_ticks_per_second,
		"fps_cap": Engine.max_fps,
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "audio_driver": AudioServer.get_driver_name(),
		"combat_audio": audio_enabled, "corpse_seconds": group.corpse_lifetime,
		"combo_weapon": combo_weapon,
	}))
	for pass_index in cycles:
		cycle = pass_index + 1
		for count: int in counts:
			population = count
			await run_population()
			if not failures.is_empty():
				break
		if not failures.is_empty():
			break
	print("POPULATION_END ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)

func run_population() -> void:
	lab.reset_player()
	lab.player_health = FIXTURE_HP
	group._spawn_serial = 0
	await measure("empty", 60)
	var baby_count := 0
	var spawn_started := Time.get_ticks_usec()
	for i in population:
		var baby := (i + 1) % 5 == 0
		if not group.spawn(lab.player, Basis.IDENTITY, lab.get_node("CombatEffects"), combo_weapon.is_empty(), baby):
			failures.append("%d: Could only spawn %d zombies" % [population, i])
			return
		baby_count += int(baby)
	print("POPULATION_SPAWN ", JSON.stringify({
		"population": population, "cycle": cycle,
		"adults": population - baby_count, "babies": baby_count,
		"spawn_dispatch_ms": (Time.get_ticks_usec() - spawn_started) / 1000.0,
	}))
	await measure("spawn", 70)
	Input.action_press("move_backward")
	await measure("chase", 120)
	Input.action_release("move_backward")
	player_hits = 0
	await measure("melee", 300)
	if group.get_child_count() != population or player_hits == 0:
		failures.append("%d: Expected a complete live crowd and at least one melee hit" % population)
		return
	if not combo_weapon.is_empty():
		await run_held_combo()
		for zombie in group.get_children():
			zombie.free()
		await measure("cleanup", 120)
		return

	# Inject a simultaneous burst at the Lab's confirmed-contact entry point.
	# This exercises damage, death, sound and VFX on the real living poses.
	# The fixture deliberately bypasses melee targeting and range checks.
	start_phase("death")
	var hit_started := Time.get_ticks_usec()
	for zombie: Zombie in group.get_children():
		group._apply_contact(zombie, zombie.combat_center(), "Attack3", 2,
			group._spawn_serial, Zombies.SABRE_STRIKES[2], Vector3.RIGHT, false, lab.player.global_position)
	var dispatch_ms := (Time.get_ticks_usec() - hit_started) / 1000.0
	await physics_frame
	var first_tick_ms := (Time.get_ticks_usec() - hit_started) / 1000.0
	var first_tick_ragdolls := count_active_ragdolls()
	if first_tick_ragdolls != population:
		failures.append("%d: Only %d ragdolls ran on the first tick" % [population, first_tick_ragdolls])
	var active_ragdoll_ticks := first_tick_ragdolls
	for i in 119:
		await physics_frame
		active_ragdoll_ticks += count_active_ragdolls()
	finish_phase()
	var survivors := group.get_child_count()
	print("POPULATION_DEATH ", JSON.stringify({
		"population": population, "cycle": cycle, "prior_melee_hits": player_hits,
		"hit_dispatch_ms": dispatch_ms, "until_next_physics_signal_ms": first_tick_ms,
		"first_tick_ragdolls": first_tick_ragdolls, "active_ragdoll_ticks": active_ragdoll_ticks,
		"survivors": survivors,
	}))
	await measure("cleanup", 120)
	if survivors != 0:
		failures.append("%d: %d actors remain after the death phase" % [population, survivors])

func run_held_combo() -> void:
	var attacks: Dictionary[int, String] = {}
	var contacts: Dictionary[int, int] = {}
	var kills := [0]
	var spawned := [0]
	var record_attack := func(_index, clip, serial): attacks[serial] = clip
	var record_contact := func(_point, _direction, _clip, _index, serial, lethal):
		contacts[serial] = contacts.get(serial, 0) + 1
		kills[0] += int(lethal)
	var refill := func(): spawned[0] += refill_crowd(population + spawned[0])
	lab.player.attack_accepted.connect(record_attack)
	group.sabre_contact.connect(record_contact)
	process_frame.connect(refill)
	player_hits = 0
	var fewest_living := population
	var peak_ragdolls := 0
	start_phase("held_combo")
	press_attack(true)
	for tick in roundi(COMBO_SECONDS * Engine.physics_ticks_per_second):
		await physics_frame
		fewest_living = mini(fewest_living, group._living_count)
		if group.get_child_count() > group._living_count:
			peak_ragdolls = maxi(peak_ragdolls, count_active_ragdolls())
	press_attack(false)
	finish_phase()
	process_frame.disconnect(refill)
	lab.player.attack_accepted.disconnect(record_attack)
	group.sabre_contact.disconnect(record_contact)
	var damage_contacts := 0
	var splash_strikes := 0
	var peak_contacts := 0
	for count: int in contacts.values():
		damage_contacts += count
		splash_strikes += int(count > 1)
		peak_contacts = maxi(peak_contacts, count)
	print("POPULATION_COMBO ", JSON.stringify({
		"population": population, "cycle": cycle, "weapon": combo_weapon, "seconds": COMBO_SECONDS,
		"accepted_attacks": attacks.size(), "damaging_attacks": contacts.size(), "damage_contacts": damage_contacts,
		"multi_target_attacks": splash_strikes, "max_targets_per_attack": peak_contacts,
		"kills": kills[0], "reinforcements": spawned[0], "fewest_living": fewest_living,
		"peak_ragdolls": peak_ragdolls, "incoming_hits": player_hits,
	}))
	if attacks.size() < 5 or damage_contacts == 0 or kills[0] == 0:
		failures.append("%d: Held %s should produce repeated real attacks, hits and deaths" % [population, combo_weapon])
	if combo_weapon == "curved-greatsword" and population >= 50 and splash_strikes == 0:
		failures.append("The Curved Greatsword crowd should receive splash damage")
	# Let the remaining strike finish and allow the last corpses their natural deadline.
	await measure("combo_recovery", 120)
	if group.get_child_count() != group._living_count:
		failures.append("%d: Corpses remain after combo recovery" % population)

func refill_crowd(spawned_total: int) -> int:
	var missing := mini(population - group._living_count, MechanicLab.CROWD_SPAWN_LIMIT_PER_FRAME)
	if missing <= 0:
		return 0
	var deadline := Time.get_ticks_usec() + MechanicLab.CROWD_SPAWN_BUDGET_USEC
	var facing := Basis(Vector3.UP, lab.player.visual.rotation.y)
	var effects := lab.get_node("CombatEffects") as Node3D
	for i in missing:
		var baby := (spawned_total + i + 1) % 5 == 0
		if not group.spawn(lab.player, facing, effects, false, baby):
			return i
		if Time.get_ticks_usec() >= deadline:
			return i + 1
	return missing

func press_attack(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)

func wait_ticks(count: int) -> void:
	for i in count:
		await physics_frame

func count_active_ragdolls() -> int:
	var active := 0
	for zombie: Zombie in group.get_children():
		active += int(zombie.ragdoll.running)
	return active

func measure(name: String, ticks: int) -> void:
	start_phase(name)
	await wait_ticks(ticks)
	finish_phase()

func start_phase(name: String) -> void:
	frame_ms.clear()
	physics_window_ms.clear()
	render_cpu_ms.clear()
	render_gpu_ms.clear()
	draw_peak = 0
	memory_peak = 0
	gpu_memory_peak = 0
	dust_peak = 0
	sparks_peak = 0
	damage_glyph_peak = 0
	voices_peak = 0
	max_physics_ticks_per_frame = 0
	phase_started_us = Time.get_ticks_usec()
	phase_started_tick = Engine.get_physics_frames()
	phase = name

func sample_physics_start() -> void:
	if ticks_in_frame == 0:
		first_physics_us = Time.get_ticks_usec()
	ticks_in_frame += 1

func sample_frame() -> void:
	var us := Time.get_ticks_usec()
	if not phase.is_empty() and last_frame_us > 0:
		frame_ms.append((us - last_frame_us) / 1000.0)
		if ticks_in_frame > 0:
			physics_window_ms.append((us - first_physics_us) / 1000.0)
			max_physics_ticks_per_frame = maxi(max_physics_ticks_per_frame, ticks_in_frame)
	last_frame_us = us
	ticks_in_frame = 0
	if phase.is_empty():
		return
	render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
	render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	draw_peak = maxi(draw_peak, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	memory_peak = maxi(memory_peak, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	gpu_memory_peak = maxi(gpu_memory_peak, int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
	if dust != null:
		dust_peak = maxi(dust_peak, dust.multimesh.visible_instance_count)
	if sparks != null:
		sparks_peak = maxi(sparks_peak, sparks.multimesh.visible_instance_count)
	if numbers != null:
		damage_glyph_peak = maxi(damage_glyph_peak, numbers.multimesh.visible_instance_count)
	var playing := 0
	for voice in audio._voices:
		playing += int(voice.playing)
	voices_peak = maxi(voices_peak, playing)

func finish_phase() -> void:
	var seconds := (Time.get_ticks_usec() - phase_started_us) / 1000000.0
	var ticks := Engine.get_physics_frames() - phase_started_tick
	print("POPULATION_PHASE ", JSON.stringify({
		"cycle": cycle, "population": population, "phase": phase,
		"samples": frame_ms.size(), "wall_seconds": seconds, "physics_ticks": ticks,
		"frame_ms": stats(frame_ms), "physics_window_ms": stats(physics_window_ms),
		"max_physics_ticks_per_frame": max_physics_ticks_per_frame,
		"render_cpu_ms": stats(render_cpu_ms), "render_gpu_ms": stats(render_gpu_ms),
		"peak_draws": draw_peak, "peak_static_bytes": memory_peak, "peak_video_bytes": gpu_memory_peak,
		"peak_zombie_dust": dust_peak, "peak_contact_sparks": sparks_peak, "peak_damage_glyphs": damage_glyph_peak,
		"peak_shared_combat_voices": voices_peak, "nodes": get_node_count(),
	}))
	phase = ""

func stats(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {}
	samples.sort()
	var end := samples.size() - 1
	return {"p50": samples[floori(0.5 * end)], "p95": samples[floori(0.95 * end)], "max": samples[end]}
