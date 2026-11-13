extends Node

const VisiblePass := preload("res://materials/world_map_canopy_player_visible.gdshader")
const CuePass := preload("res://materials/world_map_canopy_player_cue.gdshader")

var meshes: Array[MeshInstance3D] = []
var weight := 0.0
var day_tone_weight := 0.0
var _cue_materials: Array[ShaderMaterial] = []
var _attempted := false

func available(level: Node) -> bool:
	return RenderingServer.get_current_rendering_method() == "mobile" \
		and RenderingServer.get_current_rendering_driver_name() in ["d3d12", "vulkan"] \
		and is_instance_valid(level.grove) and level.grove.source_oaks \
		and level.player.get("using_original_source") == true and level.player.get("primary_ready") == true

func sync(level: Node, strength: float, day_tone: float) -> void:
	var target := 0.0
	if available(level) and level.showcase.forest_active() and not level.player.is_dead \
			and level.player.is_visible_in_tree() and (level.grove.visible or level.grove.spruce_visible()):
		var noon_distance: float = absf(level.showcase.hour - 12.0)
		target = strength * smoothstep(0.0, 0.5, noon_distance)
	if target > 0.0 and not _attempted:
		_build(level.look.actor_materials, level.player.render_presenter)
	if meshes.is_empty():
		target = 0.0
	var tone := day_tone if target > 0.0 else 0.0
	if target == weight and tone == day_tone_weight:
		return
	if target != weight:
		var stencil_changed := (target > 0.0) != (weight > 0.0)
		weight = target
		level.grove.set_player_cue_weight(target)
		if stencil_changed:
			level.look.refresh_grove_lighting()
		for proxy in meshes:
			proxy.visible = target > 0.0
		for material in _cue_materials:
			material.set_shader_parameter("cue_weight", target)
	day_tone_weight = tone
	for material in _cue_materials:
		material.set_shader_parameter("day_tone_weight", tone)

func _build(surfaces: Array[Array], presenter: Node) -> void:
	_attempted = true
	var copies: Dictionary[MeshInstance3D, MeshInstance3D] = {}
	var counts: Dictionary[MeshInstance3D, int] = {}
	for row: Array in surfaces:
		counts[row[0]] = counts.get(row[0], 0) + 1
	for row: Array in surfaces:
		var source: MeshInstance3D = row[0]
		# Only reproduce meshes covered by the same render-pose snapshots.
		if counts[source] != source.mesh.get_surface_count() or not presenter.meshes.has(source):
			continue
		var proxy: MeshInstance3D = copies.get(source)
		if proxy == null:
			proxy = MeshInstance3D.new()
			proxy.name = "CanopyCue"
			proxy.mesh = source.mesh
			proxy.skin = source.skin
			proxy.layers = source.layers
			proxy.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			proxy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			proxy.hide()
			source.add_child(proxy)
			var skeleton := source.get_node_or_null(source.skeleton)
			if skeleton is Skeleton3D:
				proxy.skeleton = proxy.get_path_to(skeleton)
			presenter.add_mesh_follower(source, proxy)
			copies[source] = proxy
			meshes.append(proxy)
		var opacity: BaseMaterial3D = row[3]
		var mask := _make_material(VisiblePass, 20, opacity)
		var cue := _make_material(CuePass, 21, opacity)
		mask.next_pass = cue
		proxy.set_surface_override_material(row[1], mask)
		_cue_materials.append(cue)

func _make_material(shader: Shader, priority: int, opacity: BaseMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = priority
	if opacity.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and opacity.albedo_texture != null:
		material.set_shader_parameter("opacity_texture", opacity.albedo_texture)
		material.set_shader_parameter("cutoff", opacity.alpha_scissor_threshold)
	return material
