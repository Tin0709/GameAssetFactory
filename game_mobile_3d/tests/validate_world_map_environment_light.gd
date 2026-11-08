extends SceneTree
var failures=[]
var checks=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
 if not ResourceLoader.exists("res://scripts/world_map_air_light.gd"):
  check(false,"Source linear scatter and original shadow-light adapter exist");print("ENVIRONMENT_LIGHT ",failures);quit(1);return
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w);await create_timer(.7).timeout
 var native=RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_rendering_device()!=null
 var air=w.showcase.air_light
 if native:
  check(air.source_ready,"Private scatter profile is hash-verified")
  check(air.shadow_available(),"Original sun visibility matches live map/recipe/sun")
  check(w.look.terrain_dielectric_response,"Terrain response defaults ON")
  w.showcase.set_hour(12.)
  check(air.day_weight(12.)==1. and air.day_weight(22.)==0.,"Only Day source color transferred; Night stays preceding color")
  var old=Vector3(.1,.2,.3);var value=air.scatter_color(old,12.)
  check(absf(value.dot(Vector3(.2126,.7152,.0722))-old.dot(Vector3(.2126,.7152,.0722)))<.00001,"Scatter chromaticity preserves existing luminance")
  air.source_ready=false;check(air.scatter_color(old,12.)==old,"Missing private source preserves previous color");air.source_ready=true
  for i in 8:await process_frame
  var texture=air.field().texture;var rebuilds=w.showcase.mist.effect.snapshot().rebuilds
  w.showcase.shadowed_scatter=false
  for i in 8:await process_frame
  check(not w.showcase.air_field().valid and w.showcase.air_field().texture==texture,"Shadow OFF keeps texture identity and neutralizes only lighting")
  check(w.showcase.mist.effect.snapshot().rebuilds==rebuilds,"Shadow toggle does not reallocate the shared medium")
  w.showcase.shadowed_scatter=true
  for i in 8:await process_frame
  check(w.showcase.mist.effect.snapshot().rebuilds==rebuilds,"Shadow restore retains medium allocation")
  for row in w.look.terrain_materials:
   var m=row[3];check(m.get_shader_parameter("terrain_dielectric_response"),"Canonical terrain uses separate dielectric fit")
   check(m.get_shader_parameter("native_specular")==row[2].metallic_specular,"Original material specular metadata retained")
   var c=w.geometry._make_cutaway_material(m)
   check(c.get_shader_parameter("terrain_rough_reflection")==m.get_shader_parameter("terrain_rough_reflection"),"Late cutaway inherits reflection state")
  w.look.set_terrain_dielectric_response(false)
  for row in w.look.terrain_materials:check(not row[3].get_shader_parameter("terrain_dielectric_response"),"Previous terrain treatment restores")
  w.look.set_terrain_dielectric_response(true)
  w.showcase.set_hour(22.);check(not air.shadow_available(),"Changed sun rejects stale Day shadow field")
  w.showcase.set_hour(12.);check(air.shadow_available(),"Day source direction resumes")
 check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Gameplay speed and mute retained")
 w.free();await process_frame;print("ENVIRONMENT_LIGHT checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty()else 1)
