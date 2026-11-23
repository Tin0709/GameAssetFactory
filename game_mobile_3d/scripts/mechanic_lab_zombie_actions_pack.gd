extends RefCounted

const PACK_FILE := "source/pack/animations/f2da1072.json"
const SOURCE_PIXEL := 0.675 / 12.0
# Named entries, byte ranges and hashes of the existing private A&S 1.13 pack.
const CLIPS := {
	"baby_idle": ["xzyuea", 3654047, 865, "6fde7684d3b40df1bb6b10ec5fcf80c2d1302cd91d2696073b955fa4430ef183"],
	"baby_move": ["spjybv", 3677420, 1212, "ba5752e0566f81ad0d7603220531f8967a5bd8c94c1668909231a6cb007731e4"],
	"pursuit": ["witjtv", 3681487, 1868, "441610ee1c59eaeb919f73d3c3d605efaed1754b34510a2596fc8092d13b0f31"],
	"alert": ["isqbxt", 3665073, 1619, "959fae79e4c923750f4f2d391f070227a9e0d3db6502029f9eabd0c840eb3bc2"],
	"attack": ["craixf", 3641430, 2733, "a9b11271057f6d0964b621f35796c0b18c63f9969081f6eeacb92eecd3daec4d"],
	"jump": ["liruwo", 3669873, 1990, "f2514086d2600adcdba7674bbbf04d07cc4996ccb1caae172287a0d0caefedce"],
	"fall": ["efxmad", 3671864, 2430, "cb43c8a7ed66ddf50fe825706365933dcf5dc2be4690ae307e609972f773167f"],
	"land": ["ogdnrx", 3674295, 1174, "a87de59242a0128a036525703713076324985b7e226eccf9543af457fb8165df"],
}
const CHANNELS := {
	&"Hips": "waist", &"Chest": "body", &"Neck": "head",
	&"Arm.L": "leftarm", &"Arm.R": "rightarm",
	&"Leg.L": "leftleg", &"Leg.R": "rightleg",
}

class Channel:
	var times := PackedFloat64Array()
	var before: Array[Vector3] = []
	var after: Array[Vector3] = []
	var splines: Array[bool] = []
	var components: Array = []

	func _init(value: Variant) -> void:
		if value is Dictionary:
			var keys: Array = value.keys()
			keys.sort_custom(func(a: String, b: String) -> bool: return a.to_float() < b.to_float())
			for key: String in keys:
				times.append(key.to_float())
				var point: Variant = value[key]
				var outgoing: Array = point.get("post", point.get("pre")) if point is Dictionary else point
				var incoming: Array = point.get("pre", outgoing) if point is Dictionary else point
				before.append(Vector3(incoming[0], incoming[1], incoming[2]))
				after.append(Vector3(outgoing[0], outgoing[1], outgoing[2]))
				splines.append(point is Dictionary and point.get("lerp_mode") == "catmullrom")
		elif value is Array:
			for component: Variant in value:
				if component is String:
					var trig := RegEx.create_from_string("Math[.](sin|cos)[(]([^()]*)[)]")
					var expression := Expression.new()
					var translated := trig.sub(component, "$1(deg_to_rad($2))", true)
					translated = translated.replace("q.anim_time", "t").replace("q.life_time", "t")
					translated = translated.replace("v.cprttl", "grounded")
					if expression.parse(translated, ["t", "grounded"]) == OK:
						components.append(expression)
					else:
						push_error("Unsupported Actions & Stuff zombie channel: " + component)
						components.append(0.0)
				else:
					components.append(float(component))

	func sample(time: float, grounded: bool) -> Vector3:
		if times.is_empty():
			var point := Vector3.ZERO
			for axis in components.size():
				var component: Variant = components[axis]
				point[axis] = float(component.execute([time, float(grounded)], null, false, true)
					if component is Expression else component)
			return point
		var next := times.bsearch(time, false)
		if next == 0:
			return before[0]
		if next >= times.size():
			return after[-1]
		var previous := next - 1
		var t := inverse_lerp(times[previous], times[next], time)
		if not (splines[previous] or splines[next]):
			return after[previous].lerp(before[next], t)
		var p0 := after[maxi(0, previous - 1)]
		var p1 := after[previous]
		var p2 := before[next]
		var p3 := before[mini(next + 1, before.size() - 1)]
		return 0.5 * ((2.0 * p1) + (p2 - p0) * t
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
			+ (3.0 * p1 - 3.0 * p2 - p0 + p3) * t * t * t)

static func load_verified() -> Dictionary:
	if not OS.has_feature("editor"):
		return {}
	var root := OS.get_environment("ACT_RESEARCH_ROOT")
	if root.is_empty():
		var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
		root = project.get_base_dir().get_base_dir().path_join("ACT-Research-1.13")
	var file := FileAccess.open(root.path_join(PACK_FILE), FileAccess.READ)
	if file == null:
		return {}
	var result := {}
	for name: String in CLIPS:
		var entry: Array = CLIPS[name]
		file.seek(entry[1])
		var bytes := file.get_buffer(entry[2])
		var digest := HashingContext.new()
		if (bytes.size() != entry[2] or digest.start(HashingContext.HASH_SHA256) != OK
				or digest.update(bytes) != OK or digest.finish().hex_encode() != entry[3]):
			return {}
		var data: Dictionary = JSON.parse_string("{" + bytes.get_string_from_utf8() + "}")
		result[name] = data["animation.oreville_ans." + entry[0]]
	return result

# The controller composes local rotations and position offsets in pixel units.
# Root travel is supplied by the Lab; limbs retain their existing rigid lengths.
static func bake(bindings: Array, layers: Array[Dictionary], duration: float, loop: bool,
		rate: float, grounded: bool, base: Animation = null) -> Animation:
	var result := Animation.new()
	result.length = duration
	result.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var samples := ceili(duration * rate)
	for i in bindings.size():
		var bone: StringName = bindings[i][1]
		var path := NodePath(":%s" % bone)
		var pos := result.add_track(Animation.TYPE_POSITION_3D)
		var rot := result.add_track(Animation.TYPE_ROTATION_3D)
		result.track_set_path(pos, path)
		result.track_set_path(rot, path)
		var base_pos := base.find_track(path, Animation.TYPE_POSITION_3D) if base else -1
		var base_rot := base.find_track(path, Animation.TYPE_ROTATION_3D) if base else -1
		var position_channels: Array[Channel] = []
		var rotation_channels: Array[Channel] = []
		for layer: Dictionary in layers:
			var channels: Dictionary = layer.bones.get(CHANNELS.get(bone, ""), {})
			position_channels.append(Channel.new(channels.get("position")))
			rotation_channels.append(Channel.new(channels.get("rotation")))
		for sample in range(samples + 1):
			var time := minf(sample / rate, duration)
			var offset := Vector3.ZERO
			var angle := Vector3.ZERO
			for layer_index in layers.size():
				var clock: float = layers[layer_index].get("held_time", time)
				offset += position_channels[layer_index].sample(clock, grounded)
				angle += rotation_channels[layer_index].sample(clock, grounded)
			var point: Vector3 = bindings[i][2]
			var facing := Quaternion(Vector3.BACK, PI) if i >= 4 and i <= 7 else Quaternion.IDENTITY
			if base_pos >= 0:
				point = base.position_track_interpolate(base_pos, fposmod(time, base.length))
			if base_rot >= 0:
				facing = base.rotation_track_interpolate(base_rot, fposmod(time, base.length))
			# Source facing is -Z and Lab facing is +Z.
			point += offset * Vector3(1, 1, -1) * SOURCE_PIXEL
			var angles := angle * (PI / 180.0) * Vector3(1, -1, -1)
			result.position_track_insert_key(pos, time, point)
			result.rotation_track_insert_key(rot, time,
				(Basis.from_euler(angles, EULER_ORDER_ZYX).get_rotation_quaternion() * facing).normalized())
	return result
