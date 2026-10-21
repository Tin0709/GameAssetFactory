extends SceneTree
## Capture the SAME gameplay scene, not a separate test scene. Inspection camera
## adjustments are temporary and never saved into player/camera settings.
func _initialize():call_deferred("run")
func run():
 var out:=OS.get_cmdline_user_args()[0]
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
 Engine.max_fps=fps
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene);current_scene=scene
 var actor=scene.player;var visual=actor.visual;var appearance=scene.soldier_appearance;actor.scripted_input=true
 for i in 4:
  var zombie=scene.zombie_combat.zombies[i];zombie.target=null;zombie.move_speed=0.;zombie.current_hp=100000;zombie.max_hp=100000;zombie.position=Vector3(0,0,8) if i==0 else Vector3(40+i*3,0,40)
 scene.camera_size=3.6
 var max_hair:=0.;var max_tail:=0.;var blinks:=0;var was_blink:=false;var shots:=0;var jump_seen:=false;var landing_seen:=false
 var times:Array[float]=[];var last:=Time.get_ticks_usec()
 for frame in 9*fps:
  var t:=float(frame)/fps
  actor.requested_direction=Vector2.ZERO;actor.requested_run=false;actor.requested_jump=false
  if t>=1. and t<3.:actor.requested_direction=Vector2(1,0)
  if t>=3. and t<5.:actor.requested_direction=Vector2(-1,-.3).normalized();actor.requested_run=true
  if t>=5. and t<6.:actor.requested_direction=Vector2(.6,-1).normalized()
  actor.requested_jump=frame==int(5.1*fps)
  if frame==int(6.2*fps):scene._fire_key_held=true;scene._sync_rifle_controls()
  if frame==int(8.1*fps):scene._fire_key_held=false;scene._sync_rifle_controls()
  # Follow from rear3Q to see both loose tails, then front3Q to read Aim/fire face.
  scene.azimuth=visual.rotation.y+2.4 if t<6.2 else visual.rotation.y-.6
  await physics_frame;await process_frame;await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();times.append((now-last)/1000.);last=now
  max_hair=maxf(max_hair,appearance.hair_spring.value.length());max_tail=maxf(max_tail,appearance.tail_spring.value.length())
  var blink:bool=appearance.channels.blink_auto>.5
  if blink and not was_blink:blinks+=1
  was_blink=blink
  jump_seen=jump_seen or appearance.face_state.ages[4]<.38
  landing_seen=landing_seen or appearance.face_state.ages[8]<.33
  if frame in [int(.6*fps),int(2.4*fps),int(4.2*fps),int(5.5*fps),int(7.3*fps),int(8.8*fps)]:root.get_texture().get_image().save_png(out+"/view_"+str(frame)+".png")
 times.sort()
 var report:={"fps_cap":fps,"frames":9*fps,"frame_median_ms":times[times.size()/2],"frame_p95_ms":times[int(times.size()*.95)],"secondary_strength":appearance.SECONDARY_STRENGTH,"hair_peak_rad":max_hair,"tail_peak_rad":max_tail,"blinks":blinks,"shots":scene.rifle_fire.shots_fired,"jump_face_seen":jump_seen,"landing_face_seen":landing_seen,"pool_misses":scene.rifle_fire.pool_misses}
 FileAccess.open(out+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("NATIVE_SOLDIER ",JSON.stringify(report));scene.free();quit()
