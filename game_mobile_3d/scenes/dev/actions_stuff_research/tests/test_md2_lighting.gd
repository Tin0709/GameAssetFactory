extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func _initialize():call_deferred("run")
func run():
 var path:="res://scenes/dev/actions_stuff_research/lighting_md2_v001/lighting.gd"
 check(ResourceLoader.exists(path),"Existing lab exposes the requested original modular lighting controller")
 if failures.is_empty():
  var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(lab)
  var light=lab.md2_lighting
  check(light!=null,"Existing scene opts into lighting without another gameplay scene")
  var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_RIGHT;down.pressed=true
  var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_RIGHT;up.pressed=false
  lab._unhandled_input(down);lab._input(up)
  check(not lab.orbiting and not lab._right_aim_held,"Mouse release over GUI cannot leave aim/orbit stuck")
  lab._unhandled_input(up)
  var sun:DirectionalLight3D=light.sun;var original:Environment=light.original_environment
  var palette=light.palette
  var midnight:Dictionary=palette.sample(0.);var wrapped:Dictionary=palette.sample(24.)
  check(midnight.ambient==wrapped.ambient and midnight.energy==wrapped.energy,"Midnight palette wraps without a seam")
  check(palette.sample(-2.).ambient==palette.sample(22.).ambient,"Negative slider/capture time wraps consistently")
  var noon:Dictionary=palette.sample(12.);var night:Dictionary=palette.sample(22.)
  check(noon.energy>night.energy and night.ambient_energy>.12,"Night is distinct but retains readable ambient fill")
  for fps in [30,60]:
   light.set_time(7.,true);light.set_time(22.)
   for f in fps:light.advance(1./fps)
   if fps==30:midnight={"time":light.current_hour}
   else:check(absf(light.current_hour-midnight.time)<.0001,"30/60FPSpreset transitions have matching timing")
  for q in 3:
   light.set_quality(q)
   check(lab.get_viewport().scaling_3d_scale<=1. and lab.get_viewport().scaling_3d_scale>=.7,"All quality scales remain within mobile budgets")
  light.set_time(16.5,true);light.set_original(true)
  check(light.world.environment==original,"Original restores exact Environment resource")
  check(sun.rotation_degrees.distance_to(Vector3(-55,-35,0))<.0001 and is_equal_approx(sun.light_energy,1.3),"Original restores exact key direction/energy")
  check(lab.grass_field.materials[0].get_shader_parameter("lighting_grade")==0.,"Original restores approved foliage fragment shading")
  check(lab.player.walk_speed==2.7 and absf(lab.player.run_speed-7.5465)<.00001,"Lighting does not change travel speeds")
  var clock:float=lab.grass_field.clock;var count:int=lab.grass_field.instance_count
  light.set_original(false);light.set_time(22.,true)
  check(lab.grass_field.clock==clock and lab.grass_field.instance_count==count,"Lighting switching leaves wind clock/population untouched")
  check(not light.environment.volumetric_fog_enabled and not light.environment.ssao_enabled and not light.environment.ssr_enabled,"Mobile preview does not request unsupported effects")
  light.release()
  check(light.world.environment==original,"Removing lighting leaves exact recoverable baseline")
  light.set_quality(0);light.set_original(false);light.set_time(7.,true)
  check(light.world.environment==original and is_equal_approx(lab.get_viewport().scaling_3d_scale,light.original_view.scale) and is_equal_approx(sun.light_energy,1.3),"Released controls cannot mutate the restored lighting or viewport")
  check(not light.ui.visible,"Release retires the preview controls")
  lab.free()
  var second=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(second)
  var owner=second.md2_lighting;owner.set_quality(0)
  var old_scale:float=owner.original_view.scale
  owner.world.free();owner.release()
  check(is_equal_approx(second.get_viewport().scaling_3d_scale,old_scale),"Removal restores viewport even if borrowed environment was removed first")
  second.free()
 print("MD2_LIGHTING_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
