extends SceneTree
## Active WorldMap, real composed pose, collisions and camera; no mocked controller.
const ACTION := "Jump_DungeonsII_Combined_v004"
const OUT := "res://.validation/jump_gif_v004"
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
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var level:Node=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(level);current_scene=level
	await tick(10)
	var p=level.player;var v=p.visual;var camera:Camera3D=level.get_node("Camera3D")
	p.get_node("WeaponBehavior").enabled=false;p.get_node("Pistol").enabled=false
	v.set_weapon_equipped(false);p.smooth_step_up_enabled=false
	check(v.samples.has(ACTION),"F5 WorldMap loads V004")
	var fixture:=Node3D.new();level.add_child(fixture)
	box(fixture,Vector3(0,29.5,0),Vector3(80,1,30))
	for kind in ["stationary","walk","run"]:
		p.cancel_jump();p.position=Vector3(-15,30.02,0);p.velocity=Vector3.ZERO;await tick(120)
		if kind!="stationary":Input.action_press("move_right")
		if kind=="run":Input.action_press("sprint")
		if kind!="stationary":await tick(20)
		check(p.request_jump(),kind+" begins from support")
		check(p.jump_profile.action==ACTION,kind+" selects combined V004")
		var start:Vector3=p.position;var peak:=start.y;var cy:=camera.position.y
		var camera_drift:=0.0;var horizontal_error:=0.0;var elbow_bend:=0.0;var pose_error:=0.0;var sampled:=0
		var landing_stride:=0.0
		var anticipation_error:=0.0;var anticipation_samples:=0
		for i in 95:
			await tick();peak=maxf(peak,p.position.y)
			if kind!="stationary" and p.jump_active and not p._airborne:
				# Compare the composed pose against the same live gait and phase.
				var actual:Array[Quaternion]=[v.skeleton.get_bone_pose_rotation(v.leg_left),v.skeleton.get_bone_pose_rotation(v.leg_right)]
				var saved_blend:float=v.jump_blend;v.jump_blend=0.0;v._evaluate(0.0)
				for j in 2:
					var bone:int=v.leg_left if j==0 else v.leg_right
					anticipation_error=maxf(anticipation_error,rad_to_deg(actual[j].angle_to(v.skeleton.get_bone_pose_rotation(bone))))
				v.jump_blend=saved_blend;v._evaluate(0.0);anticipation_samples+=1
			if p.jump_active and p._landed and p._recovery_elapsed>.1:
				landing_stride=maxf(landing_stride,rad_to_deg(v.skeleton.get_bone_pose_rotation(v.leg_left).angle_to(v.skeleton.get_bone_pose_rotation(v.leg_right))))
			if p.jump_active and not p.is_on_floor():
				camera_drift=maxf(camera_drift,absf(camera.position.y-cy))
				horizontal_error=maxf(horizontal_error,Vector2(camera.position.x-p.position.x-12,camera.position.z-p.position.z-16).length())
			if p.jump_active and v.jump_blend>.999 and v.jump_arm_weight>.999:
				for side in ["L","R"]:
					elbow_bend=maxf(elbow_bend,rad_to_deg(v.skeleton.get_bone_pose_rotation(v.skeleton.find_bone("ForeArm."+side)).get_angle()))
				if v.samples.has(ACTION) and not p._landed and (kind=="stationary" or (p._airborne and p.jump_time>.4)):
					for bone in [v.leg_left,v.leg_right]:
						pose_error=maxf(pose_error,rad_to_deg(v.skeleton.get_bone_pose_rotation(bone).angle_to(v.samples[ACTION].rotation(bone,v.jump_time))))
					sampled+=1
			if i==22 and DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUT+"/"+kind+"_apex.png")
		check(absf(peak-start.y-1.2)<.03,kind+" retains 1.2m physics apex")
		check(camera_drift<.000001,kind+" camera holds vertical jump anchor")
		check(horizontal_error<.001,kind+" camera still follows X/Z")
		check(elbow_bend<.02,kind+" unarmed elbows stay straight")
		check(sampled>8 and pose_error<.05,kind+" uses authored V004 legs at full weight")
		check(p.is_on_floor() and not p.jump_active,kind+" lands and recovers")
		if kind!="stationary":
			check(landing_stride>15.0,kind+" resumes alternating steps during landing recovery")
			check(anticipation_samples>=2 and anticipation_error<.05,kind+" preserves live stride until feet leave ground")
		measurements.append({"case":kind,"apex":peak-start.y,"camera_y_drift":camera_drift,"horizontal_follow_error":horizontal_error,"elbow_bend_deg":elbow_bend,"leg_pose_error_deg":pose_error,"landing_stride_deg":landing_stride,"anticipation_error_deg":anticipation_error,"anticipation_samples":anticipation_samples})
		Input.action_release("move_right");Input.action_release("sprint")
	fixture.queue_free();level.reset_player()
	check(absf(level.get("_camera_ground_y")-level.spawn_position.y)<.000001,"Reset clears camera anchor immediately")
	await tick(5)
	check(absf(camera.position.y-level.spawn_position.y-15)<.03,"Reset camera remains at the new supported location")
	var tag:="runtime"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):tag=arg.trim_prefix("--report=")
	FileAccess.open(OUT+"/checks_"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	print("V004_CHECKS ",checks.size()," failures=",failures)
	level.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
