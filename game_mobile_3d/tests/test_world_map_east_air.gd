extends SceneTree

const CONTROL := &"east_sunlit_mist"
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, detail: String) -> void:
	if not value:
		failures.append(detail)

func open_scene(bad_proof: bool) -> Node3D:
	var level := (load("res://scenes/WorldMap.tscn") as PackedScene).instantiate() as Node3D
	if bad_proof and level.get("east_air_profile_sha256") != null:
		level.set("east_air_profile_sha256", "f".repeat(64))
	root.add_child(level)
	current_scene = level
	return level

func draw_frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw

func run() -> void:
	var level := open_scene(false)
	var native := RenderingServer.get_rendering_device() != null and RenderingServer.get_current_rendering_method() == &"mobile"
	var showcase: Node = level.showcase
	var region: Node = level.get_node("SpruceSkyVisibility")
	check(level.get("east_air_profile") is String and not String(level.get("east_air_profile")).is_empty(), "F5 loads a private east volume")
	if native:
		await draw_frames(40)
		var directional: RefCounted = showcase.directional_air
		if region._dimensions.x == 104:
			var grid := showcase.mist.effect.get("east_directional_grid") as ImageTexture3D
			check(grid != null and directional.has_method("east_available"), "The expanded geometry binds the compact east atlas")
			if grid != null:
				check(grid.get_width() == 119 and grid.get_depth() == 38, "F5 uses the tested 2.5m field")
				showcase.set_hour(7.)
				await draw_frames(24)
				var values: PackedFloat32Array = directional.volume_parameters()
				check(values.size() == 36 and is_equal_approx(values[32], .4), "The default uses the 40 percent morning radiance")
				var slider := showcase._lighting_sliders.get(CONTROL) as HSlider
				check(slider != null and slider.editable and slider.value == 1., "The setting is visible and live")
				if slider != null:
					slider.value = 0.
					await draw_frames(12)
					var disabled: PackedFloat32Array = directional.volume_parameters()
					check(disabled.size() == 36 and disabled[32] == 0. and disabled.slice(0,24) == values.slice(0,24),
						"East A/B retains west and basin fields")
					slider.value = 1.
				for hour: float in [12.,19.5,22.]:
					showcase.set_hour(hour)
					await draw_frames(12)
					var protected: PackedFloat32Array = directional.volume_parameters()
					check(protected.size() == 36 and protected[3] == 0. and protected[32] == 0., "Protected phase bypass at %s" % hour)
				check(showcase.mist.effect.snapshot().ready, "The extended GPU shader has a live mist volume")
		level.free()
		await process_frame
		level = open_scene(true)
		await draw_frames(40)
		var fallback: Node = level.showcase
		if fallback.directional_air.region_available():
			check(fallback.mist.effect.get("east_directional_grid") == null and fallback.directional_air.volume_parameters().size() == 24,
				"Invalid checksum only falls back the unmatched east source")
	else:
		var field: RefCounted = showcase.directional_air
		if field.has_method("east_available"):
			check(not field.east_available(), "Fallback renderer skips the private direct source")
	level.free()
	await process_frame
	print("EAST_AIR_TEST ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
