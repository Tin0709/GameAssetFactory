extends RefCounted
## Transient material adapters for the original three private Sabre actor surfaces.
const OPAQUE := preload("actor_opaque.gdshader")
const CUTOUT := preload("actor_cutout.gdshader")
var bindings: Array[Dictionary] = []
var model: Node3D
var active := false

func apply(actor_model: Node3D, texture: Texture2D, phase: Vector4, enabled: bool) -> void:
	if not enabled or actor_model == null or texture == null:
		release()
		return
	if model != actor_model:
		release()
		model = actor_model
		for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if node.mesh == null:
				continue
			for surface in node.mesh.get_surface_count():
				var material := node.get_active_material(surface) as StandardMaterial3D
				if not _supported(node, material):
					bindings.clear()
					return
				var adapter := _adapt(material, texture)
				bindings.append({"node": node, "surface": surface,
					"original": node.get_surface_override_material(surface), "adapter": adapter})
		for row: Dictionary in bindings:
			row.node.set_surface_override_material(row.surface, row.adapter)
		active = not bindings.is_empty()
	update_phase(phase)

func _supported(node: MeshInstance3D, material: StandardMaterial3D) -> bool:
	if node.material_override != null or material == null or material.next_pass != null:
		return false
	if material.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]:
		return false
	return (material.cull_mode == BaseMaterial3D.CULL_DISABLED
		and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and not material.texture_repeat
		and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
		and material.diffuse_mode == BaseMaterial3D.DIFFUSE_BURLEY and material.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX
		and material.uv1_scale == Vector3.ONE and material.uv1_offset == Vector3.ZERO
		and not material.uv1_triplanar and not material.normal_enabled and not material.ao_enabled
		and not material.vertex_color_use_as_albedo and not material.disable_ambient_light
		and not material.disable_receive_shadows and not material.disable_fog
		and material.albedo_texture != null and material.roughness_texture != null
		and material.roughness_texture == material.metallic_texture
		and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		and material.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		and material.emission_enabled and material.emission_texture != null
		and material.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY)

func _adapt(source: StandardMaterial3D, texture: Texture2D) -> ShaderMaterial:
	var out := ShaderMaterial.new()
	out.shader = OPAQUE if source.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED else CUTOUT
	out.render_priority = source.render_priority
	out.set_shader_parameter("actor_albedo", source.albedo_texture)
	out.set_shader_parameter("actor_surface", source.roughness_texture)
	out.set_shader_parameter("actor_emission", source.emission_texture)
	out.set_shader_parameter("actor_tint", source.albedo_color)
	out.set_shader_parameter("actor_emission_tint", source.emission)
	out.set_shader_parameter("actor_emission_gain", source.emission_energy_multiplier)
	out.set_shader_parameter("actor_metallic", source.metallic)
	out.set_shader_parameter("actor_roughness", source.roughness)
	out.set_shader_parameter("actor_specular", source.metallic_specular)
	out.set_shader_parameter("actor_cutoff", source.alpha_scissor_threshold)
	out.set_shader_parameter("gaf_cloud_pattern", texture)
	out.set_shader_parameter("gaf_cloud_strength", 1.0)
	return out

func update_phase(phase: Vector4) -> void:
	for row: Dictionary in bindings:
		row.adapter.set_shader_parameter("gaf_cloud_phase", phase)

func release() -> void:
	for row: Dictionary in bindings:
		if is_instance_valid(row.node) and row.node.get_surface_override_material(row.surface) == row.adapter:
			row.node.set_surface_override_material(row.surface, row.original)
	bindings.clear()
	model = null
	active = false
