extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
	for i in 20:await physics_frame
	var p=w.showcase.plants
	check(p.get("grass_wind")!=null,"Source-backed background gust adapter exists")
	if p.get("grass_wind")==null:w.free();await process_frame;quit(1);return
	check(p.grass_wind.configured and p.recovered_wind_enabled,"Validated source gusts default ON")
	var roots:Array=[]
	for row:Dictionary in p.placements:roots.append(row.root)
	for m:ShaderMaterial in p.materials:
		check(m.get_shader_parameter("review_source_wind")==true,"Recovered background path selected")
		check(is_equal_approx(m.get_shader_parameter("review_wind_gain"),p.grass_wind.data.background_wind.gain),"Captured gain transferred without arbitrary amplification")
	for node:Node in p.get_children():check(node.extra_cull_margin>.8,"Culling reserves recovered rotation plus contact")
	p.set_recovered_wind(false)
	for m:ShaderMaterial in p.materials:check(m.get_shader_parameter("review_source_wind")==false,"Previous motion available for exact comparison")
	for node:Node in p.get_children():check(is_equal_approx(node.extra_cull_margin,.8),"Old culling margin restored")
	p.set_recovered_wind(true)
	for i in roots.size():check(roots[i]==p.placements[i].root,"Wind does not replant terrain")
	p.set_dense_review(false)
	for m:ShaderMaterial in p.materials:check(m.get_shader_parameter("review_source_wind")==false,"Prior flower study preserves motion")
	p.set_dense_review(true)
	check(p.instance_count+p.fern_reserved_cells.size()==8418 and p.grass_splay_active(),"Dense grass and fern clearings preserve the approved coverage")
	check(AudioServer.is_bus_mute(0) and w.player.active_clip=="Idle","Quiet grounded startup preserved")
	check_shadow_wind(w, p)
	await check_sunlight_stability(w, p)
	print("GRASS_WIND_RESULT ",JSON.stringify({"failures":failures,"wind":p.grass_wind.snapshot()}))
	w.free();await process_frame;await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)

func check_shadow_wind(world: Node, plants: Node3D) -> void:
	if not plants.grass_light.active:
		return
	var showcase: Node = world.showcase
	var id := &"day_grass_shadow_wind"
	var control: HSlider = showcase._settings._sliders.get(String(id))
	check(control != null and control.editable and is_equal_approx(control.value, 1.),
		"Forest exposes the default grass shadow motion control")
	for hour: float in [7., 12., 16.5, 19.5, 22.]:
		showcase.set_hour(hour)
		plants.grass_light.sync()
		var expected := .5 if hour in [7., 16.5] else 1.
		check(shadow_wind_matches(plants, expected), "Grass shadow wind at %s" % hour)
	showcase.set_hour(16.5)
	showcase.set_lighting_scale(id, .4)
	check(shadow_wind_matches(plants, .8), "The existing live controls refresh the shadow motion")
	var path := "user://grass_shadow_wind_%s.cfg" % OS.get_process_id()
	var config := ConfigFile.new()
	check(showcase.save_lighting_mix(path) == OK and config.load(path) == OK, "The control can be saved")
	check(config.get_value("recipe", "version", 0) == showcase.LIGHTING_MIX_VERSION
		and is_equal_approx(float(config.get_value("strengths", id, 0.)), .4), "Recipe stores the amount")
	showcase.set_lighting_scale(id, 0.)
	check(shadow_wind_matches(plants, 1.), "Zero restores full shadow motion")
	check(showcase.load_lighting_mix(path) == OK and shadow_wind_matches(plants, .8), "New recipe restores its adjustment")
	config.set_value("recipe", "version", 209)
	if config.has_section_key("strengths", id):
		config.erase_section_key("strengths", id)
	check(config.save(path) == OK and showcase.load_lighting_mix(path) == OK
		and shadow_wind_matches(plants, 1.), "Legacy recipe keeps full shadow motion")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func shadow_wind_matches(plants: Node3D, expected: float) -> bool:
	for record: Dictionary in plants.grass_light._records:
		var value: Variant = record.material.get_shader_parameter("study_grass_shadow_wind")
		if value == null or not is_equal_approx(float(value), expected):
			return false
	return true

func check_sunlight_stability(world: Node, plants: Node3D) -> void:
	if not plants.grass_light.active:
		return
	var showcase: Node = world.showcase
	var id := &"day_grass_sunlight_stability"
	var slider: HSlider = showcase._settings._sliders.get(String(id))
	check(is_instance_valid(slider) and slider.editable and is_equal_approx(slider.value, 1.),
		"Forest exposes the default grass sunlight motion control")
	for hour: float in [7., 12., 16.5, 19.5, 22.]:
		showcase.set_hour(hour)
		await process_frame
		await process_frame
		check(sunlight_matches(plants, .5 if hour in [7., 16.5] else 0.),
			"Grass sunlight follows its daylight window at %s" % hour)
	showcase.set_hour(16.5)
	showcase.set_lighting_scale(id, .6)
	check(sunlight_matches(plants, .3) and shadow_wind_matches(plants, 1.),
		"The sunlight control updates live and leaves the shadow control independent")
	var path := "user://grass_sunlight_%s.cfg" % OS.get_process_id()
	var config := ConfigFile.new()
	check(showcase.save_lighting_mix(path) == OK and config.load(path) == OK,
		"The sunlight control can be saved")
	showcase.set_lighting_scale(id, 0.)
	check(sunlight_matches(plants, 0.), "Zero restores original sampling")
	check(showcase.load_lighting_mix(path) == OK and sunlight_matches(plants, .3),
		"New recipe restores its sunlight motion setting")
	config.set_value("recipe", "version", 211)
	if config.has_section_key("strengths", id):
		config.erase_section_key("strengths", id)
	check(config.save(path) == OK and showcase.load_lighting_mix(path) == OK
		and sunlight_matches(plants, 0.), "Legacy recipe preserves original sampling")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func sunlight_matches(plants: Node3D, expected: float) -> bool:
	for record: Dictionary in plants.grass_light._records:
		var value: Variant = record.material.get_shader_parameter("study_grass_sunlight_stability")
		if value == null or not is_equal_approx(float(value), expected):
			return false
	return true
