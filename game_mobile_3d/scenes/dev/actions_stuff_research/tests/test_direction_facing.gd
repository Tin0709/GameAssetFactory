extends SceneTree
## Directional feet adapt during a turn; steady WASD must face travel, not strafe.
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
	var actor=scene.player;var v=actor.visual
	actor.set_physics_process(false);v.set_process(false)
	var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
	var dt:=1./fps;var phase: float=v.direction_snapshot.phase;var floor_min:=INF;var facing_errors: Array=[]
	for speed in [actor.walk_speed,actor.run_speed]:
		for direction in [Vector3(0,0,-1),Vector3(0,0,1),Vector3(1,0,0),Vector3(-1,0,0)]:
			for i in int(1.5/dt):
				var planar:=Vector2(actor.velocity.x,actor.velocity.z).move_toward(Vector2(direction.x,direction.z)*speed,actor.acceleration*dt)
				actor.velocity=Vector3(planar.x,0,planar.y);actor.position+=actor.velocity*dt
				v.drive_locomotion(actor.velocity,true,dt);v._evaluate(dt)
				check(v.direction_snapshot.phase>=phase,"Turning must retain gait phase");phase=v.direction_snapshot.phase
				for bone in [v.leg_left,v.leg_right]:floor_min=minf(floor_min,v._sole_world(bone).y)
			var facing: float=-deg_to_rad(v.direction_snapshot.vars["v.nthjcy"])
			var target:=atan2(direction.x,direction.z)
			var error:=absf(wrapf(facing-target,-PI,PI));facing_errors.append(rad_to_deg(error))
			check(error<deg_to_rad(8.),"Steady WASD must face its travel direction: "+str(direction)+" error="+str(rad_to_deg(error)))
	var before: float=v.look_yaw
	scene.azimuth+=PI;scene._process(dt)
	check(is_equal_approx(v.look_yaw,before),"Camera orbit must not override locomotion facing")
	check(floor_min>-.003,"Turning keeps feet above the floor")
	var report={"fps":fps,"failures":failures,"steady_facing_errors_deg":facing_errors,"floor_min":floor_min}
	print("DIRECTION_FACING ",JSON.stringify(report));scene.free();quit(0 if failures.is_empty() else 1)
