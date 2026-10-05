extends Control
## Three reused buttons; only this UI and its coordinator run during pause.
const CATALOG = preload("res://scripts/upgrade_catalog.gd")
var progression: Node
var buttons: Array[Button] = []
@onready var grid: GridContainer = $Margin/Stack/Cards

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(3):
		var button := Button.new()
		button.name = "Choice" + str(i + 1)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_choose.bind(i))
		grid.add_child(button)
		buttons.append(button)
	resized.connect(_update_layout)
	_update_layout()
	hide()

func _update_layout() -> void:
	if not is_instance_valid(grid): return
	var narrow := size.x < 850.0
	grid.columns = 1 if narrow else 3
	for button in buttons:
		button.custom_minimum_size = Vector2(0, 132 if narrow else 244)
		button.add_theme_font_size_override("font_size", 18 if narrow else 20)

func show_choices(choices: Array[Dictionary], earned_level: int, pending: int) -> void:
	$Margin/Stack/Title.text = "LEVEL %d — CHOOSE AN UPGRADE" % earned_level
	$Margin/Stack/Subtitle.text = "Gameplay paused  •  Tap a card or press 1 / 2 / 3" + ("\n%d selections remaining" % pending if pending > 1 else "")
	for i in range(3):
		buttons[i].text = "[%d]  %s\n\n%s" % [i + 1, choices[i].name, CATALOG.card_text(choices[i], progression.player, progression.pistol)]
		buttons[i].disabled = false
		buttons[i].modulate = Color.WHITE
	show()
	buttons[0].grab_focus()

func react_to_selection(index: int) -> void:
	for button in buttons: button.disabled = true
	buttons[index].modulate = Color(0.3, 1.0, 1.0)

func _choose(index: int) -> void:
	if is_instance_valid(progression): progression.select_upgrade(index)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(progression) or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if visible and key in [KEY_1, KEY_2, KEY_3]:
		progression.select_upgrade(key - KEY_1)
		get_viewport().set_input_as_handled()
	elif visible and key == KEY_R:
		get_viewport().set_input_as_handled()
		progression.reset_run()
	elif key == KEY_L and progression.debug_grant_level():
		get_viewport().set_input_as_handled()
