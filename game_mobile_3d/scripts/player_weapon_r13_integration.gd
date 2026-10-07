extends "res://scripts/player_reference_locomotion_r6p.gd"
## Native saved R12/R13 Actions in the existing sole writer; lower gait untouched.
const R13Socket=preload("res://scripts/player_weapon_socket_r13.gd")
const R13_TRANSITION_SPEED: float=R13Socket.TRANSITION_SPEED
const R13_ENTRY_BLEND: float=0.10/R13_TRANSITION_SPEED
const R13_EXIT_BLEND: float=0.12/R13_TRANSITION_SPEED
const R13_KINDS=["Pistol","Rifle","Shotgun"]
const R13_BODY=["Spine","Chest","Neck","Head"]
var r13_samples: Dictionary={}
var r13_mask:=PackedInt32Array()
var r13_mode: StringName=&""
var r13_token: int=-1
var r13_weapon: int=-1
var r13_released: bool=false
var r13_entry_positions: Array[Vector3]=[]
var r13_entry_rotations: Array[Quaternion]=[]
var r13_exit_time: float=-1.0
var r13_exit_positions: Array[Vector3]=[]
var r13_exit_rotations: Array[Quaternion]=[]
var r13_idle_time: float=0.0

func _new_weapon_socket() -> BoneAttachment3D: return R13Socket.new()
func _ready() -> void:
	# Imported resources are shared across instances/reloads. Keep this library local.
	var imported_player:=find_child("AnimationPlayer",true,false) as AnimationPlayer
	var local_library: AnimationLibrary=imported_player.get_animation_library("").duplicate(true)
	imported_player.remove_animation_library("");imported_player.add_animation_library("",local_library)
	super._ready()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/r13/source.json"))
	var library:=animation_player.get_animation_library("")
	var animation_root: Node=animation_player.get_node(animation_player.root_node)
	var skeleton_path:=String(animation_root.get_path_to(skeleton))
	for name: String in data.clips:
		var source: Dictionary=data.clips[name]
		# Retime only stow/draw, preserving native poses and all locomotion clocks.
		var playback_speed: float=R13_TRANSITION_SPEED if name.begins_with("R13_") else 1.0
		var clip:=Animation.new();clip.resource_name=name;clip.length=source.length/playback_speed
		clip.loop_mode=Animation.LOOP_LINEAR if source.loop else Animation.LOOP_NONE
		for bone_name: String in source.samples[0]:
			var pt:=clip.add_track(Animation.TYPE_POSITION_3D);var qt:=clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(pt,NodePath(skeleton_path+":"+bone_name));clip.track_set_path(qt,NodePath(skeleton_path+":"+bone_name))
			for index in source.samples.size():
				var p: Dictionary=source.samples[index][bone_name]
				clip.position_track_insert_key(pt,index/48.0/playback_speed,Vector3(p.p[0],p.p[1],p.p[2]))
				clip.rotation_track_insert_key(qt,index/48.0/playback_speed,Quaternion(p.q[0],p.q[1],p.q[2],p.q[3]))
		library.add_animation(name,clip);r13_samples[name]=Sampler.new(clip,skeleton)
	for name in HOLSTER_BONES:r13_mask.append(skeleton.find_bone(name))
	_evaluate(0)
func r13_clip_name(kind: String) -> String: return "R13_"+R13_KINDS[socket.equipped]+"_"+kind
func has_authored_holster() -> bool: return not r13_samples.is_empty()
func has_authored_draw() -> bool: return not r13_samples.is_empty()
func holster_duration() -> float: return 46.0/24.0/R13_TRANSITION_SPEED
func draw_duration() -> float: return 46.0/24.0/R13_TRANSITION_SPEED
func holster_event_time(event: StringName) -> float:
	return float({&"HOLSTER_BEGIN":0.0,&"SUPPORT_HAND_RELEASE":10.0/24.0,&"WEAPON_BACK_CONTACT":29.4/24.0,&"HOLSTER_RELEASE":29.4/24.0,&"HOLSTER_DONE":46.0/24.0}.get(event,0.0))/R13_TRANSITION_SPEED
func draw_event_time(event: StringName) -> float:
	return float({&"DRAW_BEGIN":0.0,&"WEAPON_BACK_RELEASE":16.6/24.0,&"SUPPORT_HAND_CATCH":46.0/24.0,&"DRAW_READY":46.0/24.0}.get(event,0.0))/R13_TRANSITION_SPEED
func _process(delta: float) -> void:
	if not frozen:r13_idle_time=fposmod(r13_idle_time+delta,4.0)
	super._process(delta)
func _r13_pose(kind: String, bone: int) -> Transform3D:
	var ip: RefCounted=r13_samples["R12_"+kind+"_Idle"]
	var wp: RefCounted=r13_samples["R12_"+kind+"_Walk"]
	var sp: RefCounted=r13_samples["R12_"+kind+"_Sprint"]
	var wt: float=reference_phase*wp.clip.length;var st: float=reference_phase*sp.clip.length
	var p: Vector3=ip.position(bone,r13_idle_time).lerp(wp.position(bone,wt).lerp(sp.position(bone,st),reference_sprint_weight),move_weight)
	var q: Quaternion=ip.rotation(bone,r13_idle_time).slerp(wp.rotation(bone,wt).slerp(sp.rotation(bone,st),reference_sprint_weight),move_weight)
	return Transform3D(Basis(q),p)
func _r13_reference_pose(bone: int) -> Transform3D:
	var wt:=reference_sample_time("Walk");var st:=reference_sample_time("Sprint")
	var p: Vector3=idle.position(bone,idle_time).lerp(reference_clips.Walk.position(bone,wt).lerp(reference_clips.Sprint.position(bone,st),reference_sprint_weight),move_weight)
	var q: Quaternion=idle.rotation(bone,idle_time).slerp(reference_clips.Walk.rotation(bone,wt).slerp(reference_clips.Sprint.rotation(bone,st),reference_sprint_weight),move_weight)
	return Transform3D(Basis(q),p)
func _apply_weapon_carry() -> void:
	if r13_samples.is_empty():super._apply_weapon_carry();return
	var armed: bool=weapon_equipped and (weapon_behavior==null or not weapon_behavior.enabled or weapon_behavior.state in [weapon_behavior.State.READY,weapon_behavior.State.DRAWING])
	var kind: String=R13_KINDS[weapon_type] if armed else "Unarmed"
	for bone in r13_mask:
		var pose:=_r13_pose(kind,bone);var name:=skeleton.get_bone_name(bone)
		if name in R13_BODY:
			# Keep turn, aim and recoil residuals against the straight active gait.
			var base:=_r13_reference_pose(bone)
			pose.origin=skeleton.get_bone_pose_position(bone)+pose.origin-base.origin
			pose.basis=Basis((skeleton.get_bone_pose_rotation(bone)*base.basis.get_rotation_quaternion().inverse()*pose.basis.get_rotation_quaternion()).normalized())
		elif is_firing:
			var recoil_bone:=socket_bone if name=="WeaponCarrier" else bone
			pose.origin+=(recoil_pose.position(recoil_bone,recoil_time)-recoil_pose.position(recoil_bone,0))*recoil_gain
			var recoil_delta: Quaternion=recoil_pose.rotation(recoil_bone,0).inverse()*recoil_pose.rotation(recoil_bone,recoil_time)
			pose.basis=Basis((pose.basis.get_rotation_quaternion()*Quaternion.IDENTITY.slerp(recoil_delta,recoil_gain)).normalized())
		if name in ["Arm.L","Arm.R"] and switch_weight<1:
			pose.origin=switch_positions[bone].lerp(pose.origin,switch_weight)
			pose.basis=Basis(switch_rotations[bone].slerp(pose.basis.get_rotation_quaternion(),switch_weight).normalized())
		skeleton.set_bone_pose_position(bone,pose.origin);skeleton.set_bone_pose_rotation(bone,pose.basis.get_rotation_quaternion().normalized())
	_r13_hand_frame()
func _r13_hand_frame() -> void:
	var carrier:=skeleton.find_bone("WeaponCarrier")
	skeleton.set_bone_pose_position(socket_bone,skeleton.get_bone_pose_position(carrier))
	skeleton.set_bone_pose_rotation(socket_bone,skeleton.get_bone_pose_rotation(carrier))
func _r13_start(mode: StringName, token: int) -> void:
	r13_entry_positions.clear();r13_entry_rotations.clear()
	for bone in r13_mask:
		r13_entry_positions.append(skeleton.get_bone_pose_position(bone));r13_entry_rotations.append(skeleton.get_bone_pose_rotation(bone))
	r13_mode=mode;r13_token=token;r13_weapon=socket.equipped;r13_released=false;r13_exit_time=-1.0
	_evaluate(0)
func start_authored_holster(token: int) -> void: _r13_start(&"Holster",token)
func start_authored_draw(token: int) -> void: _r13_start(&"Draw",token)
func cancel_authored_holster() -> void:
	if r13_mode!=&"Holster":return
	r13_mode=&"";r13_token=-1
	if socket.current_attachment==&"carrier":socket.end_transport(true)
func _r13_capture_exit() -> void:
	r13_exit_positions.clear();r13_exit_rotations.clear()
	for bone in r13_mask:
		r13_exit_positions.append(skeleton.get_bone_pose_position(bone));r13_exit_rotations.append(skeleton.get_bone_pose_rotation(bone))
	r13_exit_time=0
func cancel_authored_draw(blend_back: bool=false) -> void:
	# Switch/death also cancel an already-finished Draw's short exit blend.
	if blend_back and r13_mode==&"Draw":_r13_capture_exit()
	else:r13_exit_time=-1
	if r13_mode!=&"Draw":return
	r13_mode=&"";r13_token=-1
func finish_disabled_draw() -> void:
	socket.end_draw_transport();_r13_capture_exit();r13_mode=&"";r13_token=-1
func _evaluate(delta: float) -> void:
	super._evaluate(delta)
	if r13_samples.is_empty():return
	if r13_mode==&"":
		if r13_exit_time>=0:
			r13_exit_time=minf(r13_exit_time+delta,R13_EXIT_BLEND);var blend:=smoothstep(0,R13_EXIT_BLEND,r13_exit_time)
			for index in r13_mask.size():
				var bone:=r13_mask[index]
				if skeleton.get_bone_name(bone)=="WeaponCarrier":continue
				skeleton.set_bone_pose_position(bone,r13_exit_positions[index].lerp(skeleton.get_bone_pose_position(bone),blend))
				skeleton.set_bone_pose_rotation(bone,r13_exit_rotations[index].slerp(skeleton.get_bone_pose_rotation(bone),blend).normalized())
			if socket.current_attachment==&"hand":socket.finish_draw_mount(blend)
			if r13_exit_time>=R13_EXIT_BLEND:r13_exit_time=-1
		return
	if weapon_behavior==null or r13_token!=weapon_behavior.request_id or r13_weapon!=socket.equipped:r13_mode=&"";return
	var is_draw:=r13_mode==&"Draw"
	var time: float=minf(weapon_behavior.transition_elapsed,draw_duration())
	var pose: RefCounted=r13_samples[r13_clip_name(String(r13_mode))]
	var entering:=smoothstep(0,R13_ENTRY_BLEND,time);var exiting:=smoothstep(draw_duration()-R13_EXIT_BLEND,draw_duration(),time)
	for index in r13_mask.size():
		var bone:=r13_mask[index];var name:=skeleton.get_bone_name(bone)
		var p: Vector3=pose.position(bone,time);var q: Quaternion=pose.rotation(bone,time)
		if name in R13_BODY:
			p=skeleton.get_bone_pose_position(bone)+p-pose.position(bone,0)
			q=skeleton.get_bone_pose_rotation(bone)*pose.rotation(bone,0).inverse()*q
		if name!="WeaponCarrier":
			p=r13_entry_positions[index].lerp(p,entering);q=r13_entry_rotations[index].slerp(q,entering)
			p=p.lerp(skeleton.get_bone_pose_position(bone),exiting);q=q.slerp(skeleton.get_bone_pose_rotation(bone),exiting)
		skeleton.set_bone_pose_position(bone,p);skeleton.set_bone_pose_rotation(bone,q.normalized())
	_r13_hand_frame();skeleton.force_update_all_bone_transforms();socket.sync_transport_sockets()
	if is_draw:
		if not r13_released and time+0.000001>=draw_event_time(&"WEAPON_BACK_RELEASE"):
			weapon_behavior.weapon_draw_to_carrier(r13_token,time);r13_released=true
			draw_event_log.append({"event":"WEAPON_BACK_RELEASE","time":time,"weapon":r13_weapon,"token":r13_token})
			draw_event.emit(&"WEAPON_BACK_RELEASE",r13_token)
		socket.update_draw_transport(time,draw_duration(),draw_duration())
		if time+0.000001>=draw_duration():
			weapon_behavior.weapon_draw_to_hand(r13_token);_r13_capture_exit();r13_mode=&""
			draw_event_log.append({"event":"DRAW_READY","time":time,"weapon":r13_weapon,"token":r13_token})
			weapon_behavior.draw_finished(r13_token)
	else:
		if not r13_released and socket.current_attachment==&"hand":weapon_behavior.weapon_attach_to_carrier(r13_token)
		if not r13_released and time+0.000001>=holster_event_time(&"HOLSTER_RELEASE"):
			weapon_behavior.weapon_release_carrier_to_back(r13_token);r13_released=true
			holster_event_log.append({"event":"HOLSTER_RELEASE","time":time,"weapon":r13_weapon,"token":r13_token})
			holster_event.emit(&"HOLSTER_RELEASE",r13_token)
		socket.update_transport(time,holster_event_time(&"HOLSTER_RELEASE"),holster_duration(),R13_ENTRY_BLEND)
		if time+0.000001>=holster_duration():r13_mode=&"";weapon_behavior.holster_finished(r13_token)
func ready_context_text() -> String: return "R13 | latest native "+R13_KINDS[weapon_type]+" | active gait phase %.3f"%reference_phase
