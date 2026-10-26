extends RefCounted
## Explicit gameplay adapter, never source-data editing. Reorient only the two
## leg trajectories in Skeleton space; leave hips, spine, arms and weapon alone.
var rig:Skeleton3D
var legs:Array[int]=[]
var current_yaw:=0.
var current_world_yaw:=0.
var _saved:Dictionary={}
var _points:Array[Array]=[[],[]]

func setup(skeleton:Skeleton3D,model:Node)->void:
	rig=skeleton;legs=[rig.find_bone("J_L_Leg"),rig.find_bone("J_R_Leg")]
	assert(legs[0]>=0 and legs[1]>=0)
	var seen:Array[Dictionary]=[{},{}]
	for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		var bindings:Array[int]=[]
		for bind in mesh.skin.get_bind_count():
			var name:StringName=mesh.skin.get_bind_name(bind)
			bindings.append(rig.find_bone(name) if name!=&"" else mesh.skin.get_bind_bone(bind))
		for surface in mesh.mesh.get_surface_count():
			var arrays:Array=mesh.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
			if bones==null or weights==null or vertices.is_empty():continue
			var influences:int=weights.size()/vertices.size()
			for vertex in vertices.size():
				for influence in influences:
					if float(weights[vertex*influences+influence])<.9999:continue
					var bind:int=bones[vertex*influences+influence]
					if bind<0 or bind>=bindings.size():continue
					var bone:int=bindings[bind]
					for side in 2:
						var ancestor:=bone
						while ancestor>=0 and ancestor!=legs[side]:ancestor=rig.get_bone_parent(ancestor)
						if ancestor<0:continue
						var p:Vector3=vertices[vertex];var key:=Vector4(bone,p.x,p.y,p.z)
						if seen[side].has(key):continue
						seen[side][key]=true
						_points[side].append({"bone":bone,"bind":mesh.skin.get_bind_pose(bind),"point":p})
	assert(point_count()>8,"Rigid source leg vertices required for height preservation")

func point_count()->int:return _points[0].size()+_points[1].size()
func restore()->void:
	for bone:int in _saved:rig.set_bone_pose(bone,_saved[bone])
	if not _saved.is_empty():rig.force_update_all_bone_transforms()
	_saved.clear()
func deactivate()->void:
	restore();current_yaw=0.
	var forward:=rig.global_basis*Vector3(0,0,1)
	current_world_yaw=atan2(forward.x,forward.z)
func _positions(side:int)->Array[Vector3]:
	var result:Array[Vector3]=[]
	for entry:Dictionary in _points[side]:result.append(rig.get_bone_global_pose(entry.bone)*Transform3D(entry.bind)*Vector3(entry.point))
	return result
func sole_minimum(side:int)->float:
	var height:=INF
	for point:Vector3 in _positions(side):height=minf(height,point.y)
	return height
func apply(world_velocity:Vector3,delta:float)->void:
	var planar:=Vector2(world_velocity.x,world_velocity.z)
	var response:=1.-exp(-18.*maxf(delta,0.))
	if planar.length()>.025:
		current_world_yaw=lerp_angle(current_world_yaw,atan2(planar.x,planar.y),response)
		var local:Vector3=rig.global_basis.inverse()*Vector3(sin(current_world_yaw),0,cos(current_world_yaw))
		current_yaw=atan2(local.x,local.z)
	else:
		current_yaw=lerp_angle(current_yaw,0.,response)
		var forward:=rig.global_basis*Vector3(sin(current_yaw),0,cos(current_yaw))
		current_world_yaw=atan2(forward.x,forward.z)
	var yaw:=Basis(Vector3.UP,current_yaw);var inverse:=yaw.inverse()
	rig.force_update_all_bone_transforms()
	var targets:Array[Transform3D]=[];var parents:Array[Transform3D]=[]
	for side in 2:
		var bone:=legs[side];var rest:=rig.get_bone_global_rest(bone);var raw:=rig.get_bone_global_pose(bone)
		var parent:=rig.get_bone_parent(bone);var parent_pose:=rig.get_bone_global_pose(parent) if parent>=0 else Transform3D.IDENTITY
		_saved[bone]=rig.get_bone_pose(bone);parents.append(parent_pose)
		var pivot:Vector3=(parent_pose*rig.get_bone_rest(bone)).origin
		var target:=Transform3D(yaw*(raw.basis*rest.basis.inverse())*inverse*rest.basis,pivot+yaw*(raw.origin-pivot))
		var delta_pose:=target*raw.affine_inverse();var before:=INF;var after:=INF
		for point:Vector3 in _positions(side):before=minf(before,point.y);after=minf(after,(delta_pose*point).y)
		# Rotating a box-shaped toe diagonally can lower its corner despite a stable
		# center. Preserve the original evaluated minimum; do not invent floor IK.
		if is_finite(before) and is_finite(after):target.origin.y+=before-after
		targets.append(target)
	for side in 2:rig.set_bone_pose(legs[side],parents[side].affine_inverse()*targets[side])
	rig.force_update_all_bone_transforms()
