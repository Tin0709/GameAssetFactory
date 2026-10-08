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
var max_lower_position_step:=0.0
var max_lower_rotation_step:=0.0
var previous_lower: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		if failures.size()<15: push_error(message)
func move(actions: Array=[], sprint: bool=false) -> void:
	for a in ["move_left","move_right","move_forward","move_backward","sprint"]: Input.action_release(a)
	for a in actions: Input.action_press("move_"+a)
	if sprint: Input.action_press("sprint")
func ticks(n: int, near: bool=true) -> void:
	for i in n:
		if is_instance_valid(enemy):enemy.global_position=player.global_position+Vector3(0,0,-3 if near else -40)
		await physics_frame; await process_frame
		observe_pose()
func observe_pose() -> void:
	if v.combat_facing_active:
		var twist: float=absf(rad_to_deg(v.combat_torso_twist()))
		max_twist=maxf(max_twist,twist)
		check(twist<20.01,"Combat twist below 20 degrees")
		for bone in [v.hips,v.leg_left,v.leg_right]:
			var pose:=Transform3D(Basis(v.skeleton.get_bone_pose_rotation(bone)),v.skeleton.get_bone_pose_position(bone))
			if previous_lower.has(bone):
				var old: Transform3D=previous_lower[bone]
				var distance:=pose.origin.distance_to(old.origin)
				var angle:=rad_to_deg(pose.basis.get_rotation_quaternion().angle_to(old.basis.get_rotation_quaternion()))
				max_lower_position_step=maxf(max_lower_position_step,distance)
				max_lower_rotation_step=maxf(max_lower_rotation_step,angle)
				check(distance<.24 and angle<45,"Smooth lower pose step through direction transitions")
			previous_lower[bone]=pose
	else:previous_lower.clear()
func run() -> void:
	level=preload("res://scenes/Grassland.tscn").instantiate()
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	player=level.player;v=player.visual;level.toggle_animation_test_enemy();enemy=level.animation_test_enemy
	var keyboard:=InputEventKey.new();keyboard.physical_keycode=KEY_3;keyboard.pressed=true
	root.push_input(keyboard)
	check(v.weapon_type==2,"Existing keyboard adapter selects shotgun in actual main")
	keyboard.physical_keycode=KEY_2;root.push_input(keyboard)
	check(v.weapon_type==1,"Existing keyboard adapter selects rifle in actual main")
	for name in ["Combat_StrafeLeft_V2","Combat_StrafeRight_V2","Combat_StrafeForwardLeft_V1","Combat_StrafeForwardRight_V1","Combat_StrafeBackwardLeft_V1","Combat_StrafeBackwardRight_V1"]:
		check(v.combat_strafe_clips.has(name),"Missing approved six-direction clip "+name)
	if not failures.is_empty(): quit(1);return
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
	for name in v.COMBAT_CLIPS:
		check(v.animation_player.has_animation(name),"GLB missing "+name)
		var clip: Animation=v.animation_player.get_animation(name)
		check(is_equal_approx(clip.length,16.0/48.0),"Native strafe duration must remain 0.333333 s")
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

	var behavior: Node=player.get_node("WeaponBehavior")
	var gun: Node=player.get_node("Pistol")
	var sequences: Array=[[["forward"],&"Forward"],[["forward","right"],&"Combat_StrafeForwardRight_V1"],[["right"],v.STRAFE_RIGHT],[["backward","right"],&"Combat_StrafeBackwardRight_V1"],[["backward"],&"Backward"],[["backward","left"],&"Combat_StrafeBackwardLeft_V1"],[["left"],v.STRAFE_LEFT],[["forward","left"],&"Combat_StrafeForwardLeft_V1"]]
	for weapon in 3:
		move();player.equip_test_weapon(weapon);gun.cooldown=100000;await ticks(75)
		check(behavior.is_ready(),"Weapon reaches READY after native Draw")
		check(v.socket.instances.size()==3,"Only original three weapon instances exist")
		for entry in sequences:
			var phase: float=v.combat_strafe_phase
			var reference: float=v.reference_phase
			var legacy: float=v.locomotion_phase
			var upper: float=v.r13_idle_time
			move(entry[0]);await ticks(1)
			check(absf(wrapf(v.combat_strafe_phase-phase,-.5,.5))<.12,"Directional handoff never resets phase")
			await ticks(38)
			check(v.combat_direction==entry[1],"Correct aim-relative direction "+String(entry[1]))
			check(v.combat_strafe_weight>.99,"Combat movement fully engages lower blend")
			check(v.combat_direction_weights[entry[1]]>.98,"Exact cardinal/diagonal resolves to intended native gait")
			check(not is_equal_approx(v.reference_phase,reference) and not is_equal_approx(v.locomotion_phase,legacy),"Existing locomotion clocks keep advancing")
			check(not is_equal_approx(v.r13_idle_time,upper),"Living upper clock keeps advancing")
			check((v.global_basis*Vector3.BACK).dot((enemy.global_position-player.global_position).normalized())>.99,"Facing remains on enemy")
			var chest_forward: Vector3=v.global_basis*v.skeleton.get_bone_global_pose(v.chest).basis*v.skeleton.get_bone_global_rest(v.chest).basis.inverse()*Vector3.BACK
			check(chest_forward.normalized().dot((enemy.global_position-player.global_position).normalized())>.98,"Upper aim remains on target")
			check(is_equal_approx(player.current_speed,player.combat_move_speed),"Combat speed preserved")
			check(v.socket.current_attachment==&"hand" and gun.can_fire(),"READY weapon stays in hand and permits fire")
			var visible:=0
			for instance in v.socket.instances: if instance.is_visible_in_tree():visible+=1
			check(visible==1,"Exactly one weapon visible")
		move();await ticks(25)
		check(v.combat_strafe_weight<.001,"Idle smoothly removes combat gait")
		move(["right"],true);await ticks(45)
		check(not v.combat_facing_active and v.combat_strafe_weight<.001,"Sprint excludes combat blend")
		check(behavior.state==behavior.State.STOWED,"Sprint stows weapon")
		check(v.socket.current_attachment in [&"back",&"hip"],"Sprint uses approved stow socket")
		move(["right"]);await ticks(75)
		check(behavior.is_ready() and v.socket.current_attachment==&"hand","Sprint release restores native Draw to hand")
		move(["right"]);await ticks(150,false)
		check(v.combat_strafe_weight<.001 and not v.combat_facing_active,"No target restores peaceful locomotion")
		check(behavior.state==behavior.State.STOWED,"Target loss completes native Holster")
		check((v.global_basis*Vector3.BACK).dot(Vector3.RIGHT)>.99,"Peaceful movement faces travel")
	# Abrupt opposite diagonals and changing target headings, including firing.
	move();await ticks(75);gun.cooldown=0
	for actions in [["forward","right"],["backward","left"],["forward","left"],["backward","right"]]:
		move(actions)
		for i in 35:
			enemy.global_position=player.global_position+Vector3(3*cos(i*.04),0,3*sin(i*.04))
			var phase_before: float=v.combat_strafe_phase
			await physics_frame;await process_frame
			observe_pose()
			check(absf(wrapf(v.combat_strafe_phase-phase_before,-.5,.5))<.055,"Opposite diagonal and target swaps retain continuous phase")
			check(absf(rad_to_deg(v.combat_torso_twist()))<20.01,"Reversal/recoil/heading swap bounded torso twist")
	move();await ticks(20)
	keyboard.physical_keycode=KEY_F7;root.push_input(keyboard);await ticks(1,false)
	check(not level.combat.combat_enabled and level.animation_test_enemy==null,"F7 restores peaceful review state")
	check(AudioServer.is_bus_mute(0),"Silent gameplay preserved")
	DirAccess.make_dir_recursive_absolute("res://.validation/r15")
	FileAccess.open("res://.validation/r15/six_runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"max_torso_twist_deg":max_twist,"max_import_position_error_m":max_import_position_error,"min_import_rotation_dot":min_import_rotation_dot,"max_lower_position_step_m":max_lower_position_step,"max_lower_rotation_step_deg":max_lower_rotation_step},"\t"))
	print("R15 SIX: ",checks," checks / ",failures.size()," failures; twist ",max_twist," deg; import error ",max_import_position_error)
	quit(0 if failures.is_empty() else 1)
