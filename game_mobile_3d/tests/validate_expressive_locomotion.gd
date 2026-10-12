extends SceneTree
var checks: Array = []
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok: failures.append(message);push_error(message)
func run() -> void:
	var path := "res://scenes/dev/ExpressiveLocomotionTest.tscn"
	check(ResourceLoader.exists(path),"Isolated playable expressive locomotion scene exists")
	if not ResourceLoader.exists(path): quit(1);return
	var scene = load(path).instantiate()
	root.add_child(scene);current_scene=scene
	await physics_frame
	await process_frame
	var actor = scene.actor
	check(actor.visual.expressive_clips.size()==3,"Exactly three approved expressive clips loaded")
	check(not actor.has_method("request_jump"),"No jump controller integrated")
	check(actor.walk_speed==.9 and actor.run_speed==2.31,"Controller speeds match approved gait distances")
	await scene.run_validation(self)
	var out := "res://.validation/expressive_locomotion_v1"
	DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/runtime_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":scene.measurements,"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	print("EXPRESSIVE_LOCOMOTION_CHECKS ",checks.size()," failures ",failures.size())
	quit(0 if failures.is_empty() else 1)
