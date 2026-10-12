extends SceneTree
var checks: Array=[]
var failures: Array=[]
var cases: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var scene=load("res://scenes/dev/ExpressiveLocomotionTest.tscn").instantiate();root.add_child(scene);current_scene=scene
	var actor=scene.actor;actor.scripted_input=true
	for pace in [1.5,2.25]:
		for sprint in [false,true]:
			actor.requested_direction=Vector2.ZERO;scene.reset_actor();actor.position.x=-12;await scene.tick(55)
			actor.review_pace=pace;actor.requested_run=sprint;actor.requested_direction=Vector2(0,1);await scene.tick(45)
			var ground_speed: float=actor.current_speed;actor.request_jump();await scene._wait_state("AIR",30);await scene.tick(8)
			var candidate_scale: float=(1.15 if sprint else 1.5) if pace>=2.25 else 1.0
			var expected_ground: float=(actor.run_speed if sprint else actor.walk_speed)*pace*candidate_scale
			check(absf(ground_speed-expected_ground)<.015,"Requested faster Walk/Run speed and accepted1.5x comparison are exact")
			check(v_gait_matches(actor,sprint),"Speed calibration preserves Walk and Run pose identities")
			var air_speed: float=actor.current_speed
			check(absf(air_speed/ground_speed-(1.15 if sprint else 1.0))<.015,"Only running flight gains15percent horizontal speed")
			actor.requested_direction=Vector2(1,0);await scene.tick(5)
			var expected_x: float=minf(air_speed,actor.acceleration*pace*pace*(5.0/60.0)/sqrt(2.0))
			check(actor.velocity.x>=expected_x*.95,"Boosted flight retains the existing directional acceleration")
			await scene._wait_state("LAND",90);await scene.tick(20)
			check(absf(actor.current_speed/ground_speed-1)<.015,"Landing returns to normal locomotion speed")
			cases.append({"pace":pace,"run":sprint,"ground_speed":ground_speed,"air_speed":air_speed,"recovery_speed":actor.current_speed})
			actor.review_drop(6);await scene.tick(25)
			check(absf(actor.current_speed/ground_speed-1)<.015,"Unprepared falls keep their existing horizontal speed")
			actor.requested_direction=Vector2.ZERO;scene.reset_actor();actor.position.x=-12;await scene.tick(55)
			actor.requested_direction=Vector2(0,1);await scene.tick(45)
			var jump_count: int=actor.jump_count;actor.request_jump();await scene.tick(2)
			actor.position.y=6;actor.velocity.y=0;await scene.tick(25)
			check(actor.jump_state=="AIR" and actor.jump_count==jump_count,"Losing support during preparation does not invent a launch")
			check(absf(actor.current_speed/ground_speed-1)<.015,"Preparation interrupted by a ledge fall receives no running jump boost")
	var out:="res://.validation/expressive_turn_spin_v1";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/run_jump_speed.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"))
	print("RUN_JUMP_SPEED_CHECKS ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)

func v_gait_matches(actor: Node,sprint: bool) -> bool:
	return actor.visual.gait_run_weight>.99 if sprint else actor.visual.gait_run_weight<.01
