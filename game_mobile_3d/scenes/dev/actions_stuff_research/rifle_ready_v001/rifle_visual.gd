extends "res://scenes/dev/actions_stuff_research/jump_locomotion_visual.gd"
## Approved Ready clips plus the approved Aim in the existing pose/contact pipeline.
## Source studies remain read-only; generic weapon posing never overlays this set.
const RifleSampler=preload("res://scenes/dev/actions_stuff_research/rifle_ready_v001/rifle_sampler.gd")
const RIFLE_LIBRARY=preload("res://scenes/dev/actions_stuff_research/rifle_ready_v001/approved_library.res")
const AIM_LIBRARY=preload("res://scenes/dev/actions_stuff_research/rifle_ready_v001/aim_approved_library.res")
const RIFLE_ASSET=preload("res://assets/weapons/rifle_stylized_v2_test/Rifle_Stylized_V2.glb")
var rifle_ready_active:=false
var rifle_clips: Dictionary={}
var rifle_profile: Dictionary={}
var rifle_model: Node3D
var rifle_support_anchor:=Vector3.ZERO
var rifle_idle_time:=0.0
var rifle_move_weight:=0.0
var rifle_state: String="Idle"
var idle_active:=true
var presentation: Node
var carrier_in_right_arm:=Transform3D.IDENTITY
var forearm_left_rest:=Transform3D.IDENTITY
var palm_arm_local:=Vector3.ZERO
var left_socket_local:=Vector3.ZERO
var arm_left: int
var arm_right: int
var forearm_left: int
var forearm_right: int
var carrier_bone: int
var rifle_ground_poses: Array=[]
var rifle_ground_future: Array=[]
var _rifle_idle_poses: Array=[]
var _rifle_idle_future: Array=[]
var _rifle_driving:=false
var rifle_aim_clip: RefCounted
var rifle_aim_profile: Dictionary={}
var rifle_aim_requested:=false
var rifle_aim_weight:=0.0
var rifle_aim_time:=0.0
var rifle_carrier_attachment:=Transform3D.IDENTITY
var rifle_contact_shoulder_weight:=0.0
var _aim_bones: Array[int]=[]
var _aim_head_bones: Array[int]=[]
const AIM_BLEND_SECONDS:=.24

func _rows(rows: Array) -> Transform3D:
 return Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(rows[0][3],rows[1][3],rows[2][3]))
func _ready() -> void:
 super._ready()
 rifle_profile=JSON.parse_string(FileAccess.get_file_as_string("res://scenes/dev/actions_stuff_research/rifle_ready_v001/profile.json"))
 for kind in ["Idle","Walk","Run"]:rifle_clips[kind]=RifleSampler.new(RIFLE_LIBRARY.get_animation(kind),skeleton)
 carrier_in_right_arm=_rows(rifle_profile.carrier_in_right_arm);forearm_left_rest=_rows(rifle_profile.forearm_left_rest)
 rifle_carrier_attachment=carrier_in_right_arm
 rifle_aim_profile=JSON.parse_string(FileAccess.get_file_as_string("res://scenes/dev/actions_stuff_research/rifle_ready_v001/aim_profile.json"))
 rifle_aim_clip=RifleSampler.new(AIM_LIBRARY.get_animation("Aim"),skeleton)
 palm_arm_local=forearm_left_rest*Vector3(rifle_profile.palm_forearm_local[0],rifle_profile.palm_forearm_local[1],rifle_profile.palm_forearm_local[2])
 left_socket_local=Vector3(rifle_profile.shoulder_left_chest_local[0],rifle_profile.shoulder_left_chest_local[1],rifle_profile.shoulder_left_chest_local[2])+Vector3(float(rifle_profile.shoulder_outset_m),0,0)
 arm_left=skeleton.find_bone("Arm.L");arm_right=skeleton.find_bone("Arm.R");forearm_left=skeleton.find_bone("ForeArm.L");forearm_right=skeleton.find_bone("ForeArm.R");carrier_bone=skeleton.find_bone("WeaponCarrier")
 for bone_name in ["Spine","Chest","Neck","Head","Arm.L","Arm.R","ForeArm.L","ForeArm.R","WeaponCarrier"]:_aim_bones.append(skeleton.find_bone(bone_name))
 for bone_name in ["Neck","Head"]:_aim_head_bones.append(skeleton.find_bone(bone_name))
 active_walk_action=rifle_profile.clips.Walk.action;active_run_action=rifle_profile.clips.Run.action
 _cache_direction_poses();position.y=0.
 for i in skeleton.get_bone_count():
  var pose: Transform3D=direction_poses[i];var q:=pose.basis.orthonormalized().get_rotation_quaternion()
  skeleton.set_bone_pose(i,pose);_p[i]=pose.origin;_q[i]=q;_final_p[i]=pose.origin;_final_q[i]=q
  _vp[i]=Vector3.ZERO;_vq[i]=Vector3.ZERO;_offset_p[i]=Vector3.ZERO;_offset_q[i]=Vector3.ZERO;_offset_vp[i]=Vector3.ZERO;_offset_vq[i]=Vector3.ZERO
 _constrain_rifle_contacts();skeleton.force_update_all_bone_transforms()
 for side in 2:
  var b: int=[leg_left,leg_right][side];var sole:=_sole_world(b);last_sole[side]=sole;foot_anchors[side]=Vector3(sole.x,0.,sole.z);foot_rotations[side]=_leg_world_rotation(b);replant_from[side]=sole;replant_q[side]=foot_rotations[side]
 pose_dirty=false;transition_age=10.;_scale_dirty=false

func activate_rifle_ready() -> void:
 # Reuse the existing weapon socket, marker arrays and preferred model.
 var old: Node3D=socket.instances[1];old.hide();rifle_model=RIFLE_ASSET.instantiate();rifle_model.name="ApprovedRifleStylizedV2";socket.add_child(rifle_model);socket.instances[1]=rifle_model
 socket.hand_transforms[1]=_rows(rifle_profile.weapon_mount)
 for instance: MeshInstance3D in rifle_model.find_children("*","MeshInstance3D",true,false):
  for surface in instance.mesh.get_surface_count():
   var material:=instance.mesh.surface_get_material(surface) as BaseMaterial3D
   if material:material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 weapon_type=1;socket.equip(1);socket.attach_equipped(&"hand");weapon_equipped=true;switch_weight=1.;socket.visible=true;socket.set_equipped_visible(true)
 for row in [[socket.grips,"Grip_Point"],[socket.supports,"Support_Hand_Point"]]:
  var marker: Node3D=rifle_model.find_child("*"+str(row[1])+"*",true,false);row[0][1]=socket.hand_transforms[1]*rifle_model.to_local(marker.global_position)
 socket.muzzles[1]=rifle_model.find_child("*Muzzle_Point*",true,false);rifle_ready_active=true
 _constrain_rifle_contacts()

func _clip_time(kind: String,phase: float,ahead: float=0.) -> float:
 if kind=="Idle":return fposmod(rifle_idle_time+ahead,float(rifle_profile.clips.Idle.duration))
 var info: Dictionary=rifle_profile.clips[kind]
 return fposmod((phase-float(info.phase_origin))/float(info.phase_rate),float(info.duration))
func _aim_pose(bone: int,time: float) -> Transform3D:
 var pose: Transform3D=rifle_aim_clip.pose(bone,time)
 if bone==arm_left or bone==arm_right:
  # The two approved bakes use opposite longitudinal roll frames on the
  # rectangular rigid arms. A half-turn preserves their occupied volume,
  # shoulder/palm positions and whole-arm direction, while removing a spurious
  # 180deg corkscrew from Ready -> Aim. Carrier is NOT rotated: its attachment
  # is recomputed from this retargeted frame, preserving the exact rifle pose.
  pose.basis=pose.basis*Basis(Vector3.UP,PI)
 return pose

func _sample_set(ahead: float=0.) -> Array:
 var phase:=float(direction_snapshot.get("phase",0.))+ahead*gait_frequency
 var ti:=_clip_time("Idle",phase,ahead);var tw:=_clip_time("Walk",phase);var tr:=_clip_time("Run",phase)
 var poses: Array=[]
 var idle_poses: Array=[]
 for bone in skeleton.get_bone_count():
  var ip: Transform3D=rifle_clips.Idle.pose(bone,ti);var wp: Transform3D=rifle_clips.Walk.pose(bone,tw);var rp: Transform3D=rifle_clips.Run.pose(bone,tr)
  idle_poses.append(ip)
  poses.append(ip.interpolate_with(wp.interpolate_with(rp,gait_run_weight),rifle_move_weight))
 if ahead==0.:_rifle_idle_poses=idle_poses
 else:_rifle_idle_future=idle_poses
 if ahead==0.:
  rifle_support_anchor=Vector3(rifle_clips.Idle.support(ti)).lerp(Vector3(rifle_clips.Walk.support(tw)).lerp(rifle_clips.Run.support(tr),gait_run_weight),rifle_move_weight)
  rifle_carrier_attachment=carrier_in_right_arm
  rifle_contact_shoulder_weight=rifle_move_weight
 if rifle_aim_clip!=null and rifle_aim_weight>0.:
  var aim_time:=fposmod(rifle_aim_time+ahead,float(rifle_aim_profile.clips.Aim.duration))
  for bone in _aim_bones:poses[bone]=Transform3D(poses[bone]).interpolate_with(_aim_pose(bone,aim_time),rifle_aim_weight)
  # Aim owns the upper body only. Keep pelvis and legs on the SAME existing
  # Idle/gait clock: mixing the Aim pelvis with compensating Idle legs makes
  # the feet rock fore/aft and repeatedly reacquire incompatible contacts.
  if ahead==0.:
   var attachment: Transform3D=_aim_pose(arm_right,aim_time).affine_inverse()*_aim_pose(carrier_bone,aim_time)
   rifle_carrier_attachment=carrier_in_right_arm.interpolate_with(attachment,rifle_aim_weight)
   rifle_support_anchor=rifle_support_anchor.lerp(rifle_aim_clip.support(aim_time),rifle_aim_weight)
   rifle_contact_shoulder_weight=maxf(rifle_move_weight,rifle_aim_weight)
 return poses

func set_rifle_aim(held: bool) -> void:
 rifle_aim_requested=held
func _cache_direction_poses() -> void:
 if rifle_clips.is_empty():super._cache_direction_poses();return
 rifle_ground_poses=_sample_set();rifle_ground_future=_sample_set(.004)
 direction_poses=rifle_ground_poses.duplicate();direction_future_poses=rifle_ground_future.duplicate()

func drive_jump_motion(world_velocity: Vector3,requested: bool,physics: Dictionary,delta: float) -> void:
 rifle_aim_weight=move_toward(rifle_aim_weight,1. if rifle_aim_requested else 0.,delta/AIM_BLEND_SECONDS)
 if rifle_aim_requested or rifle_aim_weight>0.:rifle_aim_time=fposmod(rifle_aim_time+delta,float(rifle_aim_profile.clips.Aim.duration))
 var moving:=requested or Vector2(world_velocity.x,world_velocity.z).length()>.025
 rifle_move_weight=move_toward(rifle_move_weight,1. if moving else 0.,delta/.14)
 # Interrupt the scan immediately. Reset its cursor while fully hidden, never
 # while its pose is still visible during a very short movement tap.
 if moving:
  if rifle_move_weight>=.9999:rifle_idle_time=0.
 else:rifle_idle_time=fposmod(rifle_idle_time+delta,float(rifle_profile.clips.Idle.duration))
 _rifle_driving=true;super.drive_jump_motion(world_velocity,requested,physics,delta);_rifle_driving=false
 if jump_active:
  # No newly invented Rifle Jump Action: retain approved jump/landing core/legs
  # and carry the approved rifle arm set relative to the existing animated Chest.
  for bone in [arm_left,arm_right,forearm_left,forearm_right,carrier_bone]:direction_poses[bone]=rifle_ground_poses[bone];direction_future_poses[bone]=rifle_ground_future[bone]
  # Keep approved jump/landing chest/core motion, with the aimed head carried
  # relative to that chest rather than cancelling the physical jump response.
  for bone in _aim_head_bones:
   for pair in [[direction_poses,0.],[direction_future_poses,.004]]:
    var source: Transform3D=pair[0][bone]
    var target: Transform3D=rifle_aim_clip.pose(bone,fposmod(rifle_aim_time+float(pair[1]),float(rifle_aim_profile.clips.Aim.duration)))
    var blended:=source.interpolate_with(target,rifle_aim_weight)
    # The jump controller still owns compression/stretch; Aim owns head pose.
    blended.basis=Basis(blended.basis.orthonormalized().get_rotation_quaternion()).scaled(source.basis.get_scale())
    pair[0][bone]=blended
 else:position.y=0. # These approved clips already include native boot clearance.
 idle_active=not moving and not jump_active
 rifle_state="Run" if gait_run_weight>.98 and moving else ("Walk" if moving else "Idle")
 if jump_grounded:_update_direction_support(delta)
 support_left=_support(0);support_right=_support(1)
 _evaluate(delta)
 if presentation!=null:presentation.capture()

func _idle_foot_lateral_speed(bone: int) -> float:
 # Measure the authentic Idle foot motion, independent of the upper-body
 # weapon layer. Aim never replaces this pelvis/leg pair.
 if _rifle_idle_poses.is_empty() or _rifle_idle_future.is_empty():return 0.
 var pose: Transform3D=_rifle_idle_poses[bone]
 var future: Transform3D=_rifle_idle_future[bone]
 var parent:=skeleton.get_bone_parent(bone)
 while parent>=0:
  pose=Transform3D(_rifle_idle_poses[parent])*pose
  future=Transform3D(_rifle_idle_future[parent])*future
  parent=skeleton.get_bone_parent(parent)
 var motion: Vector3=(future*Vector3(0,.675,0)-pose*Vector3(0,.675,0))/.004
 return Vector2(motion.x,motion.z).length()

func _update_direction_support(delta: float) -> void:
 if _rifle_driving:return
 if move_requested:super._update_direction_support(delta);return
 # Preserve the approved idle's occasional free-leg weight shift.
 for side in 2:
  var bone: int=[leg_left,leg_right][side];var pose:=_source_global_pose(bone);var height:=INF
  for point in SOLE_POINTS:height=minf(height,(pose*point).y)
  var rise:=height-_source_sole_previous[side];_source_sole_previous[side]=height
  # The approved Idle has a low-clearance lateral foot reposition. Height
  # alone misses it and drags the leg root inward against an obsolete anchor.
  # Follow that authored free foot; replant when its lateral motion settles.
  var repositioning:=rifle_move_weight<.001 and not settling and not jump_active and _idle_foot_lateral_speed(bone)>.025
  if height>.035 or repositioning:_source_support[side]=false;released[side]=true
  elif height<.02 and rise<.004:_source_support[side]=true;released[side]=false
func _support(side: int) -> bool:
 if rifle_clips.is_empty():return super._support(side)
 return jump_grounded and _source_support[side] and not released[side]
func _apply_weapon_carry() -> void:
 pass # The full approved arm/Carrier pose is already in the sole pose writer.

func constrained_left_pose(arm_pose: Transform3D,target: Vector3,move_weight: float=-1.) -> Transform3D:
 var current:=arm_pose.basis*palm_arm_local
 # Keep the approved moving shoulder placement; retain the accepted Idle solve.
 if move_weight<0.:move_weight=rifle_move_weight
 var shoulder:=left_socket_local.lerp(arm_pose.origin,clampf(move_weight,0.,1.))
 var desired:=target-shoulder
 var swing:=Quaternion(current.normalized(),desired.normalized())
 var basis:=Basis(swing)*arm_pose.basis
 return Transform3D(basis,target-basis*palm_arm_local)
func _constrain_rifle_contacts() -> void:
 if rifle_clips.is_empty():return
 # Solve after blending/inertialization, so a fixed grip cannot drift halfway
 # between two independently interpolated arm and Carrier transforms.
 var carrier:=skeleton.get_bone_pose(arm_right)*rifle_carrier_attachment
 skeleton.set_bone_pose(carrier_bone,carrier);skeleton.set_bone_pose(socket_bone,carrier)
 var target:=carrier*rifle_support_anchor
 skeleton.set_bone_pose(arm_left,constrained_left_pose(skeleton.get_bone_pose(arm_left),target,rifle_contact_shoulder_weight))
 skeleton.set_bone_pose(forearm_left,forearm_left_rest)
 skeleton.force_update_all_bone_transforms()
 if socket!=null:socket.on_skeleton_update();socket.sync_transport_sockets()
func _evaluate(delta: float) -> void:
 var before:=pose_sequence;super._evaluate(delta)
 if pose_sequence!=before and not rifle_clips.is_empty():_constrain_rifle_contacts()
func reset_contacts() -> void:
 super.reset_contacts();rifle_idle_time=0.;rifle_move_weight=0.;idle_active=true
