extends RefCounted
## Bedrock look-query adapter + literal corrective clips; no new Blender Action.
const Runtime=preload("res://scenes/dev/actions_stuff_research/turn_in_place_v001/source_turn_controller.gd")
const Sampler=preload("res://scenes/dev/actions_stuff_research/turn_in_place_v001/turn_sampler.gd")
var runtime: RefCounted
var sampler: RefCounted
var future_sampler: RefCounted
var neutral: Array=[]
var snapshot: Dictionary={}
var rig: Skeleton3D
var look_yaw:=PI
var requested_yaw:=PI
var axis:=0.
var body_yaw:=PI
var gaze:=0.
var weight:=0.
var active:=false
var stepping:=false
var clock:=0.
var lead_side:=1
var was_moving:=false
func _init(skeleton: Skeleton3D,yaw: float) -> void:
 rig=skeleton;sampler=Sampler.new(rig);future_sampler=Sampler.new(rig)
 sampler.set_snapshot({"layers":[]});neutral=sampler.poses.duplicate()
 reset(yaw)
func reset(yaw: float) -> void:
 runtime=Runtime.new();runtime.seed_heading(-rad_to_deg(yaw))
 look_yaw=yaw;requested_yaw=yaw;body_yaw=yaw;gaze=0.;weight=0.;axis=0.;active=false;stepping=false;was_moving=false
 snapshot=runtime.step_turn(-rad_to_deg(yaw),false,1./60.)
func advance(current_yaw: float,target_yaw: float,moving: bool,grounded: bool,delta: float) -> float:
 var interrupted:=moving or not grounded
 if interrupted:
  look_yaw=current_yaw;requested_yaw=current_yaw
  runtime.seed_heading(-rad_to_deg(current_yaw))
 elif was_moving:
  # Arrival starts from the existing actual heading, without changing gait.
  look_yaw=current_yaw;requested_yaw=current_yaw
  runtime.seed_heading(-rad_to_deg(current_yaw))
 if not interrupted:
  if is_finite(target_yaw):requested_yaw=target_yaw
  else:requested_yaw+=axis*deg_to_rad(135.)*delta
 var previous_look:=look_yaw
 if not interrupted:look_yaw+=clampf(wrapf(requested_yaw-look_yaw,-PI,PI),-6.*delta,6.*delta)
 var count:=maxi(1,ceili(delta*60.-.000001));var dt:=delta/count
 for i in count:
  var heading:=lerpf(previous_look,look_yaw,float(i+1)/count)
  snapshot=runtime.step_turn(-rad_to_deg(heading),interrupted,dt)
 body_yaw=current_yaw if interrupted else -deg_to_rad(float(snapshot.body_degrees))
 gaze=clampf(wrapf(look_yaw-body_yaw,-PI,PI),-PI*.5,PI*.5)
 weight=move_toward(weight,0. if interrupted else 1.,delta/.15)
 stepping=snapshot.state=="vywhcj"
 clock=float(runtime.env.get("v.hdseda",0.))
 lead_side=1 if float(snapshot.turn_degrees)>0. else 0
 active=weight>.0001 and (stepping or not snapshot.layers.is_empty() or absf(gaze)>.0001)
 was_moving=interrupted
 return body_yaw
func _global(poses: Array,bone: int) -> Transform3D:
 var pose: Transform3D=poses[bone];var parent:=rig.get_bone_parent(bone)
 while parent>=0:pose=Transform3D(poses[parent])*pose;parent=rig.get_bone_parent(parent)
 return pose
func _yaw(poses: Array,bone: int,angle: float) -> void:
 if absf(angle)<.00001:return
 var global_pose:=_global(poses,bone)
 global_pose.basis=Basis(Vector3.UP,angle)*global_pose.basis
 var parent:=rig.get_bone_parent(bone)
 poses[bone]=_global(poses,parent).affine_inverse()*global_pose if parent>=0 else global_pose
func apply(poses: Array,ahead: float,aim_weight: float,automatic_aim: bool) -> void:
 if not active:return
 var sample=sampler if ahead==0. else future_sampler
 var source: Dictionary=snapshot.duplicate(true)
 if ahead>0.:
  # Probe derivative only: source local clock follows hdseda, never gait.
  source.vars["v.hdseda"]+=ahead
  for layer in source.layers:layer.clock=minf(float(layer.clock)+ahead,.7917)
 sample.set_snapshot(source)
 # The native retarget cancels waist motion out of the independent source legs.
 # Preserve that hierarchy; don't attach a single clip's pelvis to other legs.
 for name in ["Hips","Spine","Chest","Neck","Head","Leg.L","Leg.R"]:
  var bone:=rig.find_bone(name)
  var change: Transform3D=Transform3D(sample.poses[bone])*Transform3D(neutral[bone]).affine_inverse()
  poses[bone]=Transform3D.IDENTITY.interpolate_with(change,weight)*Transform3D(poses[bone])
 # Literal source arm offsets would break the approved rifle's two-hand hold.
 # Its existing common aiming frame carries both arms/weapon/head coherently.
 if not automatic_aim:
  var torso:=gaze*lerpf(.5,1.,aim_weight)*weight
  _yaw(poses,rig.find_bone("Spine"),torso)
  _yaw(poses,rig.find_bone("Head"),gaze*weight-torso)
func free_foot(side: int) -> bool:
 # Source key windows: leading lift first, trailing correction second. Ground
 # anchors are a Godot adaptation; source pack has no contact-memory/IK solver.
 if not stepping:return false
 return clock<.19 if side==lead_side else clock>.16 and clock<.45
