extends RefCounted
## A private source fixture with an independently calibrated stationary light.

const FIXTURE_SHADER := preload("res://materials/world_map_forest_path_fixture.gdshader")
const FOLDER := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Environment/DeepDark/Lighting/Firepit"
const MESH_NAME := "SM_DDD_FirePit.glb"
const MESH_SHA := "666ba722a0c0a12e1c782f80ce6bfd218ed3bbb536587a87758d97ddc8d32cb6"
const ATLAS_NAME := "T_DDD_Props.png"
const ATLAS_SHA := "5a6695a156d73eda0bc6920173c2a32f743a5344b821364fe1c0b59ce55eded0"
const ANCHOR := Vector2(-21.4, 20.2)
const RANGE_M := 10.0
const ENERGY := 3.0

var fixture: Node3D
var light: OmniLight3D
var _material: ShaderMaterial
var _attempted := false
var _submitted := Vector2.ZERO

func update(world: Node3D, phase: float, strength: float) -> bool:
	var state := Vector2(phase, ENERGY * strength * phase) if strength > 0.0 else Vector2.ZERO
	if state.y > 0.0 and not _attempted:
		_attempted = true
		_load(world)
	if not is_instance_valid(fixture) or state == _submitted:
		return false
	_submitted = state
	fixture.visible = state.y > 0.0
	light.light_energy = state.y
	# Finish the fixture reveal before the light finishes its dusk ramp.
	_material.set_shader_parameter("phase_coverage", smoothstep(0.0, 0.25, state.x))
	return true

func is_compatible_secondary(candidate: Light3D) -> bool:
	return candidate == light and candidate.light_color.b == 0.0

func _load(world: Node3D) -> void:
	if not OS.has_feature("editor") or RenderingServer.get_current_rendering_method() != "mobile":
		return
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.simplify_path().replace("\\", "/").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/").to_lower()
	if not root.is_absolute_path() or root.begins_with("res://") or root.begins_with("user://") \
		or root.to_lower() == project or root.to_lower().begins_with(project + "/"):
		return
	var directory := root.path_join(FOLDER)
	var mesh_path := directory.path_join(MESH_NAME)
	var atlas_path := directory.path_join(ATLAS_NAME)
	if not FileAccess.file_exists(mesh_path) or not FileAccess.file_exists(atlas_path):
		return
	if FileAccess.get_sha256(mesh_path) != MESH_SHA or FileAccess.get_sha256(atlas_path) != ATLAS_SHA:
		return
	var image := Image.load_from_file(atlas_path)
	var ground: float = world.surface_height(ANCHOR.x, ANCHOR.y)
	if image == null or image.is_empty() or not is_finite(ground):
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(mesh_path, state) != OK:
		return
	var imported := document.generate_scene(state) as Node3D
	if imported == null:
		return
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1 or meshes[0].mesh == null or meshes[0].mesh.get_surface_count() != 1:
		imported.free()
		return
	_material = ShaderMaterial.new()
	_material.shader = FIXTURE_SHADER
	_material.set_shader_parameter("fixture_atlas", ImageTexture.create_from_image(image))
	meshes[0].material_override = _material
	meshes[0].mesh.surface_set_material(0, null)
	meshes[0].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fixture = imported
	fixture.name = "PrivateForestPathFixture"
	fixture.position = Vector3(ANCHOR.x + 1.0, ground, ANCHOR.y + 1.0)
	fixture.hide()
	light = OmniLight3D.new()
	light.name = "ForestPathLight"
	light.position = Vector3(-1.0, 1.6, -1.0)
	light.light_color = Color(1.0, 0.467783828, 0.0).linear_to_srgb()
	light.light_energy = 0.0
	light.omni_range = RANGE_M
	light.omni_attenuation = 2.0
	light.shadow_enabled = false
	light.light_cull_mask = 1
	fixture.add_child(light)
	world.add_child(fixture)
