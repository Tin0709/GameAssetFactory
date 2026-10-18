extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "res://scenes/dev/ZombieDeathPhysicsLab.tscn"
	if not ResourceLoader.exists(path):
		push_error("FAIL: approved lab scene is missing")
		quit(1)
		return
	var lab = load(path).instantiate()
	root.add_child(lab)
	await physics_frame
	assert(lab.actor != null)
	assert(lab.actor.ragdoll.bodies.size() == 7)
	print("LAB_SMOKE_PASS")
	quit()
