extends SceneTree

var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func ticks(n: int) -> void:
	for i in n:
		await physics_frame

func attack(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	world = (load("res://scenes/WorldMap.tscn") as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	await ticks(12)
	var audio := world.get_node_or_null("HeavyLandingAudio")
	check(audio != null, "WorldMap has a material-aware heavy landing audio consumer")
	if audio != null:
		check(not audio.enabled and audio._voices.is_empty(), "WorldMap starts muted without loading the heavy landing voices")
		world.showcase.set_audio_enabled(true)
		var movement = world.player.environment_audio.audio
		for surface in ["grass", "dirt", "stone"]:
			check(movement.groups.get("land_" + surface, []).size() == 4, "The four pinned ordinary landing samples load for " + surface)
		check(not AudioServer.is_bus_mute(0) and audio._voices.size() == 3,
			"WorldMap audio uses one spatial landing pool")
		check(audio._groups.size() == 3 and audio._groups.get(&"slam_grass", []).size() == 6
			and audio._groups.get(&"slam_dirt", []).size() == 6 and audio._groups.get(&"slam_stone", []).size() == 6
			and audio._next_choice.is_empty(), "The switch loads exactly the three pinned surface families without preview playback")
		check(world.player.drop_for_lab(5.0), "WorldMap fixture can start a real drop")
		await ticks(5)
		attack(true)
		await ticks(2)
		attack(false)
		await ticks(105)
		check(audio._next_choice.get(&"slam_grass", 0) == 1 and audio._next_choice.size() == 1,
			"A real Sabre dive posts one grass cue at ground contact")
		check(movement.event_count.landing == 0, "A heavy landing has no ordinary landing layer")
		world.reset_player()
		await ticks(12)
		var before: Dictionary = audio._next_choice.duplicate()
		check(world.player.drop_for_lab(5.0), "The fixture can repeat an ordinary drop")
		await ticks(110)
		check(audio._next_choice == before, "Ordinary landing posts no heavy attack cue")
		check(movement.event_count.landing == 1 and movement.last_sources.get("land_grass", "").begins_with("sfx_player_land_grassPath_"),
			"An ordinary WorldMap drop plays one MD2 grass-path landing sample")
		var landings := {
			&"slam_dirt": Vector3(0.5, 3.0, -6.5),
			&"slam_stone": Vector3(-22.5, 3.5, -39.5),
		}
		for cue: StringName in landings:
			world.player.global_position = landings[cue] + Vector3.UP * 0.02
			world.player.cancel_jump()
			await ticks(12)
			check(world.player.drop_for_lab(5.0), "The %s fixture starts over terrain" % cue)
			await ticks(5)
			attack(true)
			await ticks(2)
			attack(false)
			await ticks(105)
			check(audio._next_choice.get(cue, 0) == 1, "A real dive plays exactly one %s sample" % cue)
			world.player.global_position = landings[cue] + Vector3.UP * 0.02
			world.player.cancel_jump()
			await ticks(12)
			var surface := String(cue).trim_prefix("slam_")
			var ordinary_cue := "land_" + surface
			var landing_count: int = movement.event_count.landing
			check(world.player.drop_for_lab(5.0), "The ordinary %s fixture starts over terrain" % surface)
			await ticks(110)
			check(movement.event_count.landing == landing_count + 1
				and movement.last_sources.get(ordinary_cue, "").begins_with("sfx_player_land_" + surface + "_"),
				"A real ordinary drop plays one MD2 %s landing sample" % surface)
		check(audio._next_choice.size() == 3, "Grass, dirt and stone are independent playback groups")
		var slab := Vector3(-37.5, 3.5, -35.5)
		world.player.global_position = slab + Vector3.UP * 0.02
		world.player.cancel_jump()
		await ticks(12)
		var event_count: int = movement.events.size()
		check(world.player.drop_for_lab(1.0), "The ordinary landing fixture can drop below the ledge")
		await ticks(90)
		var slab_events: Array = movement.events.slice(event_count)
		check(slab_events.size() == 1 and slab_events[0].key == "land_stone"
			and is_equal_approx(float(slab_events[0].at[1]), slab.y),
			"A real drop below the ledge plays stone audio at the lower slab")
		var before_unsupported: int = movement.events.size()
		world.player.surface_contact.emit(slab + Vector3.UP * 3.0, false)
		check(movement.events.size() == before_unsupported, "An unsupported foot does not play terrain audio")
		world.showcase.set_audio_enabled(false)
		check(AudioServer.is_bus_mute(0) and audio._voices.all(func(v): return not v.playing and v.stream == null),
			"Audio off stops landing tails and restores silence")
	# Finish teardown with wall-clock pacing for the audio thread.
	Engine.max_fps = 60
	print("WORLD_MAP_HEAVY_LANDING_AUDIO failures=", failures)
	world.free()
	# Let the Dummy mixer release its retired stream playbacks.
	await create_timer(0.25, true, false, true).timeout
	quit(0 if failures.is_empty() else 1)
