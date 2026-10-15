extends SceneTree
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists("res://scenes/dev/actions_stuff_research/source_idle_controller.gd"),"Approved Idle controller is missing")
	check(ResourceLoader.exists("res://scenes/dev/actions_stuff_research/source_idle_sampler.gd"),"Approved Idle composite sampler is missing")
	print("IDLE_SOURCE_TEST ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
