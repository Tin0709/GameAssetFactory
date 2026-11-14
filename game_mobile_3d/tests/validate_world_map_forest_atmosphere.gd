extends SceneTree
var failures=[]
func check(ok:bool,message:String):
	if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
	var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
	await create_timer(.4).timeout
	if not w.showcase.has_method("set_atmosphere_review"):
		print("FOREST_ATMOSPHERE missing existing-owner profile control");w.free();quit(1);return
	var s=w.showcase;var native:=RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null
	check(s.forest.phases.size()==4,"Pinned private phase profile verified")
	s.set_atmosphere_review("previous");s.set_hour(12.)
	var env:Environment=w.get_node("WorldEnvironment").environment
	var original={}
	for field:String in s.ENV_FIELDS:original[field]=env.get(field)
	var sun=w.get_node("Sun");var energy:float=sun.light_energy;var tint:Color=sun.light_color
	s.set_atmosphere_review("combined");await process_frame;await process_frame
	check(s.forest_active()==native,"Profile only applies on supported Mobile")
	if native:
		var probe=load("res://scripts/world_map_terrain_transport.gd").new();probe.level=w;probe.cache=w.terrain_light.cache.duplicate(true)
		probe.cache.set_meta("ambient_srgb",[0.,.7,.8]);check(not probe._install(),"Zero chromatic normalization rejected");probe.free()
		check(env.fog_light_color!=original.fog_light_color and env.glow_bloom>original.glow_bloom,"Haze and bloom applied")
		check(env.ambient_light_color!=original.ambient_light_color,"Source-relative indirect tint applied")
		check(w.terrain_light.is_active(),"Corrected spatial terrain survives approved tint")
		var sky:Color=env.ambient_light_color
		env.ambient_light_color=Color.RED
		check(not w.terrain_light.available(),"Unattributed color still rejects cache")
		env.ambient_light_color=sky
		s.set_atmosphere_review("haze");await process_frame;await process_frame
		check(env.ambient_light_color==original.ambient_light_color and sun.light_color==tint,"Haze-only leaves light unchanged")
		s.set_atmosphere_review("lighting");await process_frame;await process_frame
		check(env.fog_light_color==original.fog_light_color and env.glow_bloom==original.glow_bloom,"Lighting-only leaves haze unchanged")
	s.set_atmosphere_review("previous");await process_frame;await process_frame
	for field:String in original:check(env.get(field)==original[field],"Restore "+field)
	check(sun.light_energy==energy and sun.light_color==tint,"Restore sunlight")
	s.set_atmosphere_review("combined");s.set_hour(22.);await process_frame;await process_frame
	check(w.terrain_light.is_active()==native,"Original angular sky model retints through Night")
	if native:check(w.look.terrain_materials[0][3].get_shader_parameter("terrain_key_radiance")==Vector3.ZERO,"Night rejects cached Day sun rays")
	s.set_atmosphere_review("previous");await process_frame;await process_frame
	check(not w.terrain_light.is_active(),"Previous Night still rejects unadapted Day transport")
	s.set_atmosphere_review("combined");await process_frame;await process_frame
	if native:check(s._player_light.is_visible_in_tree() and s._player_light.omni_range==8. and not s._player_light.shadow_enabled,"Native-range warm night light without shadows")
	s.set_hour(12.);await process_frame;await process_frame
	check(w.terrain_light.is_active()==native,"Day restores guarded spatial lighting")
	if native:check(not s._player_light.is_visible_in_tree(),"Player light off at verified Day")
	if native:
		w.terrain_sky.set_enabled(true);await process_frame;await process_frame
		check(s.atmosphere_review=="previous" and w.terrain_sky.is_active() and not w.terrain_light.is_active(),"F12 selects the calibrated legacy context")
		s.panel.show();await process_frame
		check(s._atmosphere_picker.selected==0 and s._legacy_sky_button.button_pressed,"UI follows F12 replacement")
		s.set_atmosphere_review("combined");await process_frame;await process_frame
		check(not w.terrain_sky.enabled and w.terrain_light.is_active(),"Forest selection clears legacy replacement")
		check(s._atmosphere_picker.selected==3 and not s._legacy_sky_button.button_pressed,"UI follows Forest replacement");s.panel.hide()
	s.compare_baseline();await process_frame
	check(not s.forest_active(),"Baseline suspends atmosphere")
	s.compare_baseline();await process_frame;await process_frame
	check(s.forest_active()==native,"Combined restores atmosphere")
	if native and is_instance_valid(w.grove) and w.grove.source_oaks:
		for hour: float in [16.5, 18.5, 17.75, 19.0]:
			s.set_hour(hour)
			var canopy: Vector4 = w.grove.canopy_direct
			var direction := Vector3(canopy.x, canopy.y, canopy.z)
			check(canopy.w > 0.0 and direction.is_equal_approx(sun.global_basis.z.normalized()),
				"Canopy uses the current sun in the same update at %.2f" % hour)
		s.compare_baseline()
		check(w.grove.canopy_direct == Vector4.ZERO, "Baseline immediately clears the canopy override")
		s.compare_baseline()
		check(w.grove.canopy_direct.w > 0.0, "Combined immediately restores the canopy override")
	check(not s.audio_enabled and w.player.run_speed==7.,"Mute and approved movement retained")
	print("FOREST_ATMOSPHERE failures=",JSON.stringify(failures));w.free();await process_frame;quit(0 if failures.is_empty() else 1)
