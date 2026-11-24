extends Node3D

const EffectSource := preload("res://scripts/mechanic_lab_effect_source.gd")
const ATLAS := "extracted/2026-10-25 19-26-25/Game/Spicewood/FX/Explosion/Materials/Decals/T_CracksDecals16.png"
const ATLAS_HASH := "cb94172543bf1bd4a0e8343f7ceb4304e738ec9463e21d18d25dd37964eeb55b"
const TILE_SIZE := 16
const TERRAIN_LAYER := 1 << 12
const PROJECTION_SIZE := Vector3(1.10, 0.06, 1.10)
const DURATION := 0.95
const FADE_START := 0.34
const SURFACE_TINT := {
	"grass": Color(0.05, 0.07, 0.025, 0.54),
	"dirt": Color(0.12, 0.073, 0.038, 0.59),
	"stone": Color(0.075, 0.085, 0.10, 0.58),
}

var _decals: Array[Decal] = []
var _ticks: Array[int] = []
var _tints: Array[Color] = []
var _next := 0
var _footprint := PhysicsShapeQueryParameters3D.new()

func setup(terrain: MeshInstance3D) -> bool:
	if RenderingServer.get_current_rendering_method() == &"gl_compatibility":
		return false
	var atlas := EffectSource.load_image(ATLAS, ATLAS_HASH, Vector2i(32, 32))
	if atlas == null:
		return false
	var volume := BoxShape3D.new()
	volume.size = PROJECTION_SIZE
	_footprint.shape = volume
	_footprint.collision_mask = 1
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
			var decal := Decal.new()
			decal.texture_albedo = ImageTexture.create_from_image(mask)
			decal.cull_mask = TERRAIN_LAYER
			decal.size = PROJECTION_SIZE
			decal.normal_fade = 0.8
			decal.upper_fade = 0.0
			decal.lower_fade = 0.0
			decal.hide()
			add_child(decal)
			_decals.append(decal)
			_ticks.append(-1)
			_tints.append(Color.WHITE)
	terrain.layers |= TERRAIN_LAYER
	set_process(false)
	return true

func stamp(point: Vector3, touchdown: Vector3, surface: String) -> void:
	var space := get_world_3d().direct_space_state
	# A projected mark can reach the floor on both sides of a narrow wall.
	# Test its whole footprint, just above the receiver surface.
	var lift := Vector3.UP * (PROJECTION_SIZE.y + 0.01)
	_footprint.transform = Transform3D(Basis.IDENTITY, point + lift)
	if not space.intersect_shape(_footprint, 1).is_empty():
		point = touchdown
		_footprint.transform.origin = point + lift
		if not space.intersect_shape(_footprint, 1).is_empty():
			return
	var decal := _decals[_next]
	decal.hide()
	decal.global_position = point
	_ticks[_next] = Engine.get_physics_frames()
	_tints[_next] = SURFACE_TINT[surface]
	_next = (_next + 1) % _decals.size()
	set_process(true)

func _process(_delta: float) -> void:
	var render_tick := Engine.get_physics_frames() + Engine.get_physics_interpolation_fraction() - 1.0
	var active := false
	for i in _decals.size():
		if _ticks[i] < 0:
			continue
		var age := (render_tick - _ticks[i]) / Engine.physics_ticks_per_second
		var decal := _decals[i]
		if age >= DURATION:
			decal.hide()
			_ticks[i] = -1
			continue
		active = true
		decal.visible = age >= 0.0
		var tint := _tints[i]
		tint.a *= 1.0 - smoothstep(FADE_START, DURATION, age)
		decal.modulate = tint
	set_process(active)

func clear() -> void:
	_ticks.fill(-1)
	for decal in _decals:
		decal.hide()
	_next = 0
	set_process(false)
