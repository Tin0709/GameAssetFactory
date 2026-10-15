extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
 if not ok: failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
 var v=scene.player.visual;scene.player.set_physics_process(false);v.set_process(false)
 var legacy=load("res://scenes/dev/actions_stuff_research/source_direction_sampler.gd").new(v.skeleton)
 var max_arm_error:=0.;var max_other_error:=0.;var samples:=0
 for blend in [0.,.25,.5,.75,1.]:
  for direction in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(.7,.7)]:
   for i in 120:
    var snapshot={"phase":float(i)/120.,"life":12.+float(i)/120.,"run_weight":blend,"vars":{"v.esnrkj":lerpf(.6103515625,1.,blend),"v.cknrcn":direction.x,"v.mrmeib":direction.y},"query":{}}
    legacy.set_snapshot(snapshot);v.direction_sampler.set_snapshot(snapshot);v.direction_future_sampler.set_snapshot(snapshot)
    for bone in legacy.channels:
     for channel in legacy.channels[bone]:
      var expected: Vector3=legacy.channels[bone][channel]
      if bone=="rightarm" and channel=="rotation":expected.x*=2.
      var error: float=expected.distance_to(v.direction_sampler.channels[bone][channel])
      var future_error: float=expected.distance_to(v.direction_future_sampler.channels[bone][channel])
      if bone in ["rightarm","leftarm"]:max_arm_error=maxf(max_arm_error,maxf(error,future_error))
      else:max_other_error=maxf(max_other_error,maxf(error,future_error))
    samples+=1
 check(max_arm_error<.00004,"Unarmed current/future sampler must preserve full source alternating arms: "+str(max_arm_error))
 check(max_other_error<.000001,"Unarmed correction must preserve all nonarm source channels: "+str(max_other_error))
 print("UNARMED_ARMS_TEST ",JSON.stringify({"failures":failures,"samples":samples,"max_arm_error_degrees":max_arm_error,"max_nonarm_error":max_other_error}))
 scene.free();quit(0 if failures.is_empty() else 1)
