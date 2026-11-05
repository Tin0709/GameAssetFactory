extends RefCounted
## Original art-directed placement using the existing flower inventory.

static func compose(roots:Array[Vector2],colors:PackedInt32Array,obstacles:Array[Rect2],path_center:Callable,batch_size:float,map_half:float)->Array[Vector2]:
	var occupied:Dictionary={}
	for p:Vector2 in roots:
		var cell:=Vector2i(p.floor())
		if not occupied.has(cell):occupied[cell]=[]
		occupied[cell].append(p)
	var blockers:=_index_obstacles(obstacles)
	var result:Array[Vector2]=[]
	var noise:=FastNoiseLite.new()
	noise.seed=617941
	noise.frequency=.105
	noise.fractal_octaves=2
	for i in roots.size():
		var root:=roots[i]
		var path_x:float=path_center.call(root.y)
		var side:=signf(root.x-path_x)
		var near_path:=1.-smoothstep(5.,10.,absf(root.x-path_x))
		var sample_offset:=1.3
		var gradient:=Vector2(noise.get_noise_2dv(root+Vector2(sample_offset,0))-noise.get_noise_2dv(root-Vector2(sample_offset,0)),
				noise.get_noise_2dv(root+Vector2(0,sample_offset))-noise.get_noise_2dv(root-Vector2(0,sample_offset)))
		var shift:=gradient*3.
		var tint_phase:=float(colors[i])*.63
		var around_bend:=sin(root.y*.31+side*1.55+tint_phase)
		shift.x+=near_path*side*around_bend*.68
		shift.y+=near_path*(sin(root.y*.33+side*1.8-tint_phase))*1.75
		var bank_pocket:=smoothstep(-.1,.72,sin(root.y*.29+side*1.65))
		var side_distance:=absf(root.x-path_x)
		var toward_bank:=clampf(2.8-side_distance,-1.9,0.)
		shift.x+=side*toward_bank*near_path*bank_pocket
		shift.y+=near_path*bank_pocket*sin(root.y*.42+side)*.7
		shift=shift.limit_length(2.7)
		var first_cell:=Vector2i(root.floor())
		occupied[first_cell].erase(root)
		var next:=root
		var cell_origin:=(root/batch_size).floor()*batch_size
		var min_bound:=(cell_origin+Vector2.ONE*.03).max(Vector2.ONE*(-map_half+1.))
		var max_bound:=(cell_origin+Vector2.ONE*(batch_size-.03)).min(Vector2.ONE*(map_half-1.))
		for attempt:int in 6:
			var candidate:=root+shift*pow(.68,float(attempt))
			if candidate!=candidate.clamp(min_bound,max_bound):continue
			var distance:float=(candidate.x-float(path_center.call(candidate.y)))*side
			if distance<1.83:continue
			if _blocked(candidate,blockers):continue
			if not _has_spacing(candidate,occupied):continue
			next=candidate
			break
		var final_cell:=Vector2i(next.floor())
		if not occupied.has(final_cell):occupied[final_cell]=[]
		occupied[final_cell].append(next)
		result.append(next)
	return result

static func _has_spacing(p:Vector2,occupied:Dictionary)->bool:
	var cell:=Vector2i(p.floor())
	for dy in range(-1,2):
		for dx in range(-1,2):
			for other:Vector2 in occupied.get(cell+Vector2i(dx,dy),[]):
				if p.distance_squared_to(other)<.14:return false
	return true

static func _index_obstacles(obstacles:Array[Rect2])->Dictionary:
	var blockers:Dictionary={}
	for region in obstacles:
		var lo:=Vector2i((region.position/4.).floor())
		var hi:=Vector2i((region.end/4.).floor())
		for z in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				var cell:=Vector2i(x,z)
				if not blockers.has(cell):blockers[cell]=[]
				blockers[cell].append(region)
	return blockers

static func _blocked(point:Vector2,blockers:Dictionary)->bool:
	for region:Rect2 in blockers.get(Vector2i((point/4.).floor()),[]):
		if region.has_point(point):return true
	return false
