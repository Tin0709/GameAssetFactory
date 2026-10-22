extends SceneTree
## Actual lab regression: flat pooled bullets, stronger deaths and contact arrest.
var failures:Array[String]=[]
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func ticks(count:int)->void:
 for i in count:await physics_frame
 await process_frame
func finish(lab:Node)->void:
 lab.free()
 print("COMBAT_FEEL_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
func run():
 var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(lab)
 lab.player.scripted_input=true
 var fire=lab.rifle_fire
 check(lab.get("grass_vegetation_enabled")==false,"Vegetation is temporarily disabled in the saved lab")
 var hidden:=true
 for child in lab.grass_field.get_children():
  if child.name.begins_with("GrassRegion_"):hidden=hidden and not child.visible
 check(hidden and not lab.grass_field.is_processing() and not lab.grass_field.is_physics_processing(),"Grass draw and interaction work are paused, with source retained")
 check(lab.grass_field.get_node("ThirtyByThirtyBlocks").visible and lab.grass_field.instance_count==1317,"Ground remains visible and all grass data is retained")
 check(fire.get("level_trajectory")==true,"Current lab levels the projectile trajectory")
 check(fire.get("projectile_speed_multiplier")==1.5,"Current lab bullets travel 50 percent faster")
 check(fire.get("projectile_range_multiplier")==3.,"Current lab range extends to 45 metres")
 var zombie=lab.zombie_combat.zombies[0]
 check(zombie.corpse_lifetime==2.5,"Corpse lifetime is 2.5 seconds")
 check(zombie.combat_rifle.linear_impulse==480. and zombie.combat_rifle.upward_impulse==96.,"One doubled impulse gives doubled launch speed without a second multiplier")
 if not failures.is_empty():finish(lab);return
 finish(lab)
