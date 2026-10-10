extends SceneTree
## Historical jump regression suite, now checks the active V003 controller with retained V002 stationary jump.
var failures: Array[String] = []
var checks: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok: failures.append(message); push_error(message)
func tick(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	var level = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(level); current_scene = level
	await tick(10)
	var player = level.player
	check(player.has_method("request_jump"), "Main WorldMap uses jump-enabled player")
	if player.has_method("request_jump"):
		check(InputMap.has_action("jump"), "Jump input is registered")
		var start: Vector3 = player.position
		Input.action_press("jump"); await tick(2); Input.action_release("jump")
		check(player.jump_active, "Space action starts supported jump")
		var peak: float = player.position.y
		check(not player.request_jump(), "No second jump during active jump")
		for i in 65:
			await tick(1); peak = maxf(peak, player.position.y)
			if i==10:check(not player.is_on_floor() and not player.request_jump(),"No second jump while airborne")
		check(absf(peak-start.y-1.2)<.03, "Stationary 1.2m apex within 3cm")
		check(player.is_on_floor() and not player.jump_active, "Jump lands and recovers")
		check(absf(player.position.y-start.y) < .04, "Flat landing returns to ground")
		Input.action_press("jump");await tick(65)
		check(not player.jump_active,"Holding Space does not auto-repeat jumps")
		Input.action_release("jump");await tick(2)
		check(player.visual.samples.has("Jump_Default_v001"), "Archived Default V001 pose retained")
		check(player.visual.skeleton.find_bone("ForeArm.R") >= 0, "Authored elbow motion supported")
		check(player.visual.combat_strafe_clips.size() == 6, "Six existing combat clips retained")
		var old_model: Node=load("res://assets/characters/jump_set_v002/player_r15_jump_set_v002.glb").instantiate()
		var old_player: AnimationPlayer=old_model.find_child("AnimationPlayer",true,false)
		var new_model: Node=load("res://assets/characters/jump_loop_v003/player_r15_jump_loop_v003.glb").instantiate()
		var new_player: AnimationPlayer=new_model.find_child("AnimationPlayer",true,false)
		var preserved:=true
		for name in old_player.get_animation_list():
			preserved=preserved and new_player.has_animation(name)
			if not preserved:break
			var a: Animation=old_player.get_animation(name)
			var b: Animation=new_player.get_animation(name)
			if a.length!=b.length or a.get_track_count()!=b.get_track_count(): print("CLIP_MISMATCH ",name," ",a.length,"/",b.length," tracks ",a.get_track_count(),"/",b.get_track_count())
			preserved=preserved and is_equal_approx(a.length,b.length) and a.get_track_count()==b.get_track_count()
			for track in a.get_track_count():
				preserved=preserved and a.track_get_path(track)==b.track_get_path(track) and a.track_get_key_count(track)==b.track_get_key_count(track)
				for key in a.track_get_key_count(track):
					preserved=preserved and a.track_get_key_time(track,key)==b.track_get_key_time(track,key) and a.track_get_key_value(track,key)==b.track_get_key_value(track,key)
		check(preserved,"Existing imported clip lengths/paths/key counts preserved")
		old_model.free();new_model.free()
		player.request_jump(); await tick(15); level.reset_player(); await tick(1)
		check(not player.jump_active and player.position.distance_to(start) < .05, "R cancels jump and resets")
		# All three held grips and a weapon switch during flight.
		player.get_node("WeaponBehavior").enabled=false
		for weapon in 3:
			level.reset_player();await tick(3);player.equip_test_weapon(weapon);await tick(12)
			check(player.request_jump(),"Supported jump with weapon %d"%weapon)
			await tick(22)
			check(player.visual.socket.current_attachment==&"hand" and player.visual.jump_arm_weight<.001,"Held grip retained for weapon %d"%weapon)
			await tick(35)
		level.reset_player();await tick(3);player.request_jump();await tick(15)
		player.equip_test_weapon(1);await tick(40)
		check(not player.jump_active and player.is_on_floor(),"Weapon switch during jump recovers")
		# Force the existing target-facing update, with no duplicate detection.
		var enemy:=Node3D.new();root.add_child(enemy);enemy.position=player.position+Vector3(0,0,3)
		player.request_jump();await tick(15)
		var twist_ok:=true
		for i in 12:
			player.visual.update_motion(Vector3(2,0,0),enemy,1.0/60.0)
			player.visual._evaluate(0.0)
			twist_ok=twist_ok and absf(player.visual.combat_torso_twist())<=deg_to_rad(20.0)
			await tick(1)
		check(twist_ok,"Combat torso remains within 20 degrees while jumping")
		enemy.free();level.reset_player();await tick(4)
		# Low ceiling is collision-owned, not an unconstrained preview trajectory.
		var ceiling:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
		box.size=Vector3(4,.2,4);shape.shape=box;ceiling.add_child(shape)
		level.add_child(ceiling);ceiling.position=start+Vector3(0,2.15,0);await tick(3)
		player.request_jump();var ceiling_peak:float=player.position.y
		for i in 60:
			await tick(1);ceiling_peak=maxf(ceiling_peak,player.position.y)
		check(ceiling_peak-start.y<.3 and player.is_on_floor() and not player.jump_active,"Ceiling collision interrupts flight and lands")
		ceiling.free();level.reset_player();await tick(4)
		player.request_jump();await tick(15);player.is_dead=true;player.visual.freeze_animation();await tick(1)
		check(player.is_dead and not player.jump_active and player.visual.frozen,"Death cancels jump without reviving animation")
	DirAccess.make_dir_recursive_absolute("res://.validation/jump_loop_v003")
	FileAccess.open("res://.validation/jump_loop_v003/regression_checks.json", FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("JUMP_REGRESSION_CHECKS ", checks.size(), " failures=", failures)
	level.queue_free(); await process_frame; await process_frame
	if "--orphans" in OS.get_cmdline_user_args(): Node.print_orphan_nodes()
	quit(0 if failures.is_empty() else 1)
