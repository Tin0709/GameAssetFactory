extends SceneTree
## Interactive D0 foundation review, using the actual gameplay controller.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false
	level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	# Existing K/J debug spawning can introduce threats; no automatic review death.
