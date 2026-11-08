extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message);push_error(message)
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
	var native:bool=RenderingServer.get_rendering_device()!=null and RenderingServer.get_current_rendering_method()=="mobile"
	check(p.grass_light.active==native,"Reference lighting respects renderer support")
	var original:Dictionary={}
	p.set_grass_lighting(false)
	for mat:ShaderMaterial in p.materials:original[mat]=mat.shader
	for node:Node in p.get_children():check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Legacy casts restored")
	p.set_grass_lighting(true)
	if native:
		for mat:ShaderMaterial in p.materials:
			check(mat.shader!=original[mat],"Only shader changes for reference lighting")
			check(mat.get_shader_parameter("study_grass_up_weight")==1.,"Captured world normal uniform applied")
		for node:Node in p.get_children():check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"Grass can cast real alpha-tested shadows")
	p.set_grass_lighting(false)
	for mat:ShaderMaterial in p.materials:check(mat.shader==original[mat],"OFF restores exact legacy shader resource")
	p.set_grass_lighting(true)
	check(p.instance_count==count and p.flower_colors.is_empty(),"Density, source scale and grass-only mode unchanged")
	check(AudioServer.is_bus_mute(0) and w.player.active_clip=="Idle","Quiet grounded startup preserved")
	print("GRASS_LIGHT_RESULT ",JSON.stringify({"failures":failures,"lighting":p.grass_light.snapshot()}))
	w.free();await process_frame;await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)
