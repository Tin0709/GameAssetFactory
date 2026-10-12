extends SceneTree
func _initialize() -> void:
	var model=load("res://assets/characters/jump_gif_v004/player_r15_jump_gif_v004.glb").instantiate()
	root.add_child(model)
	for child in model.find_children("*","MeshInstance3D",true,false):
		for i in child.mesh.get_surface_count():
			var m: BaseMaterial3D=child.mesh.surface_get_material(i)
			print("RUNTIME_MATERIAL ",m.resource_path," texture ",m.albedo_texture.resource_path," color ",m.albedo_color," uv ",m.uv1_scale," ",m.uv1_offset)
			m.albedo_texture.get_image().save_png("res://.validation/expressive_locomotion_v1/imported_atlas.png")
			print("MATERIAL_PROPS ",m.normal_enabled," ",m.metallic," ",m.roughness," ",m.vertex_color_use_as_albedo)
	quit()
