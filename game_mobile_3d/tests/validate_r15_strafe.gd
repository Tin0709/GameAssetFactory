extends SceneTree
var failures: Array[String]=[]
var checks:=0
var level: Node3D
var player: CharacterBody3D
var v: Node3D
var enemy: Node3D
var max_twist:=0.0
var max_import_position_error:=0.0
var min_import_rotation_dot:=1.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		if failures.size()<12:push_error(message)
func move(action: String="", sprint: bool=false) -> void:
	for key in ["move_left","move_right","move_forward","move_backward","sprint"]:Input.action_release(key)
	if action!="":Input.action_press(action)
	if sprint:Input.action_press("sprint")
func ticks(count: int, targeted: bool=true) -> void:
	for i in count:
		if player.position.length()>5:player.position=Vector3(0,0.02,1.8)
		enemy.global_position=player.global_position+Vector3(0,0,-3 if targeted else -40)
		await physics_frame
		await process_frame
		if v.combat_facing_active:
			var twist: float=absf(v.combat_torso_twist())
			max_twist=maxf(max_twist,rad_to_deg(twist))
			check(twist<=deg_to_rad(20.0)+0.0001,"Torso twist must stay within 20 degrees")
			if v.combat_strafe_weight>.001:
				check(absf(v._combat_bone_yaw(v.chest))<deg_to_rad(12.0),"Strafe entry/exit must not leave old hip compensation in upper aim")
func run() -> void:
	level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	player=level.player;v=player.visual
	check(v.has_method("combat_torso_twist"),"Real gameplay is missing R15 combat strafe integration")
	if not failures.is_empty():quit(1);return
	level.toggle_animation_test_enemy();enemy=level.animation_test_enemy
	var behavior: Node=player.get_node("WeaponBehavior")
	var gun: Node=player.get_node("Pistol")
	var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/r15/source.json"))
	var previous:=preload("res://assets/characters/r13/player_r13.glb").instantiate()
	var previous_player:=previous.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var imported_model:=preload("res://assets/characters/r15/player_r15_combat_strafe_v1.glb").instantiate()
	var imported_player:=imported_model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	for name in previous_player.get_animation_list():
		var a:=previous_player.get_animation(name)
		var c: Animation=imported_player.get_animation(name)
		check(c!=null and a.length==c.length and a.loop_mode==c.loop_mode and a.get_track_count()==c.get_track_count(),"Previous imported gameplay clip layout preserved")
		for track in a.get_track_count():
			check(a.track_get_type(track)==c.track_get_type(track) and a.track_get_path(track)==c.track_get_path(track) and a.track_get_key_count(track)==c.track_get_key_count(track),"Previous imported gameplay track preserved")
			for key in a.track_get_key_count(track):
				check(a.track_get_key_time(track,key)==c.track_get_key_time(track,key) and a.track_get_key_value(track,key)==c.track_get_key_value(track,key),"Previous imported gameplay keys preserved exactly")
	previous.free();imported_model.free()
	for name in ["Combat_StrafeLeft_V1","Combat_StrafeRight_V1"]:
		check(v.animation_player.has_animation(name),"GLB missing "+name)
		var clip: Animation=v.animation_player.get_animation(name)
		check(is_equal_approx(clip.length,20.0/24.0),"Native strafe duration must remain 0.833333 s")
		var sampler: RefCounted=v.combat_strafe_clips[name]
		print("Import ",name," tracks ",clip.get_track_count()," first track keys ",clip.track_get_key_count(0))
		for index in native.clips[name].samples.size():
			for bone_name: String in native.clips[name].samples[index]:
				var bone: int=v.skeleton.find_bone(bone_name)
				var sample: Dictionary=native.clips[name].samples[index][bone_name]
				var time: float=index/192.0
				if sample.has("p"):
					var error: float=sampler.position(bone,time).distance_to(Vector3(sample.p[0],sample.p[1],sample.p[2]))
					max_import_position_error=maxf(max_import_position_error,error)
					check(error<.00002,"Godot import position must match native Blender sample")
				var dot: float=absf(sampler.rotation(bone,time).dot(Quaternion(sample.q[0],sample.q[1],sample.q[2],sample.q[3])))
				min_import_rotation_dot=minf(min_import_rotation_dot,dot)
				check(dot>.999999,"Godot import rotation must match native Blender sample")
	for weapon in 3:
		move();player.equip_test_weapon(weapon);gun.cooldown=100000;await ticks(90)
		check(behavior.is_ready(),"All three weapons become READY")
		for action in ["move_right","move_left"]:
			move(action);await ticks(45)
			check(v.combat_strafe_direction==(1 if action=="move_right" else -1),"Correct CHARACTER-relative authored Left/Right")
			check(v.combat_strafe_weight>.99,"Authored combat strafe fully engaged")
			check((v.global_basis*Vector3.BACK).dot((enemy.global_position-player.global_position).normalized())>.99,"Facing stays on enemy during sideways movement")
			var chest_forward: Vector3=v.global_basis*v.skeleton.get_bone_global_pose(v.chest).basis*v.skeleton.get_bone_global_rest(v.chest).basis.inverse()*Vector3.BACK
			check(chest_forward.normalized().dot((enemy.global_position-player.global_position).normalized())>.98,"Upper torso/weapon heading stays on enemy")
			var active: RefCounted=v.combat_strafe_clips[v.STRAFE_RIGHT if action=="move_right" else v.STRAFE_LEFT]
			for bone in [v.hips,v.leg_left,v.leg_right]:
				var t: float=v.combat_strafe_phase*active.clip.length
				check(v.skeleton.get_bone_pose_position(bone).distance_to(active.position(bone,t))<.00002,"Visible lower pose uses authored clip")
				check(absf(v.skeleton.get_bone_pose_rotation(bone).dot(active.rotation(bone,t)))>.999999,"Visible lower rotation uses authored clip")
			check(is_equal_approx(player.current_speed,player.combat_move_speed),"Combat movement speed preserved")
			check(v.socket.current_attachment==&"hand","Ready hand ownership preserved")
			check(gun.can_fire(),"Firing remains allowed while strafing")
			var scans: int=gun.target_scan_count
			gun.nearest_target();gun.nearest_target()
			check(gun.target_scan_count<=scans+1,"Target cache reused without duplicate detection")
			await ticks(65)
		move();await ticks(30)
		check(v.combat_strafe_weight<.001,"Stopping returns smoothly to Idle")
		move("move_forward");await ticks(30)
		check(v.combat_strafe_weight<.001,"Forward combat movement uses existing Walk")
		move("move_right",true);await ticks(60)
		check(v.combat_strafe_weight<.001 and not v.combat_facing_active,"Sprint excludes strafe/target-facing")
		check(behavior.state==behavior.State.STOWED,"Sprint still stows weapon")
		move("move_right");await ticks(90,false)
		check(v.combat_strafe_weight<.001,"No target returns to normal movement")
		check((v.global_basis*Vector3.BACK).dot(Vector3.RIGHT)>.99,"Normal movement faces travel direction")
	# Oblique directions, target swaps and recoil must remain under the torso limit.
	move();await ticks(60);gun.cooldown=0
	for direction in [Vector3(3,0,-1),Vector3(-3,0,1),Vector3(0,0,3)]:
		move("move_right")
		for i in 40:
			enemy.global_position=player.global_position+direction
			await physics_frame;await process_frame
			if v.combat_facing_active:
				var twist: float=absf(v.combat_torso_twist())
				max_twist=maxf(max_twist,rad_to_deg(twist))
				check(twist<=deg_to_rad(20)+.0001,"Recoil/target changes respect 20 degree limit")
	move()
	check(AudioServer.is_bus_mute(0),"Silent gameplay preserved")
	DirAccess.make_dir_recursive_absolute("res://.validation/r15")
	var report:={"checks":checks,"failures":failures,"max_torso_twist_deg":max_twist,"max_import_position_error_m":max_import_position_error,"min_import_rotation_dot":min_import_rotation_dot}
	FileAccess.open("res://.validation/r15/runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("R15: ",checks," checks, ",failures.size()," failures; maximum torso twist ",max_twist," degrees; import error ",max_import_position_error," m / q dot ",min_import_rotation_dot)
	quit(0 if failures.is_empty() else 1)
