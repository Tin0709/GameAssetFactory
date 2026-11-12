extends Node3D
## Stationary combat targets. Only the verified private MD2 model and clips are loaded.

const SOURCE_DIR := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Characters/Enemies/Zombie"
const SOURCE_FILES := {
	"Animations/Zombie_Idle.glb": "e55529262e3f6f93e07e5a89f50c0e6dcf8375984285d48d5064475132659f0f",
	"Animations/Zombie_Staggered.glb": "e25142f7993371ecb37c1e5bf5705cf90429ef616dfad89dccb36270fd0e5582",
	"T_Zombie.png": "1569dd314999fa126dbea34a3ea44112e79c2737f519b87ab8f20be29ad949ce",
}
const IDLE := &"Zombie_Idle"
const STAGGERED := &"Zombie_Staggered"
const FLOOR_LIMIT := 49.0
const SPACING := 1.25
const TARGET_RADIUS := 0.48

class Zombie extends StaticBody3D:
	var hits_left := 3
	var animation: AnimationPlayer

	func take_hit() -> void:
		hits_left -= 1
		if hits_left == 0:
			queue_free()
		else:
			animation.stop()
			animation.play(STAGGERED)
			animation.queue(IDLE)

var _visual: PackedScene

func spawn(player_position: Vector3, facing: Basis) -> bool:
	if _visual == null:
		_visual = _load_visual()
	if _visual == null:
		return false
	var floor_position := Vector3(player_position.x, 0.0, player_position.z)
	var point := _find_spawn_point(floor_position, facing)
	if not point.is_finite():
		return false

	var zombie := Zombie.new()
	zombie.name = "Zombie"
	zombie.position = point
	var model := _visual.instantiate()
	zombie.add_child(model)
	zombie.animation = model.get_node("AnimationPlayer")
	var capsule := CapsuleShape3D.new()
	capsule.radius = TARGET_RADIUS
	capsule.height = 1.9
	var collision := CollisionShape3D.new()
	collision.position.y = capsule.height * 0.5
	collision.shape = capsule
	zombie.add_child(collision)
	add_child(zombie, true)
	zombie.look_at(floor_position, Vector3.UP, true)
	zombie.animation.play(IDLE)
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
		if point.distance_squared_to(zombie.position) < SPACING * SPACING:
			return false
	return true

func on_sabre_impact(_index: int, base: Vector3, tip: Vector3, _serial: int) -> void:
	for zombie: Zombie in get_children():
		if zombie.is_queued_for_deletion():
			continue
		var low := zombie.global_position + Vector3.UP * TARGET_RADIUS
		var high := zombie.global_position + Vector3.UP * (1.9 - TARGET_RADIUS)
		var closest := Geometry3D.get_closest_points_between_segments(base, tip, low, high)
		if closest[0].distance_squared_to(closest[1]) <= TARGET_RADIUS * TARGET_RADIUS:
			zombie.take_hit()

func _load_visual() -> PackedScene:
	if not OS.has_feature("editor"):
		return null
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.simplify_path().replace("\\", "/").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower()
	if not root.is_absolute_path() or root.begins_with("res://") or root.begins_with("user://") \
		or root.to_lower() == project or root.to_lower().begins_with(project + "/"):
		return null
	var directory := root.path_join(SOURCE_DIR)
	for file: String in SOURCE_FILES:
		var path := directory.path_join(file)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != SOURCE_FILES[file]:
			return null

	var idle_model := _import_gltf(directory.path_join("Animations/Zombie_Idle.glb"))
	var stagger_model := _import_gltf(directory.path_join("Animations/Zombie_Staggered.glb"))
	var packed: PackedScene
	if idle_model != null and stagger_model != null:
		var idle_player := idle_model.get_node_or_null("AnimationPlayer") as AnimationPlayer
		var stagger_player := stagger_model.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if idle_player != null and idle_player.has_animation(IDLE) and stagger_player != null and stagger_player.has_animation(STAGGERED):
			idle_player.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
			idle_player.get_animation_library(&"").add_animation(STAGGERED, stagger_player.get_animation(STAGGERED))
			packed = PackedScene.new()
			if packed.pack(idle_model) != OK:
				packed = null
	if idle_model != null:
		idle_model.free()
	if stagger_model != null:
		stagger_model.free()
	return packed

func _import_gltf(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state) as Node3D
