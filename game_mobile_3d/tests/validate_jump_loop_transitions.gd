extends SceneTree
var failures:Array[String]=[]
var measurements:Array=[]
func _initialize() -> void:call_deferred("run")
func tick(count: int=1) -> void:
	for i in count:
		await physics_frame;await process_frame;await create_timer(0.0).timeout
func check(ok: bool, text: String) -> void:
	if not ok:failures.append(text);push_error(text)
func floor_box(parent: Node, location: Vector3, size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=size;shape.shape=box;body.add_child(shape);parent.add_child(body);body.position=location;return body
func run() -> void:
	var level:Node=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(level);current_scene=level
	await tick(8)
	var p=level.player;p.get_node("WeaponBehavior").enabled=false;p.get_node("Pistol").enabled=false
	p.smooth_step_up_enabled=false
	var fixture:=Node3D.new();level.add_child(fixture)
	floor_box(fixture,Vector3(0,29.5,0),Vector3(80,1,20))
	p.cancel_jump();p.position=Vector3(-15,30.02,0);p.velocity=Vector3.ZERO;await tick(4)
	Input.action_press("jump");await tick(35)
	Input.action_press("move_right");Input.action_press("sprint")
	var previous:Quaternion=p.visual.skeleton.get_bone_pose_rotation(p.visual.leg_right)
	var maximum:=0.0;var switched:=false
	for i in 35:
		await tick()
		var q:Quaternion=p.visual.skeleton.get_bone_pose_rotation(p.visual.leg_right)
		maximum=maxf(maximum,previous.angle_to(q));previous=q
		switched=switched or p.jump_kind==&"run"
	check(switched,"Held stationary jump transitions into running repeat")
	check(rad_to_deg(maximum)<18.0,"Action change blends instead of snapping at full weight")
	measurements.append({"profile_switch_maximum_step_deg":rad_to_deg(maximum)})
	Input.action_release("jump");Input.action_release("move_right");Input.action_release("sprint");p.cancel_jump()
	# Start ten metres above a lower floor and travel off a short ledge mid-jump.
	var ledge:=floor_box(fixture,Vector3(-5,39.5,0),Vector3(4,1,6))
	p.position=Vector3(-4.0,40.02,0);p.velocity=Vector3.ZERO;await tick(4)
	Input.action_press("move_right");Input.action_press("sprint");check(p.request_jump(),"Drop starts supported")
	var poses:Array[Quaternion]=[];var reached_floor:=false;var peak:float=p.position.y
	for i in 120:
		await tick();peak=maxf(peak,p.position.y)
		if p.jump_active and not p.is_on_floor() and p.jump_time>p.jump_profile.contact+.15:
			poses.append(p.visual.skeleton.get_bone_pose_rotation(p.visual.leg_right))
		if p.is_on_floor() and p.position.y<31.0:reached_floor=true;Input.action_release("move_right");Input.action_release("sprint")
	var sweep:=0.0
	for a in poses:
		for b in poses:sweep=maxf(sweep,a.angle_to(b))
	check(poses.size()>=8 and rad_to_deg(sweep)>10.0,"Extended drop keeps authored feet moving")
	check(peak<41.3 and reached_floor and not p.jump_active,"Drop has no air jump and recovers on real floor")
	measurements.append({"extended_drop_samples":poses.size(),"leg_sweep_deg":rad_to_deg(sweep),"peak_y":peak,"landed":reached_floor})
	ledge.queue_free();fixture.queue_free();level.queue_free();await process_frame;await process_frame
	FileAccess.open("res://.validation/jump_loop_v003/transitions.json",FileAccess.WRITE).store_string(JSON.stringify({"measurements":measurements,"failures":failures},"\t"))
	print("V003_TRANSITIONS failures=",failures)
	quit(0 if failures.is_empty() else 1)
