extends RefCounted
## Editor-only decorative MD2 reference. The level supplies the placement.

const SOURCE_DIR := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Environment/Generic/Props/ReplayStatue"
const MESH := "SM_ArenaReplayStatue.glb"
const BASE := "T_ArenaReplayStatue_D.png"
const PACKED := "T_ArenaReplay__SE1.png"
const SOURCES := {
	MESH: "4c8b635e7e260fd051df8e3c3a59a1e54090cc67c77a70b46b747205d9828f73",
	BASE: "ce8f05244a614533daaaa6cd6a0e88ac41ced7a04e3a1011d7d45c896ddc16a6",
	PACKED: "26f61579d04c396273415976688cb9e5470653018cc80609085f1dafb26f89b5",
}
const MATERIAL := preload("res://materials/world_map_forest_replay.gdshader")

var fixture: Node3D
var surface_field: ImageTexture3D
var _material: ShaderMaterial
var _attempted := false
var _surface_attempted := false
var _submitted_surface_gain := 0.
var _site := Vector2.INF
var _submitted := Vector2.INF
var _submitted_bounce := Vector4.ZERO

static func evening_weight(hour: float) -> float:
	if not is_finite(hour):
		return 0.
	var h := fposmod(hour, 24.)
	return 1. - smoothstep(3.5, 5.0, h) if h < 12. else smoothstep(18.25, 19.5, h)

func available(world) -> bool:
	return world != null and world.forest_replay_site.is_finite() and OS.has_feature("editor") \
		and RenderingServer.get_current_rendering_method() == "mobile" and RenderingServer.get_rendering_device() != null \
		and (not _attempted or is_instance_valid(fixture))

func update(world, phase: float, strength: float, use_steps: bool) -> void:
	var state := Vector2(phase, phase * strength) if strength > 0. else Vector2.ZERO
	if state.y > 0. and not _attempted and available(world):
		_attempted = true
		_load(world)
	if not is_instance_valid(fixture):
		return
	var site: Vector2 = world.forest_replay_steps_site if use_steps and has_step_site(world) else world.forest_replay_site
	if site != _site:
		fixture.position = Vector3(site.x, world.surface_height(site.x, site.y) + .01, site.y)
		_site = site
	if state == _submitted:
		return
	_submitted = state
	fixture.visible = state.y > 0.
	_material.set_shader_parameter("radiant_strength", 3.0 * state.y)
	_material.set_shader_parameter("phase_coverage", state.x)

func has_step_site(world) -> bool:
	if world == null or not world.forest_replay_steps_site.is_finite():
		return false
	var site: Vector2 = world.forest_replay_steps_site
	return is_finite(world.surface_height(site.x, site.y))

func publish_bounce(strength: float) -> void:
	var state := Vector4.ZERO
	if strength > 0.0 and is_instance_valid(fixture) and fixture.visible:
		var center := fixture.global_position + Vector3.UP * 1.42
		state = Vector4(center.x, center.y, center.z, 0.4 * _submitted.y * strength)
	if state == _submitted_bounce:
		return
	_submitted_bounce = state
	RenderingServer.global_shader_parameter_set("gaf_replay_bounce",state)

func surface_available(world) -> bool:
	return available(world) and has_step_site(world) and not world.forest_replay_surface_path.is_empty() \
		and (not _surface_attempted or surface_field != null)

func publish_surface(world, strength: float) -> void:
	var gain := 0.0
	var source: Vector3 = world.forest_replay_surface_source
	var bounce_center := Vector3(_submitted_bounce.x, _submitted_bounce.y, _submitted_bounce.z)
	if strength > 0. and _submitted_bounce.w > 0. and _site == world.forest_replay_steps_site \
			and source.is_finite() and bounce_center.distance_squared_to(source) < 0.0001 and surface_available(world):
		if not _surface_attempted:
			_surface_attempted = true
			_load_surface(world)
		if surface_field != null:
			gain = strength
	if gain == _submitted_surface_gain:
		return
	_submitted_surface_gain = gain
	var origin: Vector3 = world.forest_replay_surface_origin
	RenderingServer.global_shader_parameter_set("gaf_replay_surface", Vector4(origin.x, origin.y, origin.z, gain))

func release_surface() -> void:
	_submitted_surface_gain = 0.
	RenderingServer.global_shader_parameter_set("gaf_replay_surface", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("gaf_replay_surface_field", null)
	surface_field = null

func _load_surface(world) -> void:
	var root := _research_root()
	var relative: String = world.forest_replay_surface_path.simplify_path()
	var extent: Vector3i = world.forest_replay_surface_extent
	if root.is_empty() or relative.is_absolute_path() or relative.begins_with("..") \
			or not world.forest_replay_surface_origin.is_finite() \
			or mini(extent.x, mini(extent.y, extent.z)) < 2 or maxi(extent.x, maxi(extent.y * 6, extent.z)) > 256:
		return
	var path := root.path_join(relative)
	if world.forest_replay_surface_sha256.length() != 64 or world.forest_replay_surface_map_sha256.length() != 64 \
			or FileAccess.get_sha256(world.DATA) != world.forest_replay_surface_map_sha256 \
			or FileAccess.get_sha256(path) != world.forest_replay_surface_sha256:
		return
	var width := extent.x
	var height := extent.y * 6
	var stride := width * height * 2
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() != stride * extent.z:
		return
	var slices: Array[Image] = []
	for i in extent.z:
		slices.append(Image.create_from_data(width, height, false, Image.FORMAT_RG8, data.slice(i * stride, (i + 1) * stride)))
	var texture := ImageTexture3D.new()
	if texture.create(Image.FORMAT_RG8, width, height, extent.z, false, slices) == OK:
		surface_field = texture
		RenderingServer.global_shader_parameter_set("gaf_replay_surface_field", texture)

func _research_root() -> String:
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.simplify_path().replace("\\", "/").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/").to_lower()
	if not root.is_absolute_path() or root.begins_with("res://") or root.begins_with("user://") \
		or root.to_lower() == project or root.to_lower().begins_with(project + "/"):
		return ""
	return root

func _load(world) -> void:
	var root := _research_root()
	if root.is_empty():
		return
	var directory := root.path_join(SOURCE_DIR)
	for source: String in SOURCES:
		if FileAccess.get_sha256(directory.path_join(source)) != SOURCES[source]:
			return
	var site: Vector2 = world.forest_replay_site
	var ground: float = world.surface_height(site.x, site.y)
	if not is_finite(ground):
		return
	var base := Image.load_from_file(directory.path_join(BASE))
	var packed := Image.load_from_file(directory.path_join(PACKED))
	if base == null or packed == null or base.get_size() != Vector2i(64, 64) or packed.get_size() != base.get_size():
		return
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(directory.path_join(MESH), state) != OK:
		return
	var imported := doc.generate_scene(state)
	if imported == null:
		return
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1 or meshes[0].mesh == null or meshes[0].mesh.get_surface_count() != 1 \
		or not imported.find_children("*", "CollisionObject3D", true, false).is_empty():
		imported.free()
		return
	_material = ShaderMaterial.new()
	_material.shader = MATERIAL
	_material.set_shader_parameter("base_atlas", ImageTexture.create_from_image(base))
	_material.set_shader_parameter("packed_atlas", ImageTexture.create_from_image(packed))
	meshes[0].material_override = _material
	meshes[0].mesh.surface_set_material(0, null)
	meshes[0].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fixture = imported
	fixture.name = "PrivateForestReplayStatue"
	fixture.position = Vector3(site.x, ground + .01, site.y)
	_site = site
	fixture.rotation_degrees.y = 20.0
	fixture.hide()
	world.add_child(fixture)
