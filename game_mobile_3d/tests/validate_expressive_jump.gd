extends SceneTree
var checks: Array=[]
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var path:="res://scenes/dev/ExpressiveJumpPlayer.tscn"
	check(ResourceLoader.exists(path),"Separate expressive Jump V2 test actor exists")
	if not ResourceLoader.exists(path):quit(1);return
	var scene=load("res://scenes/dev/ExpressiveLocomotionTest.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	await scene.run_jump_validation(self)
	check(not scene.jump_measurements.is_empty(),"Validation reaches final metrics instead of aborting on a script error")
	var out:="res://.validation/expressive_jump_v1";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/runtime_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":scene.jump_measurements,"engine":Engine.get_version_info(),"render_fps":Engine.max_fps},"\t"))
	print("EXPRESSIVE_JUMP_CHECKS ",checks.size()," failures ",failures.size())
	quit(0 if failures.is_empty() else 1)
