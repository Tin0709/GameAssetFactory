@tool
extends EditorScenePostImport
## Preserve the saved Blender albedo contract. COLOR_0 is linear glTF data.
func _post_import(scene: Node) -> Object:
	var source_name := get_source_file().get_file().get_basename()
	var color_is_albedo := source_name.begins_with("flower_") or source_name == "tall_grass"
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	if scene is MeshInstance3D:
		meshes.append(scene)
	for node in meshes:
		for surface in node.mesh.get_surface_count():
			var material = node.mesh.surface_get_material(surface)
			if material is BaseMaterial3D:
				material.vertex_color_use_as_albedo = color_is_albedo
				material.vertex_color_is_srgb = false
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return scene
