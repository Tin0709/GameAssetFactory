extends SceneTree
## Real assets/runtime, deterministic subframe and locomotion-phase coverage.
var failures: Array[String] = []
var checks := 0
var level: Node3D
var p: CharacterBody3D
var v: Node3D
var b: Node
var gun: Node3D
var enemy: Node3D
var near := false
var clock_error := 0.0
var lower_error := 0.0
var root_travel := 0.0
var rendered := false
var cases: Array[Dictionary] = []
var ready_offsets: Array[Dictionary] = []
var collision_samples: Array[Dictionary] = []
var weapon_meshes := {}
var case_label := ""
func vector_array(vec: Vector3) -> Array: return [vec.x,vec.y,vec.z]
func matrix_array(t: Transform3D) -> Array:
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]
func sample_collision() -> void:
	if not v.draw_active or case_label.is_empty(): return
	var frames := {}; var mesh_frames: Array = []
	for name in ["Head","Chest"]: frames[name] = matrix_array(v.skeleton.global_transform*v.skeleton.get_bone_global_pose(v.skeleton.find_bone(name)))
	for mesh: MeshInstance3D in v.socket.instances[v.socket.equipped].find_children("*","MeshInstance3D",true,false):
		mesh_frames.append(matrix_array(mesh.global_transform))
	collision_samples.append({"case":case_label,"weapon":v.socket.equipped,"time":b.transition_elapsed,"body":frames,"meshes":mesh_frames,"weapon_world":matrix_array(v.socket.instances[v.socket.equipped].global_transform),"carrier_world":matrix_array(v.socket.carrier_socket.global_transform)})
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func flush() -> void:
	v.skeleton.force_update_all_bone_transforms(); v.socket.on_skeleton_update(); v.socket.sync_transport_sockets()
func tick(dt: float = 1.0/120.0) -> void:
	enemy.global_position = p.global_position + Vector3(0,0,3 if near else 40)
	gun.cached_frame = -1
	var before: float = v.authored_run_time
	b._physics_process(dt); v._process(dt)
	clock_error = maxf(clock_error, absf(wrapf(v.authored_run_time - before - dt*1.6, -v.run.clip.length/2, v.run.clip.length/2)))
	root_travel = maxf(root_travel, v.skeleton.get_bone_global_pose(v.skeleton.find_bone("Root")).origin.length())
	if v.draw_active:
		var lower: Array[Transform3D] = []
		for name in ["Root","Hips","Leg.L","Leg.R"]: lower.append(v.skeleton.get_bone_pose(v.skeleton.find_bone(name)))
		v.draw_active = false; v._evaluate(0); v.draw_active = true
		for i in lower.size():
			var pose: Transform3D = v.skeleton.get_bone_pose(v.skeleton.find_bone(["Root","Hips","Leg.L","Leg.R"][i]))
			lower_error = maxf(lower_error, lower[i].origin.distance_to(pose.origin))
			check(absf(lower[i].basis.get_rotation_quaternion().dot(pose.basis.get_rotation_quaternion())) > 0.999999, "Draw leaves lower rotations unchanged")
		v._evaluate(0)
		check(not b.is_ready() and not gun.can_fire(), "Draw blocks firing including catch/settle")
	for bone in v.skeleton.get_bone_count(): check(v.skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE), "No bone scaling")
	flush()
	sample_collision()
func stowed(weapon: int, phase: float) -> void:
	b._cancel_authored(); b.authored_draw = false; b.suspended = false
	p.fast_sprinting = false; p.is_dead = false; v.set_weapon_equipped(true)
	p.equip_test_weapon(weapon); b._set_state(b.State.STOWED); b._attach_stowed()
	near = false; b.threat_present = false; b.transition_elapsed = 0; b.grace_elapsed = 0
	gun.cooldown = 1000; v.switch_weight = 1; v.aim_weight = 0
	v.movement_speed = 6.25 if phase >= 0 else 0.0; p.current_speed = v.movement_speed
	v.move_weight = 1.0 if phase >= 0 else 0.0; v.run_weight = v.move_weight
	v.weapon_hold_weight = 0; v.long_gun_weight = 0; v.has_target = false; v.is_firing = false; v.recoil_time = 100
	v.authored_run_time = maxf(phase,0) * v.run.clip.length
	v._evaluate(0); flush()
func capture(label: String) -> void:
	if not rendered: return
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/draw_d5/%s.png" % label)
func run() -> void:
	rendered = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://.validation/draw_d5")
	level = preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled = false; level.get_node("Progression").enabled = false
	root.add_child(level); current_scene = level; level.select_test_weapon(1)
	p = level.player; v = p.visual; b = p.get_node("WeaponBehavior"); gun = p.get_node("Pistol")
	p.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("HUD").visible = false
	enemy = preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp = 100000; level.get_node("Actors").add_child(enemy); enemy.current_hp = 100000
	enemy.set_physics_process(false); level.combat.register_zombie(enemy)
	check(v.samples.has("DrawLongGun"), "Approved DrawLongGun is available to runtime")
	if not v.samples.has("DrawLongGun"): quit(1); return
	check(absf(v.draw_duration()-13.0/24.0)<0.000001, "Authored duration")
	var expected := {&"DRAW_BEGIN":0.0,&"WEAPON_GRAB":1.0/6.0,&"WEAPON_BACK_RELEASE":17.0/96.0,&"SUPPORT_HAND_CATCH":0.4125,&"DRAW_READY":13.0/24.0}
	for event in expected: check(absf(v.draw_event_time(event)-expected[event])<1e-8,"Exact metadata event %s"%event)
	var clip: Animation = v.draw_pose.clip
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		check(clip.track_get_type(track)!=Animation.TYPE_SCALE_3D and path.get_subname_count()>0 and str(path.get_subname(0)) in v.draw_data.bones,"Filtered imported Draw tracks")
	check(v.find_children("*","Skeleton3D",true,false).size()==1,"One live skeleton")
	var ids: Array[int] = []
	for instance in v.socket.instances: ids.append(instance.get_instance_id())
	for weapon in [1,2]:
		var meshes_data: Array = []
		for mesh: MeshInstance3D in v.socket.instances[weapon].find_children("*","MeshInstance3D",true,false):
			var surfaces: Array = []
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface); var points: Array = []
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: points.append(vector_array(vertex))
				surfaces.append({"vertices":points,"indices":Array(arrays[Mesh.ARRAY_INDEX])})
			meshes_data.append(surfaces)
		weapon_meshes[str(weapon)] = meshes_data
	for weapon in [1,2]:
		for phase in [-1.0,0.0,0.25,0.5,0.75]:
			stowed(weapon,phase); near=true
			var label := "%d_%s" % [weapon,str(phase).replace(".","_")]
			case_label=label
			var before: float = v.authored_run_time
			var initial: Transform3D = v.socket.instances[weapon].transform
			b._begin(b.State.DRAWING)
			check(v.draw_active and v.socket.current_attachment==&"back", "Draw begins on back")
			check(v.authored_run_time==before and v.socket.instances[weapon].transform.is_equal_approx(initial),"Begin preserves Run clock and back mount")
			await capture(label+"_00")
			for step in range(1,66):
				tick()
				if step<22: check(v.socket.current_attachment==&"back","Weapon stays on back before authored release")
				elif step<65: check(v.socket.current_attachment==&"carrier","Carrier owns rifle through catch and settle")
				if step in [12,20,22,30,38,44,50,58,64,65]: await capture(label+"_%02d"%step)
			check(b.is_ready() and v.socket.current_attachment==&"hand", "Ready ends on normal hand socket")
			check(v.draw_fired.size()==5,"Five authored events once")
			check(v.socket.instances[weapon].transform.origin.distance_to(v.socket.hand_transforms[weapon].origin)<0.00001,"Carrier and category hand mount align at Ready")
			ready_offsets.append({"weapon":weapon,"phase":phase,"position_m":v.socket.instances[weapon].transform.origin.distance_to(v.socket.hand_transforms[weapon].origin),"rotation_rad":v.socket.instances[weapon].basis.get_rotation_quaternion().angle_to(v.socket.hand_transforms[weapon].basis.get_rotation_quaternion())})
			cases.append({"weapon":weapon,"phase":phase,"events":v.draw_event_log.slice(-5)})
			for i in 18: tick()
			check(v.socket.instances[weapon].transform.is_equal_approx(v.socket.hand_transforms[weapon]),"Exit reaches unchanged hand mount")
			await capture(label+"_exit")
			p.current_speed=0; gun.cooldown=0; gun.cached_frame=-1
			var shots: int=gun.shot_count; gun._physics_process(1.0/60.0)
			check(gun.shot_count>shots,"Original gun fires only after READY %d"%weapon)
	case_label=""
	stowed(1,0); b._begin(b.State.DRAWING)
	b.transition_elapsed=0.177082; v._evaluate(0)
	check(v.socket.current_attachment==&"back","Subframe release not early")
	b.transition_elapsed=17.0/96; v._evaluate(0)
	check(v.socket.current_attachment==&"carrier","Subframe release exact")
	b.transition_elapsed=0.4125; v._evaluate(0)
	check(b.state==b.State.DRAWING and v.socket.current_attachment==&"carrier" and not gun.can_fire(),"Catch does not attach hand or enable fire")
	for weapon in [1,2]:
		for released in [false,true]:
			stowed(weapon,0.25); near=true; b._begin(b.State.DRAWING)
			for i in (30 if released else 8): tick()
			var old: int=b.request_id; var mount: Transform3D=v.socket.instances[weapon].transform
			p.fast_sprinting=true; tick()
			if released: check(v.draw_active and v.socket.current_attachment==&"carrier","Sprint after release retains forward Carrier")
			else: check(b.state==b.State.STOWED and not v.draw_active and v.socket.instances[weapon].transform.is_equal_approx(mount),"Sprint before release cancels without moving weapon")
			for i in 160: tick(); check(not gun.can_fire(),"Sprint interruption never enables fire")
			check(b.state==b.State.STOWED and v.socket.current_attachment==&"back","Sprint ends stowed with valid threat")
			b.weapon_draw_to_carrier(old,0.2); b.weapon_draw_to_hand(old); b.draw_finished(old)
			check(v.socket.current_attachment==&"back","Stale Draw events rejected")
			p.fast_sprinting=false; tick()
			check(v.draw_active and b.state==b.State.DRAWING,"Sprint release with threat immediately requests real Draw")
			for i in 85: tick()
			check(b.is_ready(),"Sprint release Draw finishes")
	for step in [8,30,58]:
		for destination in [0,2]:
			stowed(1,0.5); b._begin(b.State.DRAWING)
			for i in step: tick()
			var old: int=b.request_id; p.equip_test_weapon(destination)
			b.weapon_draw_to_hand(old); b.weapon_draw_to_carrier(old,0.2); b.draw_finished(old)
			check(v.socket.instances[1].get_parent()==v.socket and not v.socket.instances[1].visible,"Switch cleans previous transport")
			check(v.draw_active==(destination==2),"Only long-gun switch requests authored Draw")
			for i in 90: tick()
			check(b.is_ready(),"Switched weapon reaches READY")
	# A one-tick sprint tap during Reach must acquire the next Draw from the
	# visible partial Reach, rather than resetting arms to unarmed locomotion.
	stowed(1,0); near=true; b._begin(b.State.DRAWING)
	for i in 15: tick()
	p.fast_sprinting=true; tick()
	var restart_pose: Array[Transform3D] = []
	for bone in v.draw_mask: restart_pose.append(v.skeleton.get_bone_pose(bone))
	p.fast_sprinting=false; b._physics_process(0)
	for i in v.draw_mask.size():
		if v.skeleton.get_bone_name(v.draw_mask[i])=="WeaponCarrier": continue
		var actual: Transform3D=v.skeleton.get_bone_pose(v.draw_mask[i])
		check(restart_pose[i].origin.distance_to(actual.origin)<0.00001 and absf(restart_pose[i].basis.get_rotation_quaternion().dot(actual.basis.get_rotation_quaternion()))>0.999999,"Rapid sprint release keeps current upper pose")
	for guard in ["unequip","dead","disabled"]:
		stowed(1,0); b._begin(b.State.DRAWING)
		for i in 30: tick()
		var before_disable: Transform3D=v.socket.instances[1].global_transform
		if guard=="unequip": v.set_weapon_equipped(false)
		elif guard=="dead": p.is_dead=true
		else: b.enabled=false
		if guard=="disabled":
			b._physics_process(0)
			check(before_disable.origin.distance_to(v.socket.instances[1].global_position)<0.00001,"Disabling during sweep preserves weapon world transform")
		tick()
		check(not v.draw_active and v.socket.current_attachment!=&"carrier","Guard releases Carrier: "+guard)
		p.is_dead=false; b.enabled=true; v.set_weapon_equipped(true)
	stowed(1,0); b._begin(b.State.DRAWING)
	for i in 8: tick()
	var before_early_disable: Transform3D=v.socket.instances[1].global_transform
	b.enabled=false; b._physics_process(0)
	check(before_early_disable.origin.distance_to(v.socket.instances[1].global_position)<0.00001,"Disabling during Reach preserves weapon world transform")
	b.enabled=true
	stowed(0,-1); b._begin(b.State.DRAWING)
	check(not v.draw_active and not b.authored_draw,"Pistol retains placeholder")
	for i in 22: tick()
	check(v.socket.current_attachment==&"hand" and b.state==b.State.DRAWING,"Pistol original half-duration handoff")
	for i in 22: tick()
	check(b.is_ready(),"Pistol original duration")
	for i in 3: check(ids[i]==v.socket.instances[i].get_instance_id(),"Pool instance identity preserved")
	for jump in v.socket.transport_jumps: check(jump.position_m<0.00001 and jump.rotation_rad<0.0015,"Global-preserving handoff")
	check(clock_error<1e-6 and lower_error<1e-6 and root_travel<1e-6,"Continuous Run / unchanged lower body / zero root motion")
	check(v.run_animation_speed_scale==1.6 and p.run_speed==6.25 and p.walk_speed==4.25,"Cadence and speeds unchanged")
	var report={"checks":checks,"failures":failures,"cases":cases,"clock_error":clock_error,"lower_error":lower_error,"root_travel":root_travel,"handoffs":v.socket.transport_jumps,"ready_mount_offsets":ready_offsets,"rendered":rendered}
	FileAccess.open("res://tests/draw_d5_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://.validation/draw_d5/collision_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"meshes":weapon_meshes,"samples":collision_samples}))
	print("D5: %d checks, failures %s; offsets %s" % [checks,failures,ready_offsets])
	quit(0 if failures.is_empty() else 1)
