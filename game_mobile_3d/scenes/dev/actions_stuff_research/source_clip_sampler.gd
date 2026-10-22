extends "res://scripts/animation_pose_sampler.gd"
## Research PRS tracks; the production sampler deliberately has no scale channel.
var scales:=PackedInt32Array()
func _init(animation: Animation,rig: Skeleton3D) -> void:
	super(animation,rig)
	scales.resize(rig.get_bone_count());scales.fill(-1)
	for track in clip.get_track_count():
		if clip.track_get_type(track)!=Animation.TYPE_SCALE_3D:continue
		var path:=clip.track_get_path(track)
		if path.get_subname_count()>0:
			var bone:=rig.find_bone(path.get_subname(0))
			if bone>=0:scales[bone]=track
func scale(bone: int,time: float) -> Vector3:
	return clip.scale_track_interpolate(scales[bone],time) if scales[bone]>=0 else Vector3.ONE
