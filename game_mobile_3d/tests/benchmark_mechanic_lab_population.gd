extends SceneTree
## Repeatable population benchmark for the existing MechanicLab scene.
## Run with --audio-driver Dummy and user args --population=100 --cycles=1 --combat-audio.

const LAB := preload("res://scenes/dev/MechanicLab.tscn")
const Zombies := preload("res://scripts/mechanic_lab_zombies.gd")
const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")
const CombatAudio := preload("res://scripts/mechanic_lab_combat_audio.gd")
const POPULATIONS := [1, 10, 25, 50, 100, 150, 200]
const RENDER_SIZE := Vector2i(960, 540)
const FIXTURE_HP := 10000

var lab: Node3D
var group: Zombies
var audio: CombatAudio
var dust: MultiMeshInstance3D
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
var damage_glyph_peak := 0
var voices_peak := 0
var player_hits := 0
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
	if counts[0] not in POPULATIONS or cycles < 1:
		printerr("Use a supported population ", POPULATIONS, " and at least one cycle")
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
	(lab.get_node("HUD/CombatAudioToggle") as CheckButton).button_pressed = audio_enabled
	group.player_hit.connect(func(_damage: int): player_hits += 1)
	viewport = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	physics_frame.connect(sample_physics_start)
	process_frame.connect(sample_frame)
	var label := "headless" if DisplayServer.get_name() == "headless" else "rendered"
	print("POPULATION_SETUP ", JSON.stringify({
		"populations": counts, "cycles": cycles, "output": label,
		"viewport": [root.size.x, root.size.y], "physics_hz": Engine.physics_ticks_per_second,
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "audio_driver": AudioServer.get_driver_name(),
		"combat_audio": audio_enabled, "corpse_seconds": group.corpse_lifetime,
	}))
	await wait_ticks(90)
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
		if not group.spawn(lab.player, Basis.IDENTITY, lab.get_node("CombatEffects"), true, baby):
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
		"peak_zombie_dust": dust_peak, "peak_damage_glyphs": damage_glyph_peak,
		"peak_shared_combat_voices": voices_peak, "nodes": get_node_count(),
	}))
	phase = ""

func stats(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {}
	samples.sort()
	var end := samples.size() - 1
	return {"p50": samples[floori(0.5 * end)], "p95": samples[floori(0.95 * end)], "max": samples[end]}
