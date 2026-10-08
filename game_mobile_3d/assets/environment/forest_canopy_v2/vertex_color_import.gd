@tool
extends EditorScenePostImport
## Keep these reusable GLBs colored when instanced outside the forest study.
## COLOR_0 is already linear; do not apply another sRGB conversion.
func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*","MeshInstance3D",true,false):
		for index in node.mesh.get_surface_count():
			var material = node.mesh.surface_get_material(index)
			if material is BaseMaterial3D:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
				material.roughness = 0.95
				material.metallic = 0.0
	return scene
