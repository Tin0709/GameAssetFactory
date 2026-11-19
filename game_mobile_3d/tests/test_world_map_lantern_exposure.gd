extends SceneTree

const CONTROL := &"lantern_exposure"
const FOREST := preload("res://assets/graphics/biomes/forest_reference.tres")
const MEADOW := preload("res://assets/graphics/biomes/meadow.tres")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func settle(frames := 24) -> void:
	for frame in frames:
		await process_frame

func active(finish: Node) -> bool:
	var effect = finish.get("_native")
	return effect != null and effect.has_method("lantern_exposure_status") and effect.lantern_exposure_status().active

func run() -> void:
	check(FOREST.get(String(CONTROL)) == .32, "Forest sets the validated 0.32 EV maximum")
	check(MEADOW.get(String(CONTROL)) == 0., "Other biomes opt into the feature explicitly")
	var world = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await settle(42)
	var showcase = world.showcase
	var finish = showcase.phase_finish
	var native := RenderingServer.get_current_rendering_method() == &"mobile" and RenderingServer.get_rendering_device() != null
	var slider := showcase._lighting_sliders.get(CONTROL) as HSlider
	check(not active(finish), "Noon skips lantern exposure")
	showcase.set_hour(22.)
	await settle(42)
	if native:
		check(slider != null and slider.editable and slider.value == 1., "Forest exposes a live default-on control")
		check(active(finish), "Depth-aware lantern exposure renders by default at 22:00")
		if active(finish) and slider != null:
			var before: float = finish._native.lantern_exposure_status().amount
			slider.value = .5
			await settle()
			check(is_equal_approx(finish._native.lantern_exposure_status().amount, before * .5), "Half-strength uploads half the trim")
			var preset_path := "user://test-lantern-exposure-%d.cfg" % OS.get_process_id()
			check(showcase.save_lighting_mix(preset_path) == OK, "The new control is saved with the lighting preset")
			slider.value = 1.
			check(showcase.load_lighting_mix(preset_path) == OK and is_equal_approx(slider.value, .5),
				"Loading restores the saved strength")
			var cfg := ConfigFile.new()
			check(cfg.load(preset_path) == OK, "Read the full saved preset for the migration fixture")
			cfg.set_value("recipe", "version", 204)
			cfg.erase_section_key("strengths", String(CONTROL))
			check(cfg.save(preset_path) == OK and showcase.load_lighting_mix(preset_path) == OK and slider.value == 0.,
				"Presets from before the change retain their previous look")
			DirAccess.remove_absolute(preset_path)
			slider.value = 0.
			await settle()
			check(finish.active and not active(finish), "Zero leaves the stock exposure pass in use")
			slider.value = 1.
			await settle()
			check(active(finish), "Restoring the slider resumes the variant")
			finish.set_source_order(true)
			await settle()
			check(finish.active and not active(finish), "The raw bloom experiment retains its matching exposure")
			finish.set_source_order(false)
			await settle()
			check(active(finish), "Leaving the bloom experiment restores the lantern variant")
			var msaa := root.msaa_3d
			root.msaa_3d = Viewport.MSAA_DISABLED
			await settle()
			check(finish.active and not active(finish), "Without sampleable MSAA depth the stock graph remains available")
			root.msaa_3d = msaa
			await settle(36)
			check(active(finish), "MSAA restoration rebinds depth")
			root.size += Vector2i(32, 18)
			await settle(36)
			check(active(finish), "Viewport resize rebinds the renderer-owned attachment")
			world.set_review_view("overview")
			await settle()
			check(not active(finish), "Overview has no localized lantern trim")
			world.set_review_view("gameplay")
			await settle()
			showcase.set_hour(19.5)
			await settle()
			check(active(finish) and finish._native.lantern_exposure_status().amount < before,
				"Twilight trim rises smoothly with actual lamp energy")
			showcase.set_lighting_scale(&"lantern", 0.)
			await settle()
			check(finish.active and not active(finish), "An extinguished lantern has no trim")
	else:
		check(not active(finish) and (slider == null or not slider.editable), "Unsupported renderer has the original finish")
	showcase.set_hour(12.)
	await settle()
	check(not active(finish), "Returning to Noon releases the variant")
	world.free()
	await process_frame
	print("LANTERN_EXPOSURE checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
