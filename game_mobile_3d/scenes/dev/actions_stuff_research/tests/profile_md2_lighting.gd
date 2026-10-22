extends SceneTree
## No screenshots/readbacks inside measurement windows. Exact existing scene.
var lab:Node3D
var viewport:SubViewport
var out:String
func _initialize():call_deferred("run")
func draw()->void:
 await process_frame
 RenderingServer.force_draw(false)
func summarize(rows:Array)->Dictionary:
 var result:={}
 for key in rows[0]:
  var values:Array=[]
  for row:Dictionary in rows:values.append(float(row[key]))
  values.sort();result[key]={"median":values[values.size()/2],"p95":values[int(values.size()*.95)],"max":values[-1]}
 return result
func run():
 var args:=OS.get_cmdline_user_args();out=args[0];Engine.max_fps=60
 viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();viewport.add_child(lab);current_scene=viewport
 lab.player.scripted_input=true
 var lighting=lab.md2_lighting;lighting.ui.body.visible=false;lighting.set_time(12.,true)
 var report:={"renderer":RenderingServer.get_current_rendering_method(),"godot":Engine.get_version_info().string,"os":OS.get_name(),"viewport":"1280x720","frame_cap":60,"phone_tested":false,"tiers":[],"frozen_probes":[]}
 for q in 3:
  lighting.set_quality(q);lab.reset_player();lab._fire_key_held=true;lab._sync_rifle_controls()
  for i in 45:await draw()
  var rows:Array=[];var previous:=Time.get_ticks_usec();var corpses:=0;var active:=0;var maximum_speed:=0.;var shots_before:int=lab.rifle_fire.shots_fired
  for f in 300:
   var t:=float(f)/60.
   lab.player.requested_direction=Vector2(cos(t*2.),sin(t*2.))
   lab.player.requested_run=f>=120 and f<180;lab.player.requested_jump=f==190
   if f==150:lab.reset_player();lab._fire_key_held=true;lab._sync_rifle_controls()
   await draw()
   var now:=Time.get_ticks_usec();var m:Dictionary=lighting.metrics.sample().duplicate();m["frame_ms"]=(now-previous)/1000.;previous=now
   rows.append(m);corpses=maxi(corpses,lab.zombie_combat.active_ragdolls());active=maxi(active,lab.grass_field.interaction.active.size());maximum_speed=maxf(maximum_speed,lab.player.current_speed)
  report.tiers.append({"quality":lighting.TIERS[q],"samples":rows.size(),"statistics":summarize(rows),"peak_corpses":corpses,"peak_active_grass_cells":active,"peak_travel_speed":maximum_speed,"final_shots":lab.rifle_fire.shots_fired,"warmup_shots":shots_before,"pool_misses":lab.rifle_fire.pool_misses})
 # Controlled identical-pose feature probes. GPU zero is unavailable, never free.
 paused=true;lab._fire_key_held=false;lighting.set_quality(1);lighting.set_time(12.,true);lighting.ui.visible=false
 for variant in ["full","shadows_off","glow_off"]:
  lighting.sun.shadow_enabled=variant!="shadows_off";lighting.environment.glow_enabled=variant!="glow_off"
  for i in 12:await draw()
  var rows:Array=[];var previous:=Time.get_ticks_usec()
  for i in 75:
   await draw()
   var now:=Time.get_ticks_usec();var m:Dictionary=lighting.metrics.sample().duplicate();m["frame_ms"]=(now-previous)/1000.;previous=now;rows.append(m)
  report.frozen_probes.append({"variant":variant,"samples":rows.size(),"statistics":summarize(rows)})
 report["gpu_time_available"]=report.tiers[1].statistics.gpu_ms.max>0.
 report["shadow_counters_available"]=report.tiers[1].statistics.shadow_draws.max>0.
 report["notes"]="Render CPU excludes scripts. Process/physics are engine monitors. Frame pace includes60FPSlimit. No readbacks in samples. ZeroGPU or shadowcounter is N/A on this backend; per-passGPUcost unavailable. Controlled probes are whole-frame comparisons, not isolatedGPUtimings."
 FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("MD2_LIGHTING_PROFILE ",JSON.stringify(report))
 paused=false;lab.free();viewport.free()
 for i in 4:await process_frame
 quit()
