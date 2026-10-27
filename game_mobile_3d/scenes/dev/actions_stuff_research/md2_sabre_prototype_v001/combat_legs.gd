extends RefCounted
## Source-backed leg branches; interpolation/weight policy is reconstructed.
## Never writes hips, spine, head, arms, weapon or facial channels.
var rig:Skeleton3D
var bones:Array[int]=[]
var weight:=0.
var blend_seconds:=.05
var _raw:Dictionary={}
func setup(skeleton:Skeleton3D,config:Dictionary)->bool:
	rig=skeleton
	if not config.get("leg_branches") is Array or config.leg_branches.size()!=2 or config.leg_branches[0]==config.leg_branches[1]:return false
	var roots:Array=[]
	for name:Variant in config.get("leg_branches",[]):
		if name not in ["J_L_Leg","J_R_Leg"]:return false
		var bone:=rig.find_bone(String(name))
		if bone<0:return false
		roots.append(bone)
	if roots.is_empty():return false
	for bone in rig.get_bone_count():
		var ancestor:=bone
		while ancestor>=0:
			if ancestor in roots:bones.append(bone);break
			ancestor=rig.get_bone_parent(ancestor)
	blend_seconds=maxf(.000001,float(config.get("blend_seconds",.05)));return true
func discard_raw()->void:_raw.clear()
func restore()->void:
	for bone:int in _raw:rig.set_bone_pose(bone,_raw[bone])
	_raw.clear()
func clear()->void:restore();weight=0.
func apply(pose:Array[Transform3D],moving:bool,delta:float)->void:
	weight=move_toward(weight,1. if moving else 0.,maxf(delta,0.)/blend_seconds)
	_raw.clear()
	for bone in bones:
		var base:=rig.get_bone_pose(bone);_raw[bone]=base
		if weight>0.:rig.set_bone_pose(bone,base.interpolate_with(pose[bone],weight))
