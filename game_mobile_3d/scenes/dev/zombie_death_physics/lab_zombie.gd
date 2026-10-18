extends Node3D
## Isolated pose source. Does not instantiate production AI, capsule or death/VFX scripts.
const MODEL = preload("res://assets/characters/zombie_animation_v2.glb")
const RAGDOLL = preload("res://scenes/dev/zombie_death_physics/ragdoll.gd")
var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var ragdoll: Node
var state := "Idle"
var walk_speed := 0.65
var elapsed := 0.0
var dead := false
var age := 0.0
var queued_death: Dictionary = {}
var death_result := false
var spawn_position := Vector3.ZERO
var model_offset_at_handoff := Vector3.ZERO
var visible_pose: Array[Transform3D] = []
var visible_physics_samples := 0
var maximum_skin_position_error := 0.0
var maximum_skin_angle_error := 0.0
var corpse_parked := false
var first_contact_age := -1.0
var stable_contact_time := 0.0
var fade_started := -1.0
var corpse_center := Vector3.ZERO
var fade_materials: Array[BaseMaterial3D] = []

func _ready() -> void:
	spawn_position = position
	model = MODEL.instantiate()
	model.name = "OriginalZombie"
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false)
	player = model.find_child("AnimationPlayer", true, false)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name in ["Zombie_Idle", "Zombie_Walk"]:
		player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat: BaseMaterial3D = mesh.mesh.surface_get_material(i)
			if mat: mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ragdoll = RAGDOLL.new()
	add_child(ragdoll)
	ragdoll.setup(skeleton)
	skeleton.skeleton_updated.connect(_capture_visible_pose)
	set_state(state)
	ragdoll.sample(1.0 / 60.0)

func reset_for_reuse(at: Vector3) -> void:
	# The visual is pooled, never a live native physics graph or stale solver state.
	if is_instance_valid(ragdoll):
		ragdoll.release()
		ragdoll.free()
	transform = Transform3D(Basis.IDENTITY,at)
	spawn_position = at
	model.transform = Transform3D.IDENTITY
	dead = false
	age = 0.0
	elapsed = 0.0
	death_result = false
	corpse_parked = false
	first_contact_age = -1.0
	stable_contact_time = 0.0
	fade_started = -1.0
	corpse_center = at + Vector3(0,.8,0)
	queued_death.clear()
	model_offset_at_handoff = Vector3.ZERO
	visible_pose.clear()
	visible_physics_samples = 0
	maximum_skin_position_error = 0.0
	maximum_skin_angle_error = 0.0
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count(): mesh.set_surface_override_material(i,null)
	fade_materials.clear()
	skeleton.reset_bone_poses()
	ragdoll = RAGDOLL.new()
	add_child(ragdoll)
	ragdoll.setup(skeleton)
	set_physics_process(true)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visible = true
	set_state(state)

func fade_out(fraction: float) -> void:
	if fade_materials.is_empty():
		# GeometryInstance transparency is ignored by Mobile. Use temporary local
		# alpha-hash materials for the brief optional fade; original materials survive.
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			for i in mesh.mesh.get_surface_count():
				var original: BaseMaterial3D = mesh.mesh.surface_get_material(i)
				if not original: continue
				var material: BaseMaterial3D = original.duplicate()
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
				mesh.set_surface_override_material(i,material)
				fade_materials.append(material)
	for material in fade_materials: material.albedo_color.a = 1.0-clampf(fraction,0,1)

func retire() -> void:
	player.pause()
	ragdoll.release()
	set_physics_process(false)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	queued_death.clear()

func set_state(value: String) -> void:
	if dead: return
	state = value
	elapsed = 0.0
	model.position = Vector3.ZERO
	player.play("Zombie_Walk" if state == "Walk" else "Zombie_Idle", 0.0)
	player.seek(0.0,true) # Reset/reuse only; never rewind during death handoff.
	player.advance(0.0)
	# Clear the history when a clip/offset changes: no synthetic transition velocity.
	ragdoll.sample_count = 0
	ragdoll.previous.clear()
	ragdoll.current.clear()

func request_death(profile: Resource, direction: Vector3, location: String, distance: float, gravity: float) -> void:
	if dead or not queued_death.is_empty(): return
	queued_death = {"profile": profile, "direction": direction, "location": location, "distance": distance, "gravity": gravity}

func _physics_process(delta: float) -> void:
	if dead:
		age += delta
		return
	elapsed += delta
	if state == "Walk":
		position += basis * Vector3.BACK * walk_speed * delta
		# Lab travel lane wraps only while alive. Never teleport a corpse.
		if position.distance_to(spawn_position) > 4.0:
			position = spawn_position
			ragdoll.sample_count = 0
	if state == "Attack":
		# Exact existing independently authored procedural lunge; no A&S clip.
		var t := fposmod(elapsed, 1.2)
		var z := 0.0
		if t < 0.10:
			z = Tween.interpolate_value(0.0, -0.045, t, 0.10, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		elif t < 0.18:
			z = Tween.interpolate_value(-0.045, 0.235, t - 0.10, 0.08, Tween.TRANS_QUAD, Tween.EASE_IN)
		elif t < 0.36:
			z = Tween.interpolate_value(0.19, -0.19, t - 0.18, 0.18, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		model.position.z = z
	player.advance(delta)
	ragdoll.sample(delta)
	if not queued_death.is_empty() and ragdoll.sample_count >= 2:
		# Pause, never stop()/RESET/freeze_animation(): those can discard live offsets.
		model_offset_at_handoff = model.position
		player.pause()
		death_result = ragdoll.begin(queued_death.profile, queued_death.direction, queued_death.location, queued_death.distance, queued_death.gravity)
		dead = death_result
		queued_death.clear()

func _capture_visible_pose() -> void:
	if not skeleton.is_inside_tree(): return
	visible_pose.clear()
	for i in skeleton.get_bone_count(): visible_pose.append(skeleton.global_transform * skeleton.get_bone_global_pose(i))
	if dead:
		visible_physics_samples += 1
		for body in ragdoll.bodies.values():
			var expected: Transform3D = body.global_transform * body.body_offset.affine_inverse()
			var visible := visible_pose[body.get_bone_id()]
			maximum_skin_position_error = maxf(maximum_skin_position_error, visible.origin.distance_to(expected.origin))
			maximum_skin_angle_error = maxf(maximum_skin_angle_error, visible.basis.get_rotation_quaternion().angle_to(expected.basis.get_rotation_quaternion()))
