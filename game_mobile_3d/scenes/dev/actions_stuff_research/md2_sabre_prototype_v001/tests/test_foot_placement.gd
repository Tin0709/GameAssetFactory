extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
 check(FileAccess.file_exists("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/foot_placement.gd"),"Rigid foot-ground helper is available")
 if not failures.is_empty():print("SABRE_FOOT_PLACEMENT ",JSON.stringify({"checks":checks,"failures":failures}));quit(1);return
 quit()
