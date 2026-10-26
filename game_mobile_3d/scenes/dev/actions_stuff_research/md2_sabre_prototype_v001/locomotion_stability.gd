extends RefCounted
## Runtime study adapter, NOT a recovered MD2 blend graph. Original keys and
## source clocks stay intact. Only grounded spine/head orientations are damped.
const RETAINED_OSCILLATION:=.25
const FADE_SECONDS:=.10
var rig:Skeleton3D
var bones:Array[int]=[]
var references:Dictionary={}
var strength:=0.
var last_key:="Run"
var _saved:Dictionary={}

func setup(skeleton:Skeleton3D,player:AnimationPlayer,clips:Dictionary)->void:
	rig=skeleton;bones=[rig.find_bone("J_Spine"),rig.find_bone("J_Head")]
	assert(bones[0]>=0 and bones[1]>=0)
	# Calculate cycle means from the loaded source, never bake/rewrite its keys.
	for key:String in ["Walk","Run"]:
		var sums:Array[Quaternion]=[Quaternion(0,0,0,0),Quaternion(0,0,0,0)]
		var first:Array[Quaternion]=[];player.play(clips[key].action,0.)
		for sample in 96:
			player.seek(float(clips[key].duration)*sample/96.,true);rig.force_update_all_bone_transforms()
			for side in 2:
				var q:=rig.get_bone_global_pose(bones[side]).basis.orthonormalized().get_rotation_quaternion()
				if sample==0:first.append(q)
				if q.dot(first[side])<0.:q=-q
				sums[side]+=q
		references[key]=[sums[0].normalized(),sums[1].normalized()]
	player.stop()

func restore()->void:
	for bone:int in _saved:rig.set_bone_pose(bone,_saved[bone])
	if not _saved.is_empty():rig.force_update_all_bone_transforms()
	_saved.clear()

func deactivate()->void:restore();strength=0.

func apply(key:String,delta:float,wanted:bool)->void:
	strength=move_toward(strength,1. if wanted else 0.,maxf(0.,delta)/FADE_SECONDS)
	if wanted:last_key="Run" if key in ["Run","CombatRun"] else "Walk"
	if strength<=0.:return
	var raw:Array[Transform3D]=[]
	for bone in bones:raw.append(rig.get_bone_global_pose(bone));_saved[bone]=rig.get_bone_pose(bone)
	var retain:=1.-strength*(1.-RETAINED_OSCILLATION)
	for side in 2:
		var bone:=bones[side]
		var source_q:=raw[side].basis.orthonormalized().get_rotation_quaternion()
		var target_q:Quaternion=Quaternion(references[last_key][side]).slerp(source_q,retain)
		# Head target is in skeleton space: don't retain the original head's full
		# inverse-spine correction after reducing the spine, which would add nod.
		var current:=rig.get_bone_global_pose(bone)
		var current_q:=current.basis.orthonormalized().get_rotation_quaternion()
		var target:=Transform3D(Basis(target_q)*Basis(current_q).inverse()*current.basis,current.origin)
		var parent:=rig.get_bone_parent(bone)
		var parent_pose:=rig.get_bone_global_pose(parent) if parent>=0 else Transform3D.IDENTITY
		rig.set_bone_pose(bone,parent_pose.affine_inverse()*target);rig.force_update_all_bone_transforms()
