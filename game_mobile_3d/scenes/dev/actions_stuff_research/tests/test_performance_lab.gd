extends SceneTree
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->void:
 if not ok:failures.append(message);push_error(message)
func run():
 var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(lab)
 check(lab.zombie_combat.living_count()==20,"Performance lab starts with exactly 20 living zombies")
 check(lab.zombie_combat.has_method("spawn_batch"),"Performance lab supports an exact adjustable batch")
 lab.free()
 print("PERFORMANCE_LAB_CHECKS ",JSON.stringify({"failures":failures}));quit(0 if failures.is_empty() else 1)
