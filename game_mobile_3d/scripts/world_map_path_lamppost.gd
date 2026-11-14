extends RefCounted
## Private ForestA1 prop. The map supplies placement and the biome supplies its light phase.

const SOURCE := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Environment/ForestA1/Lighting/LampPost"
const MESH := "SM_SF_Lampost_01.glb"
const ALBEDO := "T_ForestLightProps_01_D.png"
const PACKED := "T_ForestLantern__SE1.png"
const DIGESTS := {
	MESH: "d3d2249cfd8062e2457add0aba689c9a5cda29b64f6eece40867f0c7d9600001",
	ALBEDO: "c4f975d4f433f59b9b0c426547926d70bdb3d27a1b5e98a797b7a0ec7ea8d1aa",
	PACKED: "bd53313593946764a22414b65702f587d18ee04f12059dc85e2e79a5d8c8f392",
}
const LIGHT_COLOR := Color(1., .467783828, 0.)
const LIGHT_ENERGY_PER_STRENGTH := .9 / .7
const EMISSION_PER_STRENGTH := 3.8 / .7
const SHAFT_SIZE := Vector3(.25, 2.8, .25)
const SHAFT_CENTER := Vector3(.125, 1.4, .125)
const FIXTURE := preload("res://scripts/world_map_forest_path_light.gd")

var fixture: Node3D
var light: OmniLight3D
var material: ShaderMaterial
var support: StaticBody3D
var _attempted := false
var _submitted_output := 0.

func update(world: Node3D, enabled: bool, phase: float, strength: float) -> bool:
	if enabled and not _attempted:
		_attempted = true
		_load(world)
	if not is_instance_valid(fixture):
		return false
	if fixture.visible != enabled:
		fixture.visible = enabled
	var output := phase * strength if enabled else 0.
	if output != _submitted_output:
		_submitted_output = output
		light.light_energy = output * LIGHT_ENERGY_PER_STRENGTH
		material.set_shader_parameter("lamp_emission", output * EMISSION_PER_STRENGTH)
	if not enabled:
		support.collision_layer = 0
	elif support.collision_layer == 0 and _player_clear(world.player):
		support.collision_layer = 1
	return enabled

func _player_clear(player: CharacterBody3D) -> bool:
	var offset := support.to_local(player.global_position)
	var shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null:
		shape = player.get_node_or_null("BodyCollision") as CollisionShape3D
	var radius := .5
	if shape != null and shape.shape is CapsuleShape3D:
		radius = shape.shape.radius
	var clearance := Vector2(absf(offset.x), absf(offset.z)) - Vector2(SHAFT_SIZE.x, SHAFT_SIZE.z) * .5
	return maxf(clearance.x, clearance.y) > radius + player.safe_margin or offset.y > SHAFT_SIZE.y * .5

func is_compatible_secondary(candidate: Light3D) -> bool:
	return candidate == light and candidate.light_color.b == 0.0

func air_parameters(gain: float, _beam := Vector4.ZERO) -> PackedFloat32Array:
	if gain <= 0. or not is_instance_valid(light) or not fixture.visible or light.light_energy <= 0.:
		return PackedFloat32Array()
	var at := light.global_position
	return PackedFloat32Array([at.x, at.y, at.z, light.omni_range,
		LIGHT_COLOR.r, LIGHT_COLOR.g, LIGHT_COLOR.b, light.light_energy * .19 * gain, 0., 0., 0., 0.])

func _load(world: Node3D) -> void:
	var anchor: Vector2 = world.biome_path_lamp_xz
	var yaw_degrees: float = world.biome_path_lamp_yaw_degrees
	if not anchor.is_finite() or not is_finite(yaw_degrees) or RenderingServer.get_rendering_device() == null:
		return
	var root := FIXTURE.research_root()
	if root.is_empty():
		return
	var dir := root.path_join(SOURCE)
	for name: String in DIGESTS:
		var path := dir.path_join(name)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != DIGESTS[name]:
			return
	var angle := deg_to_rad(yaw_degrees)
	var seat := anchor + Vector2(SHAFT_CENTER.x, SHAFT_CENTER.z).rotated(-angle)
	var ground: float = world.surface_height(seat.x, seat.y)
	if not is_finite(ground):
		return
	for corner in [Vector2.ZERO, Vector2(.25, 0.), Vector2(0., .25), Vector2(.25, .25)]:
		var foot: Vector2 = anchor + corner.rotated(-angle)
		var height: float = world.surface_height(foot.x, foot.y)
		if not is_finite(height) or absf(ground - height) > .02:
			return
	var atlas := Image.load_from_file(dir.path_join(ALBEDO))
	var packed := Image.load_from_file(dir.path_join(PACKED))
	if atlas == null or packed == null:
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(dir.path_join(MESH), state) != OK:
		return
	var imported := document.generate_scene(state) as Node3D
	if imported == null:
		return
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1 or meshes[0].mesh == null:
		imported.free()
		return
	material = ShaderMaterial.new()
	material.shader = FIXTURE.FIXTURE_SHADER
	material.set_shader_parameter("phase_coverage", 1.)
	material.set_shader_parameter("fixture_atlas", ImageTexture.create_from_image(atlas))
	material.set_shader_parameter("lamp_atlas", ImageTexture.create_from_image(packed))
	meshes[0].material_override = material
	meshes[0].mesh.surface_set_material(0, null)
	meshes[0].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fixture = imported
	fixture.name = "PrivatePathLamppost"
	fixture.position = Vector3(anchor.x, ground, anchor.y)
	fixture.rotation.y = angle
	light = OmniLight3D.new()
	light.name = "PathLamppostLight"
	light.position = Vector3(.13, 3.35, -.51)
	light.light_color = LIGHT_COLOR.linear_to_srgb()
	light.light_energy = 0.
	light.omni_range = 3.5
	light.omni_attenuation = 1.65
	light.light_cull_mask = 1
	fixture.add_child(light)
	support = StaticBody3D.new()
	support.name = "LamppostShaft"
	support.position = SHAFT_CENTER
	support.collision_layer = 0
	support.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SHAFT_SIZE
	shape.shape = box
	support.add_child(shape)
	fixture.add_child(support)
	world.add_child(fixture)
