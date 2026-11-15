extends Node

const VisiblePass := preload("res://materials/world_map_canopy_player_visible.gdshader")
const CuePass := preload("res://materials/world_map_canopy_player_cue.gdshader")

var meshes: Array[MeshInstance3D] = []
var weight := 0.0
var opacity_weight := 0.0
var day_tone_weight := 0.0
var clarity_weight := 0.0
var _cue_materials: Array[ShaderMaterial] = []
var _attempted := false
var _alternate: Node3D
var _alternate_sources: Array[MeshInstance3D] = []
var _alternate_attempted := false
var _morph_proxies: Dictionary[MeshInstance3D, MeshInstance3D] = {}

func set_alternate(appearance: Node3D, sources: Array[MeshInstance3D]) -> void:
	_alternate = appearance
	_alternate_sources = sources

func available(level: Node) -> bool:
	return RenderingServer.get_current_rendering_method() == "mobile" \
		and RenderingServer.get_current_rendering_driver_name() in ["d3d12", "vulkan"] \
		and is_instance_valid(level.grove) and level.grove.source_oaks \
		and level.player.get("using_original_source") == true and level.player.get("primary_ready") == true

func sync(level: Node, strength: float, day_tone: float, clarity: float, opacity_scale: float) -> void:
	var target := 0.0
	if available(level) and level.showcase.forest_active() and not level.player.is_dead \
			and level.player.is_visible_in_tree() and (level.grove.visible or level.grove.spruce_visible()):
		var noon_distance: float = absf(level.showcase.hour - 12.0)
		target = strength * smoothstep(0.0, 0.5, noon_distance)
	if target > 0.0:
		if not _attempted:
			_attempted = true
			var presenter: Node = level.player.render_presenter
			_build(level.look.actor_materials, presenter.meshes, presenter)
		if not _alternate_attempted and is_instance_valid(_alternate) and _alternate.is_visible_in_tree():
			_alternate_attempted = true
			_build(level.look.actor_materials, _alternate_sources)
		for source in _morph_proxies:
			if source.is_visible_in_tree():
				var proxy := _morph_proxies[source]
				for index in source.mesh.get_blend_shape_count():
					var value := source.get_blend_shape_value(index)
					if value != proxy.get_blend_shape_value(index):
						proxy.set_blend_shape_value(index, value)
	if meshes.is_empty():
		target = 0.0
	var tone := day_tone if target > 0.0 else 0.0
	var clarity_target := clarity if target > 0.0 else 0.0
	var opacity := target * opacity_scale
	if target == weight and tone == day_tone_weight and clarity_target == clarity_weight and opacity == opacity_weight:
		return
	if target != weight:
		var stencil_changed := (target > 0.0) != (weight > 0.0)
		weight = target
		level.grove.set_player_cue_weight(target)
		if stencil_changed:
			level.look.refresh_grove_lighting()
		for proxy in meshes:
			proxy.visible = target > 0.0
	if opacity != opacity_weight:
		opacity_weight = opacity
		for material in _cue_materials:
			material.set_shader_parameter("cue_weight", opacity)
	if tone != day_tone_weight or clarity_target != clarity_weight:
		day_tone_weight = tone
		clarity_weight = clarity_target
		for material in _cue_materials:
			material.set_shader_parameter("day_tone_weight", tone)
			material.set_shader_parameter("clarity_weight", clarity_target)

func _build(surfaces: Array[Array], sources: Array[MeshInstance3D], presenter: Node = null) -> void:
	var copies: Dictionary[MeshInstance3D, MeshInstance3D] = {}
	var counts: Dictionary[MeshInstance3D, int] = {}
	for row: Array in surfaces:
		counts[row[0]] = counts.get(row[0], 0) + 1
	for row: Array in surfaces:
		var source: MeshInstance3D = row[0]
		if counts[source] != source.mesh.get_surface_count() or not sources.has(source):
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
			proxy.visible = weight > 0.0
			source.add_child(proxy)
			var skeleton := source.get_node_or_null(source.skeleton)
			if skeleton is Skeleton3D:
				proxy.skeleton = proxy.get_path_to(skeleton)
			if presenter != null:
				presenter.add_mesh_follower(source, proxy)
			elif source.mesh.get_blend_shape_count() > 0:
				# The alternate mesh already follows the live presentation skeleton.
				_morph_proxies[source] = proxy
			copies[source] = proxy
			meshes.append(proxy)
		var opacity: BaseMaterial3D = row[3]
		var mask := _make_material(VisiblePass, 20, opacity)
		var cue := _make_material(CuePass, 21, opacity)
		cue.set_shader_parameter("cue_weight", opacity_weight)
		cue.set_shader_parameter("day_tone_weight", day_tone_weight)
		cue.set_shader_parameter("clarity_weight", clarity_weight)
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
