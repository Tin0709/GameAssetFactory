extends RefCounted
## A short, wall-clock pose handoff, independent of the source sampling clock.
## Snapshot the currently composed raw pose on interruption. This is a lab
## adapter, NOT a recovered MD2 animation graph or a foot-lock solver.
var rig:Skeleton3D
var elapsed:=0.
var duration:=0.
var _from:Array[Transform3D]=[]
var _last:Array[Transform3D]=[]
var _raw:Array[Transform3D]=[]
var _head:=-1
var _faces:Array[int]=[]
var _parents:Array[int]=[]
func setup(skeleton:Skeleton3D)->void:
	rig=skeleton;_head=rig.find_bone("J_Head")
	for name:String in ["J_L_EyeIris","J_R_EyeIris","J_L_Eyebrow","J_R_Eyebrow","J_Mouth"]:_faces.append(rig.find_bone(name))
	for bone in rig.get_bone_count():_parents.append(rig.get_bone_parent(bone))
func clear()->void:
	_from.clear();_last.clear();_raw.clear();elapsed=0.;duration=0.
func restore()->void:
	for bone in _raw.size():rig.set_bone_pose(bone,_raw[bone])
	_raw.clear()
func begin(seconds:float)->void:
	_from=_last.duplicate()
	if _from.is_empty():
		for bone in rig.get_bone_count():_from.append(rig.get_bone_pose(bone))
	duration=maxf(seconds,0.);elapsed=0.
func _worlds(local:Array[Transform3D])->Array[Transform3D]:
	var world:Array[Transform3D]=[]
	for bone in local.size():world.append(world[_parents[bone]]*local[bone] if _parents[bone]>=0 else local[bone])
	return world
func apply(delta:float)->void:
	_raw.clear()
	for bone in rig.get_bone_count():_raw.append(rig.get_bone_pose(bone))
	elapsed+=maxf(delta,0.)
	var alpha:=1. if duration<=0. else clampf(elapsed/duration,0.,1.)
	if _from.size()!=_raw.size() or alpha>=1.:
		_last=_raw.duplicate();_from.clear();return
	if alpha<=0.:
		_last=_from.duplicate()
	else:
		_last.clear()
		for bone in _raw.size():_last.append(_from[bone].interpolate_with(_raw[bone],alpha))
		# Source facial roots are neck siblings, not children of Head. Blend them
		# relative to Head, so a transition cannot send a face plane through it.
		var from_world:=_worlds(_from);var raw_world:=_worlds(_raw);var result_world:Array[Transform3D]=[]
		var from_inverse:=from_world[_head].affine_inverse();var raw_inverse:=raw_world[_head].affine_inverse()
		for bone in _last.size():
			var parent:Transform3D=result_world[_parents[bone]] if _parents[bone]>=0 else Transform3D.IDENTITY
			var current:=parent*_last[bone]
			if bone in _faces:
				var relative:Transform3D=(from_inverse*from_world[bone]).interpolate_with(raw_inverse*raw_world[bone],alpha)
				current=result_world[_head]*relative;_last[bone]=parent.affine_inverse()*current
			result_world.append(current)
	for bone in _last.size():rig.set_bone_pose(bone,_last[bone])
