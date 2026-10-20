extends SceneTree
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 if not ok:failures.append(message);push_error(message)
func ticks(count:int)->void:
 for i in count:await physics_frame
 await process_frame
func run()->void:
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene);scene.player.scripted_input=true
 for i in 4:
  var z=scene.zombie_combat.zombies[i];z.target=null;z.move_speed=0.;z.velocity=Vector3.ZERO;z.position=Vector3(0,0,3) if i==0 else Vector3(25+i,0,25);z.current_hp=10000
 await ticks(8)
 var v=scene.player.visual;var body_ready:=-1.;var first_shot:=-1.;var hz:=Engine.physics_ticks_per_second
 var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=true;scene._unhandled_input(event)
 var phase:float=v.direction_snapshot.phase
 var started:=Engine.get_physics_frames()
 for i in hz:
  await ticks(1);var age:=float(Engine.get_physics_frames()-started)/hz
  if body_ready<0. and absf(wrapf(v.rotation.y,-PI,PI))<deg_to_rad(8.):body_ready=age
  if first_shot<0. and scene.rifle_fire.shots_fired>0:first_shot=age
 check(body_ready>=.24 and body_ready<=.36,"Held E turns180deg decisively but visibly, around0.30seconds rather than snapping")
 check(first_shot>=.23 and first_shot<=.40,"First shot waits for approved Aim raise and the readable turn, without a long delay")
 check(absf(v.direction_snapshot.phase-phase)<.0001,"Stationary combat pivot never resets or starts gait")
 event.pressed=false;scene._input(event)
 check(not scene.rifle_fire.trigger_held,"E release still stops firing")
 var report:={"passed":failures.is_empty(),"failures":failures,"physics_hz":hz,"body_ready_s":body_ready,"first_shot_s":first_shot,"shots":scene.rifle_fire.shots_fired}
 print("RIFLE_QUICK_TURN ",JSON.stringify(report))
 var dest:=OS.get_environment("RIFLE_QUICK_TURN_RESULTS")
 if not dest.is_empty():FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 scene.free();quit(0 if failures.is_empty() else 1)
