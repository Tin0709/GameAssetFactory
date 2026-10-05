extends Node
## Temporary desktop adapter; inventory can later call equip_weapon directly.
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or get_tree().paused: return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index <= 2:
			get_parent().visual.equip_weapon(index)
			get_viewport().set_input_as_handled()
