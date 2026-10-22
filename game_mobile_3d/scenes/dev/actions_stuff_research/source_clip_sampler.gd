extends "res://scripts/animation_pose_sampler.gd"
## Research PRS tracks; the production sampler deliberately has no scale channel.
var scales:=PackedInt32Array()
# Source clips have many fixed PRS tracks. Share immutable track constants per
# Animation; varying tracks still use the exact native interpolator every tick.
static var _constant_tracks:Dictionary={}
var _fixed_position:Dictionary={}
var _fixed_rotation:Dictionary={}
var _fixed_scale:Dictionary={}
func _init(animation: Animation,rig: Skeleton3D) -> void:
	super(animation,rig)
	scales.resize(rig.get_bone_count());scales.fill(-1)
	for track in clip.get_track_count():
		if clip.track_get_type(track)!=Animation.TYPE_SCALE_3D:continue
		var path:=clip.track_get_path(track)
		if path.get_subname_count()>0:
			var bone:=rig.find_bone(path.get_subname(0))
			if bone>=0:scales[bone]=track
	if not _constant_tracks.has(clip):
		var fixed:Dictionary={}
		for track in clip.get_track_count():
			var type:=clip.track_get_type(track)
			if type not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:continue
			if clip.track_get_key_count(track)==0:continue
			var first:Variant=clip.track_get_key_value(track,0)
			var constant:=true
			for key in range(1,clip.track_get_key_count(track)):
				if clip.track_get_key_value(track,key)!=first:constant=false;break
			if constant:fixed[track]=first.normalized() if type==Animation.TYPE_ROTATION_3D else first
		_constant_tracks[clip]=fixed
	var fixed:Dictionary=_constant_tracks[clip]
	for bone in rig.get_bone_count():
		if fixed.has(positions[bone]):_fixed_position[bone]=fixed[positions[bone]]
		if fixed.has(rotations[bone]):_fixed_rotation[bone]=fixed[rotations[bone]]
		if fixed.has(scales[bone]):_fixed_scale[bone]=fixed[scales[bone]]

func position(bone:int,time:float)->Vector3:
	return _fixed_position[bone] if _fixed_position.has(bone) else super.position(bone,time)
func rotation(bone:int,time:float)->Quaternion:
	return _fixed_rotation[bone] if _fixed_rotation.has(bone) else super.rotation(bone,time)
func scale(bone: int,time: float) -> Vector3:
	if _fixed_scale.has(bone):return _fixed_scale[bone]
	return clip.scale_track_interpolate(scales[bone],time) if scales[bone]>=0 else Vector3.ONE
