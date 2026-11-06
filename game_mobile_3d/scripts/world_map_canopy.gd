extends RefCounted

const TEXELS_PER_METRE := 4
const HEIGHT_CODES_PER_METRE := 64.0
const MAX_CLEARANCE := 3.5
const REACH := 1.15
const OAK_ATLAS := "res://assets/graphics/meadow_daylight_v5/oak_contact.res"
const OAK_STAMP_SIZE := 64
const OAK_STAMP_EXTENT := 4.25
const OAK_OCCLUSION_GAIN := 0.68

static func bake(leaves: Array[Vector4], terrain: Image, map_min: Vector2i, base_y: float) -> Dictionary:
	var rect := Rect2i(map_min, terrain.get_size())
	var bounds := Rect2i()
	if not leaves.is_empty():
		var first := Vector2i(leaves[0].x, leaves[0].y)
		bounds = Rect2i(first, Vector2i.ONE)
		for leaf in leaves:
			var cell := Vector2i(leaf.x, leaf.y)
			bounds = bounds.expand(cell).expand(cell + Vector2i.ONE)
		bounds = bounds.grow(ceili(REACH) + 1).intersection(rect)
	var origin := bounds.position
	var size := bounds.size * TEXELS_PER_METRE
	if size.x == 0 or size.y == 0:
		return {"image": Image.create(1, 1, false, Image.FORMAT_RGBA8), "origin": Vector2(map_min), "extent": Vector2.ONE}
	var data := PackedByteArray()
	data.resize(size.x * size.y * 4)
	var terrain_offset := origin - map_min
	var metres := 1.0 / TEXELS_PER_METRE
	for leaf in leaves:
		# Author cells describe full and half-leaf blocks. Adjacent blocks may
		# overlap in projection, but must never compound into black rings.
		var footprint := Vector2(leaf.x, leaf.y) - Vector2(origin)
		var xz_start := Vector2i((footprint - Vector2.ONE * REACH).floor() * TEXELS_PER_METRE).max(Vector2i.ZERO)
		var xz_end := Vector2i((footprint + Vector2.ONE * (1.0 + REACH)).ceil() * TEXELS_PER_METRE).min(size)
		for z in range(xz_start.y, xz_end.y):
			for x in range(xz_start.x, xz_end.x):
				var point := (Vector2(x, z) + Vector2(0.5, 0.5)) * metres
				var receiver := Vector2i(point.floor()) + terrain_offset
				var surface := terrain.get_pixelv(receiver)
				if surface.a < 0.5: continue
				var clearance := leaf.z - surface.g
				if clearance < -0.02 or clearance >= MAX_CLEARANCE: continue
				var edge := (point - footprint - Vector2(0.5, 0.5)).abs() - Vector2(0.5, 0.5)
				var distance := edge.max(Vector2.ZERO).length() + minf(maxf(edge.x, edge.y), 0.0)
				var spread := lerpf(0.80, REACH, clampf(clearance * 0.65, 0.0, 1.0))
				var sky_weight := 1.0 - smoothstep(0.0, MAX_CLEARANCE, clearance)
				var density := lerpf(0.56, 0.96, leaf.w)
				var coverage := roundi((1.0 - smoothstep(-0.26, spread, distance)) * density * sky_weight * 255.0)
				var pixel := (z * size.x + x) * 4
				if coverage <= data[pixel]: continue
				# Encode weighted height so bilinear filtering preserves the
				# receiver at the edge of the footprint.
				var height := clampi(roundi((surface.g - base_y) * HEIGHT_CODES_PER_METRE * (coverage / 255.0)), 0, 65535)
				data[pixel] = coverage
				data[pixel + 1] = height >> 8
				data[pixel + 2] = height & 255
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)
	return {"image": image, "origin": Vector2(origin), "extent": Vector2(bounds.size)}


static func stamp_oaks(field: Dictionary, terrain: Image, map_min: Vector2i, base_y: float, oaks: Array[Transform3D], gain: float = OAK_OCCLUSION_GAIN) -> Dictionary:
	if oaks.is_empty(): return field
	var atlas := load(OAK_ATLAS) as Image
	if atlas == null: return field
	var field_origin := Vector2i(field.origin)
	var bounds := Rect2i(field_origin, Vector2i(field.extent))
	var footprint_bounds: Array[Rect2i] = []
	for oak: Transform3D in oaks:
		var centre := Vector2(oak.origin.x, oak.origin.z)
		var reach := Vector2.ONE * (OAK_STAMP_EXTENT * oak.basis.x.length())
		var low := Vector2i((centre - reach).floor())
		var high := Vector2i((centre + reach).ceil())
		var footprint := Rect2i(low, high - low)
		footprint_bounds.append(footprint)
		bounds = bounds.merge(footprint)
	bounds = bounds.intersection(Rect2i(map_min, terrain.get_size()))
	var size := bounds.size * TEXELS_PER_METRE
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var previous: Image = field.image
	image.blit_rect(previous, Rect2i(Vector2i.ZERO, previous.get_size()), (field_origin - bounds.position) * TEXELS_PER_METRE)
	for index in oaks.size():
		var inverse := oaks[index].affine_inverse()
		var covered := footprint_bounds[index].intersection(bounds)
		var first := (covered.position - bounds.position) * TEXELS_PER_METRE
		var last := (covered.end - bounds.position) * TEXELS_PER_METRE
		for z in range(first.y, last.y):
			for x in range(first.x, last.x):
				var point := Vector2(bounds.position) + (Vector2(x, z) + Vector2(0.5, 0.5)) / TEXELS_PER_METRE
				var receiver := terrain.get_pixelv(Vector2i(point.floor()) - map_min)
				if receiver.a < 0.5: continue
				var local := inverse * Vector3(point.x, receiver.g, point.y)
				var height_weight := 1.0 - smoothstep(0.10, 0.60, absf(local.y))
				if height_weight <= 0.0: continue
				var uv := Vector2(local.x, local.z) / (2.0 * OAK_STAMP_EXTENT) + Vector2(0.5, 0.5)
				var coverage := roundi(_sample_oak(atlas, index % 2, uv) * height_weight * gain * 255.0)
				var previous_sample := image.get_pixel(x, z)
				if coverage <= roundi(previous_sample.r * 255.0): continue
				var height := clampi(roundi((receiver.g - base_y) * HEIGHT_CODES_PER_METRE * (coverage / 255.0)), 0, 65535)
				# Retain existing shrub coverage for direct light, including overlaps.
				var shrub := roundi((previous_sample.r - previous_sample.a) * 255.0)
				image.set_pixel(x, z, Color8(coverage, height >> 8, height & 255, coverage - shrub))
	return {"image": image, "origin": Vector2(bounds.position), "extent": Vector2(bounds.size)}


static func _sample_oak(atlas: Image, tile: int, uv: Vector2) -> float:
	if uv.x <= 0.0 or uv.x >= 1.0 or uv.y <= 0.0 or uv.y >= 1.0: return 0.0
	var pixel := uv * OAK_STAMP_SIZE - Vector2(0.5, 0.5)
	var low := Vector2i(pixel.floor()).clamp(Vector2i.ZERO, Vector2i.ONE * (OAK_STAMP_SIZE - 1))
	var high := Vector2i(pixel.ceil()).clamp(Vector2i.ZERO, Vector2i.ONE * (OAK_STAMP_SIZE - 1))
	var weight := pixel.posmod(1.0)
	var tile_x := tile * OAK_STAMP_SIZE
	var a := lerpf(atlas.get_pixel(tile_x + low.x, low.y).r, atlas.get_pixel(tile_x + high.x, low.y).r, weight.x)
	var b := lerpf(atlas.get_pixel(tile_x + low.x, high.y).r, atlas.get_pixel(tile_x + high.x, high.y).r, weight.x)
	return lerpf(a, b, weight.y)
