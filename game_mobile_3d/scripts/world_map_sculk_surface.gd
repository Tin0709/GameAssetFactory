extends RefCounted

const BASE := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Environment/"
const TEXTURES := [
	["DeepDark/Props/Skulk/T_Skulk_Packed.png", "2bf7f9f9e32daf2e7107b30f67e4ddb4c363c10b3923363d931dd62e517f88cf", 64],
	["DeepDark/Props/Skulk/T_SculkVieinMask.png", "5b8e101525a45ef06192dbba42a90b02e2b39daf96718f3ff2b92881e31e6f57", 16],
]
const MESH := "Generic/Props/SoulCrisis/SculkPatch/SM_SkulkVein_03.glb"
const SHA := "a957e5c448314dd78b638bd4cc486dd74b24b9891efad4d8c2efebed9fb4972a"

var mesh_batch: MultiMeshInstance3D
var material: ShaderMaterial

var attempted := false
var _frame := -1

func available(world: Node3D) -> bool:
	return world != null and not world.sculk_surface_sites.is_empty() and OS.has_feature("editor") \
		and RenderingServer.get_current_rendering_method() == "mobile" and RenderingServer.get_rendering_device() != null

func update(world: Node3D, coverage: float, strength: float) -> void:
	var visible := coverage > 0.0 and strength > 0.0
	if visible and not attempted and available(world):
		attempted = true
		_load(world)
	if not is_instance_valid(mesh_batch):
		return
	mesh_batch.visible = visible
	if visible:
		material.set_shader_parameter("phase_coverage", coverage)
		material.set_shader_parameter("emission_scale", .60 * strength)
		advance_clock(world.look.cloud_clock)

func _load(world: Node3D) -> void:
	var source_root := OS.get_environment("MD2_RESEARCH_ROOT")
	if source_root.is_empty():
		source_root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	source_root = source_root.simplify_path().replace("\\", "/").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/").to_lower()
	if not source_root.is_absolute_path() or source_root.begins_with("res://") or source_root.begins_with("user://") \
			or source_root.to_lower() == project or source_root.to_lower().begins_with(project + "/"):
		return
	var images: Array[ImageTexture] = []
	for entry: Array in TEXTURES:
		var path := source_root.path_join(BASE + entry[0])
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != entry[1]:
			return
		var image := Image.load_from_file(path)
		if image == null or image.get_size() != Vector2i(entry[2],entry[2]):
			return
		images.append(ImageTexture.create_from_image(image))
	var mesh_path := source_root.path_join(BASE + MESH)
	if not FileAccess.file_exists(mesh_path) or FileAccess.get_sha256(mesh_path) != SHA:
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(mesh_path,state) != OK:
		return
	var scene := document.generate_scene(state)
	if scene == null:
		return
	var nodes := scene.find_children("*","MeshInstance3D",true,false)
	var mesh: Mesh = nodes[0].mesh if nodes.size()==1 else null
	scene.free()
	if mesh == null or mesh.get_surface_count()!=1:
		return
	mesh.surface_set_material(0,null)
	var origins: Array[Vector3] = []
	for point: Vector2 in world.sculk_surface_sites:
		var height: float = world.surface_height(point.x+.5,point.y+.5)
		if not is_finite(height):
			return
		for offset: Vector2 in [Vector2(-.5,-.5),Vector2(-.5,.5),Vector2(.5,-.5)]:
			if not is_equal_approx(height,world.surface_height(point.x+offset.x,point.y+offset.y)):
				return
		origins.append(Vector3(point.x,height,point.y))
	material = ShaderMaterial.new()
	material.shader = preload("res://materials/world_map_sculk_surface.gdshader")
	material.set_shader_parameter("packed_source",images[0])
	material.set_shader_parameter("coverage_source",images[1])
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = origins.size()
	for index in origins.size():
		var basis := Basis(Vector3.UP,index * PI * .5)
		instances.set_instance_transform(index,Transform3D(basis,origins[index]))
	mesh_batch = MultiMeshInstance3D.new()
	mesh_batch.name = "PrivateSculkSurface"
	mesh_batch.multimesh = instances
	mesh_batch.material_override = material
	mesh_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_batch.hide()
	world.add_child(mesh_batch)

func advance_clock(seconds: float) -> void:
	if not is_instance_valid(mesh_batch) or not mesh_batch.visible:
		return
	var frame := floori(fposmod(seconds * .5, 1.) * 16.)
	if frame == _frame:
		return
	_frame = frame
	material.set_shader_parameter("atlas_cell", Vector2i(frame % 4, frame >> 2))