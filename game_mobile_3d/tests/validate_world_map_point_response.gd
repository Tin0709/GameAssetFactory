extends SceneTree
var checks:=0
var failures=[]
func check(value,label):
 checks+=1
 if not value:failures.append(label)
func _initialize():call_deferred("run")
func settle():
 for i in 40:await process_frame
func run():
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
 await settle()
 check(w.showcase.has_method("set_noninverse_player_light"),"Main exposes reversible recovered non-inverse mode")
 if not w.showcase.has_method("set_noninverse_player_light"):
  print("POINT_RESPONSE checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(1);return
 check(w.showcase.noninverse_player_light,"Supported recovered mode defaults ON")
 var native=RenderingServer.get_current_rendering_method()=="mobile"and RenderingServer.get_rendering_device()!=null
 if native:
  w.showcase.set_hour(22.);await settle()
  var light=w.showcase._player_light;var energy=light.light_energy;var color=light.light_color
  check(light.visible and light.omni_range==8.,"Existing8m player point light active")
  check(light.omni_attenuation==0.,"Native noninverse flag removes Godot inverse-square factor")
  w.showcase.set_noninverse_player_light(false);await settle()
  check(light.omni_attenuation==2.,"OFF restores previous exponent")
  check(light.light_energy==energy and light.light_color==color,"No new energy/color retune")
  w.showcase.set_noninverse_player_light(true);await settle()
  check(light.omni_attenuation==0.,"ON restores noninverse mode")
  w.showcase.set_hour(12.);await settle();check(not light.visible,"Noon approved player light remains hidden")
 check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Gameplay/audio unchanged")
 print("POINT_RESPONSE checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(0 if failures.is_empty()else 1)
