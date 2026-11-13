extends Node3D
## The Cross Pollinator (MD2 RapidCrossbow_Unique1).

signal ammo_changed(amount: int)
signal bolt_impact(hit: Dictionary, direction: Vector3, serial: int)
signal shot_fired(origin: Vector3)
signal bolt_launched(bolt: Node3D)
signal bolt_ended(bolt: Node3D)

const Source := preload("res://scripts/mechanic_lab_weapon_source.gd")
const SourceGait := preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/source_gait.gd")
const DIRECTORY := Source.EQUIPMENT + "RapidCrossbow/RapidCrossbow_Unique/"
const CLIPS := Source.ANIMATIONS + "Weapons_Ranged/Crossbow/"
const LIBRARY := &"private_cross_pollinator"
const LOCOMOTION_LIBRARY := &"private_cross_pollinator_locomotion"
const SHOT := "NativeCrossPollinatorShot"
const RECOVERY := "NativeCrossPollinatorRecovery"
const AMMO_MAX := 25
const AIM_RANGE := 7.5
# RapidCrossbow_Unique1 base period, with HairtriggerUnique's +40% attack speed.
const ATTACK_PERIOD := 0.2 / 1.4
# At 18/30 s the source recoil has returned to its raised aim pose.
const RECOIL_END := 18.0 / 30.0
const RECHARGE_DELAY := 1.0
const RECHARGE_PERIOD := 0.8
const BOLT_SPEED := 35.0
# The live Polaris movement component sweeps a SphereComponent of 10 cm.
const BOLT_RADIUS := 0.10
const BOLT_MESH_SCALE := 0.7
# NS_ArrowTrail's Trail emitter initializes a world-space ribbon.
const TRAIL_SHADER := preload("res://materials/mechanic_lab_polaris_trail.gdshader")
const ImpactSparks := preload("res://scripts/mechanic_lab_polaris_impact.gd")
const TRAIL_LIFETIME := 0.30
const TRAIL_WIDTH := 0.08
const TRAIL_FADE_END_AGE := 0.60 * TRAIL_LIFETIME
const TRAIL_SAMPLE_SECONDS := 1.0 / 60.0
# BP_ArrowProp uses the same source mesh, scaled to 0.6 with a -6 cm offset.
const EMBEDDED_SCALE := 0.6
const EMBEDDED_OFFSET := 0.06
const EMBEDDED_WOBBLE_SECONDS := 1.0
const EMBEDDED_WOBBLE_SCALE := 10.0
const EMBEDDED_CAPACITY := 24
const CONTACT_PROBE_DISTANCE := 0.0001
const BOLT_LIFETIME := 5.0
const WORLD_MASK := 1
const BOLT_MASK := WORLD_MASK | 4
const STRIKE := {"damage": 8, "strength": 400.0, "angle": 25.0, "stagger": 8.1}
const ACTION_HASH := "09471c7fa549624245482513aefd2e2f8fa35a18152dfb9b23b04baabd4e65d0"
# BP_AlexCharacter: both Polaris meshes have +16 cm on UE Z at their
# respective left-weapon sockets. The GLB coordinate conversion maps it to +Y.
const MESH_OFFSET := Vector3(0.0, 0.16, 0.0)
const MUZZLE := Vector3(0.0, 0.075, 0.65)
# The source montage blends out over 0.25 s. Allow another 0.05 s in the Lab
# for the muzzle to follow the full-body handoff from raised aim to low carry.
const BLEND_OUT_SECONDS := 0.30
const LOCOMOTION := {
	"Idle": ["Player_Crossbow_Idle", 80, "5efd6e1c0d15066ab98c1bd31262b499435e125512a75a972ee87f1a74bd222a"],
	"Walk": ["Player_Crossbow_Walk", 26, "a291db024a4b3d10ec01ecc66b068c364fb8bc22d8a245150cbd69dce1af2e9c"],
	"Run": ["Player_Crossbow_Run", 13, "174a96fe4e65ea7e3d775beb5c51f5bd65e88d7761d46c7940e6b2ef509287f3"],
	"JumpTakeoff": ["Player_Crossbow_Jump", 11, "4a09c04eecc2baea728fc16d94532cf805fd830768189b6629a9b7975594bcee"],
	"JumpAirborne": ["Player_Crossbow_Jump_Loop", 25, "76266b95a62c0290ab3f38b25058e7fdc467d3c4c0b02db48329680d7a5fc2d2"],
	"JumpLanding": ["Player_Crossbow_Jump_Land", 9, "6df8515495b431b0c95e8a1daa84e9494c4cc06ae83a75e5fee894921b57b24d"],
}

var ammo := AMMO_MAX
var bolt_mesh: Mesh
var _recharge_remaining := 0.0
var _bolts: Array[Dictionary] = []
var _trails: Array[Dictionary] = []
var _trail_mesh := ImmediateMesh.new()
var _trail_renderer: MeshInstance3D
var impact_sparks: ImpactSparks
var _sweep_query := PhysicsShapeQueryParameters3D.new()
var _embedded: MultiMesh
var _embedded_arrows: Array[Dictionary] = []

static func icon() -> Texture2D:
	return Source.icon(DIRECTORY, "T_UI_RapidCrossbow_Unique_Icon",
		"0e457446c6ee40d65f7da6cc302602d7b96ac49f5f54bcbb38a7a20fbe77ae18")

static func load_mesh(actor: CharacterBody3D, root: String, recoil: bool) -> Mesh:
	var name := "SM_RapidCrossbow_Unique_F0" if recoil else "SM_RapidCrossbow_Unique_F1"
	var hash_value := "2a6f17f938b81f9c91a072b37dcbf6dabbed15999f7521437706fbe06037a6bc" if recoil \
		else "189bc26ff1e69cbe3175003c4e655d0dd3b659df85c99a14ecbf0124fb10b3af"
	return Source.load_mesh(actor, root, DIRECTORY, name, hash_value, "T_RapidCrossbow_Unique",
		"fcd97771bd152d8f3f1c772984de98eca0c68d0d48b9de0e8ac1a3bc4d64e501")

static func load_bolt(actor: CharacterBody3D, root: String) -> Mesh:
	return Source.load_mesh(actor, root, Source.SOURCE + "Actors/Equipment/RangedWeapons/Projectiles/",
		"SM_Arrow", "b68f888b24264d7db5b1fc1fe48852f33761cccc44e71ba7a65820f148cb33c3",
		"T_Arrow", "f0bf1ee4c8f45d2361fc73d0635bd8ac5ff9a10d0f63e5759959bef5e77bbd5d")

static func combat_profile(root: String) -> Dictionary:
	var result := Source.profile()
	var attack := Source.clip(root, CLIPS, "Player_CrossBow_Action", SHOT, 31, ACTION_HASH, "attack")
	var recovery := Source.clip(root, CLIPS, "Player_CrossBow_Action", RECOVERY, 31, ACTION_HASH, "recovery")
	result.additional_clips.append_array([attack, recovery])
	var shot := Source.window(attack, recovery, 1.0, 1.0 / 120.0, 1.0 / 60.0, ATTACK_PERIOD)
	shot.attack_duration = ATTACK_PERIOD
	shot.recovery_duration = RECOIL_END - ATTACK_PERIOD
	# The source has one shot animation. Combo reuses that slot for every round.
	result.windows = [shot, shot, shot]
	return result

static func interpolate_shot_poses(actor: CharacterBody3D) -> void:
	for key in [SHOT, RECOVERY]:
		var clip: Dictionary = actor.clips[key]
		var animation: Animation = actor.animation_player.get_animation(clip.action)
		for track in animation.get_track_count():
			var type := animation.track_get_type(track)
			if type != Animation.TYPE_POSITION_3D and type != Animation.TYPE_ROTATION_3D:
				continue
			# The verified export repeats every 30 Hz key four times at 120 Hz.
			# Keep the authored poses and sample continuously between them.
			var count := animation.track_get_key_count(track)
			for index in range(count - 1, 0, -1):
				if index % 4 != 0:
					animation.track_remove_key(track, index)
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)

static func load_locomotion(actor: CharacterBody3D, root: String) -> Dictionary:
	var entries: Array[Dictionary] = []
	for slot: String in LOCOMOTION:
		var source: Array = LOCOMOTION[slot]
		var is_jump := slot.begins_with("Jump")
		var category := "jump" if is_jump else ("idle" if slot == "Idle" else "locomotion")
		entries.append(Source.clip(root, CLIPS, source[0], "NativeCrossPollinator" + slot, source[1],
			source[2], category, not is_jump or slot == "JumpAirborne"))
	if not actor._load_private_clip_library(entries, LOCOMOTION_LIBRARY):
		return {}
	var slots := {}
	for slot: String in LOCOMOTION:
		slots[slot] = actor.clips["NativeCrossPollinator" + slot]
	slots.CombatReady = slots.Idle
	slots.InspectWeapon = slots.Idle
	var samples: Array[Dictionary] = []
	var keys := ["Idle", "Walk", "Run"]
	var inputs := [0.0, 0.3, 1.2]
	for i in keys.size():
		var clip: Dictionary = slots[keys[i]]
		samples.append({"semantic": keys[i], "source_name": clip.source_name,
			"input": inputs[i], "duration": clip.duration, "rate": 1.0})
	var gait := SourceGait.new()
	if not gait.setup(actor.skeleton, actor.animation_player, slots, {
		"schema": "md2-private-source-gait/1", "base_speed_cm_s": 700.0, "input_floor": 0.2, "samples": samples,
	}):
		return {}
	return {"clips": slots, "gait": gait}

func _ready() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = BOLT_RADIUS
	_sweep_query.shape = sphere
	var trail_material := ShaderMaterial.new()
	trail_material.shader = TRAIL_SHADER
	_trail_renderer = MeshInstance3D.new()
	_trail_renderer.name = "ArrowTrail"
	_trail_renderer.mesh = _trail_mesh
	_trail_renderer.material_override = trail_material
	_trail_renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_renderer.hide()
	add_child(_trail_renderer)
	var sparks := ImpactSparks.new()
	sparks.name = "ArrowImpactSparks"
	if sparks.setup(Source.research_root()):
		impact_sparks = sparks
		add_child(sparks)
	else:
		sparks.free()
	if bolt_mesh != null:
		_embedded = MultiMesh.new()
		_embedded.transform_format = MultiMesh.TRANSFORM_3D
		_embedded.mesh = bolt_mesh
		_embedded.instance_count = EMBEDDED_CAPACITY
		_embedded.visible_instance_count = 0
		var renderer := MultiMeshInstance3D.new()
		renderer.name = "EmbeddedArrows"
		renderer.multimesh = _embedded
		renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(renderer)
	set_physics_process(false)

func fire(origin: Vector3, direction: Vector3, serial: int, clearance_start: Vector3) -> bool:
	if ammo == 0:
		return false
	ammo -= 1
	_recharge_remaining = RECHARGE_DELAY + RECHARGE_PERIOD
	ammo_changed.emit(ammo)
	shot_fired.emit(origin)
	var obstruction := _sweep_bolt(get_world_3d().direct_space_state, clearance_start, origin, WORLD_MASK)
	if not obstruction.is_empty():
		_report_impact(obstruction, direction, serial)
		set_physics_process(true)
		return true
	var bolt := MeshInstance3D.new()
	bolt.mesh = bolt_mesh
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bolt)
	bolt.global_position = origin
	bolt.look_at(origin + direction, Vector3.UP if absf(direction.y) < 0.999 else Vector3.FORWARD, true)
	bolt.rotate_object_local(Vector3.UP, -PI * 0.5)
	bolt.scale = Vector3.ONE * BOLT_MESH_SCALE
	bolt.reset_physics_interpolation()
	var trail := {"origin": origin, "direction": direction, "distance": 0.0, "stopped": false, "tail_age": 0.0}
	_trails.append(trail)
	_bolts.append({"node": bolt, "direction": direction, "life": BOLT_LIFETIME, "serial": serial, "trail": trail})
	set_physics_process(true)
	bolt_launched.emit(bolt)
	return true

func reset() -> void:
	for bolt: Dictionary in _bolts:
		_remove_bolt(bolt.node)
	_bolts.clear()
	_trails.clear()
	_trail_mesh.clear_surfaces()
	_trail_renderer.hide()
	if impact_sparks != null:
		impact_sparks.clear()
	_embedded_arrows.clear()
	if _embedded != null:
		_embedded.visible_instance_count = 0
	_recharge_remaining = 0.0
	ammo = AMMO_MAX
	ammo_changed.emit(ammo)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not _embedded_arrows.is_empty():
		_update_embedded_arrows(delta)
	if ammo < AMMO_MAX:
		_recharge_remaining -= delta
		if _recharge_remaining <= 0.000001:
			_recharge_remaining += RECHARGE_PERIOD
			ammo += 1
			ammo_changed.emit(ammo)
	var space := get_world_3d().direct_space_state
	for trail in _trails:
		if trail.stopped:
			trail.tail_age += delta
	for index in range(_bolts.size() - 1, -1, -1):
		var bolt := _bolts[index]
		var node: MeshInstance3D = bolt.node
		var start := node.global_position
		var end := start + Vector3(bolt.direction) * BOLT_SPEED * minf(delta, bolt.life)
		var hit := _sweep_bolt(space, start, end, BOLT_MASK)
		var trail: Dictionary = bolt.trail
		var direction: Vector3 = bolt.direction
		bolt.life -= delta
		if not hit.is_empty() or bolt.life <= 0.000001:
			var endpoint: Vector3 = hit.get("position", end)
			var travel := (endpoint - start).dot(direction)
			trail.distance += clampf(travel, 0.0, start.distance_to(end) + BOLT_RADIUS)
			trail.stopped = true
			trail.tail_age = maxf(0.0, delta - travel / BOLT_SPEED)
			_bolts.remove_at(index)
			_remove_bolt(node)
			if not hit.is_empty():
				_embed_on_terrain(hit, bolt.direction)
				_report_impact(hit, direction, bolt.serial)
		else:
			node.global_position = end
			trail.distance += start.distance_to(end)
	if not _trails.is_empty():
		_update_trails()
	var sparks_active := impact_sparks != null and impact_sparks.advance(delta)
	if ammo == AMMO_MAX and _bolts.is_empty() and _embedded_arrows.is_empty() and _trails.is_empty() and not sparks_active:
		set_physics_process(false)

func _report_impact(hit: Dictionary, direction: Vector3, serial: int) -> void:
	if impact_sparks != null:
		impact_sparks.burst(hit.position, direction, hit.normal)
	bolt_impact.emit(hit, direction, serial)

func _update_trails() -> void:
	_trail_mesh.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	var to_local_space := global_transform.affine_inverse()
	var has_surface := false
	for index in range(_trails.size() - 1, -1, -1):
		var trail := _trails[index]
		var age: float = trail.tail_age
		if age >= TRAIL_LIFETIME:
			_trails.remove_at(index)
			continue
		var duration := minf(float(trail.distance) / BOLT_SPEED, TRAIL_FADE_END_AGE - age)
		if camera == null or duration <= 0.00001:
			continue
		var direction: Vector3 = trail.direction
		var head := Vector3(trail.origin) + direction * float(trail.distance)
		var sideways := direction.cross(camera.global_basis.z).normalized()
		if sideways.is_zero_approx():
			sideways = camera.global_basis.x
		var segments := ceili(duration / TRAIL_SAMPLE_SECONDS)
		if not has_surface:
			_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			has_surface = true
		var previous_point := to_local_space * head
		var lateral := to_local_space.basis * sideways
		var previous_width := TRAIL_WIDTH * 0.5 * (1.0 - 0.5 * age / TRAIL_LIFETIME)
		var previous_alpha := _trail_opacity(age / TRAIL_LIFETIME)
		for sample in range(1, segments + 1):
			var seconds_back := duration * float(sample) / segments
			var normalized_age := (age + seconds_back) / TRAIL_LIFETIME
			var width := TRAIL_WIDTH * 0.5 * (1.0 - 0.5 * normalized_age)
			var opacity := _trail_opacity(normalized_age)
			var point := to_local_space * (head - direction * BOLT_SPEED * seconds_back)
			var near_left := previous_point - lateral * previous_width
			var near_right := previous_point + lateral * previous_width
			var far_left := point - lateral * width
			var far_right := point + lateral * width
			_add_trail_vertex(near_left, previous_alpha)
			_add_trail_vertex(near_right, previous_alpha)
			_add_trail_vertex(far_left, opacity)
			_add_trail_vertex(near_right, previous_alpha)
			_add_trail_vertex(far_right, opacity)
			_add_trail_vertex(far_left, opacity)
			previous_point = point
			previous_width = width
			previous_alpha = opacity
	if has_surface:
		_trail_mesh.surface_end()
	_trail_renderer.visible = has_surface

func _add_trail_vertex(point: Vector3, opacity: float) -> void:
	_trail_mesh.surface_set_color(Color(1.0, 1.0, 1.0, opacity))
	_trail_mesh.surface_add_vertex(point)

static func _trail_opacity(normalized_age: float) -> float:
	# The two line segments reproduce the cooked opacity LUT.
	return maxf(0.0, maxf(1.0 - 4.0 * normalized_age, 0.3 - 0.5 * normalized_age))

func _embed_on_terrain(hit: Dictionary, direction: Vector3) -> void:
	var collider := hit.collider as StaticBody3D
	if _embedded == null or collider == null or (collider.collision_layer & WORLD_MASK) == 0:
		return
	if _embedded_arrows.size() == EMBEDDED_CAPACITY:
		_embedded_arrows.pop_front()
	var up := Vector3.UP if absf(direction.y) < 0.999 else Vector3.FORWARD
	var basis := Basis.looking_at(direction, up, true) * Basis(Vector3.UP, -PI * 0.5)
	var pose := Transform3D(basis, Vector3(hit.position) - direction * EMBEDDED_OFFSET)
	_embedded_arrows.append({"pose": global_transform.affine_inverse() * pose, "age": 0.0})

func _update_embedded_arrows(delta: float) -> void:
	var index := 0
	while index < _embedded_arrows.size():
		var arrow := _embedded_arrows[index]
		arrow.age += delta
		if arrow.age >= EMBEDDED_WOBBLE_SECONDS:
			_embedded_arrows.remove_at(index)
			continue
		var pose: Transform3D = arrow.pose
		var phase := float(arrow.age) / EMBEDDED_WOBBLE_SECONDS
		# The native component supplies the duration and scale. This damped
		# motion and one-second prop display are MechanicLab approximations.
		var angle := deg_to_rad(EMBEDDED_WOBBLE_SCALE) * sin(TAU * 6.0 * phase) * pow(1.0 - phase, 2.0)
		pose.basis = pose.basis * Basis(Vector3.UP, angle) * Basis.from_scale(Vector3.ONE * EMBEDDED_SCALE)
		_embedded.set_instance_transform(index, pose)
		index += 1
	_embedded.visible_instance_count = _embedded_arrows.size()

func _sweep_bolt(space: PhysicsDirectSpaceState3D, start: Vector3, end: Vector3, mask: int) -> Dictionary:
	_sweep_query.collision_mask = mask
	_sweep_query.transform = Transform3D(Basis.IDENTITY, start)
	_sweep_query.motion = Vector3.ZERO
	# Motion casts ignore shapes already overlapping the sphere.
	var hit := space.get_rest_info(_sweep_query)
	if hit.is_empty():
		var travel := end - start
		_sweep_query.motion = travel
		var fractions := space.cast_motion(_sweep_query)
		# Probe just inside contact to obtain its collider and surface point.
		_sweep_query.motion = Vector3.ZERO
		var distance := travel.length()
		var contact_distance := minf(distance, distance * fractions[1] + CONTACT_PROBE_DISTANCE)
		_sweep_query.transform.origin = start + travel.normalized() * contact_distance
		hit = space.get_rest_info(_sweep_query)
	if not hit.is_empty():
		hit.collider = instance_from_id(hit.collider_id)
		hit.position = hit.point
	return hit

func _remove_bolt(bolt: MeshInstance3D) -> void:
	bolt.hide()
	bolt.queue_free()
	bolt_ended.emit(bolt)
