extends SceneTree
## Real controller/weapon integration cases authored before runtime implementation.
var level
var p
var v
var b
var gun
var enemy
var near:=false
var checks:=0
var failures:Array[String]=[]
var events:Array[Dictionary]=[]
var clock_error:=0.0
var peak_grip_error:=0.0
var peak_grip_rotation_error:=0.0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,text:String) -> void:
	checks+=1
	if not ok:failures.append(text);push_error(text)
func release() -> void:
	for action in ["move_left","move_right","move_forward","move_backward","sprint"]:Input.action_release(action)
func advance(frames:int) -> void:
	for i in frames:
		# Existing clear lane; reset only position to keep this test out of terrain obstacles.
		if i%6==0 and not Input.get_vector("move_left","move_right","move_forward","move_backward").is_zero_approx():p.position=Vector3(0,0.02,-3)
		enemy.global_position=p.global_position+Vector3(0,0,3 if near else 40)
		var before:float=v.reference_phase
		var moving:bool=v.movement_speed>=v.LOCOMOTION_DEAD_ZONE
		await physics_frame
		var delta_phase:float=wrapf(v.reference_phase-before,-0.5,0.5)
		check(absf(delta_phase)<0.05,"No phase reset during real gameplay state changes")
func record(label:String) -> void:
	events.append({"case":label,"weapon":v.weapon_type,"state":b.State.keys()[b.state],"attachment":str(v.socket.current_attachment),"phase":v.reference_phase,"sprint_blend":v.reference_sprint_weight,"turn":v.reference_turn_amount})
func finish() -> void:
	var result:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":events,"peak_armed_pose_local_error":peak_grip_error,"peak_world_grip_rotation_error_degrees":peak_grip_rotation_error}
	DirAccess.make_dir_recursive_absolute("res://.validation/locomotion_r6p")
	FileAccess.open("res://.validation/locomotion_r6p/live_validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func run() -> void:
	level=load("res://scenes/CuboidGameplayTest.tscn").instantiate();level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(1);p=level.player;v=p.visual;b=p.get_node("WeaponBehavior");gun=p.get_node("Pistol")
	check("reference_phase" in v,"Real gameplay uses reference integration")
	if not failures.is_empty():finish();return
	enemy=load("res://scenes/characters/CuboidZombie.tscn").instantiate();enemy.max_hp=1000000;level.get_node("Actors").add_child(enemy);enemy.current_hp=1000000;enemy.set_physics_process(false);level.combat.register_zombie(enemy)
	gun.cooldown=1000000
	var ids:Array[int]=[]
	for instance in v.socket.instances:ids.append(instance.get_instance_id())
	for weapon in [1,2]:
		release();near=false;await advance(155);p.equip_test_weapon(weapon);gun.cooldown=1000000;await advance(12)
		check(b.state==b.State.STOWED,"Safe long gun stowed")
		Input.action_press("move_right");await advance(24)
		check(absf(p.current_speed-4.25)<0.01 and v.reference_sprint_weight<0.001,"Normal speed remains 4.25 Walk")
		near=true;await advance(2);check(b.state==b.State.DRAWING and v.draw_active,"Walk naturally requests authored Draw")
		record("Walk -> Draw")
		await advance(60);check(b.is_ready() and v.socket.current_attachment==&"hand","Real Draw reaches READY with one hand owner")
		for actions in [["move_forward"],["move_left","move_forward"],["move_left"],["move_left","move_backward"],["move_backward"],["move_right","move_backward"],["move_right"],["move_right","move_forward"]]:
			release()
			for action:String in actions:Input.action_press(action)
			await advance(18)
			check(b.is_ready() and not p.fast_sprinting and v.reference_sprint_weight<0.001,"READY curve/circle steps keep Walk")
			check(p.current_speed<=2.601,"Combat Walk speed unchanged")
			check(v.ready_run_blend_weight()==0,"New Walk never receives old Run correction")
			for bone in [v.main_arm,v.support_arm,v.socket_bone]:
				peak_grip_error=maxf(peak_grip_error,v.skeleton.get_bone_pose_position(bone).distance_to(v.long_gun_hold_pose.position(bone,0)))
				var actual:Quaternion=v.skeleton.get_bone_pose_rotation(bone)
				var authored:Quaternion=v.long_gun_hold_pose.rotation(bone,0)
				check(absf(actual.dot(authored))>0.999999,"READY arm/socket rotations retain authored Hold")
			# The two arms and socket share Chest; compare complete world-relative
			# contact frames so Chest bank cannot detach or twist the authored grip.
			var held_socket:=Transform3D(Basis(v.long_gun_hold_pose.rotation(v.socket_bone,0)),v.long_gun_hold_pose.position(v.socket_bone,0))
			for arm in [v.main_arm,v.support_arm]:
				check(v.skeleton.get_bone_parent(arm)==v.chest,"Held arm shares the weapon's Chest parent")
				var held_arm:=Transform3D(Basis(v.long_gun_hold_pose.rotation(arm,0)),v.long_gun_hold_pose.position(arm,0))
				var expected:Transform3D=held_socket.affine_inverse()*held_arm
				var actual:Transform3D=v.skeleton.get_bone_global_pose(v.socket_bone).affine_inverse()*v.skeleton.get_bone_global_pose(arm)
				peak_grip_error=maxf(peak_grip_error,expected.origin.distance_to(actual.origin))
				peak_grip_rotation_error=maxf(peak_grip_rotation_error,rad_to_deg(expected.basis.get_rotation_quaternion().angle_to(actual.basis.get_rotation_quaternion())))
				check(expected.is_equal_approx(actual),"READY world-relative arm/weapon contact frames preserve Hold")
			record("READY bend/circle")
		Input.action_press("sprint");await advance(2)
		check(p.fast_sprinting and b.state==b.State.HOLSTERING and v.holster_active and not gun.can_fire(),"Sprint priority Holsters READY and gates firing")
		record("READY turn -> Sprint Holster")
		await advance(65)
		check(b.state==b.State.STOWED and v.socket.current_attachment==&"back" and v.reference_sprint_weight>0.999,"Sprint reaches STOWED with reference Sprint")
		check(absf(p.current_speed-6.25)<0.01,"Sprint speed stays 6.25 despite threat")
		for actions in [["move_forward"],["move_left"],["move_backward"],["move_right"]]:
			release();Input.action_press("sprint")
			for action:String in actions:Input.action_press(action)
			await advance(22)
			check(b.state==b.State.STOWED and not gun.can_fire(),"Sprint bends/reversals stay stowed with no firing")
		Input.action_release("sprint");await advance(2)
		check(b.state==b.State.DRAWING and v.draw_active,"Sprint release threat requests real Draw")
		record("Sprint release -> Draw while turning")
		await advance(60)
		check(b.is_ready() and v.reference_sprint_weight<0.001,"Draw finishes over new Walk")
		gun.cooldown=0;var shots:int=gun.shot_count;await advance(15)
		check(gun.shot_count>shots,"Real firing resumes only after READY")
		gun.cooldown=1000000;near=false;await advance(140)
		check(b.state==b.State.STOWED,"No-threat Walk Holster finishes")
		for i in ids.size():check(v.socket.instances[i].get_instance_id()==ids[i],"No duplicate weapon instances")
	check(peak_grip_error<0.0001,"READY arm/socket local contacts retain authored Hold")
	release();await advance(24);check(v.move_weight==0 and not p.fast_sprinting,"Idle settles with unchanged stop behavior")
	finish()
