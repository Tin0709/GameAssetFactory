extends SceneTree
## Actual CharacterBody3D first-frame response; external private profile required.
var failures:Array[String]=[]
var checks:=0
var reports:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func tick()->void:await physics_frame;await process_frame
func run()->void:
	var floor:=StaticBody3D.new();var c:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(100,.4,100);c.shape=shape;c.position.y=-.2;floor.add_child(c);root.add_child(floor)
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();a.scripted_input=true;root.add_child(a)
	check(a.using_original_source,"Uses private original source, no authored fallback")
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second=hz;a.reset_actor()
		for i in 4:await tick()
		var start:Vector3=a.global_position;var clock:float=a.simulation_clock
		a.requested_run=true;a.requested_direction=Vector2(0,1);await tick()
		var response_speed:float=Vector2(a.velocity.x,a.velocity.z).length();var travel:float=a.global_position.distance_to(start);var elapsed:float=a.simulation_clock-clock
		check(absf(response_speed-7.)<.001,"Native configured acceleration reaches baseline within first ground tick "+str(hz))
		check(absf(travel-7.*elapsed)<.001,"First input frame travels at recovered baseline "+str(hz))
		a.requested_direction=Vector2(0,-1);await tick()
		check(a.velocity.z< -6.999 and absf(a.velocity.x)<.001,"Direct reversal has no inherited slow velocity ramp "+str(hz))
		a.requested_direction=Vector2(1,-1);await tick()
		check(absf(Vector2(a.velocity.x,a.velocity.z).length()-7.)<.001,"Diagonal response remains capped "+str(hz))
		a.requested_direction=Vector2.ZERO;var stopped_at:Vector3=a.global_position;await tick()
		check(Vector2(a.velocity.x,a.velocity.z).length()<.001 and a.global_position.distance_to(stopped_at)<.001,"Native configured braking eliminates post-release drift first ground tick "+str(hz))
		a.visual.rotation.y=0.;a.requested_direction=Vector2.RIGHT;await tick()
		var expected:=minf(PI/2.,deg_to_rad(1800.)/hz)
		check(absf(a.visual.rotation.y-expected)<.001,"Body turn uses live configured yaw limit "+str(hz))
		check(absf(a.gravity-38.4)<.0001 and absf(a.jump_height-1.2)<.0001,"Accepted jump trajectory retained "+str(hz))
		reports.append({"hz":hz,"first_tick_speed":response_speed,"first_tick_distance":travel,"elapsed":elapsed,"yaw_step":a.visual.rotation.y})
		# Planted attack retains zero travel even with native fast ground response.
		a.requested_direction=Vector2.ZERO;await tick();a.attack(true);a.requested_direction=Vector2.RIGHT
		var planted_at:Vector3=a.global_position
		await tick()
		check(a.combo.active() and a.global_position.distance_to(planted_at)<.001,"Held attack stays planted "+str(hz))
		a.attack(false);a.requested_direction=Vector2.ZERO
		# Vertical contact must not inject a frame-rate-dependent body bounce.
		a.reset_actor()
		for i in 4:await tick()
		var heights:Array[float]=[];var ground_states:Array[bool]=[]
		var monitor:=func()->void:heights.append(a.position.y);ground_states.append(a._grounded)
		a.physics_pose_ready.connect(monitor);a.requested_direction=Vector2.RIGHT;a.requested_run=true
		for i in hz:await tick()
		a.physics_pose_ready.disconnect(monitor)
		check(float(heights.max())-float(heights.min())<.0001,"Flat-ground running does not add capsule vertical jitter at"+str(hz))
		check(ground_states.all(func(on_ground:bool)->bool:return on_ground),"Zero artificial ground drive retains contact at"+str(hz))
		# Native floor snapping must not pin the actor in space beyond an edge.
		a.reset_actor();a.position.x=49.7
		for i in 4:await tick()
		a.requested_direction=Vector2.RIGHT;a.requested_run=true
		for i in ceili(hz*.3):await tick()
		check(not a._grounded and a.velocity.y<0.,"Walking beyond support still enters gravity/fall at"+str(hz))
	var report:={"checks":checks,"failures":failures,"measurements":reports}
	print("SABRE_NATIVE_GROUND ",JSON.stringify(report));a.free();floor.free();quit(0 if failures.is_empty() else 1)
