extends Node
## Applies a layout-bound far terrain shadow cache. The caller owns the lighting preset and play context.

const TileStream := preload("world_map_far_shadow_tiles.gd")
const MAX_MANIFEST_BYTES := 2 * 1024 * 1024
const MAX_ZONES := 32
const MAX_KEYS := 256
const RIDGE_LAYER := 1 << 19
const RESOLUTION := 384
const TEXTURE_BYTES := RESOLUTION * RESOLUTION * 2
const RELEASE_M := 28.0
const WIDE_M := 39.0
const TRANSFER_SECONDS := .24
const BOUND_DEGREES := .55
# Same endpoints as the one-sample branches in cached_receiver.gdshaderinc.
const SINGLE_KEY_EPSILON := .0001

static var _global_owner: WeakRef
static var _globals_registered := false

var sun: DirectionalLight3D
var record_metrics := false
var fade_in_minutes := 24.0
var fade_out_minutes := 36.0
var enabled := true
var require_both_tiles := false
var failure := ""
var peak_resident := 0
var transfers: Array[Dictionary] = []

var _stream: RefCounted
var upload_us: Array[int] = []
var holding_frames := 0
var waiting_frames := 0
var _last_upload_frame := -1
var _waiting := false
var _zones: Array[Dictionary] = []
var _first := 0.
var _last := 0.
var _dummy: ImageTexture
var _tiles := {}
var _active := {}
var _original_layers := {}
var _layer_flag := 0
var _life := 0.0
var _blend := 0.0
var _radius_mix := 0.0
var _pair: Array[String] = []
var _last_bound: Array[String] = []
var _source_scale := -1.


func register_globals() -> bool:
	if RenderingServer.get_current_rendering_method() != "mobile" or RenderingServer.get_rendering_device() == null:
		return false
	if _global_owner != null:
		var owner: Variant = _global_owner.get_ref()
		if is_instance_valid(owner):
			return owner == self
	_global_owner = weakref(self)
	_dummy = ImageTexture.create_from_image(Image.create_empty(1,1,false,Image.FORMAT_RH))
	for name: String in ["gaf_far_depth","gaf_far_depth_next"]:
		if _globals_registered:
			RenderingServer.global_shader_parameter_set(name, _dummy)
		else:
			RenderingServer.global_shader_parameter_add(name,RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D,_dummy)
	for name: String in ["gaf_far_x","gaf_far_y","gaf_far_z","gaf_far_filter","gaf_far_x_next","gaf_far_y_next",
			"gaf_far_z_next","gaf_far_filter_next","gaf_far_fit","gaf_far_key"]:
		if _globals_registered:
			RenderingServer.global_shader_parameter_set(name, Vector4.ZERO)
		else:
			RenderingServer.global_shader_parameter_add(name,RenderingServer.GLOBAL_VAR_TYPE_VEC4,Vector4.ZERO)
	_globals_registered = true
	return true


func configure(light: DirectionalLight3D, view: Camera3D, terrain_chunks: Array,
		directory: String, layout_path: String) -> bool:
	if _stream != null:
		return false
	failure = ""
	if light == null or view == null or terrain_chunks.is_empty() or directory.is_empty() or layout_path.is_empty():
		return _reject("Shadow cache requires a light, camera, terrain and layout")
	var manifest_path := directory.path_join("depth_manifest.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	if manifest_file == null or manifest_file.get_length() > MAX_MANIFEST_BYTES:
		return _reject("Shadow manifest is unavailable or too large")
	var manifest: Variant = JSON.parse_string(manifest_file.get_as_text())
	if not manifest is Dictionary or not _number(manifest.get("format")) or not _number(manifest.get("resolution")) \
			or manifest.format != 1 or manifest.resolution != RESOLUTION:
		return _reject("Invalid shadow manifest")
	var layout_hash := FileAccess.get_sha256(layout_path)
	if layout_hash.is_empty() or not manifest.get("layout_sha256") is String or manifest.layout_sha256 != layout_hash:
		return _reject("Shadow manifest layout does not match this map")
	if view.cull_mask & RIDGE_LAYER == 0 or light.light_cull_mask & RIDGE_LAYER == 0:
		return _reject("The camera or light cannot use the reserved terrain layer")
	var first: Variant = manifest.get("first_minute")
	var last: Variant = manifest.get("last_minute")
	if not _number(first) or not _number(last) or first < 0 or last > 1440 or last <= first:
		return _reject("Shadow manifest has an invalid time window")
	var raw_zones: Variant = manifest.get("zones")
	if not raw_zones is Array or raw_zones.is_empty() or raw_zones.size() > MAX_ZONES:
		return _reject("Shadow manifest has an invalid zone list")

	var geometry := {}
	for entry: Variant in terrain_chunks:
		if not entry is Dictionary or not entry.get("visual") is MeshInstance3D or not entry.get("caster") is MeshInstance3D:
			return _reject("Shadow cache could not identify the map terrain")
		var mesh: MeshInstance3D = entry.visual
		if mesh.layers & RIDGE_LAYER != 0 or entry.caster.layers & RIDGE_LAYER != 0:
			return _reject("The map already uses the reserved terrain layer")
		geometry[String(mesh.name)] = {
			"box": mesh.global_transform * mesh.get_aabb(),
			"nodes": [entry.visual, entry.caster],
		}
	var zones: Array[Dictionary] = []
	var known_names := {}
	for raw: Variant in raw_zones:
		var zone := _parse_zone(raw, geometry, first, last)
		if zone.is_empty() or known_names.has(zone.id):
			return _reject("Shadow manifest contains an invalid or duplicate zone")
		known_names[zone.id] = true
		zones.append(zone)
	sun = light
	_first = float(first)
	_last = float(last)
	_zones = zones
	_stream = TileStream.new()
	_stream.directory = directory.path_join("r16")
	_stream.byte_length = TEXTURE_BYTES
	_stream.record_timings = record_metrics
	return true


func _reject(message: String) -> bool:
	failure = message
	return false


func _parse_zone(raw: Variant, geometry: Dictionary, first: float, last: float) -> Dictionary:
	if not raw is Dictionary or not raw.get("id") is String or String(raw.id).is_empty():
		return {}
	var radius: Variant = raw.get("radius_m")
	if not _number(radius) or radius <= 0.0 or radius > 64.0 or not _numeric_array(raw.get("anchor"), 3):
		return {}
	var names: Variant = raw.get("groups")
	if not names is Array or names.is_empty() or names.size() > geometry.size():
		return {}
	var meshes: Array[MeshInstance3D] = []
	var boxes: Array[AABB] = []
	var used := {}
	for group: Variant in names:
		if not group is String or used.has(group) or not geometry.has(group):
			return {}
		used[group] = true
		boxes.append(geometry[group].box)
		for mesh: MeshInstance3D in geometry[group].nodes:
			meshes.append(mesh)
	var keys: Variant = raw.get("keys")
	if not keys is Array or keys.size() < 2 or keys.size() > MAX_KEYS:
		return {}
	var previous := -1.0
	for key: Variant in keys:
		if not _valid_key(key) or key.minute <= previous:
			return {}
		previous = key.minute
	if keys.front().minute != first or keys.back().minute != last:
		return {}
	return {"id": raw.id, "anchor": Vector2(raw.anchor[0], raw.anchor[2]), "radius": float(radius),
		"meshes": meshes, "boxes": boxes, "keys": keys}


func _valid_key(key: Variant) -> bool:
	if not key is Dictionary or not _number(key.get("minute")) or not key.get("file") is String \
			or not key.get("raw_sha256") is String or not _number(key.get("packed_bytes")):
		return false
	var file := String(key.file)
	if file.contains("/") or file.contains("\\") or not file.ends_with(".r16z") or file.length() > 128:
		return false
	if key.packed_bytes != floorf(key.packed_bytes) or key.packed_bytes < 1 or key.packed_bytes > TEXTURE_BYTES + 1024:
		return false
	var checksum := String(key.raw_sha256)
	if checksum.length() != 64 or not checksum.is_valid_hex_number(false) or checksum.begins_with("+") or checksum.begins_with("-"):
		return false
	if not _numeric_array(key.get("axis_x"), 4) or not _numeric_array(key.get("axis_y"), 4) \
			or not _numeric_array(key.get("axis_z"), 4) or not _numeric_array(key.get("light"), 3):
		return false
	if not _number(key.get("span")) or not _number(key.get("depth_range")) or key.span <= 0.0 or key.depth_range <= 0.0:
		return false
	return absf(_p3(key.light).length_squared() - 1.) < .01 and _p3(key.axis_z).length_squared() > 0.


func _numeric_array(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for component: Variant in value:
		if not _number(component):
			return false
	return true


func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _p4(value: Array) -> Vector4:
	return Vector4(value[0],value[1],value[2],value[3])

func _p3(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func _room(zone: Dictionary, position: Vector2) -> float:
	var nearest := INF
	for bound: AABB in zone.boxes:
		var contact := Vector2(clampf(position.x,bound.position.x,bound.end.x),clampf(position.y,bound.position.z,bound.end.z))
		nearest = minf(nearest,position.distance_to(contact))
	return nearest

func _distance_cap(zone: Dictionary, position: Vector3) -> float:
	var cap := 31.0
	for bound: AABB in zone.boxes:
		cap = maxf(cap,bound.get_center().distance_to(position))
	return cap

func _choose(position: Vector2, exclude := "") -> Dictionary:
	var choice := {}
	var best := INF
	for zone: Dictionary in _zones:
		if zone.id == exclude:
			continue
		var distance: float = position.distance_to(zone.anchor)
		var owned: bool = zone == _active
		var radius: float = zone.radius + (1.4 if owned else 0.)
		if distance > radius or _room(zone,position) < RELEASE_M:
			continue
		var score: float = distance/zone.radius - (.10 if owned else 0.)
		if score < best:
			best = score
			choice = zone
	return choice

func _id(key: Dictionary) -> String:
	return String(key.file)+"|"+String(key.raw_sha256)+"|"+str(int(key.packed_bytes))

func _promote_one(keys: Array, zone: Dictionary) -> void:
	var frame := Engine.get_process_frames()
	if _last_upload_frame == frame:
		return
	var desired: Array[String]=[]
	for key: Dictionary in keys:
		desired.append(_id(key))
	for key: Dictionary in keys:
		var id := _id(key)
		if _tiles.has(id):
			continue
		var bits: PackedByteArray=_stream.lookup(key)
		if bits.is_empty():
			continue
		var before:=Time.get_ticks_usec()
		var image:=Image.create_from_data(RESOLUTION,RESOLUTION,false,Image.FORMAT_RH,bits)
		var texture: ImageTexture
		if _tiles.size()==2:
			for old: String in _tiles.keys():
				if old not in desired:
					texture=_tiles[old].texture
					_tiles.erase(old)
					break
		if texture==null:
			texture=ImageTexture.create_from_image(image)
		else:
			texture.update(image)
		_tiles[id]={"texture":texture,"key":key.duplicate(),"zone":zone.id}
		_last_upload_frame=frame
		if record_metrics:
			upload_us.append(Time.get_ticks_usec()-before)
		peak_resident=maxi(peak_resident,_tiles.size())
		return

func _add_requests(out: Array, new_keys: Array) -> void:
	for key: Dictionary in new_keys:
		if not _tiles.has(_id(key)):
			out.append(key)

func _request_tiles(zone: Dictionary, choice: Dictionary, keys: Array, minute: float,
		position: Vector2, velocity: Vector3, single_index: int) -> void:
	var queue: Array=[]
	_add_requests(queue,_ordered_keys(keys,single_index))
	if not choice.is_empty() and zone!=choice:
		_add_requests(queue,_neighbor_keys(choice,minute))
	else:
		var ahead: Array=zone.keys
		var index:=ahead.find(keys[1])
		if index>=0 and index+1<ahead.size():
			_add_requests(queue,[ahead[index+1]])
		var predicted:=position + Vector2(velocity.x,velocity.z)*1.1
		var next_zone:=_choose(predicted,zone.id)
		if not next_zone.is_empty():
			_add_requests(queue,_neighbor_keys(next_zone,minute))
	_stream.update(queue)

func _neighbor_keys(zone: Dictionary, minute: float) -> Array:
	var frames: Array = zone.keys
	var low := 0
	var high := frames.size()-1
	while high-low > 1:
		var mid := (low+high)/2
		if float(frames[mid].minute) <= minute:
			low = mid
		else:
			high = mid
	return [frames[low],frames[high]]

func _set_tile(key: Dictionary, texture: Texture2D, suffix: String, cap: float) -> void:
	RenderingServer.global_shader_parameter_set("gaf_far_depth"+suffix,texture)
	RenderingServer.global_shader_parameter_set("gaf_far_x"+suffix,_p4(key.axis_x))
	RenderingServer.global_shader_parameter_set("gaf_far_y"+suffix,_p4(key.axis_y))
	RenderingServer.global_shader_parameter_set("gaf_far_z"+suffix,_p4(key.axis_z))
	RenderingServer.global_shader_parameter_set("gaf_far_filter"+suffix,Vector4(cap,key.span,key.depth_range,1./RESOLUTION))

func _bind_ready(primary: Dictionary, secondary: Dictionary, blend: float, cap: float) -> void:
	var ids: Array[String]=[_id(primary.key),_id(secondary.key)]
	if ids != _last_bound or absf(_source_scale-cap)>.25:
		_set_tile(primary.key,primary.texture,"",cap)
		_set_tile(secondary.key,secondary.texture,"_next",cap)
		_last_bound=ids
		_source_scale=cap
	_pair=[String(primary.key.file),String(secondary.key.file)]
	_blend=blend

func _blend_at(keys: Array, minute: float) -> float:
	var midpoint: float=(float(keys[0].minute)+float(keys[1].minute))*.5
	return smoothstep(midpoint-.19,midpoint+.19,minute)

func _single_key_index(blend: float) -> int:
	if require_both_tiles:
		return -1
	if blend <= SINGLE_KEY_EPSILON:
		return 0
	if blend >= 1. - SINGLE_KEY_EPSILON:
		return 1
	return -1

func _ordered_keys(keys: Array, single_index: int) -> Array:
	return [keys[1],keys[0]] if single_index==1 else keys

enum PairStatus {READY, HOLD, WAIT, ERROR}

func _matches_direction(keys: Array, blend: float, direction: Vector3) -> bool:
	var minimum_dot := cos(deg_to_rad(BOUND_DEGREES))
	return (blend >= 1. - SINGLE_KEY_EPSILON or direction.dot(_p3(keys[0].light)) >= minimum_dot) \
			and (blend <= SINGLE_KEY_EPSILON or direction.dot(_p3(keys[1].light)) >= minimum_dot)


func _prepare_pair(zone: Dictionary, keys: Array, single_index: int, direction: Vector3, cap: float, blend: float) -> PairStatus:
	for key: Dictionary in keys:
		var key_error: String=_stream.error_for(key)
		if not key_error.is_empty():
			failure=key_error
			return PairStatus.ERROR
	_promote_one(_ordered_keys(keys,single_index),zone)
	var first: Dictionary=_tiles.get(_id(keys[0]),{})
	var last: Dictionary=_tiles.get(_id(keys[1]),{})
	if not first.is_empty() and not last.is_empty():
		_bind_ready(first,last,blend,cap)
		return PairStatus.READY
	if single_index >= 0:
		var sampled := first if single_index == 0 else last
		if not sampled.is_empty():
			# Both sampler slots point to the exact active key until its neighbor uploads.
			_bind_ready(sampled,sampled,0.,cap)
			return PairStatus.READY
	if _active==zone:
		var best := {}
		var match_angle := cos(deg_to_rad(BOUND_DEGREES))
		for tile: Dictionary in _tiles.values():
			if tile.zone!=zone.id:
				continue
			var score:=direction.dot(_p3(tile.key.light))
			if score>=match_angle:
				match_angle=score
				best=tile
		if not best.is_empty():
			_bind_ready(best,best,0.,cap)
			holding_frames+=1
			return PairStatus.HOLD
	return PairStatus.WAIT

func _attach(zone: Dictionary, minute: float) -> void:
	_layer_flag = sun.shadow_caster_mask & RIDGE_LAYER
	for mesh: MeshInstance3D in zone.meshes:
		_original_layers[mesh] = mesh.layers
		mesh.layers = RIDGE_LAYER
	sun.shadow_caster_mask &= ~RIDGE_LAYER
	_active = zone
	if record_metrics:
		transfers.append({"zone":zone.id,"minute":minute,"active":true})

func _restore(minute := 0., drop_textures := true) -> void:
	if not _active.is_empty():
		for mesh: MeshInstance3D in _original_layers:
			if is_instance_valid(mesh):
				mesh.layers = _original_layers[mesh]
		if is_instance_valid(sun):
			sun.shadow_caster_mask = (sun.shadow_caster_mask & ~RIDGE_LAYER) | _layer_flag
		if record_metrics:
			transfers.append({"zone":_active.id,"minute":minute,"active":false})
		_active = {}
		_original_layers.clear()
	_life = 0.
	_pair.clear()
	_last_bound.clear()
	if drop_textures:
		_tiles.clear()
	_source_scale = -1.
	_blend = 0.
	_radius_mix = 0.
	RenderingServer.global_shader_parameter_set("gaf_far_key",Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("gaf_far_depth",_dummy)
	RenderingServer.global_shader_parameter_set("gaf_far_depth_next",_dummy)

func wants_receivers(player: Vector3, minute: float) -> bool:
	if _stream == null or not is_instance_valid(sun) or not sun.shadow_enabled \
			or not is_finite(minute) or minute < _first or minute >= _last:
		return false
	var zone := _active if not _active.is_empty() else _choose(Vector2(player.x, player.z))
	if zone.is_empty():
		return false
	# A different solar preset can have the same clock time and a different light vector.
	var keys := _neighbor_keys(zone, minute)
	return _matches_direction(keys, _blend_at(keys, minute), sun.global_basis.z.normalized())


func update_shadow(delta: float, player: Vector3, velocity: Vector3,
		minute: float, context_allows_shadows: bool) -> void:
	if _stream == null or _dummy == null or _global_owner == null or _global_owner.get_ref() != self or not is_instance_valid(sun):
		return
	if not enabled or not context_allows_shadows or not sun.shadow_enabled \
			or not is_finite(minute) or minute < _first or minute >= _last:
		_stream.update([])
		if not _active.is_empty() or not _tiles.is_empty():
			_restore(minute)
		_waiting=false
		return
	var position := Vector2(player.x,player.z)
	var choice := _choose(position)
	var direction := sun.global_basis.z.normalized()
	if not _active.is_empty():
		if _room(_active,position) < RELEASE_M:
			_restore(minute,choice.is_empty())
		elif _active != choice:
			_life = maxf(0.,_life-delta/TRANSFER_SECONDS)
			if is_zero_approx(_life):
				_restore(minute,choice.is_empty())
		else:
			_life = minf(1.,_life+delta/TRANSFER_SECONDS)
	if _active.is_empty() and choice.is_empty():
		_stream.update([])
		if not _tiles.is_empty():
			_restore(minute)
		_waiting=false
		return
	var zone := choice if _active.is_empty() else _active
	var keys:=_neighbor_keys(zone,minute)
	var blend:=_blend_at(keys,minute)
	if not _matches_direction(keys, blend, direction):
		_stream.update([])
		_waiting = false
		failure = "The current sun falls outside the baked direction"
		_restore(minute)
		return
	var single_index:=_single_key_index(blend)
	_request_tiles(zone,choice,keys,minute,position,velocity,single_index)
	var status:=_prepare_pair(zone,keys,single_index,direction,_distance_cap(zone,player),blend)
	_waiting=status==PairStatus.WAIT
	if status==PairStatus.ERROR:
		_restore(minute)
		return
	if _waiting:
		waiting_frames+=1
		if not _active.is_empty():
			_restore(minute,false)
		return
	if _active.is_empty():
		_attach(zone,minute)
	failure=""
	var distance := _room(zone,position)
	var reach := smoothstep(RELEASE_M,WIDE_M,distance)
	var fade_in := clampf(fade_in_minutes,.001,(_last-_first)*.5)
	var fade_out := clampf(fade_out_minutes,.001,(_last-_first)*.5)
	var phase := smoothstep(_first,_first+fade_in,minute)*(1.-smoothstep(_last-fade_out,_last,minute))
	var rim: float = position.distance_to(zone.anchor)
	var boundary := 1.-smoothstep(zone.radius-3.,zone.radius+1.4,rim)
	_radius_mix=reach*phase*boundary*_life
	RenderingServer.global_shader_parameter_set("gaf_far_fit",Vector4(.16,_radius_mix,_blend,0.))
	RenderingServer.global_shader_parameter_set("gaf_far_key",Vector4(direction.x,direction.y,direction.z,1.))

func snapshot() -> Dictionary:
	return {"zone":_active.get("id",""),"blend":_blend,"pair":_pair.duplicate(),"resident":_tiles.size(),
		"lifecycle":_life,"radius_mix":_radius_mix,"failure":failure,"loading":_waiting,
		"stream":_stream.snapshot() if _stream!=null else {}}

func _exit_tree() -> void:
	if _dummy != null and _global_owner != null and _global_owner.get_ref() == self:
		_restore()
		_global_owner = null
		_dummy = null
	if _stream != null:
		_stream.close()
