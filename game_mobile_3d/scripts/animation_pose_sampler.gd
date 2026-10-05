extends RefCounted
## Cached imported Animation tracks. One persistent phase drives both gait clips.
var clip: Animation
var positions := PackedInt32Array()
var rotations := PackedInt32Array()
var rests: Array[Transform3D] = []

func _init(animation: Animation, skeleton: Skeleton3D) -> void:
	clip = animation
	positions.resize(skeleton.get_bone_count())
	rotations.resize(skeleton.get_bone_count())
	positions.fill(-1)
	rotations.fill(-1)
	for i in skeleton.get_bone_count(): rests.append(skeleton.get_bone_rest(i))
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var bone := skeleton.find_bone(path.get_subname(0))
		if bone < 0: continue
		if clip.track_get_type(track) == Animation.TYPE_POSITION_3D: positions[bone] = track
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D: rotations[bone] = track

func position(bone: int, time: float) -> Vector3:
	return clip.position_track_interpolate(positions[bone], time) if positions[bone] >= 0 else rests[bone].origin

func rotation(bone: int, time: float) -> Quaternion:
	return clip.rotation_track_interpolate(rotations[bone], time).normalized() if rotations[bone] >= 0 else rests[bone].basis.get_rotation_quaternion()
