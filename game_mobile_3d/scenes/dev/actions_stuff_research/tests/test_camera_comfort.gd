extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label);push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
	scene.set_process(false);scene.player.set_physics_process(false);scene.player.visual.set_process(false)
	check(scene.get("camera_anchor")!=null,"Camera must have a vertical anchor independent of jump height")
	if not failures.is_empty(): scene.free();quit(1);return
	var reports:=[]
	for fps in [30,60]:
		scene.reset_player();var dt:=1./fps
		var start: Vector3=scene.camera.global_position
		var max_y:=0.;var max_step:=0.;var previous: Vector3=start
		for i in fps*2:
			var t: float=float(i)*dt
			scene.player.position=Vector3(t*1.8,maxf(0.,1.256*sin(PI*minf(t/.75,1.))),0.)
			scene.player.visual.jump_grounded=t>=.75
			scene._update_camera(dt)
			max_y=maxf(max_y,absf(scene.camera.global_position.y-start.y))
			max_step=maxf(max_step,absf(scene.camera.global_position.y-previous.y));previous=scene.camera.global_position
		check(max_y<.001,"Normal jump keeps vertical frame stable at "+str(fps))
		check(scene.camera_anchor.x>3.2 and scene.camera_anchor.x<3.6,"Horizontal follow remains smooth and responsive")
		check(is_equal_approx(scene.camera.global_position.distance_to(scene.camera_anchor),8.),"Camera distance preserved")
		# Simulated new platform/long fall, without adding any scene or physics content.
		for height in [6.,-9.]:
			var prior: float=scene.camera_anchor.y
			scene.player.position.y=height;scene.player.visual.jump_grounded=false
			scene._update_camera(dt)
			check(absf(scene.camera_anchor.y-prior)<.6,"Large elevation follows without teleport")
			for i in fps*4: scene._update_camera(dt)
			check(absf(scene.camera_anchor.y-(height+.95))<1.5,"Long elevation change keeps player in vertical visibility zone")
			scene.player.visual.jump_grounded=true
			for i in fps*4: scene._update_camera(dt)
			check(absf(scene.camera_anchor.y-(height+.95))<.001,"Grounded elevation settles smoothly")
		check(scene.azimuth==.66 and scene.elevation==.40 and scene.camera_size==5.1,"Original angle and framing preserved")
		reports.append({"fps":fps,"normal_jump_camera_y_range":max_y,"normal_jump_max_y_step":max_step})
	print("CAMERA_COMFORT ",JSON.stringify({"failures":failures,"reports":reports}))
	scene.free();quit(0 if failures.is_empty() else 1)
