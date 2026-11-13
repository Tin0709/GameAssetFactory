extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var world := (load("res://scenes/WorldMap.tscn") as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	var dust := world.get_node_or_null("MovementDust") as Node3D
	check(dust != null, "WorldMap installs the verified movement dust emitter")
	if dust != null:
		var site := Vector3(-0.5, 3.02, -0.5)
		for block in ["grass", "dirt", "stone"]:
			var found := false
			for cell: Vector3i in world.geometry.cells:
				var tile: Dictionary = world.runtime.palette[world.geometry.cells[cell]]
				if tile.category != "terrain" or not tile.kind.begins_with(block):
					continue
				var at: Vector3 = world.source_to_world(cell)
				at.y += float(tile.base_y_offset) + float(tile.height)
				if absf(at.x) > 42.0 or absf(at.z) > 42.0 or not is_equal_approx(at.y, world.surface_height(at.x, at.z)):
					continue
				world.player.surface_contact.emit(at + Vector3.UP * 0.08, true)
				var visible: Array[Sprite3D] = []
				for sprite: Sprite3D in dust.get_children():
					if sprite.visible:
						visible.append(sprite)
				check(visible.size() == 5, "The %s surface emits one landing burst" % block)
				if visible.size() > 0:
					check(absf(visible[0].global_position.y - (at.y + 0.05)) < 0.002,
						"The %s burst sits on the actual collider" % block)
					check(visible[0].modulate.is_equal_approx(Color(dust.SURFACE_DUST[block], 0.58)),
						"The %s burst uses its surface tint" % block)
				world.reset_player()
				check(dust.get_children().all(func(sprite): return not sprite.visible), "WorldMap reset clears dust immediately")
				site = at
				found = true
				break
			check(found, "The authored map includes an exposed %s test surface" % block)
		world.player.surface_contact.emit(site + Vector3.UP * 4.0, false)
		check(dust.get_children().all(func(sprite): return not sprite.visible), "An unsupported foot emits no dust")
		var saw_live_dust := false
		Input.action_press("move_forward")
		for i in 85:
			await physics_frame
			saw_live_dust = saw_live_dust or dust.get_children().any(func(sprite): return sprite.visible)
		Input.action_release("move_forward")
		check(saw_live_dust, "Actual WorldMap movement emits dust with default audio disabled")
		world.reset_player()
		for i in 12:
			await physics_frame
		var landing_bursts: Array[int] = []
		world.player.surface_contact.connect(func(_point: Vector3, landed: bool):
			if landed:
				landing_bursts.append(dust.get_children().filter(func(sprite): return sprite.visible).size()))
		Input.action_press("jump")
		await physics_frame
		await physics_frame
		Input.action_release("jump")
		for i in 85:
			await physics_frame
			if not landing_bursts.is_empty():
				break
		check(landing_bursts == [5], "An actual WorldMap jump emits exactly one burst on landing")
	print("WORLD_MAP_MOVEMENT_DUST failures=", failures)
	world.free()
	quit(0 if failures.is_empty() else 1)

