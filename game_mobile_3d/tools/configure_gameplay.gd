extends SceneTree
## One-time configuration helper; preserves all existing project settings.

func _initialize() -> void:
	var config := ConfigFile.new()
	assert(config.load("res://project.godot") == OK)
	var bindings := {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W,
		"move_backward": KEY_S, "sprint": KEY_SHIFT, "reset_test": KEY_R}
	for action in bindings:
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		config.set_value("input", action, {"deadzone": 0.2, "events": [event]})
	config.set_value("application", "run/main_scene", "res://scenes/CuboidGameplayTest.tscn")
	assert(config.save("res://project.godot") == OK)
	quit()
