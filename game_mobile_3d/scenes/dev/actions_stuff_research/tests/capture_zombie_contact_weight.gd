extends SceneTree
func _initialize():call_deferred("run")
func run():
 var stage:=OS.get_cmdline_user_args()[0]
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene);current_scene=scene
 scene.player.scripted_input=true;scene.camera_size=5.1
 for z in scene.zombie_combat.zombies:z.position.z=absf(z.position.z)
 var physics:Dictionary={};var max_corpses:=0;var saw_attack:=false;var captures:Dictionary={}
 for i in 360:
  if i==125:
   var e:=InputEventKey.new();e.keycode=KEY_E;e.physical_keycode=KEY_E;e.pressed=true;scene._unhandled_input(e)
  if i==310:
   var e:=InputEventKey.new();e.keycode=KEY_E;e.physical_keycode=KEY_E;e.pressed=false;scene._input(e)
  await physics_frame;await process_frame;await RenderingServer.frame_post_draw
  max_corpses=maxi(max_corpses,scene.zombie_combat.active_ragdolls())
  for z in scene.zombie_combat.zombies:
   saw_attack=saw_attack or z.visual.attack_count>0
   if not z.is_dead and i<125 and z.visual.attack_time>=.17 and z.visual.attack_time<=.23 and not captures.has(z.name):
    root.get_texture().get_image().save_png(stage+"/contact_"+z.name+".png");captures[z.name]=true
   if z.is_dead:
    var age:float=z.corpse_age
    for bucket in [.1,.35,.55,.9]:
     var key:String=z.name+"_"+str(bucket)
     if age>=bucket and not physics.has(key):
      physics[key]={"age":age,"chest":str(z.ragdoll.bodies.Chest.position)}
      if z.name=="ResearchZombie_1":root.get_texture().get_image().save_png(stage+"/death_"+str(bucket)+".png")
  if i==110:root.get_texture().get_image().save_png(stage+"/group_contact.png")
 var report:={"passed":saw_attack and captures.size()>=2 and scene.zombie_combat.kills>=3 and scene.rifle_fire.point_blank_hits>0 and scene.rifle_fire.pool_misses==0 and max_corpses<=4,"source_attacks_seen":saw_attack,"contact_window_zombies":captures.keys(),"kills":scene.zombie_combat.kills,"shots":scene.rifle_fire.shots_fired,"point_blank_hits":scene.rifle_fire.point_blank_hits,"maximum_corpses":max_corpses,"pool_misses":scene.rifle_fire.pool_misses,"corpse_samples":physics}
 FileAccess.open(stage+"/native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("NATIVE_ZOMBIE_CONTACT_WEIGHT ",JSON.stringify(report));quit(0 if report.passed else 1)
