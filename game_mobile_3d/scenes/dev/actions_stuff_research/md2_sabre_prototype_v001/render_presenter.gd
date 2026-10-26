extends Node
## Render-only snapshots. Authoritative capsule, source skeleton, markers and
## gameplay clocks remain at the latest physics pose. Matches the legacy lab's
## display architecture, adapted to the original multi-mesh32-joint GLB.
var actor:CharacterBody3D
var rig:Skeleton3D
var meshes:Array[MeshInstance3D]=[]
var bindings:Array[Dictionary]=[]
var parents:Array[int]=[]
var previous:Dictionary={}
var current:Dictionary={}
var display_world:Array=[]
var display_meshes:Array[Transform3D]=[]
var display_actor:=Vector3.ZERO
var display_clock:=0.
var render_alpha:=1.
var enabled:=true
var presented_frames:=0
var last_uploaded_actor:=Vector3.ZERO

func setup(body:CharacterBody3D)->void:
	actor=body;rig=actor.skeleton;actor._refresh_markers()
	for bone in rig.get_bone_count():parents.append(rig.get_bone_parent(bone))
	for mesh:MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		meshes.append(mesh)
		var record:={"skin":null,"bones":[],"bone":-1,"offset":Transform3D.IDENTITY}
		if mesh.skin!=null:
			record.skin=rig.register_skin(mesh.skin)
			for index in mesh.skin.get_bind_count():
				var name:StringName=mesh.skin.get_bind_name(index)
				var bone:=rig.find_bone(name) if name!=&"" else mesh.skin.get_bind_bone(index)
				assert(bone>=0 and bone<rig.get_bone_count());record.bones.append(bone)
		elif actor._weapon_attachment.is_ancestor_of(mesh):
			record.bone=actor._weapon_attachment.bone_idx
			record.offset=actor._weapon_attachment.global_transform.affine_inverse()*mesh.global_transform
		bindings.append(record)
	actor.physics_pose_ready.connect(capture);actor.presentation_reset.connect(reset_history)
	reset_history();RenderingServer.frame_pre_draw.connect(_upload)

func _exit_tree()->void:
	if RenderingServer.frame_pre_draw.is_connected(_upload):RenderingServer.frame_pre_draw.disconnect(_upload)

func capture()->void:
	if not is_instance_valid(actor):return
	actor._refresh_markers()
	var poses:Array[Transform3D]=[];var world:Array[Transform3D]=[];var transforms:Array[Transform3D]=[]
	for bone in rig.get_bone_count():
		poses.append(rig.get_bone_pose(bone));world.append(rig.global_transform*rig.get_bone_global_pose(bone))
	for mesh:MeshInstance3D in meshes:transforms.append(mesh.global_transform)
	previous=current
	current={"poses":poses,"world":world,"rig":rig.global_transform,"meshes":transforms,"actor":actor.global_position,"clock":actor.effects.clock if actor.effects!=null else actor.simulation_clock}
	if previous.is_empty():previous=current

func reset_history()->void:
	current={};capture();previous=current;prepare(1.)

func _global_pose(bone:int,locals:Array,globals:Array)->Transform3D:
	if globals[bone]!=null:return globals[bone]
	var result:Transform3D=locals[bone]
	if parents[bone]>=0:result=_global_pose(parents[bone],locals,globals)*result
	globals[bone]=result;return result

func prepare(alpha:float)->void:
	if current.is_empty():return
	render_alpha=clampf(alpha,0.,1.) if enabled else 1.
	display_actor=Vector3(previous.actor).lerp(current.actor,render_alpha)
	display_clock=lerpf(previous.clock,current.clock,render_alpha)
	if render_alpha<=0. or render_alpha>=1.:
		var source:Dictionary=previous if render_alpha<=0. else current
		display_world=source.world.duplicate();display_meshes.assign(source.meshes);return
	var locals:Array=[];var globals:Array=[];globals.resize(rig.get_bone_count())
	for bone in rig.get_bone_count():locals.append(Transform3D(previous.poses[bone]).interpolate_with(current.poses[bone],render_alpha))
	var rig_transform:=Transform3D(previous.rig).interpolate_with(current.rig,render_alpha)
	display_world.clear()
	for bone in rig.get_bone_count():display_world.append(rig_transform*_global_pose(bone,locals,globals))
	display_meshes.clear()
	for index in meshes.size():
		var record:Dictionary=bindings[index]
		display_meshes.append(display_world[record.bone]*Transform3D(record.offset) if record.bone>=0 else Transform3D(previous.meshes[index]).interpolate_with(current.meshes[index],render_alpha))

func display_marker(marker:Node3D)->Transform3D:
	var anchor:BoneAttachment3D=actor._weapon_attachment
	var offset:Transform3D=marker.transform if marker.get_parent()==anchor else anchor.global_transform.affine_inverse()*marker.global_transform
	return Transform3D(display_world[anchor.bone_idx])*offset

func _upload()->void:
	if current.is_empty() or not is_instance_valid(rig):return
	for index in meshes.size():
		var mesh:=meshes[index];var record:Dictionary=bindings[index]
		RenderingServer.instance_set_transform(mesh.get_instance(),display_meshes[index])
		if record.skin==null:continue
		var inverse:=display_meshes[index].affine_inverse()
		var skin_reference:SkinReference=record.skin
		for bind in record.bones.size():
			RenderingServer.skeleton_bone_set_transform(skin_reference.get_skeleton(),bind,inverse*Transform3D(display_world[record.bones[bind]])*mesh.skin.get_bind_pose(bind))
	presented_frames+=1
	last_uploaded_actor=display_actor
