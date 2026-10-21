extends SceneTree
func _initialize():call_deferred("run")
func run():
 var out:=OS.get_cmdline_user_args()[0]
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
 Engine.max_fps=fps
 var frame_times:Array[float]=[];var last:=Time.get_ticks_usec()
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene);current_scene=scene
 var a=scene.player;var v=a.visual;a.scripted_input=true
 for i in 4:
  var z=scene.zombie_combat.zombies[i];z.target=null;z.move_speed=0.;z.current_hp=100000;z.max_hp=100000;z.position=Vector3(0,0,6) if i==0 else Vector3(30+i*3,0,30)
 scene.camera_size=3.6;scene.azimuth=.66
 for frame in 390:
  a.requested_direction=Vector2.ZERO;a.requested_run=false
  if frame==45:scene.azimuth=2.6
  if frame==65:v.set_rifle_aim(true)
  if frame==120:scene.rifle_fire.set_trigger(true);v.combat_turn_requested=true
  if frame>=170 and frame<220:a.requested_direction=Vector2(1,0)
  if frame>=220 and frame<270:a.requested_direction=Vector2(0,-1);a.requested_run=true
  a.requested_jump=frame==275
  if frame==325:scene.rifle_fire.set_trigger(false);v.set_rifle_aim(false);v.combat_turn_requested=false
  if frame>=330 and frame<375:a.requested_direction=Vector2(0,-1);a.requested_run=true
  await physics_frame;await process_frame;await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();frame_times.append((now-last)/1000.);last=now
  if frame>=70:scene.azimuth=v.rotation.y-.70
  if frame in [35,60,100,155,205,255,292,360]:root.get_texture().get_image().save_png(out+"/native_"+str(frame)+".png")
 frame_times.sort()
 var report:={"fps_cap":fps,"frame_median_ms":frame_times[int(frame_times.size()*.5)],"frame_p95_ms":frame_times[int(frame_times.size()*.95)],"shots":scene.rifle_fire.shots_fired,"hits":scene.rifle_fire.hit_count,"pool_misses":scene.rifle_fire.pool_misses,"frames":390,"skin":str(v.meshes[0].name),"weapon":v.rifle_model.scene_file_path}
 FileAccess.open(out+"/native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));scene.free();quit()
