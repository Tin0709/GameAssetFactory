extends SceneTree
## Catches missing Ready layers, drift, direction resets, lower-body contamination,
## and transitions that bypass the actual behavior/socket runtime.
var failures: Array[String] = []
var checks := 0
var level: Node3D
var p: CharacterBody3D
var v: Node3D
var b: Node
var gun: Node3D
var enemy: Node3D
var near := true
var clock_error := 0.0
var phase_error := 0.0
var lower_error := 0.0
var cases: Array[Dictionary] = []
var composition_position_error := 0.0
var composition_rotation_error := 0.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func flush() -> void:
	v.skeleton.force_update_all_bone_transforms(); v.socket.on_skeleton_update(); v.socket.sync_transport_sockets()
func tick(dt: float = 1.0 / 120.0) -> void:
	enemy.global_position = p.global_position + Vector3(0,0,3 if near else 40)
	gun.cached_frame = -1
	var before: float = v.authored_run_time
	b._physics_process(dt); v._process(dt); flush()
	clock_error = maxf(clock_error, absf(wrapf(v.authored_run_time - before - dt * 1.6, -v.run.clip.length/2, v.run.clip.length/2)))
func advance(seconds: float) -> void:
	for i in ceili(seconds * 120): tick()
func motion(velocity: Vector3) -> void:
	p.velocity = velocity; p.current_speed = velocity.length()
	v.update_motion(velocity, enemy if near else null, 1.0/120.0)
func lower() -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for name in ["Root", "Hips", "Leg.L", "Leg.R"]: poses.append(v.skeleton.get_bone_pose(v.skeleton.find_bone(name)))
	return poses
func compare_lower(reference: Array[Transform3D]) -> void:
	var current := lower()
	for i in current.size():
		lower_error = maxf(lower_error, current[i].origin.distance_to(reference[i].origin))
		check(current[i].origin.distance_to(reference[i].origin) < 0.000001, "Ready preserves lower positions")
		check(absf(current[i].basis.get_rotation_quaternion().dot(reference[i].basis.get_rotation_quaternion())) > 0.999999, "Ready preserves lower rotations")
func record(label: String) -> void:
	cases.append({"case":label,"weapon":v.socket.equipped,"state":b.State.keys()[b.state],"attachment":str(v.socket.current_attachment),"ready_weight":v.living_ready_weight,"move_weight":v.ready_move_weight,"run_time":v.authored_run_time,"ready_run_time":v.ready_run_sample_time()})
func from_rows(rows: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(rows[0][3],rows[1][3],rows[2][3]))
func finish() -> void:
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"clock_error_seconds":clock_error,"phase_error_seconds":phase_error,"lower_position_error_m":lower_error,"composition_position_error_m":composition_position_error,"composition_rotation_error_rad":composition_rotation_error,"cases":cases}
	var f := FileAccess.open("res://tests/living_ready_e3_validation.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t")); f.close()
	print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
func run() -> void:
	level = preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled = false; level.get_node("Progression").enabled = false
	root.add_child(level); current_scene = level; level.select_test_weapon(1)
	p = level.player; v = p.visual; b = p.get_node("WeaponBehavior"); gun = p.get_node("Pistol")
	check(v.animation_player.has_animation("LongGunReadyIdle"), "Imported Living Ready Idle exists")
	check(v.animation_player.has_animation("LongGunReadyRun"), "Imported Living Ready Run exists")
	if not failures.is_empty(): finish(); return
	for name in ["LongGunReadyIdle","LongGunReadyRun"]:
		var clip: Animation = v.animation_player.get_animation(name)
		check(clip.loop_mode == Animation.LOOP_LINEAR, "Ready imported as loop")
		for track in clip.get_track_count():
			var path := clip.track_get_path(track)
			check(path.get_subname_count() > 0 and str(path.get_subname(0)) in ["Spine","Chest","Neck","Head","Arm.R","Arm.L","WeaponCarrier"] and clip.track_get_type(track) in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D], "Ready native tracks remain strictly upper body without scale")
	enemy = preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp = 1000000; level.get_node("Actors").add_child(enemy); enemy.current_hp = 1000000
	enemy.set_physics_process(false); level.combat.register_zombie(enemy)
	# No awaits in this deterministic test: controller remains enabled so the
	# real behavior's disabled/death guard does not suspend the actor.
	v.set_process(false); b.set_physics_process(false); gun.set_physics_process(false); gun.cooldown = 1000
	var ids: Array[int] = []
	for instance in v.socket.instances: ids.append(instance.get_instance_id())
	for weapon in [1,2]:
		v.equip_weapon(weapon); near = true; p.fast_sprinting = false; motion(Vector3.ZERO); advance(1.0)
		check(b.is_ready() and v.socket.current_attachment == &"hand", "Standing Draw naturally reaches READY %d" % weapon)
		check(v.living_ready_weight > 0.999 and v.ready_move_weight < 0.001, "Stationary selects living Idle %d" % weapon)
		record("A/I standing draw -> idle")
		for speed in [2.6,4.25,6.25]:
			motion(Vector3.RIGHT * speed); advance(0.35)
			check(v.ready_move_weight > 0.999, "Movement selects ReadyRun %d at %.2f" % [weapon,speed])
			for i in 2400:
				var angle := float(i) * 0.037
				motion(Vector3(cos(angle),0,sin(angle)) * speed); tick(1.0 / 120.0 if i % 3 != 0 else 1.0 / 75.0)
				var expected: float = v.authored_run_time / v.run.clip.length * v.ready_run_pose.clip.length
				phase_error = maxf(phase_error, absf(v.ready_run_sample_time() - expected))
			check(phase_error < 0.000001, "Shared active gait phase has no independent clock drift")
			record("B/C/D/E/F running and direction changes %.2f" % speed)
			var living_lower := lower()
			v.ready_animation_mode = 0; advance(0.20); v._evaluate(0.0)
			var legacy_lower := lower()
			v.ready_animation_mode = 1; v.living_ready_weight = 1.0; v._evaluate(0.0)
			compare_lower(legacy_lower)
			if speed <= 4.25:
				var living_upper: Array[Transform3D] = []
				for bone in v.ready_mask: living_upper.append(v.skeleton.get_bone_pose(bone))
				v.ready_animation_mode = 0; v.living_ready_weight = 0; v._evaluate(0)
				for i in v.ready_mask.size(): check(living_upper[i].is_equal_approx(v.skeleton.get_bone_pose(v.ready_mask[i])), "Walk safely retains entire calibrated Hold instead of Run correction")
				v.ready_animation_mode = 1; v.living_ready_weight = 1; v._evaluate(0)
			check(living_lower.size() == legacy_lower.size(), "One original skeleton/lower body")
		motion(Vector3.ZERO); advance(0.20)
		check(v.ready_move_weight < 0.001, "G Run stop blends to Idle")
		motion(Vector3(1,0,1).normalized() * 6.25); advance(0.20)
		check(v.ready_move_weight > 0.999, "H Stop Run uses current phase")
		p.fast_sprinting = true; tick()
		check(b.state == b.State.HOLSTERING and v.holster_active and not gun.can_fire(), "K READY Run sprint uses existing Holster/fire gate")
		advance(1.0)
		check(b.state == b.State.STOWED and v.socket.current_attachment == &"back" and v.living_ready_weight < 0.001, "Sprint settles STOWED without Ready")
		record("K sprint -> holster -> stowed")
		p.fast_sprinting = false; tick()
		check(b.state == b.State.DRAWING and v.draw_active, "L Sprint release threat uses authored Draw")
		advance(0.9)
		check(b.is_ready() and v.ready_move_weight > 0.999 and v.living_ready_weight > 0.999, "J/L Moving Draw blends directly to current ReadyRun")
		record("J/L moving draw -> ReadyRun")
		for bone in v.skeleton.get_bone_count(): check(v.skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE), "No scale/root motion")
		check(v.skeleton.get_bone_global_pose(v.skeleton.find_bone("Root")).origin.length() < 0.00001, "No root motion")
		check(gun.can_fire() == p.can_fire_moving(), "Existing READY firing permission retained")
		for i in ids.size(): check(ids[i] == v.socket.instances[i].get_instance_id(), "Weapon instance never duplicated")
		for jump in v.socket.transport_jumps: check(jump.position_m < 0.00001 and jump.rotation_rad < 0.001, "Socket handoff stays continuous")
		near = false; advance(2.5)
		check(b.state == b.State.STOWED, "Safe grace still holsters")
	check(clock_error < 0.00001, "Run still advances continuously at 1.60")
	# Compare the actual final bone world frames against independent Blender
	# compositions of source Actions. A missing or misclocked layer must fail.
	v.equip_weapon(1); near = true; p.fast_sprinting = false; motion(Vector3.ZERO); advance(1)
	b.state = b.State.READY; v.draw_active = false; v.holster_active = false; v.draw_exit_time = -1
	v.has_target = false; v.aim_weight = 0; v.bounce_enabled = false; v.is_firing = false
	v.acceleration = Vector3.ZERO; v.turn_rate = 0; v.weapon_lag = 0; v.lower_rotation = Quaternion.IDENTITY
	v.switch_weight = 1; v.weapon_hold_weight = 1; v.long_gun_weight = 1; v.living_ready_weight = 1; v.ready_animation_mode = 1
	var composition_file := ProjectSettings.globalize_path("res://../blender/characters/player/cuboid/export/ready_e3/runtime_composition_samples.json")
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string(composition_file))
	# Independent reference uses the exact previous native base clip and raw
	# exported Ready frames. The test reference skeleton is never gameplay data.
	var reference_model := preload("res://assets/characters/player_cuboid_animated_v3.glb").instantiate()
	root.add_child(reference_model); reference_model.visible = false
	var reference_skeleton := reference_model.find_child("Skeleton3D",true,false) as Skeleton3D
	var reference_player := reference_model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	for name in ["Idle","Run","DrawLongGun","HolsterLongGun"]:
		var old_clip: Animation = reference_player.get_animation(name)
		var new_clip: Animation = v.animation_player.get_animation(name)
		check(old_clip.get_track_count() == new_clip.get_track_count() and old_clip.length == new_clip.length, "Previous native %s clip retained" % name)
		for track in old_clip.get_track_count():
			check(old_clip.track_get_path(track) == new_clip.track_get_path(track) and old_clip.track_get_key_count(track) == new_clip.track_get_key_count(track), "Native %s tracks/keys retained" % name)
			for key in old_clip.track_get_key_count(track):
				check(old_clip.track_get_key_time(track,key) == new_clip.track_get_key_time(track,key) and old_clip.track_get_key_value(track,key) == new_clip.track_get_key_value(track,key), "Native %s key data identical" % name)
	for fixture: Dictionary in fixtures:
		var sample_p_error := 0.0; var sample_q_error := 0.0
		var is_run: bool = fixture.context == "Run"
		v.move_weight = 1 if is_run else 0; v.run_weight = 1 if is_run else 0; v.ready_move_weight = 1 if is_run else 0
		v.authored_run_time = float(fixture.phase)*v.run.clip.length
		v.idle_time = float(fixture.phase)*v.idle.clip.length; v.ready_idle_time = float(fixture.phase)*v.ready_idle_pose.clip.length
		v._evaluate(0); flush()
		var base_clip: Animation = reference_player.get_animation(fixture.context)
		var base_sampler := preload("res://scripts/animation_pose_sampler.gd").new(base_clip,reference_skeleton)
		for bone in reference_skeleton.get_bone_count():
			reference_skeleton.set_bone_pose(bone, Transform3D(Basis(base_sampler.rotation(bone,fixture.phase*base_clip.length)),base_sampler.position(bone,fixture.phase*base_clip.length)))
		for name: String in fixture.ready_locals:
			var bone := reference_skeleton.find_bone(name)
			var ready_local := from_rows(fixture.ready_locals[name])
			var composed := reference_skeleton.get_bone_pose(bone) * reference_skeleton.get_bone_rest(bone).affine_inverse() * ready_local if name in ["Spine","Chest","Neck","Head"] else ready_local
			reference_skeleton.set_bone_pose(bone,composed)
		reference_skeleton.force_update_all_bone_transforms()
		for name: String in fixture.bones:
			var expected := reference_skeleton.global_transform * reference_skeleton.get_bone_global_pose(reference_skeleton.find_bone(name))
			var bone: int = v.skeleton.find_bone(name)
			var actual: Transform3D = v.global_transform.affine_inverse() * v.skeleton.global_transform * v.skeleton.get_bone_global_pose(bone)
			composition_position_error = maxf(composition_position_error, expected.origin.distance_to(actual.origin))
			composition_rotation_error = maxf(composition_rotation_error, expected.basis.get_rotation_quaternion().angle_to(actual.basis.get_rotation_quaternion()))
			sample_p_error = maxf(sample_p_error, expected.origin.distance_to(actual.origin))
			sample_q_error = maxf(sample_q_error, expected.basis.get_rotation_quaternion().angle_to(actual.basis.get_rotation_quaternion()))
		check(sample_p_error < 0.0001 and sample_q_error < 0.0015, "Final %s upper pose matches exported source composition at phase %.4f" % [fixture.context,fixture.phase])
	reference_model.free()
	# Long-gun fade weight can remain nonzero on the switch tick. It must never
	# substitute a Ready rifle pose into the unchanged Pistol composition.
	v.equip_weapon(0); v.living_ready_weight = 1; v._evaluate(0)
	var pistol_living: Array[Transform3D] = []
	for bone in v.upper: pistol_living.append(v.skeleton.get_bone_pose(bone))
	v.living_ready_weight = 0; v._evaluate(0)
	for i in v.upper.size(): check(pistol_living[i].is_equal_approx(v.skeleton.get_bone_pose(v.upper[i])), "Pistol never receives Living rifle pose during switch")
	finish()
