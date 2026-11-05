extends RefCounted

const TEXELS_PER_METRE := 4
const HEIGHT_CODES_PER_METRE := 64.0
const MAX_CLEARANCE := 3.5
const REACH := 1.15

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
	var field := PackedFloat32Array()
	var terrain_offset := origin - map_min
	field.resize(size.x * size.y)
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
				var coverage := (1.0 - smoothstep(-0.26, spread, distance)) * density * sky_weight
				var index := z * size.x + x
				field[index] = maxf(field[index], coverage)
	var data := PackedByteArray()
	data.resize(field.size() * 4)
	for z in size.y:
		for x in size.x:
			var index := z * size.x + x
			var coverage := roundi(field[index] * 255.0)
			if coverage == 0: continue
			var receiver := Vector2i(x * metres, z * metres) + terrain_offset
			var top := terrain.get_pixelv(receiver).g
			# Encoding the weighted height preserves the receiver through
			# bilinear filtering at the edge of the footprint.
			var height := clampi(roundi((top - base_y) * HEIGHT_CODES_PER_METRE * (coverage / 255.0)), 0, 65535)
			var pixel := index * 4
			data[pixel] = coverage
			data[pixel + 1] = height >> 8
			data[pixel + 2] = height & 255
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)
	return {"image": image, "origin": Vector2(origin), "extent": Vector2(bounds.size)}
