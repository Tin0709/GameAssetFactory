extends SceneTree
const OUT="/Users/tin/Desktop/Game Dev/GameAssetFactory/.validation/horde_120fps_v001/"
var lab:Node3D
var view:SubViewport
var moving:=false
var running:=false
var held:=false
var origin_time:=0
func _initialize():call_deferred("run")
func draw(n:int=1):
 for i in n:await process_frame;RenderingServer.force_draw(false)
func percentile(a:Array,p:float)->float:
 a.sort();return float(a[mini(a.size()-1,int(a.size()*p))])
func sample(label:String,seconds:float)->Dictionary:
 var frames:Array=[];var physics:Array=[];var start:=Time.get_ticks_usec();var previous:=start
 var window_start:=start;var window_frames:=0;var windows:Array=[]
 var shots:int=lab.rifle_fire.shots_fired;var hits:int=lab.rifle_fire.hit_count;var distance:=0.;var last:Vector3=lab.player.position;var strafing:=0;var rays:=0;var count:=0;var minimum_alive:=100
 while (Time.get_ticks_usec()-start)/1000000.<seconds:
  var t:float=(Time.get_ticks_usec()-origin_time)/1000000.
  lab.player.requested_direction=Vector2(sin(t*.9),cos(t*.9)) if moving else Vector2.ZERO
  lab.player.requested_run=running
  # Equivalent to physically held E even when focus is elsewhere during automation.
  lab._fire_key_held=held;lab._sync_rifle_controls()
  await process_frame
  var now:=Time.get_ticks_usec();frames.append((now-previous)/1000.);previous=now
  physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
  distance+=lab.player.position.distance_to(last);last=lab.player.position
  if lab.player.visual.rifle_strafe_weight>.99:strafing+=1
  minimum_alive=mini(minimum_alive,lab.zombie_combat.living_count())
  if lab.rifle_auto_aim.get("last_ray_count")!=null:rays+=lab.rifle_auto_aim.last_ray_count;count+=1
  window_frames+=1
  if now-window_start>=1000000:
   windows.append(window_frames*1000000./(now-window_start));window_frames=0;window_start=now
 var elapsed:float=(Time.get_ticks_usec()-start)/1000000.
 var result:={"phase":label,"seconds":elapsed,"average_fps":frames.size()/elapsed,"fps_windows":windows,"frame_p95_ms":percentile(frames,.95),"physics_p95_ms":percentile(physics,.95),"alive":lab.zombie_combat.living_count(),"minimum_alive":minimum_alive,"shots":lab.rifle_fire.shots_fired-shots,"hits":lab.rifle_fire.hit_count-hits,"travel_m":distance,"strafe_fraction":float(strafing)/frames.size(),"mean_LOS_rays":float(rays)/maxi(1,count),"ragdolls":lab.zombie_combat.active_ragdolls(),"pool_misses":lab.rifle_fire.pool_misses}
 print("HORDE_120 ",JSON.stringify(result));return result
func run():
 Engine.physics_ticks_per_second=60;Engine.max_fps=120;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 view=SubViewport.new();view.size=Vector2i(3004,1805);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();view.add_child(lab);current_scene=view
 var uploads:Array[Callable]=[Callable(lab.presentation,"_upload"),Callable(lab.soldier_appearance,"_upload")]
 for cb in uploads:
  if RenderingServer.frame_pre_draw.is_connected(cb):RenderingServer.frame_pre_draw.disconnect(cb)
 await draw(3)
 for cb in uploads:RenderingServer.frame_pre_draw.connect(cb)
 lab.player.scripted_input=true;lab.zombie_combat.spawn_batch(0);lab.performance_controls.select_count(50);lab.performance_controls.spawn_button.pressed.emit();lab.performance_controls.spawn_button.pressed.emit()
 for z in lab.zombie_combat.zombies:z.current_hp=1000000;z.max_hp=1000000
 origin_time=Time.get_ticks_usec();await sample("warmup",5.)
 var rows:Array=[]
 held=true;rows.append(await sample("stand_fire100",3.))
 moving=true;rows.append(await sample("walk_fire100",6.))
 running=true;rows.append(await sample("run_fire100",12.))
 moving=false;running=false;held=false;rows.append(await sample("release100",2.))
 for z in lab.zombie_combat.zombies:z.current_hp=60;z.max_hp=60
 moving=true;running=true;held=true;rows.append(await sample("run_fire_normal_hp",8.))
 var label:=OS.get_environment("HORDE_RESULT")
 if label.is_empty():label="final"
 var report:={"rows":rows,"viewport":"3004x1805","render_cap":120,"renderer":"mobile/Metal","physics_hz":60,"grass":lab.grass_field.instance_count,"map_blocks":lab.grass_field.side_length,"fixed_fps":false,"note":"Normal render loop. No forced draws/readbacks in measured windows. Stress HP only keeps100alive; normalHP phase separately exercises lethal corpses. DesktopM2Pro only."}
 FileAccess.open(OUT+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 if label=="final":view.get_texture().get_image().save_png(OUT+"final.png")
 var ok:bool=rows[2].average_fps>=110. and rows[2].minimum_alive==100 and rows[2].travel_m>60. and rows[2].shots>=48 and rows[2].hits>=40 and rows[2].strafe_fraction>.99 and rows[3].shots==0 and rows[4].alive<100 and lab.rifle_fire.pool_misses==0
 for fps in rows[2].fps_windows:ok=ok and fps>=110.
 print("HORDE_120_TARGET ",ok)
 lab.free();view.free();await draw(3);quit(0 if ok else 1)
