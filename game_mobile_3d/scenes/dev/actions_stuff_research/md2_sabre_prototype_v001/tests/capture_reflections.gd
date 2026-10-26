extends SceneTree
func _initialize()->void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(-16000,-16000));call_deferred("run")
func frames(count:int)->void:
	for i in count:await RenderingServer.frame_post_draw
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.md2_sabre_prototype_enabled=true;root.add_child(lab);current_scene=lab
	var a=lab.player;var mode=lab.sabre_mode
	var output:String=a.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/godot_native/source_v002")
	DirAccess.make_dir_recursive_absolute(output)
	lab.camera_size=3.8;lab._camera_initialized=false;lab._update_camera()
	a.set_physics_process(false);mode.set_physics_process(false);lab.grass_field.set_process(false);lab.grass_field.set_physics_process(false);lab.md2_lighting.set_process(false)
	lab.set_process(false);mode.present(0.)
	await frames(14)
	var checkbox:CheckButton=mode.find_child("LocalReflectionCheckbox",true,false)
	mode.reflection_probe.visible=false;checkbox.set_pressed_no_signal(false);await frames(3)
	var off:=root.get_texture().get_image();off.save_png(output.path_join("reflections_off.png"))
	mode.reflection_probe.visible=true;checkbox.set_pressed_no_signal(true);await frames(14)
	var on:=root.get_texture().get_image();on.save_png(output.path_join("reflections_on.png"))
	var grass_max:=0.;var changed_actor:=0
	for y in range(540,640):
		for x in range(820,920):
			var p:Color=off.get_pixel(x,y);var q:Color=on.get_pixel(x,y)
			grass_max=maxf(grass_max,Vector3(p.r-q.r,p.g-q.g,p.b-q.b).length())
	for y in range(150,530):
		for x in range(450,800):
			var p:Color=off.get_pixel(x,y);var q:Color=on.get_pixel(x,y)
			if Vector3(p.r-q.r,p.g-q.g,p.b-q.b).length()>.03:changed_actor+=1
	var report:={"renderer":RenderingServer.get_current_rendering_method(),"actor_changed_pixels":changed_actor,"grass_max_difference":grass_max,"environment_reflection_source":lab.md2_lighting.environment.reflected_light_source,"probe_reflection_mask":mode.reflection_probe.reflection_mask,"probe_capture_mask":mode.reflection_probe.cull_mask}
	FileAccess.open("res://.validation/md2_sabre_prototype_v001/reflections.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_REFLECTIONS ",JSON.stringify(report));lab.free();await frames(3);quit(0 if changed_actor>100 and grass_max<.001 else 1)
