extends Node3D
## Spawn and hit routing for private MD2 zombies in MechanicLab.

signal sabre_contact(point: Vector3, direction: Vector3, clip: String, index: int, serial: int, lethal: bool)

const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")
const Feedback := preload("res://scripts/mechanic_lab_zombie_feedback.gd")
const SOURCE_DIR := "extracted/2026-10-25 19-26-25/Game/Spicewood"
const ZOMBIE_DIR := "Art/Characters/Enemies/Zombie"
const CLIP_HASHES := {
	&"Zombie_Idle": "e55529262e3f6f93e07e5a89f50c0e6dcf8375984285d48d5064475132659f0f",
	&"Zombie_Spawn": "c21a5172d02ec26d6b834902fe546f2f461fcb167d6d60d65d07b22c7e592c74",
	&"Zombie_Walk": "ccd26d9c5dedc86432f442ebf1cead14b2d3efac030b6ab0363a8dd1bcf6e7b6",
	&"Zombie_Walk_Variant1": "001ea35703d08b6eb41ca9fafbab91245453b31a927bfe9a8fb7497b9020d059",
	&"Zombie_Walk_Variant2": "7785f1bd55e988cbedad72203c41f8efe9235d6820724b795b6add229578824e",
	&"Zombie_BasicAttack": "722337a57294a4551a0ef0df5cd014784baf94298401a685dbc467a72875feb6",
	&"Zombie_Staggered": "e25142f7993371ecb37c1e5bf5705cf90429ef616dfad89dccb36270fd0e5582",
	&"Zombie_Novelty": "a0fe0925857a2a481105d5e933ffc45575011056612ad60f98dfa439d7d0cf3d",
}
const SKIN_HASH := "1569dd314999fa126dbea34a3ea44112e79c2737f519b87ab8f20be29ad949ce"
const DIGIT_HASH := "7fa2e2801d368ee8f1a61c81bf736c60a250f42bd343ed97b71ceb9000e9beef"
const FLOOR_LIMIT := 49.0
const SPACING := 1.25
const SABRE_DAMAGE := [20, 20, 28]
const BLADE_RADIUS := 0.14

var _visual: PackedScene
var _digits: Array[Texture2D]
var _spawn_serial := 0
var _hit_windows: Dictionary[String, Vector2] = {}
var _attack_serial := -1
var _previous_base := Vector3.ZERO
var _previous_tip := Vector3.ZERO
var _hit_targets: Dictionary[int, bool] = {}

func setup_combat(clips: Dictionary, native_windows: Array) -> void:
	for clip: String in clips:
		var data: Dictionary = clips[clip]
		if data.category == "attack" or clip == "AirAttack":
			var trail: Array = data.vfx_window
			_hit_windows[clip] = Vector2(float(trail[0]), float(trail[1]))
	for index in native_windows.size():
		var native: Dictionary = native_windows[index]
		var clip: String = native.get("attack_key", "Attack%d" % (index + 1))
		var trail: Array = native.get("trail_window", clips[clip].vfx_window)
		# The source contact key anchors the start. The trail tail bounds the lab sweep.
		_hit_windows[clip] = Vector2(minf(float(trail[0]), float(native.melee)), maxf(float(trail[1]), float(native.melee)))

func spawn(player: CharacterBody3D, facing: Basis, effects: Node3D) -> bool:
	if _visual == null:
		_load_assets()
	if _visual == null:
		return false
	var floor_position := Vector3(player.global_position.x, 0.0, player.global_position.z)
	var point := _find_spawn_point(floor_position, facing)
	if not point.is_finite():
		return false

	var zombie := Zombie.new()
	zombie.name = "Zombie"
	zombie.position = point
	zombie.configure(_visual.instantiate(), player, effects, _digits, _spawn_serial)
	_spawn_serial += 1
	add_child(zombie, true)
	zombie.look_at(floor_position, Vector3.UP, true)
	return true

func _find_spawn_point(player_position: Vector3, facing: Basis) -> Vector3:
	var preferred := player_position + facing * Vector3(0.42, 0.0, 1.78)
	preferred.x = clampf(preferred.x, -FLOOR_LIMIT, FLOOR_LIMIT)
	preferred.z = clampf(preferred.z, -FLOOR_LIMIT, FLOOR_LIMIT)
	if _spawn_point_clear(preferred, player_position):
		return preferred
	for ring in range(1, 80):
		for slot in 8 * ring:
			var angle := TAU * slot / (8 * ring)
			var offset := Vector3(cos(angle), 0.0, sin(angle)) * SPACING * ring
			var point := preferred + facing * offset
			if absf(point.x) <= FLOOR_LIMIT and absf(point.z) <= FLOOR_LIMIT and _spawn_point_clear(point, player_position):
				return point
	return Vector3.INF

func _spawn_point_clear(point: Vector3, player_position: Vector3) -> bool:
	if point.distance_squared_to(player_position) < SPACING * SPACING:
		return false
	for zombie in get_children():
		if zombie.health > 0 and point.distance_squared_to(zombie.position) < SPACING * SPACING:
			return false
	return true

func sample_sabre(index: int, clip: String, source_time: float, base: Vector3, tip: Vector3, serial: int) -> void:
	var window: Vector2 = _hit_windows.get(clip, Vector2(-1.0, -1.0))
	if source_time < window.x or source_time > window.y:
		return
	if serial != _attack_serial:
		_attack_serial = serial
		_previous_base = base
		_previous_tip = tip
		_hit_targets.clear()
	for zombie: Zombie in get_children():
		var id := zombie.get_instance_id()
		if zombie.health <= 0 or zombie.is_queued_for_deletion() or _hit_targets.has(id):
			continue
		var low := zombie.global_position + Vector3.UP * Zombie.HIT_RADIUS
		var high := zombie.global_position + Vector3.UP * (Zombie.HEIGHT - Zombie.HIT_RADIUS)
		var reach := Zombie.HIT_RADIUS + BLADE_RADIUS
		# Check the current blade and both diagonals of the surface swept since the previous pose.
		var contact := _blade_contact(base, tip, low, high, reach)
		if not contact.is_finite():
			contact = _blade_contact(_previous_base, tip, low, high, reach)
		if not contact.is_finite():
			contact = _blade_contact(base, _previous_tip, low, high, reach)
		if contact.is_finite():
			var direction := zombie.global_position - zombie.target.global_position
			_hit_targets[id] = true
			zombie.take_hit(SABRE_DAMAGE[clampi(index, 0, SABRE_DAMAGE.size() - 1)], direction)
			sabre_contact.emit(contact, direction.normalized(), clip, index, serial, zombie.health <= 0)
	_previous_base = base
	_previous_tip = tip

func _blade_contact(a: Vector3, b: Vector3, low: Vector3, high: Vector3, reach: float) -> Vector3:
	var closest := Geometry3D.get_closest_points_between_segments(a, b, low, high)
	return closest[0] if closest[0].distance_squared_to(closest[1]) <= reach * reach else Vector3.INF

func _load_assets() -> void:
	if not OS.has_feature("editor"):
		return
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.simplify_path().replace("\\", "/").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower()
	if not root.is_absolute_path() or root.begins_with("res://") or root.begins_with("user://") \
		or root.to_lower() == project or root.to_lower().begins_with(project + "/"):
		return
	var source := root.path_join(SOURCE_DIR)
	var directory := source.path_join(ZOMBIE_DIR)
	var digit_path := source.path_join("Cues/UI/T_DamageNumbers.png")
	if not _verified(directory.path_join("T_Zombie.png"), SKIN_HASH) or not _verified(digit_path, DIGIT_HASH):
		return
	for clip: StringName in CLIP_HASHES:
		if not _verified(_clip_path(directory, clip), CLIP_HASHES[clip]):
			return

	var model := _import_gltf(_clip_path(directory, Zombie.IDLE))
	if model == null:
		return
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player != null and player.has_animation(Zombie.IDLE) and _add_clips(directory, player):
		_digits = Feedback.load_digits(digit_path)
		var packed := PackedScene.new()
		if _digits.size() == 10 and packed.pack(model) == OK:
			_visual = packed
	model.free()

func _add_clips(directory: String, player: AnimationPlayer) -> bool:
	var library := player.get_animation_library(&"")
	player.get_animation(Zombie.IDLE).loop_mode = Animation.LOOP_LINEAR
	for name: StringName in CLIP_HASHES:
		if name == Zombie.IDLE:
			continue
		var imported := _import_gltf(_clip_path(directory, name))
		if imported == null:
			return false
		var clip_player := imported.get_node_or_null("AnimationPlayer") as AnimationPlayer
		var clip := clip_player.get_animation(name) if clip_player != null and clip_player.has_animation(name) else null
		imported.free()
		if clip == null:
			return false
		if name in Zombie.WALK_CLIPS:
			clip.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(name, clip)
	return true

func _clip_path(directory: String, clip: StringName) -> String:
	return directory.path_join("Animations/%s.glb" % clip)

func _verified(path: String, expected_hash: String) -> bool:
	return FileAccess.file_exists(path) and FileAccess.get_sha256(path) == expected_hash

func _import_gltf(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state) as Node3D
