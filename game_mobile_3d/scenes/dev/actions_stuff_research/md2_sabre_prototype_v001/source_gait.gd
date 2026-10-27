extends RefCounted
## Compose existing imported sources on one normalized phase. Sample settings
## come from the private profile; local/face interpolation is our reconstruction.
var rig:Skeleton3D
var samples:Array[Dictionary]=[]
var base_speed:=1.
var animations:Dictionary={}
var channels:Dictionary={}
var defaults:Array[Transform3D]=[]
var positions:Array[Vector3]=[]
var rotations:Array[Quaternion]=[]
var scales:Array[Vector3]=[]
var parents:Array[int]=[]
var faces:Array[int]=[]
var head:=-1

func setup(skeleton:Skeleton3D,player:AnimationPlayer,clips:Dictionary,config:Variant)->bool:
	if not config is Dictionary or config.get("schema","")!="md2-private-source-gait/1" or not config.get("samples") is Array:return false
	var native_speed:Variant=config.get("base_speed_cm_s")
	if not (native_speed is float or native_speed is int) or not is_finite(float(native_speed)) or float(native_speed)<=0.:return false
	var validated:Array[Dictionary]=[]
	for value:Variant in config.samples:
		if not value is Dictionary or not value.get("semantic") is String:return false
		var key:String=value.semantic
		if key not in ["Idle","Walk","Run"] or not clips.has(key) or value.get("source_name")!=clips[key].source_name:return false
		for field:String in ["input","duration","rate"]:
			var number:Variant=value.get(field)
			if not (number is float or number is int) or not is_finite(float(number)):return false
		if float(value.rate)<=0. or absf(float(value.duration)-float(clips[key].duration))>.001:return false
		if not validated.is_empty() and float(value.input)<=float(validated[-1].input):return false
		validated.append(value)
	if validated.size()!=3 or validated[0].semantic!="Idle" or validated[1].semantic!="Walk" or validated[2].semantic!="Run":return false
	rig=skeleton;samples=validated;base_speed=float(native_speed)/100.
	var saved:Array[Transform3D]=[]
	for bone in rig.get_bone_count():saved.append(rig.get_bone_pose(bone))
	rig.reset_bone_poses()
	for bone in rig.get_bone_count():
		defaults.append(rig.get_bone_pose(bone));positions.append(rig.get_bone_pose_position(bone));rotations.append(rig.get_bone_pose_rotation(bone));scales.append(rig.get_bone_pose_scale(bone));parents.append(rig.get_bone_parent(bone));rig.set_bone_pose(bone,saved[bone])
	head=rig.find_bone("J_Head")
	for name:String in ["J_L_EyeIris","J_R_EyeIris","J_L_Eyebrow","J_R_Eyebrow","J_Mouth"]:
		var bone:=rig.find_bone(name)
		if bone>=0:faces.append(bone)
	for record:Dictionary in samples:
		var key:String=record.semantic;var animation:Animation=player.get_animation(clips[key].action);var tracks:Array=[]
		if animation==null:return false
		animations[key]=animation
		for index in animation.get_track_count():
			var path:=animation.track_get_path(index)
			if path.get_subname_count()==0:continue
			var bone:=rig.find_bone(path.get_subname(0));var kind:=animation.track_get_type(index)
			if bone>=0 and kind in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:tracks.append({"bone":bone,"kind":kind,"index":index})
		channels[key]=tracks
	return true

func state(speed:float)->Dictionary:
	var input:=clampf(maxf(speed,0.)/base_speed,float(samples[0].input),float(samples[-1].input));var left:=0
	while left<samples.size()-2 and input>float(samples[left+1].input):left+=1
	var a:Dictionary=samples[left];var b:Dictionary=samples[left+1]
	var weight:=clampf((input-float(a.input))/(float(b.input)-float(a.input)),0.,1.)
	return {"left":a.semantic,"right":b.semantic,"weight":weight,"input":input,"period":lerpf(float(a.duration)/float(a.rate),float(b.duration)/float(b.rate),weight)}

func sample(key:String,phase:float)->Array[Transform3D]:
	var animation:Animation=animations[key];var time:=fposmod(phase,1.)*animation.length
	var p:=positions.duplicate();var q:=rotations.duplicate();var s:=scales.duplicate()
	for channel:Dictionary in channels[key]:
		match channel.kind:
			Animation.TYPE_POSITION_3D:p[channel.bone]=animation.position_track_interpolate(channel.index,time)
			Animation.TYPE_ROTATION_3D:q[channel.bone]=animation.rotation_track_interpolate(channel.index,time)
			Animation.TYPE_SCALE_3D:s[channel.bone]=animation.scale_track_interpolate(channel.index,time)
	var result:Array[Transform3D]=[]
	for bone in defaults.size():result.append(Transform3D(Basis(q[bone]).scaled(s[bone]),p[bone]))
	return result

func worlds(local:Array[Transform3D])->Array[Transform3D]:
	var result:Array[Transform3D]=[]
	for bone in local.size():result.append(result[parents[bone]]*local[bone] if parents[bone]>=0 else local[bone])
	return result

func compose(phase:float,speed:float)->Array[Transform3D]:
	var blend:=state(speed);var weight:float=blend.weight
	var a:=sample(blend.left,phase)
	if weight<=.0000001:return a
	var b:=sample(blend.right,phase)
	if weight>=.9999999:return b
	var result:Array[Transform3D]=[]
	for bone in a.size():result.append(a[bone].interpolate_with(b[bone],weight))
	# Keep the existing face-root fidelity contract on this neck-sibling rig.
	if head>=0:
		var aw:=worlds(a);var bw:=worlds(b);var current:Array[Transform3D]=[]
		for bone in result.size():
			var parent:Transform3D=current[parents[bone]] if parents[bone]>=0 else Transform3D.IDENTITY
			if bone in faces:
				var relative:Transform3D=(aw[head].affine_inverse()*aw[bone]).interpolate_with(bw[head].affine_inverse()*bw[bone],weight)
				result[bone]=parent.affine_inverse()*current[head]*relative
			current.append(parent*result[bone])
	return result

func apply(phase:float,speed:float)->void:
	var pose:=compose(phase,speed)
	for bone in pose.size():rig.set_bone_pose(bone,pose[bone])
