extends SceneTree
var checks: Array=[]
var failures: Array=[]
var cases: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var scene=load("res://scenes/dev/ExpressiveLocomotionTest.tscn").instantiate()
	root.add_child(scene);current_scene=scene;var actor=scene.actor;actor.scripted_input=true
	check(actor.get("jump_flight_speed")!=null,"Test actor offers independent jump flight timing")
	if actor.get("jump_flight_speed")==null:quit(1);return
	check(is_equal_approx(actor.jump_flight_speed,1.4) and is_equal_approx(actor.jump_height,1.35),"New test default is snappier and modestly higher")
	await scene.tick(2)
	check(is_equal_approx(scene.camera.size,12.5),"Default camera uses requested closer gameplay framing")
	var event:=InputEventKey.new();event.physical_keycode=KEY_J;event.pressed=true
	for expected in [1.18,1.0,1.4]:
		scene._unhandled_key_input(event)
		check(is_equal_approx(actor.jump_flight_speed,expected),"J preserves all three timing comparisons")
	check(is_equal_approx(actor.jump_height,1.35),"J restores the higher candidate height")
	for pace in [1.5,2.25]:
		for mode in ["Stationary","Walk","Run"]:
			var versions: Array=[]
			for rate in [1.18,1.4]:
				actor.requested_direction=Vector2.ZERO;actor.requested_run=false;scene.reset_actor();actor.position.x=-12
				actor.jump_height=1.2 if rate<1.3 else 1.35;actor.jump_flight_speed=rate;actor.review_pace=pace;await scene.tick(60)
				actor.requested_direction=Vector2.ZERO if mode=="Stationary" else Vector2(0,1);actor.requested_run=mode=="Run"
				await scene.tick(35);actor.request_jump()
				check(await scene._wait_state("AIR",35),"Physical launch remains responsive")
				var start: float=actor.jump_events[-1].time;var peak: float=actor.position.y;var max_air_frame:=0.0
				while actor.jump_state=="AIR":
					peak=maxf(peak,actor.position.y);max_air_frame=maxf(max_air_frame,actor.visual.jump_frame);await scene.tick(1)
				var flight: float=actor.jump_events[-1].time-start
				check(actor.jump_state=="LAND" and actor.is_on_floor(),"Physics collision owns quicker touchdown")
				check(absf(peak-actor.jump_height)<.025,"Quicker flight preserves requested physical height")
				check(max_air_frame>=30,"Strong airborne arm silhouette still develops")
				await scene.tick(60)
				check(actor.jump_state=="GROUND","Original impact/recovery returns to live gait")
				versions.append({"rate":rate,"flight_seconds":flight,"peak_m":peak,"maximum_air_frame":max_air_frame})
			check(versions[1].flight_seconds<versions[0].flight_seconds*.95 and versions[1].flight_seconds>versions[0].flight_seconds*.78,"Flight is moderately shorter without an exaggerated timing change")
			check(versions[1].peak_m>versions[0].peak_m+.12 and versions[1].peak_m<versions[0].peak_m+.18,"New height is modestly greater by about15cm")
			cases.append({"pace":pace,"mode":mode,"versions":versions})
	# A comparison key change in midair must not alter that flight's gravity.
	actor.requested_direction=Vector2.ZERO;await scene.tick(60);actor.jump_flight_speed=1.4;actor.request_jump();await scene._wait_state("AIR",35)
	var gravity_before: float=actor._flight_gravity();actor.jump_flight_speed=1.0
	var camera_y: float=scene.camera.position.y;await scene.tick(4)
	check(absf(scene.camera.position.y-camera_y)<.001,"Gameplay camera stays grounded during launch")
	check(is_equal_approx(actor._flight_gravity(),gravity_before),"Flight rate is latched until contact; comparison changes next jump")
	await scene._wait_state("LAND",90);await scene.tick(60)
	actor.jump_flight_speed=1.4;actor.review_drop(6);await scene.tick(2)
	check(is_equal_approx(actor._flight_gravity(),actor.gravity),"Unprepared falls retain original gravity and gesture timing")
	var out:="res://.validation/expressive_jump_quicker_v2";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/comparison.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"))
	print("EXPRESSIVE_QUICKER_JUMP_CHECKS ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)
