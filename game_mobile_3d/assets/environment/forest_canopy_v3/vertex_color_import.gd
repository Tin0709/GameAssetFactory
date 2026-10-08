@tool
extends EditorScenePostImport
## GLB COLOR_0 contains linear albedo; these native materials work outside the study.
func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		for index in node.mesh.get_surface_count():
			var material = node.mesh.surface_get_material(index)
			if material is BaseMaterial3D:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
				material.roughness = 0.95
				material.metallic = 0.0
	return scene
