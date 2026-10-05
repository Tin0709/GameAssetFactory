extends Control
## Development-only selection UI. Simulation keeps its inherited pausable mode.
const NAMES = ["Pistol", "M4A1", "Shotgun"]
const DESCRIPTIONS = ["Fast, compact, two-hand stance", "Automatic rifle, controlled recoil", "Heavy close-range weapon, strong recoil"]
var coordinator: Node
var buttons: Array[Button] = []
var grid: GridContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.02, 0.04, 0.06, 0.95)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 20)
	margin.add_child(stack)
	for text in ["WEAPON TEST SELECT", "Gameplay paused • Choose a weapon to start / resume", "Development test • Click / tap a card or press 1 / 2 / 3"]:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 28 if text == "WEAPON TEST SELECT" else 18)
		stack.add_child(label)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	stack.add_child(grid)
	for i in 3:
		var button := Button.new()
		button.text = "[%d]  %s\n\n%s" % [i + 1, NAMES[i].to_upper(), DESCRIPTIONS[i]]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose.bind(i))
		grid.add_child(button)
		buttons.append(button)
	resized.connect(_update_layout)
	_update_layout()
	hide()

func _update_layout() -> void:
	if grid == null: return
	var narrow := size.x < 850
	grid.columns = 1 if narrow else 3
	for button in buttons:
		button.custom_minimum_size = Vector2(0, 112 if narrow else 220)
		button.add_theme_font_size_override("font_size", 18 if narrow else 22)

func open() -> void:
	show()
	buttons[coordinator.player.visual.weapon_type].grab_focus()

func _choose(index: int) -> void:
	coordinator.select_test_weapon(index)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(coordinator) or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if visible and key in [KEY_1, KEY_2, KEY_3]:
		get_viewport().set_input_as_handled()
		_choose(key - KEY_1)
	elif visible and key == KEY_R:
		get_viewport().set_input_as_handled()
		coordinator.reset_run()
	elif key == KEY_F2 and OS.is_debug_build():
		get_viewport().set_input_as_handled()
		coordinator.open_weapon_selector()
