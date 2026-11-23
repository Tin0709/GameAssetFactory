extends RefCounted
## Optional matched afternoon lighting for an authored layout.

const ActorBounce := preload("res://scripts/world_map_actor_bounce.gd")
const LUMA := Vector3(.2126, .7152, .0722)
const LAST_HOUR := 19.5

var ready := false
var active := false
var stock_sky_weight := 1.
var terrain_texture: ImageTexture3D
var _review: Node
var _casters_current: Callable
var _knots: Array
var _air_hours: Array[float] = []
var _air_directions: Array[Vector3] = []
var _air_slots: Array[int] = []
var _terrain_hours: Array[float] = []
var _terrain_directions: Array[Vector3] = []
var _terrain_layers: Array[int] = []
var _actor_fields: Array[ActorBounce] = []
var _noon_axis: Vector3
var _right: Vector3
var _sunset: Vector3


func setup(level: Node3D, sky: Node) -> void:
	var relative: String = level.afternoon_lighting_profile
	if relative.is_empty() or level.regional_sky_region == null:
		return
	var review: Node = level.showcase
	var air = review.directional_air
	if review.mist == null or not air.east_available() or not sky.east_casters_current():
		return
	var path := _under_root(air.research_root, relative)
	if path.is_empty() or not FileAccess.file_exists(path) \
			or FileAccess.get_sha256(path) != level.afternoon_lighting_sha256:
		return
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not proof is Dictionary or proof.get("schema") != "gaf_afternoon_lighting/1" \
			or proof.map != FileAccess.get_sha256(level.map_layout_path) \
			or proof.canopy_layout != level.forest_canopy_extension_sha256 \
			or not level.regional_sky_region.supports_matched_sun_bounce(proof.bounce_layout):
		return
	var noon := Basis.from_euler(review._day.sun_rotation * (PI / 180.), level.get_node("Sun").rotation_order).z
	if not noon.is_equal_approx(_vector(proof.noon)):
		return
	var west: ImageTexture3D
	if not level.afternoon_west_air_payload.is_empty():
		var calibrated: Dictionary = proof.west.duplicate()
		calibrated.path = level.afternoon_west_air_payload
		calibrated.sha256 = level.afternoon_west_air_sha256
		west = _air_atlas(air, air.texture, calibrated)
	if west == null:
		west = _air_atlas(air, air.texture, proof.west)
	var east := _air_atlas(air, air.east_texture, proof.east)
	var terrain: ImageTexture3D = level.regional_sky_region._load_volume(proof.terrain.path, proof.terrain.sha256,
		int(proof.terrain.depth))
	if west == null or east == null or terrain == null:
		return
	var actor_fields: Array[ActorBounce] = []
	for row: Dictionary in proof.actor:
		var folder := _under_root(air.research_root, row.folder)
		if folder.is_empty():
			return
		var field := ActorBounce.new()
		field._configure(row, folder, true)
		if not field.available():
			return
		actor_fields.append(field)
	if actor_fields.size() != 2:
		return

	_noon_axis = Vector3(noon.x, 0., noon.z).normalized()
	_right = Vector3.UP.cross(_noon_axis).normalized()
	_sunset = _vector(proof.sunset)
	_knots = proof.knots
	for row: Dictionary in proof.air:
		_air_hours.append(row.hour)
		_air_directions.append(_vector(row.dir))
		_air_slots.append(row.slot)
	for row: Dictionary in proof.terrain.samples:
		_terrain_hours.append(row.hour)
		_terrain_directions.append(_vector(row.dir))
		_terrain_layers.append(row.layer)
	_actor_fields = actor_fields
	terrain_texture = terrain
	_review = review
	_casters_current = Callable(sky, "east_casters_current")
	air.texture = west
	air.east_texture = east
	review.mist.effect.directional_grid = west
	review.mist.effect.east_directional_grid = east
	ready = true


func _air_atlas(air, stock: ImageTexture3D, descriptor: Dictionary) -> ImageTexture3D:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	for layer: Image in stock.get_data():
		digest.update(layer.get_data())
	if digest.finish().hex_encode() != descriptor.stock_sha:
		return null
	var path := _under_root(air.research_root, descriptor.path)
	if path.is_empty() or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != descriptor.sha256:
		return null
	var shape := Vector3i(_vector(descriptor.shape))
	var payload := FileAccess.get_file_as_bytes(path)
	if payload.size() != shape.x * shape.y * shape.z:
		return null
	return air._make_texture(payload, shape)


func _under_root(root: String, relative: String) -> String:
	var path := relative.simplify_path()
	if path.is_empty() or path.is_absolute_path() or path == ".." or path.begins_with("../"):
		return ""
	return root.path_join(path)


func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])


func apply(sun: DirectionalLight3D) -> void:
	active = ready and _review.captured_key_direction and not _review._balanced_preview \
		and _review.atmosphere_review == "combined" and _review.hour > 12. and _review.hour < LAST_HOUR
	stock_sky_weight = 1.
	if not active:
		return
	var hour: float = _review.hour
	var tilt := _tilt(hour)
	var stock := sun.global_basis.z.normalized()
	var direction := sin(tilt) * _noon_axis + cos(tilt) * Vector3.UP
	var frame := Basis(_right, direction.cross(_right).normalized(), direction)
	if hour > _sunset.x:
		var restart := smoothstep(_sunset.z, LAST_HOUR, hour)
		sun.light_energy *= _sunlight_fade(sun, hour) + restart
	if hour > _sunset.y:
		var blend := smoothstep(_sunset.y, _sunset.z, hour)
		var yaw := lerp_angle(atan2(direction.x, direction.z), atan2(stock.x, stock.z), blend)
		var height := lerpf(asin(direction.y), asin(stock.y), blend)
		direction = Vector3(sin(yaw) * cos(height), sin(height), cos(yaw) * cos(height))
		frame = Basis(direction, PI * (1. - blend)) * Basis.looking_at(-direction)
	stock_sky_weight = 1. - smoothstep(deg_to_rad(1.), deg_to_rad(12.), stock.angle_to(direction))
	sun.global_basis = frame


func _sunlight_fade(sun: DirectionalLight3D, hour: float) -> float:
	if hour >= _sunset.y:
		return 0.
	var phase := smoothstep(_sunset.x, _sunset.y, hour)
	if not _review.key_response_active or not _review._dusk_key_fade_available():
		return 1. - phase
	var h: Vector2 = _review._biome_profile.dusk_key_fade_hours
	var amount: float = _review._biome_profile.dusk_key_fade_strength * _review._lighting_scale(&"dusk_key_fade")
	var key: Vector3 = _review.key_response.smooth_dusk_energy(_review._captured_key_rgb(_sunset.y),
		_review._captured_key_rgb(h.x), _review._captured_key_rgb(h.y), inverse_lerp(h.x, h.y, _sunset.y), amount)
	var color := sun.light_color.srgb_to_linear()
	var incoming := sun.light_energy * Vector3(color.r, color.g, color.b).dot(LUMA)
	var cutoff: float = key.dot(LUMA) * _review._lighting_scale(&"sun") * _review.noon_direct_scale(_sunset.y)
	return clampf(1. - cutoff * phase / maxf(incoming, .000001), 0., 1.)


func _tilt(hour: float) -> float:
	var i := 1
	while i < _knots.size() - 1 and hour > float(_knots[i][0]):
		i += 1
	var a: Array = _knots[i - 1]
	var b: Array = _knots[i]
	var width: float = b[0] - a[0]
	var t := clampf((hour - float(a[0])) / width, 0., 1.)
	var p := t * t
	var q := p * t
	return deg_to_rad((2. * q - 3. * p + 1.) * float(a[1]) + (q - 2. * p + t) * width * float(a[2])
		+ (-2. * q + 3. * p) * float(b[1]) + (q - p) * width * float(b[2]))


func air_slots(hour: float, direction: Vector3, gain: float) -> Vector4:
	gain *= smoothstep(13., 15.1, hour) * (1. - smoothstep(19.05, 19.38, hour))
	if gain <= 0.:
		return Vector4.ZERO
	var high := clampi(_air_hours.bsearch(hour), 1, _air_hours.size() - 1)
	var low := high - 1
	var a := _air_directions[low]
	var b := _air_directions[high]
	var weight := _direction_weight(a, b, direction)
	gain *= 1. - smoothstep(deg_to_rad(.45), deg_to_rad(1.35), a.slerp(b, weight).angle_to(direction))
	return Vector4(_air_slots[low], _air_slots[high], weight, gain)


func terrain_sample(hour: float, direction: Vector3) -> Vector2:
	var gain := smoothstep(12.5, 13.25, hour) * (1. - smoothstep(19.05, 19.38, hour))
	if gain <= 0. or not _review.level.grove.spruce_shadows or not _casters_current.call():
		return Vector2.ZERO
	var high := clampi(_terrain_hours.bsearch(hour), 1, _terrain_hours.size() - 1)
	var low := high - 1
	var a := _terrain_directions[low]
	var b := _terrain_directions[high]
	var weight := _direction_weight(a, b, direction)
	gain *= 1. - smoothstep(deg_to_rad(1.), deg_to_rad(4.), a.slerp(b, weight).angle_to(direction))
	var layer := lerpf(_terrain_layers[low], _terrain_layers[high], weight)
	return Vector2((layer + .5) / terrain_texture.get_depth(), gain)


func _direction_weight(a: Vector3, b: Vector3, direction: Vector3) -> float:
	return clampf(a.angle_to(direction) / a.angle_to(b), 0., 1.)


func actor_field(point: Vector3) -> ActorBounce:
	return _actor_fields[1] if _actor_fields[1].fade(point) > 0. else _actor_fields[0]


func actor_slots(slots: Vector4) -> Vector4:
	if slots.w > 0.:
		slots.x -= _air_slots[0]
		slots.y -= _air_slots[0]
	return slots
