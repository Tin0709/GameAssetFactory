extends SceneTree
var failures=[]
func check(ok:bool,message:String):
	if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
	var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
	await create_timer(.4).timeout
	if not w.showcase.has_method("set_spatial_mist"):
		print("SPATIAL_MIST missing volume-depth control");w.free();quit(1);return
	var s=w.showcase;var native:bool=s.forest.available()
	s.set_hour(7.);s.set_atmosphere_review("combined");s.set_spatial_mist(true)
	await process_frame;await process_frame
	var env:Environment=w.get_node("WorldEnvironment").environment
	if native:
		check(s.mist.effect.snapshot().ready and s.mist.failure().is_empty(),"Shared medium generated before shading")
		check(s.mist.visible and env.fog_density==0.,"World-volume integration replaces global ramp")
		env.fog_enabled=false;await process_frame;await process_frame
		check(not s.mist.visible,"H also disables volume")
		env.fog_enabled=true;await process_frame;await process_frame
		check(s.mist.visible,"H restores volume")
		s.set_spatial_mist(false);await process_frame
		check(not s.mist.visible and env.fog_density>0.,"Flat reference remains inspectable")
		s.set_spatial_mist(true);s.set_atmosphere_review("previous");await process_frame
		check(not s.mist.visible,"Previous hides volume")
	if native:
		s.set_atmosphere_review("combined");s.set_spatial_mist(true)
		for i in 5:await process_frame
		var exposure=w.look._exposure_effect
		w.look.set_local_exposure(false)
		for i in 5:await process_frame
		check(s.mist.effect in w.get_node("Camera3D").compositor.compositor_effects,"Mist survives exposure OFF")
		w.look.set_local_exposure(true)
		for i in 5:await process_frame
		check(w.look.local_exposure_active() and s.mist.effect in w.get_node("Camera3D").compositor.compositor_effects,"Exposure and mist share owned chain")
		s.mist.effect._report("error","injected test failure")
		for i in 4:await process_frame
		check(not s.mist.visible and env.fog_density>0.,"GPU failure restores reference haze")
		s.mist.effect._report("error","")
	var model=load("res://scripts/world_map_atmosphere_volume.gd")
	var a:float=model.integral(Vector3(0,0,0),Vector3(10,0,0),.1,0.,0.,0.,1024)
	check(absf(a-1.)<.00001,"Homogeneous optical depth is sigma times distance")
	var high:float=model.integral(Vector3(0,10,0),Vector3(10,10,0),.1,.2,0.,0.,1024)
	check(absf(high-exp(-2.))<.00001,"Height changes density in world space")
	check(model.integral(Vector3.ZERO,Vector3(2,0,0),.1,0.,0.,3.,1024)==0.,"Foreground before start remains clear")
	print("SPATIAL_MIST failures=",JSON.stringify(failures));w.free();await process_frame;quit(0 if failures.is_empty() else 1)
