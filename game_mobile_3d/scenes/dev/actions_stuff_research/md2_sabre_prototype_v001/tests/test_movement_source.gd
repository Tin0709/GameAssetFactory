extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func tick()->void:await physics_frame;await process_frame
func ticks(count:int)->void:
	for i in count:await tick()
func release()->void:
	for action:String in ["move_left","move_right","move_forward","move_backward","sprint","jump"]:Input.action_release(action)
func run()->void:
	var floor:=StaticBody3D.new();var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1000,.4,1000);floor_shape.shape=box;floor_shape.position.y=-.2;floor.add_child(floor_shape);root.add_child(floor)
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a)
	check(a.using_original_source,"Probe uses original private source profile")
	check(absf(a.run_speed-7.)<.00001,"Public player700 baseline converts100UU per Godot metre")
	check(absf(a.walk_speed-2.)<.00001,"Slow study Walk remains separately declared adapter")
	var reports:Array[Dictionary]=[]
	for hz in [30,60]:
		Engine.physics_ticks_per_second=hz;release();a.reset_actor();await ticks(4)
		Input.action_press("move_forward");await ticks(hz/2)
		check(a.active_clip=="Run" and absf(a.current_speed-7.)<.01,"Ordinary WASD uses normal7 speed at "+str(hz))
		var start:Vector3=a.global_position;var clock:float=a.simulation_clock
		await ticks(hz)
		var travel:float=start.distance_to(a.global_position);var elapsed:float=a.simulation_clock-clock
		check(absf(travel-7.*elapsed)<.025,"Measured capsule distance follows7 baseline at "+str(hz))
		check(absf(a._playback_speed-a.current_speed/5.6)<.00001,"Gait rate follows actual travel/stride, not target-speed normalization at "+str(hz))
		var rate:float=a._playback_speed
		Input.action_press("move_right");await ticks(hz/2)
		check(absf(a.current_speed-7.)<.01,"Diagonal input has no sqrt2 speed bonus at "+str(hz))
		Input.action_press("sprint");await ticks(hz/2)
		check(a.active_clip=="Walk" and absf(a.current_speed-2.)<.01,"Human Shift selects explicit slow study Walk at "+str(hz))
		release();await ticks(hz/2)
		check(a.active_clip=="Idle" and a.current_speed<.01,"Braking settles to stationary Idle at "+str(hz))
		check(a.has_method("set_movement_camera_basis"),"Camera-relative input setter available")
		if a.has_method("set_movement_camera_basis"):
			a.set_movement_camera_basis(Basis(Vector3.UP,PI/2.));Input.action_press("move_forward");await ticks(hz/2)
			check(a.velocity.x< -6.99 and absf(a.velocity.z)<.01,"W follows camera forward, including orbit, at "+str(hz))
			release();a.set_movement_camera_basis(Basis.IDENTITY)
		a.reset_actor();await ticks(4)
		# Actual collision must stop both travel and distance-driven gait.
		var wall:=StaticBody3D.new();var wc:=CollisionShape3D.new();var wb:=BoxShape3D.new();wb.size=Vector3(20,5,1);wc.shape=wb;wall.position=Vector3(0,2,-3);wall.add_child(wc);root.add_child(wall)
		Input.action_press("move_forward");await ticks(hz)
		var blocked_start:Vector3=a.global_position;await ticks(8)
		check(a.global_position.distance_to(blocked_start)<.001 and a.current_speed<.001 and a._playback_speed<.001,"Blocked capsule does not walk in place at "+str(hz))
		release();wall.free();a.reset_actor();await ticks(4)
		# Simulate an actual ledge by removing support, not by changing is_on_floor.
		floor_shape.set_deferred("disabled",true);await ticks(2)
		Input.action_press("jump");await tick();Input.action_release("jump")
		check(a.velocity.y>0. and a._jump_stage=="JumpTakeoff","Recovered-table coyote window permits recent ledge departure at "+str(hz))
		await tick();var first_launch:float=a.velocity.y;Input.action_press("jump");await tick();Input.action_release("jump")
		check(a.velocity.y<first_launch,"Coyote jump cannot be retriggered in air at "+str(hz))
		floor_shape.set_deferred("disabled",false);a.reset_actor();await ticks(4)
		floor_shape.set_deferred("disabled",true);await ticks(ceili(.22*hz))
		Input.action_press("jump");await tick();Input.action_release("jump")
		check(a.velocity.y<0.,"Coyote jump rejected after155ms table window at "+str(hz))
		floor_shape.set_deferred("disabled",false);release();a.reset_actor();await ticks(4)
		# Explicit scripted walk/run remains stable for existing capture tooling.
		a.scripted_input=true;a.requested_direction=Vector2(0,-1);a.requested_run=false;await ticks(hz/2)
		check(absf(a.current_speed-2.)<.01,"Scripted Walk semantic is preserved at "+str(hz))
		a.requested_run=true;await ticks(hz/2)
		check(absf(a.current_speed-7.)<.01,"Scripted Run uses corrected physical baseline at "+str(hz))
		a.scripted_input=false;release();a.reset_actor();await ticks(4)
		reports.append({"hz":hz,"elapsed":elapsed,"actual_distance":travel,"speed":travel/elapsed,"source_gait_rate":rate})
	a.set_physics_process(false);a.review("Run");a._animate(float(a.clips.Run.duration)*.5)
	check(absf(a.animation_player.current_animation_position/float(a.clips.Run.duration)-.5)<.00001,"Raw source review remains1x despite gameplay cadence")
	var out:={"checks":checks,"failures":failures,"measurements":reports,"provenance":"public table700; standard unit conversion; runtime effective config unverified"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation/md2_sabre_movement"));FileAccess.open("res://.validation/md2_sabre_movement/source-motion.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("SABRE_SOURCE_MOVEMENT ",JSON.stringify(out));a.free();floor.free();quit(0 if failures.is_empty() else 1)
