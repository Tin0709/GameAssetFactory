extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();scene.rifle_ready=false;root.add_child(scene)
	var actor=scene.player;var v=actor.visual
	actor.set_physics_process(false);v.set_process(false)
	var dt:=1./60.
	for i in 60:v.drive_locomotion(Vector3.ZERO,false,dt);v._evaluate(dt)
	check(v.correction_clamps==0 and v.contact_drift<.01,"Cold start must initialize source contacts before presenting the character")
	for i in 120:v.drive_locomotion(Vector3.ZERO,false,dt);v._evaluate(dt)
	var initial_clamps: int=v.correction_clamps;var feet: Array[Vector3]=[v.contact_point(0),v.contact_point(1)]
	var max_idle_drift:=0.
	for i in 60:
		v.look_yaw=PI+PI*(i+1)/60.
		v.drive_locomotion(Vector3.ZERO,false,dt);v._evaluate(dt)
		for side in 2:max_idle_drift=maxf(max_idle_drift,v.contact_point(side).distance_to(feet[side]))
	check(v.correction_clamps==initial_clamps and max_idle_drift<.01,"Idle look/orbit must not spin or drag planted feet: "+str(max_idle_drift))
	var max_stop_height_step:=0.
	for run in [false,true]:
		var speed: float=actor.run_speed if run else actor.walk_speed
		for i in 180:
			actor.velocity=Vector3(0,0,speed);actor.position+=actor.velocity*dt
			v.drive_locomotion(actor.velocity,true,dt);v._evaluate(dt)
		var last_height: float=v.position.y
		for i in 120:
			speed=move_toward(speed,0.,actor.deceleration*dt)
			actor.velocity=Vector3(0,0,speed);actor.position+=actor.velocity*dt
			v.drive_locomotion(actor.velocity,speed>0.,dt);v._evaluate(dt)
			max_stop_height_step=maxf(max_stop_height_step,absf(v.position.y-last_height));last_height=v.position.y
	check(max_stop_height_step<.025,"Stop must retain continuous native height: "+str(max_stop_height_step))
	var report={"failures":failures,"idle_foot_drift_m":max_idle_drift,"max_stop_height_step_m":max_stop_height_step}
	print("DIRECTION_CONTINUITY ",JSON.stringify(report));scene.free();quit(0 if failures.is_empty() else 1)
