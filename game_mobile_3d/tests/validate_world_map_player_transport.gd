extends SceneTree
var failures:Array=[]
var checks=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
 if not ResourceLoader.exists("res://scripts/world_map_actor_irradiance.gd"):
  check(false,"Original actor field sampler is implemented");print("PLAYER_TRANSPORT ",failures);quit(1);return
 var s=load("res://scripts/world_map_actor_irradiance.gd").new()
 var r=Resource.new();r.set_meta("origin",[0.,0.,0.]);r.set_meta("step",[1.,1.,1.]);r.set_meta("dimensions",[2,2,2])
 var sky=PackedFloat32Array();var sun=PackedFloat32Array();var valid=PackedByteArray()
 for x in 2:
  for y in 2:
   for z in 2:
    valid.append(1)
    for direction in 6:sky.append_array([float(x),float(y),float(z)]);sun.append_array([0.,0.,0.])
 r.set_meta("sky",sky);r.set_meta("sun",sun);r.set_meta("valid",valid)
 check(s.initialize(r),"Finite complete lattice accepted")
 var q=s.sample(Vector3(.2,.3,.4))
 check(q.valid and q.sky[0].distance_to(Vector3(.2,.3,.4))<.00001,"Trilinear RGB is exact on linear field")
 check(not s.sample(Vector3(-.01,0,0)).valid,"Out of volume restores former ambient")
 valid.fill(0);r.set_meta("valid",valid);check(s.initialize(r),"Solid flags valid schema")
 check(not s.sample(Vector3(.5,.5,.5)).valid,"No empty corners never emit invented light")
 r.set_meta("sky",PackedFloat32Array([NAN]));check(not s.initialize(r),"Malformed cache rejected")
 r.set_meta("sky",[0]);check(not s.initialize(r),"Wrong array type rejected without engine error")
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w);await create_timer(.7).timeout
 var native=RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null
 if native:
  check(w.get("player_light")!=null,"Main WorldMap owns actor field")
  if w.get("player_light")!=null:
   w.player_light.refresh(true)
   check(w.player_light.is_active(),"Validated Day field active at startup")
   var energy=w.player_light.cache.get_meta("ambient_energy")
   w.player_light.cache.set_meta("ambient_energy",0.);w.player_light.refresh(true)
   check(not w.player_light.is_active(),"Mismatched normalization falls back before dividing")
   w.player_light.cache.set_meta("ambient_energy",energy);w.player_light.refresh(true)
   check(w.player_light.is_active(),"Valid normalization resumes")
   var materials:Array=w.look._direct_actor_materials.filter(func(m):return m!=null)
   check(materials.size()==3,"Only supported body, face and Sabre materials are adapted")
   for m in materials:check(m.get_shader_parameter("player_local_light"),"All three surfaces receive source-independent spatial field")
   var count=0
   for m in materials:
    if m.get_meta("verified_valorie",false):
     check(m.get_shader_parameter("skin_profile_mask")!=null,"Source mask restored externally")
     check(m.get_shader_parameter("skin_wrap_enabled"),"Original selective skin response enabled")
     count+=1
    else:check(not m.get_shader_parameter("skin_wrap_enabled"),"Sabre never gets skin response")
   check(count==2,"Only Valorie face/body verified")
   for key in ["player_local_light_enabled","player_reflection_enabled","player_skin_enabled"]:
    var button=w.showcase.panel.find_child(key,true,false)
    check(button!=null,"Comparison control exists: "+key)
    if button!=null:
     button.button_pressed=false;check(not w.look.get(key),"UI toggles correct independent flag: "+key)
     button.button_pressed=true;check(w.look.get(key),"UI restores correct flag: "+key)
   w.look.player_local_light_enabled=false;w.player_light.refresh(true)
   for m in materials:check(not m.get_shader_parameter("player_local_light"),"Diffuse can be disabled independently")
   w.look.player_local_light_enabled=true;w.look.set_player_material_review("neutral");w.player_light.refresh(true)
   for m in materials:check(not m.get_shader_parameter("player_local_light"),"Old neutral comparison is unchanged")
   w.look.set_player_material_review("combined");w.showcase.set_hour(22.);w.player_light.refresh(true)
   check(w.player_light.is_active(),"Night uses original phase-aware sky transport")
   check(w.player_light.has_method("set_phase_sky"),"Independent all-phase sky control exists")
   if w.player_light.has_method("set_phase_sky"):
    for time in [7.,11.999,12.001,16.5,18.5,22.]:
     w.showcase.set_hour(time);w.player_light.refresh(true)
     check(w.player_light.is_active(),"Spatial sky remains active at "+str(time))
     for m in materials:
      check(not m.get_shader_parameter("skin_wrap_enabled"),"Day-only mask stays suspended at "+str(time))
      check(not m.get_shader_parameter("recovered_self_light"),"Captured self-light not invented at "+str(time))
     if time in [7.,16.5,18.5,22.]:
      for m in materials:check(m.get_shader_parameter("player_probe_key")==Vector3.ZERO,"No stale Day bounce at "+str(time))
    w.player_light.set_phase_sky(false)
    check(not w.player_light.is_active(),"OFF restores old Night ambient path")
    w.player_light.set_phase_sky(true)
    check(w.player_light.is_active(),"ON restores phase sky")
    w.showcase.compare_baseline();w.player_light.refresh(true)
    check(not w.player_light.is_active(),"Baseline suspends phase sky")
    w.showcase.compare_baseline();w.player_light.refresh(true)
    check(w.player_light.is_active(),"Combined resumes selected phase sky")
    w.look.set_player_material_review("neutral");w.player_light.refresh(true)
    check(not w.player_light.is_active(),"Night neutral keeps original comparison")
    w.look.set_player_material_review("combined");w.player_light.refresh(true)
    check(w.player_light.is_active(),"Night Combined resumes")
   w.showcase.set_hour(12.);w.player_light.refresh(true);check(w.player_light.is_active(),"Day resumes")
 check(w.player.run_speed==7.,"Verified speed unchanged")
 check(AudioServer.is_bus_mute(0),"Test audio remains muted")
 w.free();await process_frame;print("PLAYER_TRANSPORT checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty()else 1)
