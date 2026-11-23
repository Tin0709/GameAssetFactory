extends RefCounted

const PACK_FILE := "source/pack/animations/f2da1072.json"
const MOVE_BABY := "animation.oreville_ans.spjybv"
# Byte range of the complete named animation entry in the A&S 1.13 source pack.
const CLIP_OFFSET := 3677420
const CLIP_SIZE := 1212
const CLIP_HASH := "ba5752e0566f81ad0d7603220531f8967a5bd8c94c1668909231a6cb007731e4"
const SOURCE_PIXEL := 0.675 / 12.0
const CHANNELS := {
	&"Hips": "waist", &"Chest": "body", &"Neck": "head",
	&"Arm.L": "leftarm", &"Arm.R": "rightarm",
	&"Leg.L": "leftleg", &"Leg.R": "rightleg",
}

class Channel:
	var times := PackedFloat64Array()
	var values: Array[Vector3] = []
	var components: Array = []

	func _init(value: Variant) -> void:
		if value is Dictionary:
			var keys: Array = value.keys()
			keys.sort_custom(func(a: String, b: String) -> bool: return a.to_float() < b.to_float())
			for key: String in keys:
				var point: Array = value[key]
				times.append(key.to_float())
				values.append(Vector3(point[0], point[1], point[2]))
		elif value is Array:
			for component: Variant in value:
				if component is String:
					var trig := RegEx.create_from_string("Math[.](sin|cos)[(]([^()]*)[)]")
					var expression := Expression.new()
					var translated := trig.sub(component, "$1(deg_to_rad($2))", true)
					translated = translated.replace("q.anim_time", "t").replace("v.cprttl", "grounded")
					if expression.parse(translated, ["t", "grounded"]) == OK:
						components.append(expression)
					else:
						components.append(0.0)
				else:
					components.append(float(component))

	func sample(time: float) -> Vector3:
		if not times.is_empty():
			var next := times.bsearch(time)
			if next == 0:
				return values[0]
			if next >= times.size():
				return values[-1]
			return values[next - 1].lerp(values[next], inverse_lerp(times[next - 1], times[next], time))
		var point := Vector3.ZERO
		for axis in components.size():
			var value: Variant = components[axis]
			# This locomotion preset samples the grounded branch.
			point[axis] = float(value.execute([time, 1.0], null, false, true) if value is Expression else value)
		return point

static func build(idle: Animation, rate: float) -> Animation:
	var root := OS.get_environment("ACT_RESEARCH_ROOT")
	if root.is_empty():
		var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
		root = project.get_base_dir().get_base_dir().path_join("ACT-Research-1.13")
	var source := _read_source_clip(root.path_join(PACK_FILE))
	if source.is_empty():
		return null
	var clip := Animation.new()
	clip.length = float(source.animation_length)
	clip.loop_mode = Animation.LOOP_LINEAR
	var sample_count := ceili(clip.length * rate)
	for bone_index in range(0, idle.get_track_count(), 3):
		var bone_path := idle.track_get_path(bone_index)
		var bone := bone_path.get_subname(0)
		var channels: Dictionary = source.bones.get(CHANNELS.get(bone, ""), {})
		var offset := Channel.new(channels.get("position"))
		var angle := Channel.new(channels.get("rotation"))
		var location_track := clip.add_track(Animation.TYPE_POSITION_3D)
		var rotation_track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(location_track, bone_path)
		clip.track_set_path(rotation_track, bone_path)
		for sample in range(sample_count + 1):
			var time := minf(sample / rate, clip.length)
			# Preserve the existing idle sway under the baby move layer.
			# Sampling one full, symmetric segment keeps both ends continuous.
			var idle_time := minf(time, clip.length - time)
			var pos := idle.position_track_interpolate(bone_index, idle_time)
			var base_rot := idle.rotation_track_interpolate(bone_index + 1, idle_time)
			var move := offset.sample(time) * SOURCE_PIXEL
			# The pack's front is -Z. The Lab's front is +Z.
			pos += move * Vector3(1, 1, -1)
			var rotation := angle.sample(time) * (PI / 180.0) * Vector3(1, -1, -1)
			var pose := Basis.from_euler(rotation, EULER_ORDER_ZYX).get_rotation_quaternion() * base_rot
			clip.position_track_insert_key(location_track, time, pos)
			clip.rotation_track_insert_key(rotation_track, time, pose.normalized())
	return clip

static func _read_source_clip(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < CLIP_OFFSET + CLIP_SIZE:
		return {}
	# Parse just the verified clip so startup does not load the rest of the pack.
	file.seek(CLIP_OFFSET)
	var bytes := file.get_buffer(CLIP_SIZE)
	var digest := HashingContext.new()
	if (bytes.size() != CLIP_SIZE or digest.start(HashingContext.HASH_SHA256) != OK
			or digest.update(bytes) != OK or digest.finish().hex_encode() != CLIP_HASH):
		return {}
	var data: Dictionary = JSON.parse_string("{" + bytes.get_string_from_utf8() + "}")
	return data[MOVE_BABY]
