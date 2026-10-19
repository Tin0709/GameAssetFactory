extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
 if not ok and not failures.has(label):failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
 var v=scene.player.visual
 check(v.has_method("set_rifle_aim"),"Existing rifle controller supports hold/release of the approved Aim")
 if not failures.is_empty():scene.free();quit(1);return
 # Integration checks are added below after this first missing-behavior guard.
 scene.free();quit(0)
