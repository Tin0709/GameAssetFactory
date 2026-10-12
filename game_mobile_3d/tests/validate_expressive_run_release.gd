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
	var actor=scene.actor;var v=actor.visual;actor.scripted_input=true
	for pace in [1.5,2.25]:
		actor.requested_direction=Vector2.ZERO;scene.reset_actor();await scene.tick(60)
		actor.review_pace=pace;actor.requested_run=true;actor.requested_direction=Vector2(0,1);await scene.tick(60)
		var feet: Array=v.last_sole.duplicate();var support: Array=v.foot_support.duplicate()
		var events: Array=[];var worst:=0.0;var release_age: Array[float]=[1.0,1.0]
		var previous_velocity: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO];var peak_velocity_jump:=0.0;var peak_acceleration:=0.0
		for sample in 180:
			await scene.tick(1)
			for side in 2:
				var speed: float=v.last_sole[side].distance_to(feet[side])/v.pose_delta
				var velocity: Vector3=(v.last_sole[side]-feet[side])/v.pose_delta
				if support[side] and not v.foot_support[side]:
					worst=maxf(worst,speed);events.append({"side":side,"phase":v.gait_phase,"release_speed":speed,"delta":v.pose_delta})
					release_age[side]=0
				if release_age[side]<.08:
					peak_velocity_jump=maxf(peak_velocity_jump,(velocity-previous_velocity[side]).length())
					peak_acceleration=maxf(peak_acceleration,(velocity-previous_velocity[side]).length()/v.pose_delta)
				release_age[side]+=v.pose_delta;previous_velocity[side]=velocity
				feet[side]=v.last_sole[side];support[side]=v.foot_support[side]
		cases.append({"pace":pace,"worst_release_speed":worst,"peak_release_velocity_jump":peak_velocity_jump,"peak_release_acceleration":peak_acceleration,"events":events})
		check(not events.is_empty(),"Straight Run reaches support-to-swing events")
		check(worst<4.5,"Run lifts from support smoothly rather than dropping contact translation instantly")
		check(peak_acceleration<300,"Foot velocity ramps through the release instead of moving its discontinuity a few frames later")
	var out:="res://.validation/expressive_turn_spin_v1";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/run_release.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"))
	print("RUN_RELEASE_CHECKS ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)
