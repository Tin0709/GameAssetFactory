extends "res://scenes/dev/actions_stuff_research/jump_locomotion_visual.gd"
## Approved Ready clips plus the approved Aim in the existing pose/contact pipeline.
## Source studies remain read-only; generic weapon posing never overlays this set.
const RifleSampler=preload("res://scenes/dev/actions_stuff_research/rifle_ready_v001/rifle_sampler.gd")
const RIFLE_LIBRARY=preload("res://scenes/dev/actions_stuff_research/rifle_ready_v001/approved_library.res")
const AIM_LIBRARY=preload("res://scenes/dev/actions_stuff_research/rifle_ready_v001/aim_approved_library.res")
const RECOIL_LIBRARY=preload("res://scenes/dev/actions_stuff_research/rifle_ready_v001/recoil_approved_library.res")
const RIFLE_ASSET=preload("res://assets/weapons/rifle_stylized_v2_test/Rifle_Stylized_V2.glb")
const RifleTurn=preload("res://scenes/dev/actions_stuff_research/turn_in_place_v001/rifle_turn.gd")
var stationary_turn: RifleTurn
var turn_axis:=0.
var combat_turn_requested:=false
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
var rifle_strafe_weight:=0.
var _rifle_strafe_context:=false
var _rifle_strafe_bones:Array[int]=[]
var _rifle_strafe_height:=0.
var _rifle_strafe_floor_y:=0.
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
var rifle_recoil_clip: RefCounted
var rifle_recoil_profile: Dictionary={}
var rifle_recoil_time:=10.
var _recoil_reference_inverse: Array[Transform3D]=[]
var _recoil_saved: Array[Transform3D]=[]
var _recoil_support_base:=Vector3.ZERO
var _recoil_saved_support:=Vector3.ZERO
var _recoil_applied:=false
var auto_aim_target: Node3D
var auto_aim_aligned:=true
var barrel_contact_query: Callable
var _auto_aim_spine: int
var _auto_aim_saved:=Transform3D.IDENTITY
var _auto_aim_rotation:=Quaternion.IDENTITY
var _auto_aim_applied:=false
var _auto_aim_turning:=false
var _gameplay_run_weight:=0.
var _ground_travel:=0.
var _micro_stop:=false
var _distance_phase:=NAN
var _travel_yaw_velocity:=0.

func _retime_locomotion_phase(step:float)->void:
 if rifle_clips.is_empty():super._retime_locomotion_phase(step);return
 # Gameplay speed owns classification. The literal research controller's
 # 0.61035 Walk query never crosses its 0.6 Run exit hysteresis.
 var speed:=movement_speed/maxf(travel_speed_scale,.001)
 _gameplay_run_weight=move_toward(_gameplay_run_weight,smoothstep(WALK_SPEED+.05,RUN_SPEED-.05,speed),step/.14)
 direction_snapshot.run_weight=_gameplay_run_weight
 if jump_active or not jump_grounded:
  super._retime_locomotion_phase(step);return
 # Keep the common cursor continuous, but advance it by actual travel rather
 # than the source speed filter's residual motion after the capsule stops.
 var previous_phase:float=direction_snapshot.phase-step*float(direction_snapshot.cadence)
 # Cancel round-off from subtracting the source advance, without masking
 # intentional source jump phase overrides on takeoff/landing.
 if is_finite(_distance_phase) and absf(previous_phase-_distance_phase)<.0000001:previous_phase=_distance_phase
 var stride:=lerpf(WALK_SPEED/1.25,RUN_SPEED/1.6,_gameplay_run_weight)
 var cadence:=speed/stride*locomotion_playback_rate
 var phase:=previous_phase+step*cadence
 _distance_phase=phase
 var phase01:=fposmod(phase,1.)
 direction_snapshot.phase=phase;direction_snapshot.phase01=phase01;direction_snapshot.cadence=cadence
 direction_snapshot.vars["v.eqhdel"]=phase;direction_snapshot.vars["v.ifcvde"]=phase01
 direction_controller.env["v.eqhdel"]=phase;direction_controller.env["v.ifcvde"]=phase01

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
 rifle_recoil_profile=JSON.parse_string(FileAccess.get_file_as_string("res://scenes/dev/actions_stuff_research/rifle_ready_v001/recoil_profile.json"))
 rifle_recoil_clip=RifleSampler.new(RECOIL_LIBRARY.get_animation("Recoil"),skeleton)
 for bone in skeleton.get_bone_count():_recoil_reference_inverse.append(rifle_recoil_clip.pose(bone,0.).affine_inverse())
 _recoil_support_base=rifle_recoil_clip.support(0.)
 for bone in _aim_bones:_recoil_saved.append(skeleton.get_bone_pose(bone))
 active_walk_action=rifle_profile.clips.Walk.action;active_run_action=rifle_profile.clips.Run.action
 for bone_name in ["Root","Hips","Leg.L","Leg.R"]:_rifle_strafe_bones.append(skeleton.find_bone(bone_name))
 stationary_turn=RifleTurn.new(skeleton,rotation.y)
 _cache_direction_poses();position.y=0.
 for i in skeleton.get_bone_count():
  var pose: Transform3D=direction_poses[i];var q:=pose.basis.orthonormalized().get_rotation_quaternion()
  skeleton.set_bone_pose(i,pose);_p[i]=pose.origin;_q[i]=q;_final_p[i]=pose.origin;_final_q[i]=q
  _vp[i]=Vector3.ZERO;_vq[i]=Vector3.ZERO;_offset_p[i]=Vector3.ZERO;_offset_q[i]=Vector3.ZERO;_offset_vp[i]=Vector3.ZERO;_offset_vq[i]=Vector3.ZERO
 _constrain_rifle_contacts();skeleton.force_update_all_bone_transforms()
 for side in 2:
  var b: int=[leg_left,leg_right][side];var sole:=_sole_world(b);last_sole[side]=sole;foot_anchors[side]=Vector3(sole.x,0.,sole.z);foot_rotations[side]=_leg_world_rotation(b);replant_from[side]=sole;replant_q[side]=foot_rotations[side]
 pose_dirty=false;transition_age=10.;_scale_dirty=false

func activate_rifle_ready(asset: PackedScene=RIFLE_ASSET) -> void:
 # Reuse the existing weapon socket, marker arrays and preferred model.
 var old: Node3D=socket.instances[1];old.hide();rifle_model=asset.instantiate();rifle_model.name="ResearchRifle";socket.add_child(rifle_model);socket.instances[1]=rifle_model
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
 if stationary_turn!=null:stationary_turn.apply(poses,ahead,rifle_aim_weight,_has_auto_aim())
 if rifle_strafe_weight>0.:
  var directional:Array=direction_future_sampler.poses if ahead>0. else direction_sampler.poses
  # Keep the source waist/leg parent compensation together. The approved
  # rifle upper-body locals, grip and recoil remain on their existing path.
  for bone in _rifle_strafe_bones:poses[bone]=Transform3D(poses[bone]).interpolate_with(directional[bone],rifle_strafe_weight)
 return poses

func set_rifle_aim(held: bool) -> void:
 rifle_aim_requested=held
func _has_auto_aim() -> bool:
 return rifle_aim_requested and is_instance_valid(auto_aim_target) and not auto_aim_target.is_dead
func _advance_facing(target_yaw: float,delta: float) -> void:
 if _has_auto_aim():
  _travel_yaw_velocity=0.
  var offset: Vector3=auto_aim_target.global_position-global_position
  if Vector2(offset.x,offset.z).length_squared()>.0001:target_yaw=atan2(offset.x,offset.z)
  if combat_turn_requested:
   rotation.y+=clampf(wrapf(target_yaw-rotation.y,-PI,PI),-RifleTurn.QUICK_TURN_RATE*delta,RifleTurn.QUICK_TURN_RATE*delta)
   return
 if _has_auto_aim():super._advance_facing(target_yaw,delta)
 else:
  # Exact critically damped angular response: carry turn velocity through
  # changing input instead of hard starting/stopping a constant-rate pivot.
  # Stationary Q/C and the approved 0.6s E pivot keep their existing path.
  var offset:=wrapf(rotation.y-target_yaw,-PI,PI)
  var spring:=_travel_yaw_velocity+26.*offset
  var decay:=exp(-26.*delta)
  var next_offset:float=(offset+spring*delta)*decay
  _travel_yaw_velocity=clampf((_travel_yaw_velocity-26.*spring*delta)*decay,-14.,14.)
  rotation.y+=clampf(next_offset-offset,-14.*delta,14.*delta)
func _restore_auto_aim() -> void:
 if not _auto_aim_applied:return
 skeleton.set_bone_pose(_auto_aim_spine,_auto_aim_saved)
 _auto_aim_applied=false
func _prepare_auto_aim(delta: float) -> void:
 # Compute from the clean Aim pose BEFORE recoil; never chase/cancel its kick.
 _auto_aim_spine=skeleton.find_bone("Spine")
 var desired:=Quaternion.IDENTITY
 if _has_auto_aim():
  var parent: int=skeleton.get_bone_parent(_auto_aim_spine)
  var parent_world:=skeleton.global_transform*skeleton.get_bone_global_pose(parent)
  var inverse:=parent_world.affine_inverse()
  var pose:=skeleton.get_bone_pose(_auto_aim_spine)
  var muzzle: Vector3=inverse*socket.muzzle_position()
  var carrier:=skeleton.global_transform*skeleton.get_bone_global_pose(carrier_bone)
  var forward: Vector3=(inverse.basis*carrier.basis.y).normalized()
  var target: Vector3=inverse*(auto_aim_target.global_position+Vector3(0,1.02,0))-pose.origin
  var reach:=muzzle-pose.origin
  var perpendicular:=reach-forward*reach.dot(forward)
  # Rotate the intact hold about Spine so its actual muzzle ray intersects the
  # target. Account for the weapon's offset/length, rather than aiming an
  # invisible bullet independently of its barrel or moving either hand.
  var along_squared:=target.length_squared()-perpendicular.length_squared()
  if along_squared>0.0001:
   var source:=perpendicular+forward*sqrt(along_squared)
   desired=Quaternion(source.normalized(),target.normalized()).normalized()
   if desired.w<0.0:desired=-desired
   var angle:=desired.get_angle()
   # The source leaves up to60deg head/body yaw at rest. Reserve another15deg
   # of the common hold's cone for muzzle parallax + pitch at melee distance;
   # otherwise a57deg target can saturate a60deg 3D cone and never be fired at.
   # Moving/airborne acquisition keeps its existing bound and facing behavior.
   var cone:=75. if jump_grounded and not move_requested and stationary_turn!=null and absf(stationary_turn.gaze)<=deg_to_rad(60.) else 60.
   if angle>deg_to_rad(cone):desired=Quaternion.IDENTITY.slerp(desired,deg_to_rad(cone)/angle)
 _auto_aim_rotation=_auto_aim_rotation.slerp(desired,1.0-exp(-(40.0 if combat_turn_requested else 20.0)*delta)).normalized()
 if _auto_aim_rotation.get_angle()<.0001:_auto_aim_rotation=Quaternion.IDENTITY
func _apply_auto_aim() -> void:
 # Carry the full approved recoil/hold together under that same aiming frame.
 _auto_aim_saved=skeleton.get_bone_pose(_auto_aim_spine)
 if _auto_aim_rotation!=Quaternion.IDENTITY:
  skeleton.set_bone_pose(_auto_aim_spine,Transform3D(Basis(_auto_aim_rotation)*_auto_aim_saved.basis,_auto_aim_saved.origin))
  _auto_aim_applied=true
  _constrain_rifle_contacts()
 auto_aim_aligned=true
 if _has_auto_aim():
  var to_target: Vector3=auto_aim_target.global_position+Vector3(0,1.02,0)-socket.muzzle_position()
  var barrel:=skeleton.global_transform*skeleton.get_bone_global_pose(carrier_bone)
  auto_aim_aligned=barrel.basis.y.normalized().dot(to_target.normalized())>.999
  # An approaching zombie can intersect the barrel before its center is in
  # front of the muzzle. Require real segment contact rather than waiting for
  # an impossible forward ray or silently redirecting a bullet backwards.
  if not auto_aim_aligned and to_target.dot(barrel.basis.y)<0. and barrel_contact_query.is_valid():
   var contact: Dictionary=barrel_contact_query.call()
   auto_aim_aligned=contact.get("collider")==auto_aim_target
func _cache_direction_poses() -> void:
 if rifle_clips.is_empty():super._cache_direction_poses();return
 if rifle_strafe_weight>0.:
  direction_sampler.set_snapshot(direction_snapshot)
  var future:Dictionary=direction_snapshot.duplicate(true)
  future.phase+=.004*float(future.cadence);future.life+=.004
  direction_future_sampler.set_snapshot(future)
  _rifle_strafe_height=direction_sampler.height_offset(direction_snapshot)
 rifle_ground_poses=_sample_set();rifle_ground_future=_sample_set(.004)
 direction_poses=rifle_ground_poses.duplicate();direction_future_poses=rifle_ground_future.duplicate()

func drive_jump_motion(world_velocity: Vector3,requested: bool,physics: Dictionary,delta: float) -> void:
 # Remove the previous displayed impulse before the existing pose writer reads
 # its state. Recoil never feeds the inertializer, gait, feet or the next shot.
 _restore_auto_aim()
 _restore_rifle_recoil()
 rifle_recoil_time=minf(rifle_recoil_time+delta,rifle_recoil_clip.clip.length)
 rifle_aim_weight=move_toward(rifle_aim_weight,1. if rifle_aim_requested else 0.,delta/AIM_BLEND_SECONDS)
 if rifle_aim_requested or rifle_aim_weight>0.:rifle_aim_time=fposmod(rifle_aim_time+delta,float(rifle_aim_profile.clips.Aim.duration))
 var moving:=requested or Vector2(world_velocity.x,world_velocity.z).length()>.025
 if not moving:_travel_yaw_velocity=0.
 if moving:
  if not move_requested:_ground_travel=0.
  _ground_travel+=Vector2(world_velocity.x,world_velocity.z).length()*delta
  _micro_stop=false
 elif move_requested:
  _micro_stop=_ground_travel<.18 and bool(physics.grounded) and not jump_active
 var combat:=combat_turn_requested and _has_auto_aim()
 # Verified pre29 recent-action branch keeps forward/lateral weights relative
 # to look. E is our rifle-combat equivalent; never reset its shared gait.
 if combat:direction_controller.seed_context(true)
 elif _rifle_strafe_context:direction_controller.seed_context(false)
 _rifle_strafe_context=combat
 var grounded_combat:=combat and moving and bool(physics.grounded) and not bool(physics.get("takeoff",false)) and not jump_active
 rifle_strafe_weight=move_toward(rifle_strafe_weight,1. if grounded_combat else 0.,delta/.14)
 var target_yaw:=NAN
 if _has_auto_aim():
  var toward: Vector3=auto_aim_target.global_position-global_position
  target_yaw=atan2(toward.x,toward.z)
  if not bool(physics.grounded) and not moving:_advance_facing(target_yaw,delta)
 stationary_turn.axis=turn_axis
 rotation.y=stationary_turn.advance(rotation.y,target_yaw,moving,bool(physics.grounded),delta,combat_turn_requested)
 look_yaw=rotation.y
 rifle_move_weight=move_toward(rifle_move_weight,1. if moving else 0.,delta/.14)
 # Interrupt the scan immediately. Reset its cursor while fully hidden, never
 # while its pose is still visible during a very short movement tap.
 if moving:
  if rifle_move_weight>=.9999:rifle_idle_time=0.
 else:rifle_idle_time=fposmod(rifle_idle_time+delta,float(rifle_profile.clips.Idle.duration))
 _rifle_driving=true;super.drive_jump_motion(world_velocity,requested,physics,delta);_rifle_driving=false
 if jump_grounded and not jump_active:
  for key in PHASE_KEYS:jump_runtime.env[key]=direction_snapshot.vars[key]
 if _micro_stop and not moving and settling:
  # A tap does not warrant the inherited alternating 0.44s replant sequence.
  # Retain its current ground contacts while the moving pose fades out.
  settling=false
  for side in 2:
   foot_anchors[side]=Vector3(last_sole[side].x,0.,last_sole[side].z)
   foot_rotations[side]=_leg_world_rotation([leg_left,leg_right][side])
   foot_support[side]=true;support_aim[side]=Quaternion.IDENTITY
 if jump_active:
  _rifle_strafe_floor_y=0.
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
 else:
  # Smooth only this rig's geometric height envelope. Literal source waist/
  # leg bounce remains in the PRS; the existing floor solver owns contact.
  _rifle_strafe_floor_y=move_toward(_rifle_strafe_floor_y,_rifle_strafe_height*rifle_strafe_weight,delta*.75)
  position.y=_rifle_strafe_floor_y
 idle_active=not moving and not jump_active
 rifle_state="Run" if gait_run_weight>.98 and moving else ("Walk" if moving else "Idle")
 if jump_grounded:_update_direction_support(delta)
 support_left=_support(0);support_right=_support(1)
 _evaluate(delta)
 _prepare_auto_aim(delta)
 _apply_rifle_recoil()
 _apply_auto_aim()
 if presentation!=null:presentation.capture()

func play_rifle_recoil() -> void:
 rifle_recoil_time=0.
func _restore_rifle_recoil() -> void:
 if not _recoil_applied:return
 for i in _aim_bones.size():skeleton.set_bone_pose(_aim_bones[i],_recoil_saved[i])
 rifle_support_anchor=_recoil_saved_support
 _recoil_applied=false
 _constrain_rifle_contacts()
func cancel_rifle_recoil() -> void:
 _restore_auto_aim()
 _restore_rifle_recoil();rifle_recoil_time=rifle_recoil_clip.clip.length
func _apply_rifle_recoil() -> void:
 if rifle_recoil_time>=rifle_recoil_clip.clip.length:return
 # Evaluated source-local delta, including translation; not a generic kick.
 # Pre-multiplication also preserves the accepted rectangular-arm roll frame.
 _recoil_saved_support=rifle_support_anchor
 for i in _aim_bones.size():
  var bone: int=_aim_bones[i];var pose:=skeleton.get_bone_pose(bone);_recoil_saved[i]=pose
  var impulse: Transform3D=rifle_recoil_clip.pose(bone,rifle_recoil_time)*_recoil_reference_inverse[bone]
  skeleton.set_bone_pose(bone,impulse*pose)
 rifle_support_anchor+=rifle_recoil_clip.support(rifle_recoil_time)-_recoil_support_base
 _recoil_applied=true
 _constrain_rifle_contacts()

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
 if move_requested:
  super._update_direction_support(delta)
  for side in 2:
   if not _source_support[side] or not foot_support[side]:continue
   var bone:int=[leg_left,leg_right][side]
   var raw_yaw:=_foot_yaw(_source_global_pose(bone).basis.orthonormalized().get_rotation_quaternion())
   # The inherited 35deg anchor tolerance holds a foot sideways, then snaps
   # it back during a diagonal start/reversal. Release before that wind-up;
   # the same gait/contact rearm logic still owns its next landing.
   if absf(wrapf(raw_yaw-_foot_yaw(foot_rotations[side]),-PI,PI))>deg_to_rad(12.):
    _source_support[side]=false;_support_rearmed[side]=false
    _release_phase[side]=direction_snapshot.phase;released[side]=true
  return
 if stationary_turn!=null and stationary_turn.quick_turning:
  # Combat input outranks the long observational step sequence. Release old
  # anchors for the brief pivot, then replant through the existing floor solve.
  for side in 2:_source_support[side]=false;released[side]=true
  return
 if stationary_turn!=null and stationary_turn.active:
  settling=false
  for side in 2:
   var bone: int=[leg_left,leg_right][side]
   var pose:=_source_global_pose(bone);var height:=INF
   for point in SOLE_POINTS:height=minf(height,(pose*point).y)
   var free_leg: bool=stationary_turn.free_foot(side)
   # Once the corrective foot keys settle, the approved Idle can still make
   # its low-clearance lateral weight shift. A residual head/body yaw must not
   # disable that existing contact release and drag an old anchor inward.
   var idle_reposition: bool=(not stationary_turn.stepping or stationary_turn.clock>.5) and _idle_foot_lateral_speed(bone)>.025
   if free_leg or height>.035 or idle_reposition:_source_support[side]=false;released[side]=true
   elif height<.025:_source_support[side]=true;released[side]=false
  return
 # Preserve the approved idle's occasional free-leg weight shift.
 if _micro_stop and rifle_move_weight>.001:
  for side in 2:_source_support[side]=true;released[side]=false
  return
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
func _replant_clearance(side: int,destination: Vector3) -> float:
 # A free foot already has clearance: lower it directly instead of lifting
 # it again. A grounded foot only needs a small lift for a real stance change,
 # not the inherited compulsory 35mm step after every directional tap.
 if replant_from[side].y>.006:return 0.
 var distance:=Vector2(destination.x-replant_from[side].x,destination.z-replant_from[side].z).length()
 return smoothstep(.04,.16,distance)*.008
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
 _gameplay_run_weight=0.;_ground_travel=0.;_micro_stop=false;_distance_phase=NAN;_travel_yaw_velocity=0.
 _restore_auto_aim();auto_aim_target=null;auto_aim_aligned=true;_auto_aim_rotation=Quaternion.IDENTITY;_auto_aim_turning=false
 if rifle_recoil_clip!=null:cancel_rifle_recoil()
 super.reset_contacts();rifle_idle_time=0.;rifle_move_weight=0.;idle_active=true
 rifle_strafe_weight=0.;_rifle_strafe_context=false;_rifle_strafe_height=0.;_rifle_strafe_floor_y=0.;direction_controller.seed_context(false)
 turn_axis=0.
 if stationary_turn!=null:stationary_turn.reset(rotation.y)
