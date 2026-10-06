extends SceneTree
## Deterministic integration fixture uses actual controller, sampler, behavior,
## weapon assets and firing implementation. Optional engine-rendered captures.
var level: Node3D
var player: CharacterBody3D
var v: Node3D
var b: Node
var gun: Node3D
var enemy: Node3D
var checks := 0
var failures: Array[String] = []
var clock_error := 0.0
var lower_error := 0.0
var root_travel := 0.0
var rendered := false
var results: Array[Dictionary] = []
var near := false
var collision_samples: Array[Dictionary] = []
var weapon_meshes := {}
var case_label := ""
func vector_array(vec: Vector3) -> Array: return [vec.x,vec.y,vec.z]
func matrix_array(t: Transform3D) -> Array:
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]
func sample_collision() -> void:
	if not v.holster_active or case_label.is_empty(): return
	var frames := {}; var mesh_frames: Array = []
	for name in ["Head","Chest"]: frames[name] = matrix_array(v.skeleton.global_transform*v.skeleton.get_bone_global_pose(v.skeleton.find_bone(name)))
	for mesh: MeshInstance3D in v.socket.instances[v.socket.equipped].find_children("*","MeshInstance3D",true,false):
		mesh_frames.append(matrix_array(mesh.global_transform))
	collision_samples.append({"case":case_label,"weapon":v.socket.equipped,"time":b.transition_elapsed,"body":frames,"meshes":mesh_frames,"weapon_world":matrix_array(v.socket.instances[v.socket.equipped].global_transform)})
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error(message)

func tick(dt: float = 1.0/60.0) -> void:
	enemy.global_position = player.global_position + Vector3(0,0,3 if near else 40)
	gun.cached_frame = -1
	var before: float = v.authored_run_time
	b._physics_process(dt); v._process(dt); gun._physics_process(dt)
	clock_error = maxf(clock_error, absf(wrapf(v.authored_run_time - before - dt*1.6, -v.run.clip.length/2, v.run.clip.length/2)))
	root_travel = maxf(root_travel, v.skeleton.get_bone_global_pose(v.skeleton.find_bone("Root")).origin.length())
	if v.holster_active:
		var lower: Array[Transform3D] = []
		for name in ["Root","Hips","Leg.L","Leg.R"]: lower.append(v.skeleton.get_bone_pose(v.skeleton.find_bone(name)))
		v.holster_active = false; v._evaluate(0.0); v.holster_active = true
		for i in lower.size():
			var pose: Transform3D = v.skeleton.get_bone_pose(v.skeleton.find_bone(["Root","Hips","Leg.L","Leg.R"][i]))
			lower_error = maxf(lower_error, lower[i].origin.distance_to(pose.origin))
			check(absf(lower[i].basis.get_rotation_quaternion().dot(pose.basis.get_rotation_quaternion())) > 0.999999, "Lower-body rotation untouched")
		v._evaluate(0.0)
	for bone in v.skeleton.get_bone_count(): check(v.skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE), "No pose scale")
	sample_collision()

func capture(label: String, back: bool = false) -> void:
	if not rendered: return
	var camera: Camera3D = level.get_node("Camera3D")
	camera.position = player.position + (Vector3(-3,2.6,-5) if back else Vector3(3,2.8,5))
	camera.look_at(player.position + Vector3(0,1.0,0)); camera.size = 2.7
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/holster_d2/d2_%s.png" % label)

func ready(weapon: int, phase: float, running: bool) -> void:
	v.cancel_authored_holster(); b.authored_holster = false; b.suspended = false
	player.equip_test_weapon(weapon); gun.cooldown = 1000.0
	b.weapon_attach_to_hand(); b._set_state(b.State.READY)
	near = false; b.grace_elapsed = 0.0; b.transition_elapsed = 0.0
	v.movement_speed = 6.25 if running else 0.0; player.current_speed = v.movement_speed
	v.move_weight = 1.0 if running else 0.0; v.run_weight = v.move_weight
	v.weapon_hold_weight = 1.0; v.long_gun_weight = 1.0
	v.switch_weight = 1.0; v.aim_weight = 0.0; v.has_target = false; v.is_firing = false; v.recoil_time = 100.0
	v.authored_run_time = phase * v.run.clip.length; v._evaluate(0.0)
	v.skeleton.force_update_all_bone_transforms(); v.socket.on_skeleton_update(); v.socket.sync_transport_sockets()

func run() -> void:
	rendered = "--capture" in OS.get_cmdline_user_args()
	level = preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled = false; level.get_node("Progression").enabled = false
	root.add_child(level); current_scene = level; level.select_test_weapon(1)
	if rendered:
		DirAccess.make_dir_recursive_absolute("res://.validation/holster_d2")
		level.get_node("HUD").visible=false
	player = level.player; v = player.visual; b = player.get_node("WeaponBehavior"); gun = player.get_node("Pistol")
	player.set_physics_process(false); b.set_physics_process(false); gun.set_physics_process(false); v.set_process(false)
	# Behavior's suspension gate expects the real controller to be active. Keep
	# it active but disable its inherited processing while manually stepping it.
	player.set_physics_process(true); player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector3(0,0,-3)
	enemy = preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp = 100000; level.get_node("Actors").add_child(enemy); enemy.current_hp = 100000
	enemy.set_physics_process(false); level.combat.register_zombie(enemy)
	check(v.skeleton.get_bone_count() == 12, "11 exported bones plus preserved legacy WeaponSocket")
	check(v.find_children("*","Skeleton3D",true,false).size() == 1, "One live skeleton")
	check(absf(v.holster_duration()-17.0/24.0)<0.000001, "Imported duration exact")
	var clip: Animation = v.holster_pose.clip
	for track in clip.get_track_count():
		check(clip.track_get_type(track)!=Animation.TYPE_SCALE_3D, "No imported scale tracks")
		var path := clip.track_get_path(track)
		check(path.get_subname_count()>0 and str(path.get_subname(0)) in v.HOLSTER_BONES, "Only seven authored upper bones imported")
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
		for phase in [0.0,0.25,0.5,0.75,-1.0]:
			ready(weapon,maxf(0,phase),phase>=0)
			var label := "%d_%s" % [weapon,str(phase).replace(".","_")]
			case_label=label
			var before: float = v.authored_run_time
			var initial: Transform3D = v.socket.instances[weapon].global_transform
			b._begin(b.State.HOLSTERING)
			sample_collision()
			check(v.holster_active and v.socket.current_attachment==&"carrier", "Authored start follows carrier")
			check(initial.origin.distance_to(v.socket.instances[weapon].global_position)<0.00001, "Start globally continuous")
			check(v.authored_run_time==before, "No run restart at begin")
			var steps := 0
			await capture(label+"_begin")
			while b.state==b.State.HOLSTERING and steps<55:
				tick(); steps+=1
				check(not gun.can_fire(), "No firing while holstering or stowed")
				if steps in [8,20,35,38]: await capture(label+"_step%d"%steps,steps>=35)
			check(b.state==b.State.STOWED and v.socket.current_attachment==&"back", "DONE stows on stable back socket")
			check(v.socket.instances[weapon].get_parent()==v.socket.back_mount, "Carrier released at back")
			check(v.socket.instances[weapon].transform.is_equal_approx(v.socket.transport_canonical()), "Approved back endpoint reached")
			check(v.holster_fired.size()==5, "All five centralized events once")
			for name in ["Arm.L","Arm.R"]:
				var bone: int = v.skeleton.find_bone(name)
				var expected: Quaternion = v.run.rotation(bone,v.authored_run_time) if phase>=0 else v.idle.rotation(bone,v.idle_time)
				check(absf(expected.dot(v.skeleton.get_bone_pose_rotation(bone)))>0.999999,"Smooth exit to original free arms")
			results.append({"weapon":weapon,"run_phase":phase,"steps60hz":steps,"events":v.holster_event_log.slice(-5)})
			await capture(label+"_done",true)
	case_label=""
	# Threat returns while transported: finish, then forward placeholder Draw.
	ready(1,0.25,true); b._begin(b.State.HOLSTERING)
	for i in 12: tick()
	near=true
	for i in 8: tick()
	check(b.state==b.State.HOLSTERING and v.holster_active,"Threat does not reverse/teleport holster")
	for i in 25: tick()
	check(b.state==b.State.DRAWING and v.socket.current_attachment==&"back", "Threat queues draw after holster")
	for i in 40: tick()
	check(b.is_ready() and v.socket.current_attachment==&"hand","Placeholder forward draw finishes safely")
	# Switching invalidates authored events, maintains pool identity and category.
	ready(1,0.5,true); b._begin(b.State.HOLSTERING); tick()
	var token: int = b.request_id
	player.equip_test_weapon(0); b.weapon_attach_to_back(token); v._evaluate(0)
	check(not v.holster_active and v.socket.current_attachment==&"hip", "Switch cancels old carrier events")
	check(v.socket.instances[1].get_parent()==v.socket and not v.socket.instances[1].visible,"Old weapon cleaned up")
	ready(0,0,false); b._begin(b.State.HOLSTERING)
	check(not v.holster_active and not b.authored_holster and v.socket.current_attachment==&"hand", "Pistol remains D0 placeholder")
	for i in 28: tick()
	check(b.state==b.State.STOWED and v.socket.current_attachment==&"hip","Pistol placeholder completes")
	for weapon in [1,2]:
		ready(weapon,0,false); near=true; gun.cooldown=0
		var shots: int = gun.shot_count; tick()
		check(gun.can_fire() and gun.shot_count>shots,"READY fires original profile %d"%weapon)
		gun.cooldown=0; near=false; b._begin(b.State.HOLSTERING); tick()
		check(not gun.can_fire(),"Long gun immediately gated during holster")
	ready(1,0,false); b._begin(b.State.HOLSTERING); tick()
	v.set_weapon_equipped(false); tick()
	check(not v.holster_active and v.socket.current_attachment!=&"carrier" and not gun.can_fire(),"Unequip cancels transport")
	v.set_weapon_equipped(true)
	ready(1,0,false); b._begin(b.State.HOLSTERING); tick(); token=b.request_id
	player.is_dead=true; tick(); b.weapon_attach_to_hand(token)
	check(b.suspended and not v.holster_active and v.socket.current_attachment==&"back" and not gun.can_fire(),"Death rejects stale events and releases carrier")
	player.is_dead=false
	for i in 3: check(ids[i]==v.socket.instances[i].get_instance_id(),"Same three pooled instances; no duplicates")
	for jump in v.socket.transport_jumps: check(jump.position_m<0.00001 and jump.rotation_rad<0.0015,"No attachment transform discontinuity")
	check(clock_error<0.000001 and lower_error<0.000001 and root_travel<0.000001,"Run continuous; lower body/root unchanged")
	check(v.run_animation_speed_scale==1.6 and player.run_speed==6.25 and player.walk_speed==4.25,"Movement/cadence preserved")
	var report := {"checks":checks,"failures":failures,"duration":v.holster_duration(),"clock_error":clock_error,"lower_position_error":lower_error,"root_travel":root_travel,"cases":results,"handoffs":v.socket.transport_jumps,"rendered":rendered}
	FileAccess.open("res://tests/holster_d2_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://tests/holster_d2_collision_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"meshes":weapon_meshes,"samples":collision_samples}))
	print("D2 checks: ",checks," failures: ",failures)
	quit(0 if failures.is_empty() else 1)

