extends "res://scenes/dev/actions_stuff_research/source_clip_sampler.gd"
## Approved full evaluated PRS; the auxiliary value track is a palm target, not a bone.
var support_track: int=-1
func _init(animation: Animation,rig: Skeleton3D) -> void:
 super(animation,rig)
 for track in clip.get_track_count():
  if clip.track_get_type(track)==Animation.TYPE_VALUE and str(clip.track_get_path(track))=="RifleSupportAnchor":support_track=track
 assert(support_track>=0)
func pose(bone: int,time: float) -> Transform3D:
 return Transform3D(Basis(rotation(bone,time)).scaled(scale(bone,time)),position(bone,time))
func support(time: float) -> Vector3:
 return clip.value_track_interpolate(support_track,time)
