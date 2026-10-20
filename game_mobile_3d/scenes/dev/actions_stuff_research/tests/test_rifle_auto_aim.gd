extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok and not failures.has(message):failures.append(message);push_error(message)
func ticks(count: int) -> void:
	for i in count:await physics_frame
	await process_frame
func key(scene: Node,pressed: bool) -> void:
	var e:=InputEventKey.new();e.keycode=KEY_E;e.physical_keycode=KEY_E;e.pressed=pressed
	if pressed:scene._unhandled_input(e)
	else:scene._input(e)
func mouse(scene: Node,pressed: bool) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=pressed;scene._unhandled_input(e)
func freeze(z: CharacterBody3D,at: Vector3) -> void:
	z.target=null;z.move_speed=0.0;z.knockback_speed=0.0;z.position=at;z.velocity=Vector3.ZERO
func run() -> void:
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
	var aim=scene.get("rifle_auto_aim")
	check(aim!=null,"Nearest-zombie auto-aim exists in the SAME scene")
	if aim==null:scene.free();quit(1);return
	var a=scene.player;var v=a.visual;a.scripted_input=true
	var group=scene.zombie_combat;var z0=group.zombies[0];var z1=group.zombies[1];var z2=group.zombies[2];var z3=group.zombies[3]
	freeze(z0,Vector3(3,0,0));freeze(z1,Vector3(0,0,-5));freeze(z2,Vector3(-8,0,0));freeze(z3,Vector3(0,0,20))
	await ticks(4)
	check(aim.target==null,"Ready does not rotate toward zombies without Aim input")
	mouse(scene,true);await ticks(60)
	check(aim.target==z0,"RMB aims at the nearest living zombie even beside/behind current facing")
	var barrel: Transform3D=v.skeleton.global_transform*v.skeleton.get_bone_global_pose(v.carrier_bone)
	var toward: Vector3=(z0.global_position+Vector3(0,1.02,0)-v.socket.muzzle_position()).normalized()
	check(barrel.basis.y.normalized().dot(toward)>.999,"Actual gun barrel visibly points at nearest target, not redirected invisible bullets")
	var camera_before: Vector3=scene.camera_anchor
	z0.take_damage(999,Vector3.RIGHT);await ticks(2)
	check(aim.target==z1,"A dead but visible ragdoll is immediately skipped")
	var wall:=StaticBody3D.new();wall.position=Vector3(0,1,-2.5)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2,3,.3);shape.shape=box;wall.add_child(shape);scene.add_child(wall)
	await ticks(3)
	check(aim.target==z2,"Blocked nearest zombie is skipped for nearest unobstructed target")
	wall.free();mouse(scene,false);await ticks(2)
	check(aim.target==null,"Releasing Aim clears target")
	a.requested_direction=Vector2(1,0);await ticks(35);a.requested_direction=Vector2.ZERO
	check(absf(wrapf(v.look_yaw-PI*.5,-PI,PI))<.08,"Normal WASD facing resumes outside Aim")
	scene.reset_player();await ticks(3)
	for i in group.zombies.size():
		freeze(group.zombies[i],[Vector3(3,0,0),Vector3(0,0,-5),Vector3(-8,0,0),Vector3(0,0,20)][i])
	key(scene,true)
	var saw_target_switch:=false;var previous: Node3D
	for i in 480:
		await ticks(1)
		if is_instance_valid(aim.target) and is_instance_valid(previous) and aim.target!=previous:saw_target_switch=true
		if is_instance_valid(aim.target):previous=aim.target
		if group.living_count()==1:break
	check(group.living_count()==1,"Held E auto-turns and kills all three in-range zombies with actual projectiles")
	check(aim.target==null,"Last living zombie outside rifle range is not auto-targeted")
	check(scene.rifle_fire.pool_misses==0,"Auto-aim preserves bounded projectile pools")
	key(scene,false);scene.reset_player();await ticks(3)
	check(aim.target==null,"Reset leaves no stale target")
	for i in group.zombies.size():freeze(group.zombies[i],Vector3(3,0,-4) if i==0 else Vector3(25+i*3,0,20))
	group.zombies[0].current_hp=10000;group.zombies[0].max_hp=10000
	key(scene,true)
	var grip_error:=0.0;var support_error:=0.0;var saw_air:=false;var saw_run:=false;var camera_span:=0.0
	var start_y: float=scene.camera_anchor.y
	for i in 180:
		a.requested_direction=Vector2(sin(i*.05),cos(i*.05));a.requested_run=i>45;a.requested_jump=i==85
		await ticks(1)
		saw_air=saw_air or not v.jump_grounded;saw_run=saw_run or a.current_speed>7.5
		var right: Transform3D=v.skeleton.get_bone_global_pose(v.arm_right)
		var carrier: Transform3D=v.skeleton.get_bone_global_pose(v.carrier_bone)
		grip_error=maxf(grip_error,(right*v.rifle_carrier_attachment).origin.distance_to(carrier.origin))
		var palm: Vector3=Vector3(v.rifle_profile.palm_forearm_local[0],v.rifle_profile.palm_forearm_local[1],v.rifle_profile.palm_forearm_local[2])
		support_error=maxf(support_error,(v.skeleton.get_bone_global_pose(v.forearm_left)*palm).distance_to(carrier*v.rifle_support_anchor))
		camera_span=maxf(camera_span,absf(scene.camera_anchor.y-start_y))
	check(saw_air and saw_run,"Auto-aim retains responsive running and jumping")
	check(grip_error<.00005 and support_error<.00005,"Auto-aim rotates the intact hold without hand sliding")
	check(camera_span<.03,"Auto-aim adds no jump/camera bob")
	key(scene,false);await ticks(20)
	check(aim.target==null and v.auto_aim_target==null,"Release clears both target references")
	var report:={"passed":failures.is_empty(),"failures":failures,"grip_error_m":grip_error,"support_error_m":support_error,"camera_y_span_m":camera_span,"shots":scene.rifle_fire.shots_fired,"scan_count":aim.scan_count}
	print("RIFLE_AUTO_AIM ",JSON.stringify(report))
	var dest:=OS.get_environment("RIFLE_AUTO_AIM_RESULTS")
	if not dest.is_empty():FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	scene.free();quit(0 if failures.is_empty() else 1)
