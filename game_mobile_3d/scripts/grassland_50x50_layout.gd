extends RefCounted
## Pure seeded placement; density changes are reproducible and independent of rendering.
const WIDTH := 50
const ROCK_CENTERS := [Vector2(-11,-9), Vector2(13,-12), Vector2(-16,12), Vector2(15,15), Vector2(8,8)]
const FLOWER_CENTERS := [Vector2(4,3.5),Vector2(-6,-5),Vector2(11,-8),Vector2(-14,8),Vector2(14,13),Vector2(-10,-17)]
var seed_value := 8055
var dirt_density := 1.0
var grass: Array[Transform3D] = []
var props := {}
var dirt_cells := 0

func path_distance(p: Vector2) -> float:
	var north_south := absf(p.x - 3.4 * sin(p.y * 0.16))
	var east_west := absf(p.y - (7.0 + 2.6 * sin(p.x * 0.20)))
	return minf(north_south, east_west)

func is_clear(p: Vector2, margin := 0.0) -> bool:
	return p.length() < 2.5 + margin or path_distance(p) < 1.15 + margin

func is_dirt(p: Vector2) -> bool:
	if path_distance(p) < 1.05: return true
	if p.length() < 2.45: return false
	for center in ROCK_CENTERS:
		var edge := 1.5 + 0.3 * sin(p.x * 2.1 + p.y * 1.6)
		if p.distance_to(center) < edge * dirt_density: return true
	return false

func build(entries: Array, seed_input: int, grass_density: float, rock_density: float, flower_density: float, ground_density: float) -> void:
	seed_value = seed_input
	dirt_density = ground_density
	grass.clear(); props.clear(); dirt_cells = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for z in range(WIDTH):
		for x in range(WIDTH):
			var p := Vector2(x - 24.5, z - 24.5)
			if is_dirt(p): dirt_cells += 1
			if is_clear(p,0.3) or absf(p.x) > 23 or absf(p.y) > 23: continue
			# Dense southwest meadow and a broad open southeast field.
			var density := 0.36 + 0.22 * sin(p.x * 0.22 + sin(p.y * 0.15))
			if p.distance_to(Vector2(-7,5)) < 6.0: density = 0.86
			if p.distance_to(Vector2(9,-1)) < 6.0: density = 0.10
			if rng.randf() < density * grass_density:
				p += Vector2(rng.randf_range(-0.18,0.18),rng.randf_range(-0.18,0.18))
				grass.append(make_transform(p,rng,1.0))
	for entry in entries:
		var transforms: Array[Transform3D] = []
		var category := str(entry.category)
		var count := 0
		match category:
			"rock": count = maxi(1,roundi((14 if entry.variant == "small" else 7) * rock_density))
			"flower": count = maxi(1,roundi((24 if entry.variant == "red" else 44) * flower_density))
			"dirt": count = maxi(1,roundi(12 * ground_density))
		for i in range(count):
			var p := Vector2.ZERO
			var accepted := false
			for attempt in range(120):
				var center: Vector2
				if category == "flower":
					# Every color has a near-spawn mixed cluster, plus distant color fields.
					center = FLOWER_CENTERS[0] if i < count / 3 else FLOWER_CENTERS[(int(entry.get("placement_index",0)) + i / 12) % FLOWER_CENTERS.size()]
					p = center + Vector2(rng.randfn(0,1.65),rng.randfn(0,1.65))
				else:
					center = ROCK_CENTERS[i % ROCK_CENTERS.size()]
					p = center + Vector2(rng.randfn(0,1.25),rng.randfn(0,1.25))
				if absf(p.x) > 23 or absf(p.y) > 23 or is_clear(p,0.8 if category == "rock" else 0.25): continue
				if category == "rock" and not rock_clear(p,0.9,transforms): continue
				accepted = true
				break
			if not accepted: continue
			var transform := make_transform(p,rng,rng.randf_range(0.94,1.06))
			if category == "dirt": transform.origin.y = 0.975
			transforms.append(transform)
		props[entry.name] = transforms

func rock_clear(p: Vector2, clearance: float, pending: Array[Transform3D] = []) -> bool:
	for t in pending:
		if p.distance_to(Vector2(t.origin.x,t.origin.z)) < clearance: return false
	for name in props:
		if not str(name).begins_with("ENV_Rock"): continue
		for t in props[name]:
			if p.distance_to(Vector2(t.origin.x,t.origin.z)) < clearance: return false
	return true

func make_transform(p: Vector2, rng: RandomNumberGenerator, scale_value: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE * scale_value),Vector3(p.x,1,p.y))

func landmarks() -> Dictionary:
	return {"open_walk":Vector3(9,1.02,-1), "dense_grass":Vector3(-7,1.02,5), "rocks":Vector3(-8,1.02,-9), "flowers":Vector3(4,1.02,3.5), "dirt":Vector3(3.4*sin(12*0.16),1.02,12), "spawn":Vector3(0,1.02,0)}


