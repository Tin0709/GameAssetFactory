extends Node
## Connects the shared terrain shadow cache to the WorldMap's existing lighting owners.

const Cache := preload("res://scripts/world_map_far_terrain_shadow.gd")
const Receivers := preload("res://scripts/world_map_far_shadow_receivers.gd")

var _world: Node
var _cache: Cache
var _receivers := Receivers.new()
var enabled := true
var prepare_usec := 0


func configure(world: Node, directory: String) -> bool:
	var cache := Cache.new()
	if not cache.configure(world.get_node("Sun"), world.get_node("Camera3D"),
			world.geometry._cutaway_chunks, directory, world.map_layout_path):
		cache.free()
		return false
	if not cache.register_globals():
		cache.free()
		return false
	_world = world
	_cache = cache
	if is_instance_valid(world.showcase.mist):
		_receivers.mist_variant = world.showcase.mist.material_variant
	var started := Time.get_ticks_usec()
	_receivers.prepare(world.showcase.far_terrain_shading_materials())
	prepare_usec = Time.get_ticks_usec() - started
	add_child(cache)
	process_priority = 110 # After the atmosphere has chosen its material variants.
	return true


func _process(delta: float) -> void:
	if _cache == null or not is_instance_valid(_world):
		return
	var player: CharacterBody3D = _world.player
	var minute: float = _world.showcase.hour * 60.
	var supported: bool = enabled and _world.look.stage == 2 and _world.view_mode == "gameplay" \
			and _world.look.direct_clouds_active() and _world.showcase.forest_active() \
			and _world.showcase.atmosphere_review == "combined" and not _world.showcase._balanced_preview
	var wants_receivers := supported and _cache.wants_receivers(player.global_position, minute)
	if not wants_receivers:
		_cache.update_shadow(delta, player.global_position, player.velocity, minute, false)
		_release_receivers()
		return
	# A frame with native casters lets the renderer see the material variant before switching shadows.
	var changed := _receivers.bind(_world.showcase.far_terrain_shading_materials())
	_cache.update_shadow(delta, player.global_position, player.velocity, minute, not changed and _receivers.bound_count > 0)


func _release_receivers() -> void:
	if _receivers.release() and is_instance_valid(_world.showcase.mist):
		_world.showcase.mist._process(0.)


func snapshot() -> Dictionary:
	var result := _cache.snapshot() if _cache != null else {}
	result["receivers"] = _receivers.bound_count
	return result


func _exit_tree() -> void:
	_receivers.release()
