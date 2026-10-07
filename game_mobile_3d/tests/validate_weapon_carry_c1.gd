extends SceneTree
const LEVEL=preload("res://scenes/CuboidGameplayTest.tscn")
const ZOMBIE=preload("res://scenes/characters/CuboidZombie.tscn")
var level: Node3D
var player: CharacterBody3D
var v: Node3D
var failures: Array[String]=[]
var checks:=0
var metrics: Dictionary={}
var rendered:=false
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func tick(n: int) -> void:
	for i in n:await physics_frame
func capture(label: String) -> void:
	if not rendered:return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/carry_c1_%s.png"%label)
	if label.ends_with("idle") or label.ends_with("run"):
		var camera: Camera3D=level.get_node("Camera3D")
		var old_size:=camera.size;camera.size=4.5
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/carry_c1_%s_close.png"%label)
		camera.size=old_size
func release() -> void:
	for a in ["move_left","move_right","move_forward","move_backward","sprint"]:Input.action_release(a)
func unchanged_lower() -> void:
	v.set_process(false)
	var original: float=v.weapon_hold_weight
	v.weapon_hold_weight=0.0;v._evaluate(0.0)
	var poses: Dictionary={}
	for name in ["Root","Hips","Leg.L","Leg.R","Spine","Chest","Neck","Head"]:
		var bone: int=v.skeleton.find_bone(name)
		poses[bone]=[v.skeleton.get_bone_pose_position(bone),v.skeleton.get_bone_pose_rotation(bone)]
	v.weapon_hold_weight=1.0;v._evaluate(0.0)
	for bone in poses:
		check(v.skeleton.get_bone_pose_position(bone).is_equal_approx(poses[bone][0]) and absf(v.skeleton.get_bone_pose_rotation(bone).dot(poses[bone][1]))>0.999999,"Hold filter preserves %s"%v.skeleton.get_bone_name(bone))
	v.weapon_hold_weight=original;v._evaluate(0.0);v.set_process(true)
func run() -> void:
	rendered="--capture" in OS.get_cmdline_user_args()
	level=LEVEL.instantiate();level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level)
	level.player.get_node("WeaponBehavior").enabled=false # Historical pose/gameplay baseline, without D0 behavior.
	current_scene=level;level.select_test_weapon(0)
	player=level.player;v=player.visual;player.get_node("Pistol").enabled=false
	v.set_locomotion_mode(0) # C1's historical V7/generic-carry baseline.
	v.long_gun_carry_v2=false # Preserve C1's generic-pose regression baseline.
	level.combat.audio.minimum_event_interval=1000000.0
	await tick(20)
	check(v.run_animation_speed_scale==1.6 and player.run_speed==6.25 and player.walk_speed==4.25,"Approved cadence and speeds unchanged")
	check(v.animation_player.has_animation("WeaponHold") and v.skeleton.get_bone_count()==12,"One pose resource and one skeleton with Carrier/socket")
	var pose: Animation=v.animation_player.get_animation("WeaponHold")
	for track in pose.get_track_count():check(String(pose.track_get_path(track).get_subname(0)) in ["Arm.L","Arm.R","WeaponSocket"],"Strict upper filter")
	v.set_weapon_equipped(false);await tick(15)
	check(v.weapon_hold_weight==0.0 and not v.socket.visible,"Unarmed Idle state")
	await capture("unarmed_idle")
	player.position=Vector3(0,0.02,-3)
	Input.action_press("move_backward");Input.action_press("sprint");await tick(25)
	check(v.current_state==&"Run" and v.weapon_hold_weight==0.0,"Unarmed Run")
	await capture("unarmed_run")
	release();await tick(25)
	for weapon in 3:
		player.position=Vector3(0,0.02,0);player.equip_test_weapon(weapon)
		await tick(20)
		check(v.weapon_hold_weight==1.0 and v.socket.visible and v.socket.equipped==weapon,"Armed Idle %d"%weapon)
		unchanged_lower();await capture("weapon_%d_idle"%weapon)
		player.position=Vector3(0,0.02,-3)
		Input.action_press("move_backward");Input.action_press("sprint");await tick(25)
		unchanged_lower();await capture("weapon_%d_run"%weapon)
		await tick(1)
		var before: float=v.authored_run_time
		Input.action_release("move_backward");Input.action_press("move_right")
		player.equip_test_weapon((weapon+1)%3)
		check(v.authored_run_time==before,"Switch itself never changes clock %d"%weapon)
		await tick(25)
		check(absf(wrapf(v.authored_run_time-before-25.0/60.0*v.run_animation_speed_scale,-v.run.clip.length/2,v.run.clip.length/2))<0.00001,"Moving switch/turn preserves Run clock %d"%weapon)
		check(v.socket.muzzle_position().is_finite(),"Socket muzzle valid %d"%weapon)
		release();await tick(25)
		check(v.current_state==&"Idle", "Armed stop %d"%weapon)
	for repeat in 3:
		player.position=Vector3(0,0.02,-3)
		Input.action_press("move_backward");Input.action_press("sprint");await tick(25)
		check(v.current_state==&"Run","Repeated armed start")
		release();await tick(25);check(v.current_state==&"Idle","Repeated armed stop")
	# Four uninterrupted runtime cycles: local carry stays controlled while the
	# inherited Chest/Spine motion continues to animate the arms in model space.
	player.position=Vector3(0,0.02,-3)
	Input.action_press("move_backward");Input.action_press("sprint");await tick(25)
	var initial_arm: Quaternion=v.skeleton.get_bone_global_pose(v.main_arm).basis.get_rotation_quaternion()
	var inherited_arm_motion:=0.0
	var stationary_root_error:=0.0
	for frame in 100:
		if frame%25==0:player.position=Vector3(0,0.02,-3)
		await tick(1)
		var arm: Quaternion=v.skeleton.get_bone_global_pose(v.main_arm).basis.get_rotation_quaternion()
		inherited_arm_motion=maxf(inherited_arm_motion,initial_arm.angle_to(arm))
		stationary_root_error=maxf(stationary_root_error,v.skeleton.get_bone_pose_position(v.skeleton.find_bone("Root")).length())
	check(inherited_arm_motion>0.005,"Carry inherits visible body rhythm over four Run cycles")
	check(stationary_root_error<0.00001,"No animated root travel over four Run cycles")
	release();await tick(25)
	player.position=Vector3(0,0.02,0);player.velocity=Vector3.ZERO
	var enemy:=ZOMBIE.instantiate();enemy.position=Vector3(0,0.02,3.5);enemy.max_hp=100000
	level.get_node("Actors").add_child(enemy);enemy.current_hp=100000;enemy.set_physics_process(false);level.combat.register_zombie(enemy)
	player.get_node("Pistol").enabled=true
	for weapon in 3:
		player.position=Vector3(0,0.02,0);player.velocity=Vector3.ZERO;player.equip_test_weapon(weapon)
		var shots: int=player.get_node("Pistol").shot_count
		Input.action_press("move_right");await tick(50)
		check(player.current_speed>0.1 and player.current_speed<=3.0 and player.get_node("Pistol").shot_count>shots,"Unchanged moving fire gate/profile %d"%weapon)
		await capture("weapon_%d_moving_fire"%weapon)
		release();await tick(20)
	metrics={"filtered_bones":["Arm.L","Arm.R","WeaponSocket"],"blend_seconds":v.weapon_hold_blend_duration,"run_scale":v.run_animation_speed_scale,"run_speed":player.run_speed,"runtime_skeletons":v.find_children("*","Skeleton3D",true,false).size(),"socket_path":str(v.socket.get_path()),"weapon_local_transforms":[]}
	metrics.merge({"inherited_arm_motion_degrees":rad_to_deg(inherited_arm_motion),"root_translation_max_m":stationary_root_error})
	for instance in v.socket.instances:metrics.weapon_local_transforms.append(str(instance.transform))
	var file:=FileAccess.open("res://tests/weapon_carry_c1_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"rendered":rendered},"\t"));file.close()
	print("WEAPON_CARRY_C1="+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"rendered":rendered}))
	quit(0 if failures.is_empty() else 1)



