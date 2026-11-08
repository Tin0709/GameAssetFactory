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
	check(plants.get("dense_grass_review")==true,"Dense grass-only review is the current default")
	if plants.get("dense_grass_review")==true:
		check(plants.flower_colors.is_empty(),"No flowers in dense review")
		check(plants.placements.size()==plants.eligible_grass_cells,"Every supported grass block covered; dirt excluded")
		var roots:Dictionary={};var full_scale:=true;var supported:=true
		for row:Dictionary in plants.placements:
			check(not roots.has(row.cell),"One dense patch root per block")
			roots[row.cell]=true
			full_scale=full_scale and is_equal_approx(row.scale,1.) and row.cards==4
			supported=supported and row.ground_kind.begins_with("grass_") and absf(row.bounds.position.y-w.surface_height(row.root.x,row.root.z))<.002
		check(full_scale,"Dense patches keep native source scale and four crossed cards")
		check(supported,"Dense grass is grounded and never rooted on dirt paths")
		for material:ShaderMaterial in plants.materials:
			check(material.get_shader_parameter("cell_limited_motion")==false,"Native canopy is not clipped to individual cells")
			check(material.get_shader_parameter("ground_mask_enabled")==true,"Canopy clipped away from dirt path surfaces")
		plants.set_dense_review(false)
		check(not plants.dense_grass_review,"Previous clustered flower study remains selectable")
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
	var wind_toggle:CheckButton
	var contact_toggle:CheckButton
	for node:Node in w.showcase.panel.find_children("*","CheckButton",true,false):
		if node.text=="Grass wind":wind_toggle=node
		if node.text=="Player grass / flower interaction":contact_toggle=node
	check(wind_toggle!=null and contact_toggle!=null,"Wind/contact controls available")
	if wind_toggle!=null and contact_toggle!=null:
		wind_toggle.button_pressed=false
		check(not plants.wind_enabled and plants.interactions_enabled,"Wind control targets only wind")
		contact_toggle.button_pressed=false
		check(not plants.interactions_enabled,"Contact control targets interaction")
		wind_toggle.button_pressed=true;contact_toggle.button_pressed=true
	plants.interaction.reset();plants.interaction.advance(.1,w.player.global_position,Vector3(7,0,0))
	check(not plants.interaction.active.is_empty(),"Player passage activates recoverable grass field")
	plants.interaction.reset()
	var cliff=plants.interaction.get_script().new()
	check(cliff.get("surface_height_provider")!=null,"Interaction field supports stepped terrain")
	if cliff.get("surface_height_provider")!=null:
		cliff.surface_height_provider=func(x:float,_z:float)->float:return 3. if x>=0. else 0.
		for i in 30:cliff.advance(1./60.,Vector3(-.5,0,0),Vector3(7,0,0))
		check(cliff.sample_at(Vector2(-.8,0)).length()>.01,"Contact bends same-level grass")
		check(cliff.sample_at(Vector2(.8,0)).length()<.0001,"No contact on a cliff three meters above the player")
	print("WORLD_MAP_PLANTING_RESULT ",JSON.stringify({"failures":failures,"planting":plants.snapshot()}))
	w.free();await process_frame;await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)
