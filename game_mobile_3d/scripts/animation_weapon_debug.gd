extends Node
## Temporary desktop adapter; inventory can later call equip_weapon directly.
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or get_tree().paused: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F6 and get_parent().visual.has_method("set_locomotion_mode"):
			var visual: Node3D = get_parent().visual
			visual.set_locomotion_mode(1-visual.locomotion_mode)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_V and "ready_animation_mode" in get_parent().visual:
			var visual: Node3D = get_parent().visual
			visual.ready_animation_mode = 1 - visual.ready_animation_mode
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_0:
			get_parent().visual.set_weapon_equipped(false)
			get_viewport().set_input_as_handled()
			return
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index <= 2:
			get_parent().equip_test_weapon(index)
			get_viewport().set_input_as_handled()
