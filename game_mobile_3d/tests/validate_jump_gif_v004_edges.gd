extends SceneTree
const OUT:="res://.validation/jump_gif_v004"
var checks:Array=[]
var failures:Array[String]=[]
var measurements:Array=[]
func _initialize() -> void:call_deferred("run")
func tick(count:int=1) -> void:
	for i in count:
		await physics_frame;await process_frame;await create_timer(0.0).timeout
func check(ok:bool,text:String) -> void:
	checks.append({"check":text,"passed":ok})
	if not ok:failures.append(text);push_error(text)
func box(parent:Node,location:Vector3,size:Vector3) -> StaticBody3D:
	var b:=StaticBody3D.new();var c:=CollisionShape3D.new();var s:=BoxShape3D.new()
	s.size=size;c.shape=s;b.add_child(c);parent.add_child(b);b.position=location;return b
func release() -> void:
	for action in ["move_right","move_left","move_forward","move_backward","sprint","jump"]:Input.action_release(action)
func run() -> void:
	var level:Node=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(level);current_scene=level;await tick(10)
	var p=level.player;var v=p.visual;var camera:Camera3D=level.get_node("Camera3D")
	p.get_node("WeaponBehavior").enabled=false;p.get_node("Pistol").enabled=false
	v.set_weapon_equipped(false);p.smooth_step_up_enabled=false
	var fixture:=Node3D.new();level.add_child(fixture);box(fixture,Vector3(0,29.5,0),Vector3(100,1,25))
	var platform:=box(fixture,Vector3(1.5,30.5,0),Vector3(3,1,6))
	for kind in ["walk","run"]:
		p.cancel_jump();p.position=Vector3(-2.3,30.02,0);p.velocity=Vector3.ZERO;await tick(120)
		Input.action_press("move_right")
		if kind=="run":Input.action_press("sprint")
		check(p.request_jump(),kind+" supported raised-block approach")
		var landed:=false;var maximum:=0.0;var previous:Quaternion=v.skeleton.get_bone_pose_rotation(v.leg_right)
		var camera_step:=0.0;var cy:=camera.position.y;var first_contact_time:=-1.0;var sole_error:=0.0
		for i in 100:
			await tick()
			var q:Quaternion=v.skeleton.get_bone_pose_rotation(v.leg_right)
			maximum=maxf(maximum,rad_to_deg(previous.angle_to(q)));previous=q
			camera_step=maxf(camera_step,absf(camera.position.y-cy));cy=camera.position.y
			if p.is_on_floor() and p.position.y>30.95:
				if not landed:first_contact_time=p._contact_pose_time
				landed=true;release()
				v.skeleton.force_update_all_bone_transforms()
				var low:=INF
				for leg in [v.leg_left,v.leg_right]:
					for x in [-.1125,.1125]:
						for z in [-.1125,.1125]:low=minf(low,(v.skeleton.global_transform*v.skeleton.get_bone_global_pose(leg)*Vector3(x,.675,z)).y)
				sole_error=maxf(sole_error,absf(low-p.position.y))
		check(landed and p.is_on_floor() and not p.jump_active,kind+" lands on 1m block without step assistance")
		check(first_contact_time>=0 and first_contact_time<p.jump_profile.contact,kind+" raised collision enters landing early")
		check(maximum<35.0,kind+" early landing has no large pose snap")
		check(sole_error<.015,kind+" final soles remain supported")
		check(camera_step<.22 and absf(camera.position.y-46)<.03,kind+" camera settles to raised ground without popping")
		measurements.append({"case":kind+" raised","max_leg_step_deg":maximum,"camera_max_step":camera_step,"source_contact_time":first_contact_time,"sole_error_m":sole_error})
		release()
	platform.free()
	p.cancel_jump();p.position=Vector3(-20,30.02,0);p.velocity=Vector3.ZERO;await tick(6)
	Input.action_press("move_right");Input.action_press("sprint");Input.action_press("jump")
	var wraps:=0;var supported:=true;var previous_time:=0.0;var max_step:=0.0
	var previous_q:Quaternion=v.skeleton.get_bone_pose_rotation(v.leg_right)
	var largest_step_event:Dictionary={}
	for i in 230:
		await tick()
		var q:Quaternion=v.skeleton.get_bone_pose_rotation(v.leg_right)
		var step:=rad_to_deg(previous_q.angle_to(q))
		if step>max_step:largest_step_event={"landed":p._landed,"landing_elapsed":v._landing_elapsed,"jump_blend":v.jump_blend,"pose_time":v.jump_time,"jump_time":p.jump_time}
		max_step=maxf(max_step,step);previous_q=q
		if p.jump_active and p.jump_time<previous_time-.2:wraps+=1;supported=supported and p.is_on_floor()
		previous_time=p.jump_time
	check(wraps>=2 and supported,"Held running repeats only after supported recovery")
	check(max_step<35.0,"Moving landing and repeated takeoff blend without large snap")
	release();await tick(100);check(not p.jump_active,"Release finishes last jump without another repeat")
	measurements.append({"case":"held run","wraps":wraps,"max_leg_step_deg":max_step,"largest_step_event":largest_step_event})
	# Ceiling and a long drop never replay takeoff or apply an airborne impulse.
	p.cancel_jump();p.position=Vector3(-15,30.02,0);p.velocity=Vector3.ZERO;await tick(5)
	var ceiling:=box(fixture,Vector3(-15,32.15,0),Vector3(4,.2,4))
	p.request_jump();var peak:float=p.position.y
	for i in 100:await tick();peak=maxf(peak,p.position.y)
	check(peak<30.4 and p.is_on_floor() and not p.jump_active,"Ceiling interrupts physics and completes landing")
	ceiling.free()
	var ledge:=box(fixture,Vector3(-5,39.5,0),Vector3(4,1,6))
	p.cancel_jump();p.position=Vector3(-4,40.02,0);p.velocity=Vector3.ZERO;await tick(5)
	Input.action_press("move_right");Input.action_press("sprint");p.request_jump()
	var held_air:=0;var valid_air:=true;peak=p.position.y
	for i in 180:
		await tick();peak=maxf(peak,p.position.y)
		if p.jump_active and not p.is_on_floor() and p.jump_time>p.jump_profile.contact+.1:
			held_air+=1;valid_air=valid_air and p._pose_time<p.jump_profile.contact and not p.request_jump()
		if p.is_on_floor() and p.position.y<31:release()
	check(held_air>5 and valid_air and peak<41.3,"Long drop holds aerial pose without air jump")
	check(p.is_on_floor() and not p.jump_active,"Long drop enters Land on actual floor")
	ledge.free();fixture.free();release();level.reset_player();await tick(8)
	# Original mapped riser, rather than only a temporary fixture.
	var route:Dictionary=load("res://tests/jump_v003_map_route.gd").find(level)
	check(not route.is_empty(),"Find original map 1m riser")
	if not route.is_empty():
		for kind in ["walk","run"]:
			p.cancel_jump();p.position=route.start;p.velocity=Vector3.ZERO;await tick(5)
			Input.action_press(route.action)
			if kind=="run":Input.action_press("sprint")
			p.request_jump();var landed:=false
			for i in 100:
				await tick()
				if p.is_on_floor() and absf(p.position.y-route.target.y)<.04:landed=true;release()
			check(landed and p.is_on_floor() and not p.jump_active,kind+" reaches original WorldMap 1m terrace")
			release()
	level.reset_player();await tick(8);p.request_jump();await tick(12)
	var anchor:float=level.get("_camera_ground_y")
	level.set_review_view("overview");var overview:Vector3=camera.position;await tick(2)
	check(camera.position==overview,"Overview remains fixed during a jump")
	level.set_review_view("gameplay");await tick()
	check(absf(camera.position.y-anchor-15)<.000001,"Returning to gameplay midair retains the ground anchor")
	level.reset_player();await tick();check(not p.jump_active,"Reset cancels active jump")
	for weapon in 3:
		p.equip_test_weapon(weapon);await tick(15);check(p.request_jump(),"Weapon %d jump starts"%weapon);await tick(24)
		check(v.socket.current_attachment==&"hand" and v.jump_arm_weight<.001,"Weapon %d keeps authored grip"%weapon)
		await tick(80)
	p.request_jump();await tick(15);p.is_dead=true;v.freeze_animation();await tick()
	check(not p.jump_active and v.frozen,"Death cancels jump without unfreezing")
	var tag:="runtime"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):tag=arg.trim_prefix("--report=")
	DirAccess.make_dir_recursive_absolute(OUT)
	FileAccess.open(OUT+"/edges_"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	print("V004_EDGES ",checks.size()," failures=",failures)
	level.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
