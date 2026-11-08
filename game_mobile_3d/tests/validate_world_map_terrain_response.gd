extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func run()->void:
	var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
	await create_timer(.4).timeout
	check(w.look.has_method("set_terrain_visibility_response"),"Existing terrain owner must expose a reversible colored response")
	if failures.is_empty():
		check(w.look.terrain_visibility_response,"Main-map response defaults on")
		var native:bool=w.terrain_light.is_active()
		for enabled in [false,true,false,true]:
			w.look.set_terrain_visibility_response(enabled)
			await process_frame
			if native:
				for row in w.look.terrain_materials:
					var m:ShaderMaterial=row[3]
					check(m.get_shader_parameter("terrain_colored_visibility")==enabled,"Live terrain follows comparison")
					var cut=w.geometry._make_cutaway_material(m)
					check(cut.get_shader_parameter("terrain_colored_visibility")==enabled,"New cutaway inherits comparison")
		w.look.set_stage(0);await process_frame
		check(not w.terrain_light.is_active(),"Baseline retains transport guard")
		w.look.set_stage(2);await process_frame
		check(w.terrain_light.is_active()==native,"Combined resumes eligible transport")
	check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Movement speed and quiet tests retained")
	check(w.geometry.cells.size()==42996 and w.geometry.terrain_triangles==67694,"Authored map unchanged")
	w.free();print("TERRAIN_RESPONSE checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
