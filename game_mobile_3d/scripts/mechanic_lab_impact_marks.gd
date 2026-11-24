extends Node3D

const EffectSource := preload("res://scripts/mechanic_lab_effect_source.gd")
const FLAT_MARK_SHADER := preload("res://materials/mechanic_lab_ground_mark.gdshader")
const ATLAS := "extracted/2026-10-25 19-26-25/Game/Spicewood/FX/Explosion/Materials/Decals/T_CracksDecals16.png"
const ATLAS_HASH := "cb94172543bf1bd4a0e8343f7ceb4304e738ec9463e21d18d25dd37964eeb55b"
const TILE_SIZE := 16
const TERRAIN_LAYER := 1 << 12
const PROJECTION_SIZE := Vector3(1.10, 0.06, 1.10)
const FLAT_MARK_LIFT := 0.004
const DURATION := 0.95
const FADE_START := 0.34
const SURFACE_TINT := {
	"grass": Color(0.05, 0.07, 0.025, 0.54),
	"dirt": Color(0.12, 0.073, 0.038, 0.59),
	"stone": Color(0.075, 0.085, 0.10, 0.58),
}

var _marks: Array[Node3D] = []
var _ticks: Array[float] = []
var _tints: Array[Color] = []
var _next := 0
var _footprint := PhysicsShapeQueryParameters3D.new()
var _terrain: MeshInstance3D
var _flat_mesh: PlaneMesh

func setup(terrain: MeshInstance3D) -> void:
	var volume := BoxShape3D.new()
	volume.size = PROJECTION_SIZE
	_footprint.shape = volume
	_footprint.collision_mask = 1
	set_process(false)
	var atlas := EffectSource.load_image(ATLAS, ATLAS_HASH, Vector2i(32, 32))
	if atlas == null:
		return
	_terrain = terrain
	if RenderingServer.get_current_rendering_method() == &"gl_compatibility":
		_flat_mesh = PlaneMesh.new()
		_flat_mesh.size = Vector2(PROJECTION_SIZE.x, PROJECTION_SIZE.z)
	else:
		terrain.layers |= TERRAIN_LAYER
	atlas.convert(Image.FORMAT_RGBA8)
	for y in 2:
		for x in 2:
			var tile := atlas.get_region(Rect2i(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE))
			var pixels := tile.get_data()
			# The exported red channel supplies the crack intensity.
			# Retain the coverage and tint the marks for the Lab floor.
			for pixel in range(0, pixels.size(), 4):
				pixels[pixel + 3] = roundi(float(pixels[pixel]) * pixels[pixel + 3] / 255.0)
				pixels[pixel] = 255
				pixels[pixel + 1] = 255
				pixels[pixel + 2] = 255
			var mask := Image.create_from_data(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8, pixels)
			var mark := _create_mark(ImageTexture.create_from_image(mask))
			mark.hide()
			add_child(mark)
			_marks.append(mark)
			_ticks.append(-1)
			_tints.append(Color.WHITE)

func _create_mark(texture: ImageTexture) -> Node3D:
	if _flat_mesh != null:
		var surface := _terrain.mesh.get_aabb()
		var material := ShaderMaterial.new()
		material.shader = FLAT_MARK_SHADER
		material.render_priority = -2
		material.set_shader_parameter(&"mark_mask", texture)
		material.set_shader_parameter(&"floor_bounds", Vector4(
			surface.position.x, surface.position.z, surface.end.x, surface.end.z))
		var flat_mark := MeshInstance3D.new()
		flat_mark.mesh = _flat_mesh
		flat_mark.material_override = material
		flat_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return flat_mark
	var decal := Decal.new()
	decal.texture_albedo = texture
	decal.cull_mask = TERRAIN_LAYER
	decal.size = PROJECTION_SIZE
	decal.normal_fade = 0.8
	decal.upper_fade = 0.0
	decal.lower_fade = 0.0
	return decal


func stamp(point: Vector3, surface: String, elapsed_ticks := 0.0) -> bool:
	# Check the whole footprint before the caller emits its debris and sound.
	# The placement also applies when the current renderer has no decals.
	var lift := Vector3.UP * (PROJECTION_SIZE.y + 0.01)
	_footprint.transform = Transform3D(Basis.IDENTITY, point + lift)
	if not get_world_3d().direct_space_state.intersect_shape(_footprint, 1).is_empty():
		return false
	if _marks.is_empty():
		return true
	var mark := _marks[_next]
	mark.hide()
	mark.global_position = point
	if mark is MeshInstance3D:
		var basis := _terrain.global_basis.orthonormalized()
		mark.global_transform = Transform3D(basis, point + basis.y * FLAT_MARK_LIFT)
		mark.material_override.set_shader_parameter(&"world_to_floor", _terrain.global_transform.affine_inverse())
	_ticks[_next] = Engine.get_physics_frames() - elapsed_ticks
	_tints[_next] = SURFACE_TINT[surface]
	_next = (_next + 1) % _marks.size()
	set_process(true)
	return true

func _process(_delta: float) -> void:
	var render_tick := Engine.get_physics_frames() + Engine.get_physics_interpolation_fraction() - 1.0
	var active := false
	for i in _marks.size():
		if _ticks[i] < 0:
			continue
		var age := (render_tick - _ticks[i]) / Engine.physics_ticks_per_second
		var mark := _marks[i]
		if age >= DURATION:
			mark.hide()
			_ticks[i] = -1
			continue
		active = true
		mark.visible = age >= 0.0
		var tint := _tints[i]
		tint.a *= 1.0 - smoothstep(FADE_START, DURATION, age)
		if mark is Decal:
			mark.modulate = tint
		else:
			mark.material_override.set_shader_parameter(&"tint", tint)
	set_process(active)

func clear() -> void:
	_ticks.fill(-1)
	for mark in _marks:
		mark.hide()
	_next = 0
	set_process(false)
