extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message);push_error(message)
func _petal_return(material: ShaderMaterial, uniform_name := "petal_shadow_return") -> float:
	var value: Variant = material.get_shader_parameter(uniform_name)
	return value if value is float else NAN

func _initialize()->void:call_deferred("run")
func run()->void:
	var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
	for i in 20:await physics_frame
	var p=w.showcase.plants
	check(p.get("grass_light")!=null,"Grass has a scoped lighting controller")
	if p.get("grass_light")==null:w.free();await process_frame;quit(1);return
	check(p.grass_light.configured,"Hash-verified captured normal parameter available")
	check(is_equal_approx(p.grass_light.weight,1.),"Source captured Day normal weight recovered")
	var count:int=p.instance_count
	var flower_colors:Dictionary=p.flower_colors.duplicate()
	var native:bool=RenderingServer.get_rendering_device()!=null and RenderingServer.get_current_rendering_method()=="mobile"
	check(p.grass_light.active==native,"Reference lighting respects renderer support")
	var original:Dictionary={}
	p.set_grass_lighting(false)
	for mat:ShaderMaterial in p.materials:original[mat]=mat.shader
	for node:Node in p.get_children():check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Legacy casts restored")
	p.set_grass_lighting(true)
	if native:
		const STEP_COVERAGE := "grass_step_coverage"
		var material: ShaderMaterial = p.materials[0]
		check(material.get_shader_parameter(STEP_COVERAGE) == 1., "Dense grass uses the stepped-terrain coverage correction by default")
		w.showcase.set_lighting_scale(&"grass_step_coverage", .4)
		check(material.get_shader_parameter(STEP_COVERAGE) == .4, "Grass coverage responds to the live slider without rebuilding plants")
		w.showcase.set_lighting_scale(&"grass_step_coverage", 0.)
		check(material.get_shader_parameter(STEP_COVERAGE) == 0., "Zero coverage restores the original alpha path")
		w.showcase.set_lighting_scale(&"grass_step_coverage", 1.)
		w.set_reference_look(false)
		await process_frame
		await process_frame
		var mist_shader = preload("res://scripts/world_map_atmosphere_volume.gd")
		check(not p.grass_light.active and mist_shader.base_shader(material.shader) == mist_shader.base_shader(original[material]),
			"Original graphics comparison uses the shader without coverage correction")
		w.set_reference_look(true)
		await process_frame
		check(material.get_shader_parameter(STEP_COVERAGE) == 1., "Returning to Combined restores stepped-terrain coverage")
		var receivers := preload("res://scripts/world_map_far_shadow_receivers.gd").new()
		receivers.mist_variant = w.showcase.mist.material_variant
		var authored := receivers.authored_shader(material.shader)
		check(receivers.bind([material]), "Grass shader can receive far terrain shadows")
		check(receivers.authored_shader(material.shader) == authored, "Far shadows and mist retain the grass lighting source")
		p.set_grass_lighting(true)
		check(receivers.authored_shader(material.shader).code.count("#define GAF_REFERENCE_GRASS_LIGHTING") == 1,
			"Refreshing grass through an active far receiver keeps one lighting define")
		receivers.release()
		check(receivers.authored_shader(material.shader).code.count("#define GAF_REFERENCE_GRASS_LIGHTING") == 1,
			"Releasing far receivers preserves the latest grass shader")
		check(w.showcase._lighting_sliders.has(StringName(STEP_COVERAGE)), "Terrain step coverage has a settings slider")
		var preset_path := "user://grass_step_%d.cfg" % OS.get_process_id()
		w.showcase.set_lighting_scale(&"grass_step_coverage", .4)
		check(w.showcase.save_lighting_mix(preset_path) == OK, "Coverage can be saved with the other graphics settings")
		w.showcase.set_lighting_scale(&"grass_step_coverage", 0.)
		check(w.showcase.load_lighting_mix(preset_path) == OK, "Saved coverage preset loads")
		p.grass_light.sync()
		check(material.get_shader_parameter(STEP_COVERAGE) == .4, "Saved preset reapplies the coverage strength")
		var preset := ConfigFile.new()
		if preset.load(preset_path) == OK:
			preset.set_value("recipe", "version", 151)
			preset.erase_section_key("strengths", STEP_COVERAGE)
			check(preset.save(preset_path) == OK and w.showcase.load_lighting_mix(preset_path) == OK,
				"Previous recipe format still loads")
			p.grass_light.sync()
			check(material.get_shader_parameter(STEP_COVERAGE) == 0., "Previous saved recipes retain original coverage")
		DirAccess.remove_absolute(preset_path)
		w.showcase.reset_lighting_mix()
		for mat:ShaderMaterial in p.materials:
			check(mat.shader!=original[mat],"Only shader changes for reference lighting")
			var turf: bool = mat.get_shader_parameter("tinted_grass") == true
			check(mat.get_shader_parameter("study_grass_up_weight")== (1. if turf else 0.),
				"Grass uses captured up normals while flowers and shrubs keep mesh normals")
			check(is_equal_approx(mat.get_shader_parameter("study_transmission"),float(mat.get_meta("plains_foliage_transmission",.1248))),
				"Regional foliage lighting retains the material-specific transmission")
		var petals: ShaderMaterial = p.grass_light._flower_materials[0]
		const SHADE_RETURN := &"flower_shadow_return"
		w.showcase.set_hour(12.)
		p.grass_light.sync()
		check(w.showcase._lighting_sliders.has(SHADE_RETURN), "Petal shade return has a graphics slider")
		check(is_equal_approx(_petal_return(petals), .0516),
			"Default noon applies the mild petal shadow return")
		var petal_source := petals.shader
		const OPEN_RETURN := &"flower_open_return"
		const OPEN_UNIFORM := "petal_open_return"
		check(w.showcase._lighting_sliders.has(OPEN_RETURN), "The sunlit petal balance has a graphics slider")
		check(is_equal_approx(_petal_return(petals, OPEN_UNIFORM), .55),
			"Default noon rebalances direct and returned light on the flower heads")
		w.showcase.set_lighting_scale(OPEN_RETURN, .5)
		check(is_equal_approx(_petal_return(petals, OPEN_UNIFORM), .275) and petals.shader == petal_source,
			"The sunlit petal slider changes strength on the same shader")
		w.showcase.set_lighting_scale(SHADE_RETURN, .5)
		check(is_equal_approx(_petal_return(petals), .0258) and petals.shader == petal_source,
			"The slider changes only the strength of the existing flower material")
		w.showcase.set_hour(22.)
		p.grass_light.sync()
		check(_petal_return(petals) == 0., "Petal shade return is off at night")
		check(_petal_return(petals, OPEN_UNIFORM) == 0., "Sunlit petal return is off at night")
		w.showcase.set_hour(12.)
		p.grass_light.sync()
		var flower_preset := "user://petal_shade_%d.cfg" % OS.get_process_id()
		check(w.showcase.save_lighting_mix(flower_preset) == OK, "Petal shade return saves with the graphics preset")
		w.showcase.set_lighting_scale(SHADE_RETURN, 0.)
		check(w.showcase.load_lighting_mix(flower_preset) == OK, "The petal shade preset reloads")
		p.grass_light.sync()
		check(is_equal_approx(_petal_return(petals), .0258),
			"The preset restores the selected petal shade strength")
		check(is_equal_approx(_petal_return(petals, OPEN_UNIFORM), .275),
			"The preset restores the sunlit petal balance")
		var previous_preset := ConfigFile.new()
		if previous_preset.load(flower_preset) == OK:
			previous_preset.set_value("recipe", "version", 233)
			if previous_preset.has_section_key("strengths", OPEN_RETURN):
				previous_preset.erase_section_key("strengths", OPEN_RETURN)
			if previous_preset.has_section_key("strengths", SHADE_RETURN):
				previous_preset.erase_section_key("strengths", SHADE_RETURN)
			check(previous_preset.save(flower_preset) == OK and w.showcase.load_lighting_mix(flower_preset) == OK,
				"The existing lighting preset format still loads")
			p.grass_light.sync()
			check(_petal_return(petals) == 0.,
				"Previous saved presets keep their previous petal lighting")
			check(_petal_return(petals, OPEN_UNIFORM) == 0.,
				"Older presets keep their previous sunlit petal balance")
		DirAccess.remove_absolute(flower_preset)
		w.showcase.reset_lighting_mix()
		var foliage_filters := 0
		var msaa_active: bool = root.msaa_3d != Viewport.MSAA_DISABLED
		for mat: ShaderMaterial in p.materials:
			var filter_installed := mat.shader.code.contains("#define GAF_FOLIAGE_COLOR_MIPS")
			var has_mips := mat.has_meta("plains_foliage_color_mips")
			check(filter_installed == (has_mips and msaa_active),
				"Only Plains flower and shrub atlases use the Mobile color filter")
			if has_mips:
				foliage_filters += 1
				var texture: Texture2D = mat.get_meta("plains_foliage_color_mips")
				check(texture.get_image().has_mipmaps(), "Linear alpha-weighted foliage mips are available")
		check(foliage_filters == 2, "Both broad-leaf atlases are prepared")
		p.set_grass_edge_sampling(false)
		for mat: ShaderMaterial in p.materials:
			check(not mat.shader.code.contains("#define GAF_FOLIAGE_COLOR_MIPS"),
				"Foliage antialiasing toggle restores nearest color sampling")
		p.set_grass_edge_sampling(true)
		for node:MultiMeshInstance3D in p.get_children():
			var plant_material := node.multimesh.mesh.surface_get_material(0) as ShaderMaterial
			var casts: bool = plant_material.get_shader_parameter("tinted_grass") == true or plant_material.get_meta("plains_shrub", false)
			check(node.cast_shadow == (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),
				"Grass and shrubs cast alpha-tested shadows while flowers receive them")
	p.set_grass_lighting(false)
	for mat:ShaderMaterial in p.materials:check(mat.shader==original[mat],"OFF restores exact legacy shader resource")
	p.set_grass_lighting(true)
	check(p.instance_count==count and p.flower_colors==flower_colors,"Lighting preserves planting density and flower selection")
	check(AudioServer.is_bus_mute(0) and w.player.active_clip=="Idle","Quiet grounded startup preserved")
	print("GRASS_LIGHT_RESULT ",JSON.stringify({"failures":failures,"lighting":p.grass_light.snapshot()}))
	w.free();await process_frame;await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)
