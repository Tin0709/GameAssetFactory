extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
 var dt:=1./fps
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
 var a=scene.player;var v=a.visual
 scene.set_process(false);a.set_physics_process(false);v.set_process(false)
 var max_idle_joint_drag:=0.;var min_upper_gap:=INF;var min_floor:=INF;var free_weight_shift:=0;var support_motion:=0.;var previous_support: Array=[];var previous_soles: Array=[]
 for i in int(26.*fps):
  var t:=i*dt;var moving:=t>12. and t<14.;var velocity:=Vector3(0,0,-a.walk_speed) if moving else Vector3.ZERO
  a.velocity=velocity;a.position+=velocity*dt
  v.set_rifle_aim(t>20. and t<24.)
  v.drive_jump_motion(velocity,moving,{"grounded":true,"body_position":a.position,"vertical_speed":0.,"takeoff":false,"sprinting":false},dt)
  var settled: bool=not v.move_requested and not v.settling and v.rifle_move_weight<.001 and v.transition_age>.7
  var upper_edges: Array[float]=[INF,-INF]
  for side in 2:
   var b: int=[v.leg_left,v.leg_right][side]
   var raw: Transform3D=v._source_global_pose(b)
   var actual: Transform3D=v.skeleton.global_transform*v.skeleton.get_bone_global_pose(b)
   var sole: Vector3=v._sole_world(b)
   min_floor=minf(min_floor,sole.y)
   if settled:
    var correction:=actual.origin-raw.origin
    if v.rifle_aim_weight<.001:max_idle_joint_drag=maxf(max_idle_joint_drag,Vector2(correction.x,correction.z).length())
    if not v.foot_support[side]:free_weight_shift+=1
    for x in [-.1125,.1125]:
     for y in [0.,.1]:
      for z in [-.1125,.1125]:
       var p: Vector3=v.skeleton.get_bone_global_pose(b)*Vector3(x,y,z)
       upper_edges[side]=minf(upper_edges[side],p.x) if side==0 else maxf(upper_edges[side],p.x)
    if not previous_support.is_empty() and previous_support[side] and v.foot_support[side]:support_motion=maxf(support_motion,sole.distance_to(previous_soles[side]))
  if settled:min_upper_gap=minf(min_upper_gap,upper_edges[0]-upper_edges[1])
  previous_support=v.foot_support.duplicate();previous_soles=[v._sole_world(v.leg_left),v._sole_world(v.leg_right)]
 check(max_idle_joint_drag<.025,"Idle contact must not drag rigid leg roots inward: "+str(max_idle_joint_drag))
 check(min_upper_gap>-.005,"Settled Idle upper legs must remain separated: "+str(min_upper_gap))
 check(free_weight_shift>4,"Authored low-clearance lateral weight shift releases its foot")
 check(support_motion<.0001,"Actual supported soles stay stable: "+str(support_motion))
 check(min_floor>-.0002,"Feet remain above floor")
 var report:={"fps":fps,"failures":failures,"max_idle_joint_drag_m":max_idle_joint_drag,"minimum_upper_leg_gap_m":min_upper_gap,"supported_sole_step_m":support_motion,"free_weight_shift_samples":free_weight_shift,"minimum_floor":min_floor}
 print("RIFLE_IDLE_CONTACTS ",JSON.stringify(report));scene.free();quit(0 if failures.is_empty() else 1)
