extends RefCounted
## World-space contact field for the flat Overworld review scene.

const SIZE := 512
const EXTENT := 104.0
const ORIGIN := Vector2(-52., -52.)
const CELL := EXTENT / SIZE
const ROCK_SLICE_HEIGHT := 0.48

static func build(rocks: Array[Node], trunks: Array[StaticBody3D]) -> ImageTexture:
	var field := Image.create(SIZE, SIZE, false, Image.FORMAT_R8)
	for body: Node in rocks:
		if not body is StaticBody3D or body.get_meta("overworld_surface", "") != "stone":
			continue
		for child: Node in body.get_children():
			if child is CollisionShape3D and not child.disabled and child.shape is ConcavePolygonShape3D:
				var base := _rock_footprint(child.shape.get_faces(), child.global_transform)
				_stamp(field, base, 0.95, 1.0)
	for body: StaticBody3D in trunks:
		for child: Node in body.get_children():
			if not child is CollisionShape3D or child.disabled or not child.shape is CylinderShape3D:
				continue
			var base := PackedVector2Array()
			for i in 12:
				var point := Vector2.from_angle(TAU * i / 12.) * child.shape.radius
				var world: Vector3 = child.global_transform * Vector3(point.x, -0.5 * child.shape.height, point.y)
				base.append(Vector2(world.x, world.z))
			_stamp(field, base, 0.85, 1.0)
	return ImageTexture.create_from_image(field)

static func _rock_footprint(faces: PackedVector3Array, transform: Transform3D) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(0, faces.size(), 3):
		for j in 3:
			var a := transform * faces[i + j]
			var b := transform * faces[i + (j + 1) % 3]
			var a_inside := a.y <= ROCK_SLICE_HEIGHT
			if a_inside:
				points.append(Vector2(a.x, a.z))
			if a_inside != (b.y <= ROCK_SLICE_HEIGHT):
				var t := (ROCK_SLICE_HEIGHT - a.y) / (b.y - a.y)
				var clipped := a.lerp(b, t)
				points.append(Vector2(clipped.x, clipped.z))
	if points.size() < 3:
		return PackedVector2Array()
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[-1]:
		hull.remove_at(hull.size() - 1)
	return hull

static func _stamp(field: Image, footprint: PackedVector2Array, reach: float, strength: float) -> void:
	if footprint.size() < 3:
		return
	var bounds := Rect2(footprint[0], Vector2.ZERO)
	for point: Vector2 in footprint:
		bounds = bounds.expand(point)
	bounds = bounds.grow(reach)
	var lo := Vector2i(((bounds.position - ORIGIN) / CELL).floor()).clamp(Vector2i.ZERO, Vector2i.ONE * (SIZE - 1))
	var hi := Vector2i(((bounds.end - ORIGIN) / CELL).ceil()).clamp(Vector2i.ZERO, Vector2i.ONE * (SIZE - 1))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var world := ORIGIN + (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL
			var distance := 0.0
			if not Geometry2D.is_point_in_polygon(world, footprint):
				distance = reach
				for i in footprint.size():
					var nearest := Geometry2D.get_closest_point_to_segment(world, footprint[i], footprint[(i + 1) % footprint.size()])
					distance = minf(distance, world.distance_to(nearest))
			var occlusion := strength * (1.0 - smoothstep(0.0, reach, distance))
			if occlusion > field.get_pixel(x, y).r:
				field.set_pixel(x, y, Color(occlusion, 0., 0.))
