extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
	for i in 24:await physics_frame
	var plants=w.showcase.get("plants")
	check(plants!=null,"Primary map has the private grass and flower planting")
	if plants==null:w.free();await process_frame;quit(1);return
	check(plants.error.is_empty(),"Existing external Blender bundle loads without extraction")
	check(plants.placements.size()>800,"Large meadow carpets and scattered patches exist")
	var occupied:Dictionary={};var bounds_ok:=true;var ground_ok:=true
	for row:Dictionary in plants.placements:
		check(not occupied.has(row.cell),"Each block has only one plant asset")
		occupied[row.cell]=true
		var bounds:AABB=row.bounds
		bounds_ok=bounds_ok and bounds.position.x>=row.cell.x+.01 and bounds.end.x<=row.cell.x+.99 and bounds.position.z>=row.cell.y+.01 and bounds.end.z<=row.cell.y+.99
		ground_ok=ground_ok and absf(bounds.position.y-w.surface_height(row.cell.x+.5,row.cell.y+.5))<.002
	check(bounds_ok,"Every static plant footprint stays inside its own block")
	check(ground_ok,"Plants sit on the actual terrain elevation")
	for color:String in ["pink","yellow","white","purple"]:check(plants.flower_colors.get(color,0)>0,"Flower cluster color "+color)
	check(not w.grove.visible and not w.look.canopy_contact_active(),"No trees or ghost canopy shading")
	check(AudioServer.is_bus_mute(0),"Test remains muted")
	check(w.player.active_clip=="Idle" and w.player.is_on_floor(),"Startup Idle preserved")
	check(plants.materials.size()>0 and plants.interaction.texture!=null,"Shared animated materials and interaction field")
	for material:ShaderMaterial in plants.materials:check(material.get_shader_parameter("cell_limited_motion")==true,"Animated tips bounded to their assigned block")
	plants.interaction.reset();plants.interaction.advance(.1,Vector3.ZERO,Vector3(7,0,0))
	check(not plants.interaction.active.is_empty(),"Player passage activates recoverable grass field")
	plants.interaction.reset()
	print("WORLD_MAP_PLANTING_RESULT ",JSON.stringify({"failures":failures,"planting":plants.snapshot()}))
	w.free();await process_frame;await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)
