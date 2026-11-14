extends SceneTree

const MistVolume = preload("res://scripts/world_map_atmosphere_volume.gd")
const LocalRegion = preload("res://scripts/local_mist_region.gd")
const FIELD_SIZE := Vector3i(17, 17, 32)
const CAMERA_FAR := 40.
const BANK_ENTRY := 12.
const CENTER_DEPTH := 12.
const RADIUS := 6.
const EXTINCTION := .06

var _field := PackedByteArray()
var _field_mutex := Mutex.new()
var _failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if RenderingServer.get_rendering_device() == null:
		push_error("This test requires a real RenderingDevice")
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(272, 272)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	viewport.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = CAMERA_FAR
	viewport.add_child(camera)
	var mist := MistVolume.new()
	camera.add_child(mist)
	mist.setup()
	mist.noise_strength = 0.
	mist.publish({
		"fog_begin": BANK_ENTRY, "near_layer": Vector3(8., .000001, 0.),
		"fog_color": Vector3.ONE, "volume_density": 0.,
		"height_falloff": 0., "scatter_energy": 1.,
		"player_light_color": Vector3.ZERO, "player_light_weight": 0.,
	}, Vector3.ZERO, 0., 0., true, 1.)
	mist.show()

	var first := _region(Vector3(1., 0., 0.))
	var second := _region(Vector3(0., 0., 1.))
	for mask in [1, 2, 3, 0]:
		mist.set_local_region(first, float(mask & 1))
		mist.set_additional_local_region(second, float((mask >> 1) & 1))
		for frame in 12:
			await RenderingServer.frame_post_draw
		var data := PackedByteArray()
		_field_mutex.lock()
		_field.clear()
		_field_mutex.unlock()
		RenderingServer.call_on_render_thread(_read_field.bind(mist.effect.texture.texture_rd_rid))
		for frame in 60:
			_field_mutex.lock()
			data = _field
			_field_mutex.unlock()
			if not data.is_empty():
				break
			await process_frame
		if data.size() != FIELD_SIZE.x * FIELD_SIZE.y * FIELD_SIZE.z * 8:
			_failures.append("Mist texture was not available for mask %d" % mask)
			continue
		for slice in [10, 13, 15, 16, 17, 18, 19, 23, 31]:
			_check_slice(data, slice, mask)
	print("LOCAL_MIST_BANK_TRANSITION failures=", _failures)
	viewport.free()
	await process_frame
	quit(int(not _failures.is_empty()))

func _region(tint: Vector3) -> LocalRegion:
	var region := LocalRegion.new()
	region.center_m = Vector3(0., 0., -CENTER_DEPTH)
	region.radii_m = Vector3(RADIUS, RADIUS, RADIUS)
	region.extinction_per_meter = EXTINCTION
	region.scatter_multiplier = tint
	return region

func _check_slice(data: PackedByteArray, slice: int, mask: int) -> void:
	var depth := pow(float(slice) / float(FIELD_SIZE.z - 1), 2.) * CAMERA_FAR
	var inside := clampf(depth - CENTER_DEPTH, -RADIUS, RADIUS)
	# Integral of 1 - x²/r² from -r to the sampled depth.
	var tau := EXTINCTION * (inside - pow(inside, 3.) / (3. * RADIUS * RADIUS) + 2. * RADIUS / 3.)
	var red := float(mask & 1)
	var blue := float((mask >> 1) & 1)
	var sources := red + blue
	var expected_t := exp(-tau * sources)
	var expected_rgb := Vector3(red, 0., blue) * ((1. - expected_t) / maxf(sources, 1.))
	var byte := ((slice * FIELD_SIZE.y + (FIELD_SIZE.y >> 1)) * FIELD_SIZE.x + (FIELD_SIZE.x >> 1)) * 8
	var actual_rgb := Vector3(data.decode_half(byte), data.decode_half(byte + 2), data.decode_half(byte + 4))
	var actual_t := data.decode_half(byte + 6)
	if absf(actual_t - expected_t) > .001 or actual_rgb.distance_to(expected_rgb) > .001:
		_failures.append("mask %d depth %.2fm: T %.5f vs %.5f, RGB %s vs %s"
			% [mask, depth, actual_t, expected_t, actual_rgb, expected_rgb])

func _read_field(texture: RID) -> void:
	if texture.is_valid():
		var data := RenderingServer.get_rendering_device().texture_get_data(texture, 0)
		_field_mutex.lock()
		_field = data
		_field_mutex.unlock()
