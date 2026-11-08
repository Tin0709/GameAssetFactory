extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func run()->void:
	var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
	await create_timer(.3).timeout
	check(w.look.has_method("set_terrain_review"),"Existing Look exposes independent terrain comparisons")
	check(w.get("terrain_light")!=null,"Existing map installs spatial terrain owner")
	if not w.look.has_method("set_terrain_review") or w.get("terrain_light")==null:
		w.free();print("TERRAIN_LIGHT checks=",checks," failures=",JSON.stringify(failures));quit(1);return
	var native:bool=RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null
	var exporter=load("res://tools/export_world_map_terrain_light.gd")
	for chunk:Node3D in w.geometry.terrain_chunks:
		check(exporter.original_chunk_transform(chunk,w.geometry.CHUNK_SIZE),"Authoring accepts original translated chunks")
	var probe_chunk:=Node3D.new();probe_chunk.name="Terrain_-2_3";root.add_child(probe_chunk)
	probe_chunk.position=Vector3(-20,0,30)
	check(exporter.original_chunk_transform(probe_chunk,10),"Negative grid coordinates accepted")
	probe_chunk.position.x+=.25
	check(not exporter.original_chunk_transform(probe_chunk,10),"Moved authoring chunk rejected")
	probe_chunk.position.x-=.25;probe_chunk.rotation.y=.1
	check(not exporter.original_chunk_transform(probe_chunk,10),"Rotated authoring chunk rejected");probe_chunk.free()
	w.look.set_terrain_review("combined")
	check(w.terrain_light.is_active()==native,"Only supported Day configuration applies local lighting")
	for row in w.look.terrain_materials:
		var source:BaseMaterial3D=row[2];var m:ShaderMaterial=row[3]
		check(is_equal_approx(float(m.get_shader_parameter("native_specular")),source.metallic_specular),"Source specular is retained")
		check(is_equal_approx(float(m.get_shader_parameter("native_roughness")),source.roughness),"Source roughness is retained")
		var cut=w.geometry._make_cutaway_material(m)
		check(cut.get_shader_parameter("native_specular")==m.get_shader_parameter("native_specular"),"Cutaway retains PBR")
	if native:
		w.look.set_ground_bounce(false)
		check(w.terrain_light.is_active(),"Reflected sun toggle retains spatial sky")
		check(w.look.terrain_materials[0][3].get_shader_parameter("terrain_key_radiance")==Vector3.ZERO,"Shift F1 also gates new reflected sunlight")
		w.look.set_ground_bounce(true)
		check(w.terrain_light.error.is_empty(),"Cache validates all source data")
		for energy in [0.,NAN,INF]:
			var probe=load("res://scripts/world_map_terrain_transport.gd").new();probe.level=w;probe.cache=w.terrain_light.cache.duplicate(true);probe.cache.set_meta("ambient_energy",energy)
			check(not probe._install() and "normalization" in probe.error,"Invalid normalization metadata fails closed");probe.free()
		var chunk:Node3D=w.geometry.terrain_chunks[0];var position:Vector3=chunk.position
		chunk.position.x+=.25;await process_frame;await process_frame
		check(not w.terrain_light.is_active(),"Changed world transform rejects stale transport")
		chunk.position=position;await process_frame;await process_frame
		check(w.terrain_light.is_active(),"Restored transform resumes transport")
		check(not w.look.ground_bounce_active(),"Legacy mineral bounce does not double count")
		w.showcase.set_hour(22.);await process_frame;await process_frame
		check(w.look.terrain_materials[0][3].get_shader_parameter("terrain_key_radiance")==Vector3.ZERO,"Night rejects cached Day sunlight")
		w.showcase.set_atmosphere_review("previous");await process_frame;await process_frame
		check(not w.terrain_light.is_active(),"Previous Night rejects unadapted Day transport")
		w.showcase.set_atmosphere_review("combined")
		w.showcase.set_hour(12.);await process_frame;await process_frame
		check(w.terrain_light.is_active(),"Noon restores local transport")
		w.look.set_stage(0);await process_frame
		check(not w.terrain_light.is_active(),"B restores baseline")
		w.look.set_stage(2);await process_frame
	w.look.set_terrain_review("previous");await process_frame
	check(not w.terrain_light.is_active(),"Prior graphics remains inspectable")
	check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Gameplay speed and mute retained")
	check(w.geometry.cells.size()==42996 and w.geometry.terrain_triangles==67694,"Map topology retained")
	w.free();print("TERRAIN_LIGHT checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
