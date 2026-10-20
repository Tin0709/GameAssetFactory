extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
 var dt:=1./fps
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
 scene.set_process(false);var a=scene.player;var v=a.visual;a.set_physics_process(false);v.set_process(false)
 var max_pitch:=0.;var max_joint_step:=0.;var min_floor:=INF;var support_step:=0.;var previous_roots:=[];var previous_soles:=[];var previous_support:=[]
 for i in int(24.*fps):
  var t:=i*dt
  v.set_rifle_aim(t>.3 and t<20.)
  if t>9. and t<10.:v.set_rifle_aim(fmod(t,.22)<.11)
  v.drive_jump_motion(Vector3.ZERO,false,{"grounded":true,"body_position":a.position,"vertical_speed":0.,"takeoff":false,"sprinting":false},dt)
  var roots:=[];var soles:=[]
  for side in 2:
   var b: int=[v.leg_left,v.leg_right][side];var p: Transform3D=v.skeleton.get_bone_global_pose(b)
   roots.append(p.origin);soles.append(v._sole_world(b));min_floor=minf(min_floor,soles[side].y)
   if t>1.:
    max_pitch=maxf(max_pitch,absf(rad_to_deg(atan2(p.basis.y.z,-p.basis.y.y))))
    max_joint_step=maxf(max_joint_step,p.origin.distance_to(previous_roots[side]))
    if previous_support[side] and v.foot_support[side]:support_step=maxf(support_step,soles[side].distance_to(previous_soles[side]))
  previous_roots=roots;previous_soles=soles;previous_support=v.foot_support.duplicate()
 check(max_pitch<.1,"Stationary Aim must not add incompatible fore/aft foot rocking: "+str(max_pitch))
 check(max_joint_step<.025,"Stationary Aim has no abrupt contact-driven leg root jumps: "+str(max_joint_step))
 check(support_step<.0001,"Supported Aim feet stay stable: "+str(support_step))
 check(min_floor>-.0002,"Aim feet remain above floor")
 var report:={"fps":fps,"failures":failures,"max_fore_aft_leg_tilt_deg":max_pitch,"max_leg_root_step_m":max_joint_step,"supported_sole_step_m":support_step,"minimum_floor":min_floor}
 print("RIFLE_AIM_STANDING ",JSON.stringify(report));scene.free();quit(0 if failures.is_empty() else 1)
