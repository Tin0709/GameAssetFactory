extends SceneTree
var failures: Array[String]=[]
var checks: Array=[]
var measurements: Array=[]
func _initialize() -> void:call_deferred("run")
func tick(count: int=1) -> void:
	for i in count:
		await physics_frame;await process_frame
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func box(parent: Node, position: Vector3, size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var geometry:=BoxShape3D.new()
	geometry.size=size;shape.shape=geometry;body.add_child(shape);parent.add_child(body);body.position=position
	return body
func run() -> void:
	var level:Node=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(level);current_scene=level
	await tick(10)
	var p=level.player
	p.get_node("WeaponBehavior").enabled=false;p.get_node("Pistol").enabled=false
	for action in ["Jump_Walk_Loop_v003","Jump_Run_Loop_v003"]:
		check(p.visual.samples.has(action),"WorldMap loads "+action)
	# Temporary isolated collision fixture above WorldMap; never saved into the map.
	var fixture:=Node3D.new();level.add_child(fixture)
	box(fixture,Vector3(0,29.5,0),Vector3(40,1,40))
	var platform:=box(fixture,Vector3(1.5,30.5,0),Vector3(3,1,6))
	p.smooth_step_up_enabled=false
	for kind in ["stationary","walk","run"]:
		p.cancel_jump();p.position=Vector3(-7,30.02,0);p.velocity=Vector3.ZERO;await tick(5)
		if kind!="stationary":Input.action_press("move_right")
		if kind=="run":Input.action_press("sprint")
		check(p.request_jump(),kind+" starts supported")
		var peak:float=p.position.y;var start:float=p.position.y
		for i in 65:
			await tick();peak=maxf(peak,p.position.y)
		check(peak-start>1.10 and peak-start<1.30,kind+" clears one block with 1.2m apex")
		if kind!="stationary":check(p.jump_profile.action=="Jump_"+("Walk" if kind=="walk" else "Run")+"_Loop_v003",kind+" selects authored V003")
		check(p.is_on_floor() and not p.jump_active,kind+" recovers on support")
		measurements.append({"case":kind,"apex":peak-start})
		Input.action_release("move_right");Input.action_release("sprint")
	for kind in ["walk","run"]:
		p.cancel_jump();p.position=Vector3(-2.3,30.02,0);p.velocity=Vector3.ZERO;await tick(5)
		Input.action_press("move_right")
		if kind=="run":Input.action_press("sprint")
		check(p.request_jump(),kind+" block approach starts supported")
		var landed_on_top:=false;var max_y:float=p.position.y
		for i in 80:
			await tick();max_y=maxf(max_y,p.position.y)
			if p.is_on_floor() and p.position.y>30.95:
				landed_on_top=true;Input.action_release("move_right");Input.action_release("sprint")
		check(landed_on_top,kind+" lands on 1m block without smooth step assistance")
		check(p.is_on_floor() and absf(p.position.y-31.0)<.04 and not p.jump_active,kind+" stands stably on raised block")
		measurements.append({"case":kind+" block ascent","landed":landed_on_top,"position":[p.position.x,p.position.y,p.position.z],"peak":max_y})
		Input.action_release("move_right");Input.action_release("sprint")
	platform.free()
	p.cancel_jump();p.position=Vector3(-12,30.02,0);p.velocity=Vector3.ZERO;await tick(5)
	Input.action_press("move_right");Input.action_press("sprint");Input.action_press("jump")
	var wraps:=0;var previous:=0.0;var minimum_blend:=1.0;var supported:=true;var wrap_steps:Array=[]
	var last_q:Quaternion=p.visual.skeleton.get_bone_pose_rotation(p.visual.leg_right)
	for i in 150:
		await tick()
		var q:Quaternion=p.visual.skeleton.get_bone_pose_rotation(p.visual.leg_right)
		if p.jump_active and p.jump_time<previous-.1:
			wraps+=1;supported=supported and p.is_on_floor();wrap_steps.append(rad_to_deg(last_q.angle_to(q)))
		if i>10 and p.jump_active:
			if "jump_blend" in p.visual:minimum_blend=minf(minimum_blend,p.visual.jump_blend)
			else:minimum_blend=0.0
		previous=p.jump_time;last_q=q
	check(wraps>=2 and supported,"Held running repeats only from support")
	check(minimum_blend>.99,"Held cycles preserve full pose blend across joins")
	var seamless:=true
	for degrees in wrap_steps:seamless=seamless and degrees<18.0
	check(seamless,"No large leg snap at repeated cycle join")
	Input.action_release("jump");await tick(70)
	check(not p.jump_active,"Space release completes final cycle without repeat")
	Input.action_release("move_right");Input.action_release("sprint")
	measurements.append({"wraps":wraps,"minimum_blend":minimum_blend,"join_steps_deg":wrap_steps})
	fixture.queue_free()
	await tick(3)
	var route:Dictionary=load("res://tests/jump_v003_map_route.gd").find(level)
	check(not route.is_empty(),"Find a clear original WorldMap 1m riser")
	if not route.is_empty():
		for kind in ["walk","run"]:
			p.cancel_jump();p.position=route.start;p.velocity=Vector3.ZERO;await tick(5)
			Input.action_press(route.action)
			if kind=="run":Input.action_press("sprint")
			check(p.request_jump(),kind+" starts real terrain jump")
			var landed:=false
			for i in 65:
				await tick()
				if p.is_on_floor() and absf(p.position.y-route.target.y)<.04:
					landed=true;Input.action_release(route.action);Input.action_release("sprint")
			check(landed and p.is_on_floor() and absf(p.position.y-route.target.y)<.04,kind+" lands and stays on actual mapped 1m riser")
			measurements.append({"case":kind+" actual map ascent","landed":landed,"source_column":str(route.column),"position":str(p.position)})
			Input.action_release(route.action);Input.action_release("sprint")
	var tag:="runtime"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):tag=arg.trim_prefix("--report=")
	DirAccess.make_dir_recursive_absolute("res://.validation/jump_loop_v003")
	FileAccess.open("res://.validation/jump_loop_v003/checks_"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	print("V003_CHECKS ",checks.size()," failures=",failures)
	level.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
