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
		world.reset_player()
		await ticks(12)
		var before: Dictionary = audio._next_choice.duplicate()
		check(world.player.drop_for_lab(5.0), "The fixture can repeat an ordinary drop")
		await ticks(110)
		check(audio._next_choice == before, "Ordinary landing posts no heavy attack cue")
		for surface in ["dirt", "stone"]:
			var found := false
			for cell: Vector3i in world.geometry.cells:
				var tile: Dictionary = world.runtime.palette[world.geometry.cells[cell]]
				if tile.category != "terrain" or not tile.kind.begins_with(surface):
					continue
				var at: Vector3 = world.source_to_world(cell)
				at.y += float(tile.base_y_offset) + float(tile.height)
				if not is_equal_approx(at.y, world.surface_height(at.x, at.z)):
					continue
				world.player.heavy_jump_landed.emit(at + Vector3.UP * 0.02, Vector3.FORWARD, 41, 5.0)
				check(audio._next_choice.get(StringName("slam_" + surface), 0) == 1,
					"The authored %s collision selects its own source family" % surface)
				found = true
				break
			check(found, "WorldMap has an exposed %s fixture" % surface)
		world.showcase.set_audio_enabled(false)
		check(AudioServer.is_bus_mute(0) and audio._voices.all(func(v): return not v.playing and v.stream == null),
			"Audio off stops landing tails and restores silence")
	print("WORLD_MAP_HEAVY_LANDING_AUDIO failures=", failures)
	world.free()
	quit(0 if failures.is_empty() else 1)
