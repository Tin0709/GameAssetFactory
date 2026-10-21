extends SceneTree
func _initialize():call_deferred("run")
func key(scene:Node,held:bool):
 var e:=InputEventKey.new();e.physical_keycode=KEY_E;e.pressed=held
 if held:scene._unhandled_input(e)
 else:scene._input(e)
func run():
 var stage:=OS.get_cmdline_user_args()[0]
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene);current_scene=scene
 var a=scene.player;var v=a.visual;a.scripted_input=true;a.global_position=Vector3(0,0,5);v.reset_contacts();scene.presentation.reset_history()
 for i in 4:
  var z=scene.zombie_combat.zombies[i];z.target=null;z.move_speed=0.;z.knockback_speed=0.;z.velocity=Vector3.ZERO;z.current_hp=100000;z.max_hp=100000;z.position=Vector3(0,0,-2) if i==0 else Vector3(30+i*3,0,30)
 var records:Array=[];var max_grip:=0.;var max_palm:=0.;var min_floor:=0.;var side_seen:=false;var back_seen:=false;var run_seen:=false;var jump_seen:=false
 for frame in 405:
  var t:=frame/30.;var stick:=Vector2.ZERO
  if frame==21:key(scene,true)
  if frame==348:key(scene,false)
  if t>=.7 and t<2.:stick=Vector2(-1,0)
  elif t>=2. and t<3.3:stick=Vector2(0,-1)
  elif t>=3.3 and t<4.6:stick=Vector2(1,0)
  elif t>=4.6 and t<5.9:stick=Vector2(0,1)
  elif t>=5.9 and t<7.2:stick=Vector2(-1,-1)
  elif t>=7.2 and t<8.5:stick=Vector2(1,1)
  elif t>=8.5 and t<9.8:stick=Vector2(-1 if int(t/.1)%2==0 else 1,0)
  elif t>=9.8 and t<10.7:stick=Vector2(1,0)
  elif t>=10.7 and t<11.6:stick=Vector2(-1,0)
  elif t>=11.6 and t<12.8:stick=Vector2(0,-1)
  a.requested_direction=stick;a.requested_run=t>=9.8 and t<10.7;a.requested_jump=frame==322
  await physics_frame;await process_frame;await RenderingServer.frame_post_draw
  var vars:Dictionary=v.direction_snapshot.vars
  side_seen=side_seen or absf(vars["v.mrmeib"])>.3;back_seen=back_seen or vars["v.cknrcn"]<-.3;run_seen=run_seen or v.gait_run_weight>.98;jump_seen=jump_seen or not v.jump_grounded
  var display:Array=scene.presentation.display_world
  if not display.is_empty():
   var right:Transform3D=display[v.arm_right];var carrier:Transform3D=display[v.carrier_bone]
   var alpha:float=scene.presentation.render_alpha
   var attachment:=Transform3D(scene.presentation.previous.rifle_attachment).interpolate_with(scene.presentation.current.rifle_attachment,alpha)
   max_grip=maxf(max_grip,(right*attachment).origin.distance_to(carrier.origin))
   var palm:Vector3=Vector3(v.rifle_profile.palm_forearm_local[0],v.rifle_profile.palm_forearm_local[1],v.rifle_profile.palm_forearm_local[2])
   # The presenter interpolates both targets along with the visible hands.
   var anchor:Vector3=Vector3(scene.presentation.previous.rifle_support).lerp(scene.presentation.current.rifle_support,alpha)
   max_palm=maxf(max_palm,(Transform3D(display[v.forearm_left])*palm).distance_to(carrier*anchor))
   for b in [v.leg_left,v.leg_right]:
    for point in v.SOLE_POINTS:min_floor=minf(min_floor,(Transform3D(display[b])*point).y)
  if frame%15==0:records.append({"time":t,"source_phase":v.direction_snapshot.phase,"forward":vars["v.cknrcn"],"side":vars["v.mrmeib"],"strafe_weight":v.rifle_strafe_weight,"height":v.position.y,"shots":scene.rifle_fire.shots_fired,"speed":a.current_speed,"grounded":v.jump_grounded,"jump_active":v.jump_active,"target":str(scene.rifle_auto_aim.target.name) if scene.rifle_auto_aim.target!=null else "none"})
  if frame in [50,90,130,170,210,250,290,310,335,375]:root.get_texture().get_image().save_png(stage+"/frame_"+str(frame)+".png")
 var report:={"passed":side_seen and back_seen and run_seen and jump_seen and scene.rifle_fire.shots_fired>30 and scene.rifle_fire.hit_count>10 and scene.rifle_fire.pool_misses==0 and max_grip<.0001 and max_palm<.0001 and min_floor>-.01,"side_seen":side_seen,"back_seen":back_seen,"run_seen":run_seen,"jump_seen":jump_seen,"shots":scene.rifle_fire.shots_fired,"hits":scene.rifle_fire.hit_count,"pool_misses":scene.rifle_fire.pool_misses,"render_grip_error_m":max_grip,"render_palm_error_m":max_palm,"render_min_floor_m":min_floor,"records":records}
 FileAccess.open(stage+"/native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("NATIVE_RIFLE_STRAFE ",JSON.stringify(report));scene.free();quit(0 if report.passed else 1)
