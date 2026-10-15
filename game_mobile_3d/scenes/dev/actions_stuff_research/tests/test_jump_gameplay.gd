extends SceneTree
var failures: Array[String]=[]
var reports: Array=[]
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func tick(v: Node) -> void:
 await physics_frame
 await process_frame
 v._evaluate(1./Engine.physics_ticks_per_second)
func run() -> void:
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
 Engine.physics_ticks_per_second=fps
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
 var a=scene.player;var v=a.visual;a.scripted_input=true;v.set_process(false)
 check(v.has_method("drive_jump_motion"),"Existing scene must bind approved Jump visual")
 check(a.get("requested_jump")!=null,"Existing scene must bind physical Jump actor")
 if not v.has_method("drive_jump_motion") or a.get("requested_jump")==null:scene.free();quit(1);return
 check(is_equal_approx(scene.camera_size,5.1),"Camera framing remains unchanged")
 check(a.walk_speed==1.8 and a.run_speed==5.031 and a.acceleration==32. and a.deceleration==28.,"Existing movement speeds/response remain unchanged")
 for i in 5:await tick(v)
 for mode in ["stand","walk","run","reverse","stop_air"]:
  a.requested_direction=Vector2.ZERO if mode=="stand" else Vector2(0,-1);a.requested_run=mode in ["run","reverse","stop_air"]
  for i in int(.6*fps):await tick(v)
  a.requested_jump=true
  var air_frames:=0;var landings:=0;var min_floor:=INF;var root_min:=1.;var leg_max:=1.;var actual_peak:=0.;var source_states: Dictionary={};var max_leg_step:=0.;var previous: Array=[]
  for i in int(2.6*fps):
   await tick(v)
   var q: Dictionary=a.last_jump_query
   if i==2:a.requested_jump=false
   if mode=="reverse" and i==int(.2*fps):a.requested_direction=Vector2(0,1)
   if mode=="stop_air" and i==int(.2*fps):a.requested_direction=Vector2.ZERO
   if not q.grounded:air_frames+=1;check(not v.foot_support[0] and not v.foot_support[1],mode+" airborne feet cannot be planted")
   if q.landed:
    landings+=1
    check(v.jump_snapshot.controllers.pyhwuc.state in ["yytrhz","cfpejq"],mode+" source landing starts on actual ground contact")
    check(a.is_on_floor(),mode+" actual floor collision")
   actual_peak=maxf(actual_peak,a.position.y)
   for controller in ["ngeixo","pyhwuc","muiqdc"]:source_states[controller+":"+str(v.jump_snapshot.controllers[controller].state)]=true
   var rootbone: int=v.skeleton.find_bone("Root");root_min=minf(root_min,v.skeleton.get_bone_pose_scale(rootbone).y)
   var current: Array=[]
   for bone in [v.leg_left,v.leg_right]:
    var sole: Vector3=v._sole_world(bone);min_floor=minf(min_floor,sole.y);leg_max=maxf(leg_max,v.skeleton.get_bone_pose_scale(bone).y)
    current.append(v._leg_world_rotation(bone))
   if not previous.is_empty():
    for side in 2:max_leg_step=maxf(max_leg_step,rad_to_deg(Quaternion(previous[side]).angle_to(current[side])))
   previous=current
  check(air_frames>int(.5*fps) and landings==1,mode+" real flight and single landing")
  check(actual_peak>1.15,mode+" Godot physics owns height, no duplicated1m preview")
  check(root_min<.99,mode+" authored root squash preserved")
  if mode in ["stand","walk"]:check(leg_max>1.18,mode+" authored ordinary Jump leg stretch preserved")
  check(min_floor>-.004,mode+" feet do not penetrate flat ground: "+str(min_floor))
  check(max_leg_step<75.,mode+" no leg pose reset/spin at transition: "+str(max_leg_step))
  check(not v.jump_active,mode+" returns to existing locomotion after recovery")
  check(v.direction_sampler.holding_right==0. and v.jump_sampler.holding_right==0.,mode+" unarmed correction retained")
  reports.append({"mode":mode,"air_frames":air_frames,"landings":landings,"peak_m":actual_peak,"root_scale_min":root_min,"leg_scale_max":leg_max,"min_foot_y":min_floor,"max_leg_step_deg":max_leg_step,"source_states":source_states.keys()})
 print("JUMP_GAMEPLAY ",JSON.stringify({"fps":fps,"failures":failures,"trials":reports}))
 scene.free();quit(0 if failures.is_empty() else 1)
