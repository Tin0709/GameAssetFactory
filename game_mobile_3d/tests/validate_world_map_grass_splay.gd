extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func vertices(p:Node)->Array:
	var result:Array=[]
	for i in 6:result.append(p.bundle.meshes[p._patch_name(i)].surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	return result
func run()->void:
	var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
	for i in 20:await physics_frame
	var p=w.showcase.plants
	check(p.get("grass_splay")!=null,"Captured grass placement inclinations have a scoped adapter")
	if p.get("grass_splay")==null:w.free();await process_frame;quit(1);return
	check(p.grass_splay.configured and p.grass_splay_enabled,"Captured inclinations load by default")
	var roots:Array=[]
	for row:Dictionary in p.placements:roots.append(row.root)
	p.set_grass_splay(false)
	var upright:=vertices(p)
	p.set_grass_splay(true)
	var fan:=vertices(p)
	var max_length_error:=0.;var max_angle_error:=0.;var min_ground:=INF;var min_bent_ground:=INF
	for variant in 6:
		var a:PackedVector3Array=upright[variant];var b:PackedVector3Array=fan[variant]
		var mesh:Mesh=p.bundle.meshes[p._patch_name(variant)]
		var raw:Variant=mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]
		var motion:PackedFloat32Array=raw.to_float32_array() if raw is PackedByteArray else raw
		check(a.size()==b.size(),"Source topology unchanged")
		for card in 4:
			var tops:Dictionary={};var bases:Dictionary={}
			for i in range(card*6,card*6+6):
				min_ground=minf(min_ground,b[i].y)
				var u:float=motion[i*4];var h:float=motion[i*4+1]
				# Conservative existing WPO bound: strongest contact/wind bend.
				min_bent_ground=minf(min_bent_ground,b[i].y+h*sin(.75*u)/.75-h*u)
				if motion[i*4]>.99:tops[b[i]]=true
				if motion[i*4]<.01:bases[b[i]]=true
				for j in range(card*6,card*6+6):max_length_error=maxf(max_length_error,absf(a[i].distance_to(a[j])-b[i].distance_to(b[j])))
			var top:=Vector3.ZERO;var base:=Vector3.ZERO
			for v:Vector3 in tops:top+=v/float(tops.size())
			for v:Vector3 in bases:base+=v/float(bases.size())
			var stem:=top-base
			var angle:=atan2(Vector2(stem.x,stem.z).length(),stem.y)
			max_angle_error=maxf(max_angle_error,absf(angle-p.grass_splay.angle(variant*4+card)))
	check(max_length_error<.00001,"Native card edge lengths preserved without stretching")
	check(max_angle_error<.00001,"Card inclination matches measured captured input")
	check(min_ground>-.00001,"All static roots stay above ground")
	check(min_bent_ground>-.00001,"Existing maximum wind/contact bend cannot push these cards below their support plane")
	for i in roots.size():check(roots[i]==p.placements[i].root,"Cell root layout and RNG unchanged")
	p.set_grass_splay(false)
	var restored:=vertices(p)
	check(restored==upright,"OFF restores exact previous upright patches")
	p.set_grass_splay(true)
	check(p.instance_count==8418 and p.flower_colors.is_empty(),"Density and grass-only selection preserved")
	check(AudioServer.is_bus_mute(0) and w.player.active_clip=="Idle","Muted grounded startup preserved")
	print("GRASS_SPLAY_RESULT ",JSON.stringify({"failures":failures,"max_edge_error_m":max_length_error,"max_angle_error_rad":max_angle_error,"min_ground_m":min_ground,"min_bent_ground_m":min_bent_ground,"shape":p.grass_splay.snapshot()}))
	w.free();await process_frame;await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)
