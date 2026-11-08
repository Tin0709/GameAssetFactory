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
	check(p.instance_count==8418 and p.grass_splay_active(),"Approved density and spread preserved")
	check(AudioServer.is_bus_mute(0) and w.player.active_clip=="Idle","Quiet grounded startup preserved")
	print("GRASS_WIND_RESULT ",JSON.stringify({"failures":failures,"wind":p.grass_wind.snapshot()}))
	w.free();await process_frame;await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)
