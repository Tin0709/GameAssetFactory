extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label);push_error(label)
func _initialize() -> void: call_deferred("run")
func tick(v: Node) -> void:
	await physics_frame
	await process_frame
	v._evaluate(1./Engine.physics_ticks_per_second)
func run() -> void:
	var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
	Engine.physics_ticks_per_second=fps
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
	var a=scene.player;var v=a.visual;a.scripted_input=true;v.set_process(false)
	check(v.get("idle_controller")!=null,"Existing scene must bind approved Idle overlay")
	if not failures.is_empty(): scene.free();quit(1);return
	var min_sole:=INF;var max_pose_step:=0.;var previous:=Quaternion.IDENTITY;var seen:=false
	for i in int(5.*fps):
		await tick(v)
		if v.idle_snapshot.state=="tculwn": seen=true
		for bone in [v.leg_left,v.leg_right]: min_sole=minf(min_sole,v._sole_world(bone).y)
		var q: Quaternion=v.skeleton.get_bone_pose_rotation(v.skeleton.find_bone("Head"))
		if i>0: max_pose_step=maxf(max_pose_step,rad_to_deg(previous.angle_to(q)))
		previous=q
	check(seen and v.idle_active,"Exact approved LookAround starts after source dwell")
	check(v.idle_snapshot.layers[0].alias=="tculwn","Only approved Idle gesture plays")
	check(v.direction_controller.env["v.tnlxsa"]==2.,"Idle profile does not mutate accepted ground profile")
	var phase: float=v.gait_phase
	a.requested_direction=Vector2(0,-1)
	await tick(v)
	check(a.current_speed>.1,"Movement responds on first input tick")
	check(v.idle_snapshot.state=="bhsawv","LookAround interrupted on first input tick")
	check(v.idle_snapshot.controllers.bjmscc.outgoing=="tculwn","Source .2s exit fade retained")
	check(absf(wrapf(v.gait_phase-phase,-.5,.5))<.3,"No gait phase restart on interruption")
	for i in int(.5*fps): await tick(v)
	check(not v.idle_active,"Idle fade completes during Walk")
	a.requested_run=true
	for i in fps: await tick(v)
	check(v.gait_run_weight>.98,"Run remains available after Idle")
	a.requested_direction=Vector2.ZERO;a.requested_run=false
	for i in int(5.*fps): await tick(v)
	check(v.idle_active,"Natural stop returns to approved Idle")
	a.requested_jump=true
	for i in int(2.8*fps):
		await tick(v)
		if i==1: a.requested_jump=false
		if v.jump_active: check(not v.idle_active,"Jump owns pose; no Idle overlay in flight/landing")
	check(not v.jump_active,"Existing physical jump and landing complete")
	check(min_sole>-.004,"Idle feet remain above ground: "+str(min_sole))
	check(max_pose_step<12.,"No Idle head snaps at30/60FPS: "+str(max_pose_step))
	print("IDLE_GAMEPLAY ",JSON.stringify({"fps":fps,"failures":failures,"min_sole":min_sole,"max_head_step_deg":max_pose_step}))
	scene.free();quit(0 if failures.is_empty() else 1)
