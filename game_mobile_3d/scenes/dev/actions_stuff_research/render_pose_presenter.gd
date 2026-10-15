extends Node
## Research-only display of the final, contact-solved physics poses. Never writes
## Skeleton3D, actor transforms, source clocks, contacts or gameplay sockets.
var actor: CharacterBody3D
var visual: Node
var rig: Skeleton3D
var mesh: MeshInstance3D
var skin_reference: SkinReference
var bind_bones: Array[int]=[]
var parents: Array[int]=[]
var previous: Dictionary={}
var current: Dictionary={}
var display_world: Array=[]
var display_mesh:=Transform3D.IDENTITY
var display_actor:=Vector3.ZERO
var render_alpha:=1.0
var presented_frames:=0

func setup(body: CharacterBody3D,source_visual: Node) -> void:
	actor=body;visual=source_visual;rig=visual.skeleton;mesh=visual.meshes[0]
	# Same bind mapping/formula as Skeleton3D, retaining the existing skin RID.
	assert(mesh.global_transform.is_equal_approx(rig.global_transform))
	skin_reference=rig.register_skin(mesh.skin)
	for i in mesh.skin.get_bind_count():
		var name: StringName=mesh.skin.get_bind_name(i)
		var bone:=rig.find_bone(name) if name!=&"" else mesh.skin.get_bind_bone(i)
		assert(bone>=0 and bone<rig.get_bone_count());bind_bones.append(bone)
	for i in rig.get_bone_count(): parents.append(rig.get_bone_parent(i))
	reset_history()
	RenderingServer.frame_pre_draw.connect(_upload)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_upload): RenderingServer.frame_pre_draw.disconnect(_upload)

func sole(world: Transform3D) -> Vector3:
	var center:=world*Vector3(0,.675,0);var lowest:=INF
	for x in [-.1125,.1125]:
		for z in [-.1125,.1125]: lowest=minf(lowest,(world*Vector3(x,.675,z)).y)
	return Vector3(center.x,lowest,center.z)

func capture() -> void:
	var poses:=[];var world:=[];var soles:=[]
	rig.force_update_all_bone_transforms()
	for i in rig.get_bone_count():
		poses.append(rig.get_bone_pose(i));world.append(mesh.global_transform*rig.get_bone_global_pose(i))
	for bone in [visual.leg_left,visual.leg_right]: soles.append(sole(world[bone]))
	previous=current
	current={"poses":poses,"world":world,"mesh":mesh.global_transform,"actor":actor.global_position,"support":visual.foot_support.duplicate(),"soles":soles}
	if previous.is_empty(): previous=current

func reset_history() -> void:
	current={};capture();previous=current
	prepare(1.)

func _global_pose(bone: int,locals: Array,globals: Array) -> Transform3D:
	if globals[bone]!=null: return globals[bone]
	var pose: Transform3D=locals[bone]
	if parents[bone]>=0: pose=_global_pose(parents[bone],locals,globals)*pose
	globals[bone]=pose
	return pose

func prepare(alpha: float) -> void:
	if current.is_empty(): return
	render_alpha=clampf(alpha,0.,1.)
	display_actor=Vector3(previous.actor).lerp(current.actor,render_alpha)
	display_mesh=Transform3D(previous.mesh).interpolate_with(current.mesh,render_alpha)
	if render_alpha<=0. or render_alpha>=1.:
		# Preserve exact source squash/stretch/shear and solved contacts at endpoints.
		display_world=(previous.world if render_alpha<=0. else current.world).duplicate()
		return
	var locals:=[];var globals:=[];globals.resize(rig.get_bone_count())
	for i in rig.get_bone_count(): locals.append(Transform3D(previous.poses[i]).interpolate_with(current.poses[i],render_alpha))
	display_world=[]
	for i in rig.get_bone_count(): display_world.append(display_mesh*_global_pose(i,locals,globals))
	# Rigid feet need world-space support continuity between the two solved poses.
	# This correction is display-only; no new IK or altered support decisions.
	for side in 2:
		var bone: int=[visual.leg_left,visual.leg_right][side]
		var world: Transform3D=display_world[bone]
		var foot:=sole(world)
		if previous.support[side] and current.support[side]:
			world.origin+=Vector3(previous.soles[side]).lerp(current.soles[side],render_alpha)-foot
		elif foot.y<0.: world.origin.y-=foot.y
		display_world[bone]=world

func _upload() -> void:
	if current.is_empty() or not is_instance_valid(mesh): return
	var inverse:=display_mesh.affine_inverse()
	# Upload after Skeleton3D's deferred updates, immediately before drawing.
	# CPU rig/contact caches retain the current authoritative physics pose.
	RenderingServer.instance_set_transform(mesh.get_instance(),display_mesh)
	for bind in bind_bones.size():
		RenderingServer.skeleton_bone_set_transform(skin_reference.get_skeleton(),bind,inverse*Transform3D(display_world[bind_bones[bind]])*mesh.skin.get_bind_pose(bind))
	presented_frames+=1
