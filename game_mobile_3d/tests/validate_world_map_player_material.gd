extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func run()->void:
	var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
	await create_timer(.5).timeout
	var look=w.look
	check(look.has_method("set_player_material_review"),"Independent player material controls exist")
	var adapters:=0
	for m in look._direct_actor_materials:
		if m!=null:adapters+=1
	var native:bool=RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null
	if native:check(adapters==3,"Body, face and Sabre preserve rich PBR through adapters")
	if look.has_method("set_player_material_review"):
		var row0=look.actor_materials[0]
		for flag:int in [BaseMaterial3D.FLAG_DISABLE_DEPTH_TEST,BaseMaterial3D.FLAG_UV1_USE_TRIPLANAR,BaseMaterial3D.FLAG_EMISSION_ON_UV2]:
			var unusual:BaseMaterial3D=row0[3].duplicate();unusual.set_flag(flag,true)
			check(not look.player_material.supports(row0[0],unusual),"Unsupported vertex/depth/UV behavior falls back")
		if native:
			check(not look.player_material.profile.is_empty(),"Captured profile validates in private workspace")
			var skins:=0
			for m in look._direct_actor_materials:
				if m!=null and m.get_meta("verified_valorie",false):skins+=1
			check(skins==2,"Only pixel-identified Valorie body and face are verified")
		look.set_player_material_review("neutral")
		for i in look.actor_materials.size():
			var row=look.actor_materials[i];var m=row[0].get_active_material(row[1])
			if not native:continue
			check(m is ShaderMaterial,"Neutral uses a real adapter")
			check(m.get_shader_parameter("albedo_tint")==row[4],"Neutral retains original tint")
			check(m.get_shader_parameter("metal_map")==row[3].metallic_texture,"Metal texture preserved")
			check(m.get_shader_parameter("rough_map")==row[3].roughness_texture,"Rough texture preserved")
			check(m.get_shader_parameter("glow_map")==row[3].emission_texture,"Emission preserved")
			check(not m.get_shader_parameter("recovered_roughness") and not m.get_shader_parameter("recovered_self_light"),"Neutral enables no recovered effects")
		look.set_player_material_review("roughness")
		for i in look.actor_materials.size():
			var row=look.actor_materials[i];var m=look._direct_actor_materials[i]
			if m==null:continue
			check(not m.get_shader_parameter("recovered_self_light"),"Roughness does not enable self-light")
			if str(row[0].name)=="SabrePrototypeSabre":check(not m.get_shader_parameter("recovered_roughness"),"Sabre never receives skin roughness")
		look.set_player_material_review("self_light")
		for m in look._direct_actor_materials:
			if m!=null:check(not m.get_shader_parameter("recovered_roughness"),"Self-light does not enable roughness")
		look.set_player_material_review("combined")
		if native:
			look.set_ground_bounce(false)
			w.showcase.hour=22.;w.showcase.apply_time()
			for j in 3:await process_frame
			for m in look._direct_actor_materials:
				if m!=null:check(not m.get_shader_parameter("recovered_roughness") and not m.get_shader_parameter("recovered_self_light"),"Automatic cycle suspends Day effects without relying on bounce refresh")
			w.showcase.set_hour(22.)
			for m in look._direct_actor_materials:
				if m!=null:check(not m.get_shader_parameter("recovered_roughness") and not m.get_shader_parameter("recovered_self_light"),"Unverified Night suspends Day material effects")
			w.showcase.set_hour(12.)
			var active:=0
			for m in look._direct_actor_materials:
				if m!=null and m.get_shader_parameter("recovered_roughness"):active+=1
			check(active==2,"Day returns both verified skin effects")
		look.set_stage(0)
		for row in look.actor_materials:check(row[0].get_surface_override_material(row[1])==row[2],"B restores original overrides")
		look.set_stage(2);look.set_player_material_review("original")
		for row in look.actor_materials:check(row[0].get_surface_override_material(row[1])==row[2],"Original comparison restores source")
	w.free()
	print("PLAYER_MATERIAL checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
