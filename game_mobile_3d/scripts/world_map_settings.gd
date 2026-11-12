extends RefCounted
## Reorganizes the real showcase widgets, preserving their callbacks and live values.
const Copy := preload("res://scripts/world_map_settings_copy.gd")
const NAMED := {
	"AtmosphereComparison": "atmosphere",
	"LightingMixPreset": "preset",
	"LightingMixSave": "save-mix",
	"LightingMixLoad": "load-mix",
	"SceneLightingMix": "apply-forest",
	"PlayerMaterialComparison": "player-material",
	"TerrainLightComparison": "terrain-material",
	"BalancedAtmospherePreview": "balanced",
	"NearHazePreview": "near-haze-toggle",
	"SettingsKeysHelp": "keys-help",
	"SettingsPlayerNote": "player-note",
	"SettingsTerrainNote": "terrain-note",
	"SettingsPresetMessage": "preset-message",
}
const PHASES := ["morning", "day", "golden", "night"]
const PRESETS := ["save-mix", "load-mix", "reset-mix"]
const DAY_QUICK := ["sun", "fog", "near_haze", "shadow", "bloom"]
const NIGHT_QUICK := ["moon", "fog", "near_haze", "night_cliff_mist", "bloom"]
const COMPARE := "compare-original-combined-graphics-b"
const ACCENT := Color("#edc788")
const DIM := Color("#acc0b3")
const BORDER := Color("#3e5448")
const UNDO_LIMIT := 48
const DEFAULT_MENU_SIZE := Vector2(608.0, 644.0)
const MIN_MENU_SIZE := Vector2(448.0, 240.0)
const LEADING_INSET := Vector2(8.0, 8.0)
const TRAILING_INSET := Vector2(16.0, 16.0)

var hud: CanvasLayer
var gear: Button
var panel: PanelContainer
var scroll: ScrollContainer
var search: LineEdit
var _shield: Control
var _body: VBoxContainer
var _park: Control
var _views: OptionButton
var _regex := RegEx.create_from_string("[^a-z0-9]+")
var _active := 0
var _night := false
var _full := false
var _info: PanelContainer
var _info_trigger: Button
var _widgets: Dictionary = {}
var _items := Copy.ITEMS.duplicate()
var _map_mix_ids: Array[String] = []
var _sliders: Dictionary = {}
var _undo_button: Button
var _history: Array[Callable] = []
var _undoing := false
var _toggle_before: Dictionary = {}
var _choice_before: Dictionary = {}
var _dragging := false
var _drag_offset := Vector2.ZERO
var _moved := false
var _preferred_position := Vector2.ZERO
var _preferred_size := DEFAULT_MENU_SIZE
var _resizing := false
var _resize_offset := Vector2.ZERO

func setup(layer: CanvasLayer, window: PanelContainer, legacy: VBoxContainer,
		sliders: Dictionary, status: Label, full: bool) -> void:
	hud = layer
	panel = window
	_full = full
	_park = Control.new()
	_park.name = "SettingsControlStorage"
	_park.hide()
	panel.add_child(_park)
	if status != null:
		status.reparent(_park)
	_collect(legacy, sliders)
	panel.remove_child(legacy)
	legacy.queue_free()

	_shield = Control.new()
	_shield.name = "WorldMapSettingsPointerShield"
	_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_shield.mouse_force_pass_scroll_events = false
	hud.add_child(_shield)
	_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shield.gui_input.connect(_outside_click)
	panel.reparent(_shield, false)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.custom_minimum_size = Vector2.ZERO
	panel.theme = _make_theme()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_force_pass_scroll_events = false
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := _label("Cài đặt Overworld", 23)
	heading.name = "SettingsDragHandle"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	heading.mouse_default_cursor_shape = Control.CURSOR_MOVE
	heading.tooltip_text = "Giữ chuột trái trên tiêu đề và kéo để di chuyển menu."
	heading.gui_input.connect(_drag_header)
	header.add_child(heading)
	if full:
		_undo_button = _button("Hoàn tác")
		_undo_button.name = "UndoSettings"
		_undo_button.tooltip_text = "Khôi phục lần chỉnh gần nhất."
		_undo_button.disabled = true
		_undo_button.pressed.connect(_undo_last)
		header.add_child(_undo_button)
	if _widgets.has(COMPARE):
		var compare: Button = _widgets[COMPARE]
		compare.reparent(header)
		compare.text = "So sánh (B)"
		compare.tooltip_text = "So sánh bản gốc với cấu hình đang dùng."
		header.add_child(_info_button(COMPARE, layout))
	var close := _button("Đóng")
	header.add_child(close)
	close.pressed.connect(set_open.bind(false))

	if status != null:
		status.reparent(layout)
		status.add_theme_color_override("font_color", DIM)
		status.add_theme_font_size_override("font_size", 13)

	var navigation := HBoxContainer.new()
	layout.add_child(navigation)
	_views = OptionButton.new()
	_views.name = "SettingsSection"
	_views.focus_mode = Control.FOCUS_NONE
	_views.add_item("Dùng nhanh" if full else "Điều khiển trong game")
	if full:
		for tab: Dictionary in Copy.TABS:
			_views.add_item(tab.title)
	navigation.add_child(_views)
	_views.item_selected.connect(_select_view)
	search = LineEdit.new()
	search.name = "SettingsSearch"
	search.placeholder_text = "Tìm tùy chọn…"
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(search)
	search.visible = full
	search.text_changed.connect(_rebuild)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content)
	scroll = ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_force_pass_scroll_events = false
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	content.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
	var grip := _button("◢")
	grip.name = "SettingsResizeHandle"
	grip.custom_minimum_size = Vector2(30.0, 22.0)
	grip.size_flags_horizontal = Control.SIZE_SHRINK_END
	grip.mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
	grip.tooltip_text = "Giữ chuột trái và kéo để đổi kích thước menu."
	grip.add_theme_color_override("font_color", ACCENT)
	grip.gui_input.connect(_drag_resize)
	content.add_child(grip)

	gear = _button("⚙  Cài đặt")
	gear.name = "WorldMapSettingsButton"
	gear.theme = panel.theme
	gear.tooltip_text = "Mở cài đặt Overworld. Phím L ẩn / hiện HUD."
	hud.add_child(gear)
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -142
	gear.offset_right = -16
	gear.offset_top = 12
	gear.offset_bottom = 50
	gear.pressed.connect(_toggle_open)
	hud.move_child(_shield, -1)
	hud.get_viewport().size_changed.connect(_resize)
	_resize()
	_rebuild()
	set_open(false)

func _collect(legacy: VBoxContainer, sliders: Dictionary) -> void:
	for id: StringName in sliders:
		var slider: HSlider = sliders[id]
		var row := slider.get_parent() as HBoxContainer
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_sliders[String(id)] = slider
		_register(String(id), row)
	for node: Node in legacy.get_children():
		if node is HBoxContainer:
			for child: Node in node.get_children():
				_collect_widget(child)
		else:
			_collect_widget(node)

func _collect_widget(node: Node) -> void:
	var id: String = NAMED.get(String(node.name), "")
	if node.has_meta("settings_item_id"):
		id = node.get_meta("settings_item_id")
		_items[id] = node.get_meta("settings_item_copy")
		_map_mix_ids.append(id)
	if id.is_empty() and node is Button and not node is OptionButton:
		id = _regex.sub(node.text.to_lower(), "-", true).strip_edges().trim_prefix("-").trim_suffix("-")
	if not id.is_empty():
		_register(id, node)

func _register(id: String, widget: Control) -> void:
	_widgets[id] = widget
	widget.reparent(_park)
	if _items.has(id):
		if widget is HBoxContainer:
			var caption := widget.get_child(0) as Label
			caption.text = _items[id][0]
			caption.custom_minimum_size.x = 0
			caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			caption.size_flags_stretch_ratio = 1.5
			caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif widget is Button and not widget is OptionButton:
			widget.text = _items[id][0]
			if widget is CheckButton:
				widget.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if widget is Label:
		widget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif widget is CheckButton:
		widget.button_down.connect(_begin_toggle.bind(widget))
		widget.pressed.connect(_finish_toggle.bind(widget))
	elif widget is OptionButton:
		widget.get_popup().about_to_popup.connect(func(): _choice_before[widget] = widget.selected)
		widget.item_selected.connect(_finish_choice.bind(widget))

func _resize() -> void:
	var bounds := _shield.get_viewport_rect().size
	var available := (bounds - LEADING_INSET - TRAILING_INSET).max(Vector2.ONE)
	var wanted := _preferred_size.clamp(MIN_MENU_SIZE.min(available), available)
	var desired := _preferred_position if _moved else Vector2(bounds.x - wanted.x - TRAILING_INSET.x, 60.0)
	var position_limit := bounds - TRAILING_INSET - Vector2(wanted.x, minf(MIN_MENU_SIZE.y, available.y))
	panel.position = desired.clamp(LEADING_INSET, position_limit.max(LEADING_INSET))
	panel.size = wanted.min(bounds - panel.position - TRAILING_INSET)

func _drag_header(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = event.global_position - panel.position
	elif event is InputEventMouseMotion and _dragging:
		_moved = true
		_preferred_position = event.global_position - _drag_offset
		_resize()

func _drag_resize(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_resizing = event.pressed
		if _resizing:
			_resize_offset = panel.get_global_rect().end - event.global_position
	elif event is InputEventMouseMotion and _resizing:
		# Clamp the moving corner while keeping the top-left corner fixed.
		_moved = true
		_preferred_position = panel.position
		var available := _shield.get_viewport_rect().size - panel.position - TRAILING_INSET
		var wanted: Vector2 = event.global_position + _resize_offset - panel.get_global_rect().position
		_preferred_size = wanted.clamp(MIN_MENU_SIZE.min(available), available)
		_resize()

func remember_edit(restore: Callable) -> void:
	if _undoing or _undo_button == null:
		return
	if _history.size() == UNDO_LIMIT:
		_history.pop_front()
	_history.append(restore)
	_undo_button.disabled = false

func _undo_last() -> void:
	if _history.is_empty():
		return
	_close_info()
	_undoing = true
	var restore: Callable = _history.pop_back()
	restore.call()
	_undoing = false
	_undo_button.disabled = _history.is_empty()

func _begin_toggle(widget: CheckButton) -> void:
	_toggle_before.clear()
	_toggle_before[widget] = widget.button_pressed
	for other: Control in _widgets.values():
		if other is CheckButton:
			_toggle_before[other] = other.button_pressed

func _finish_toggle(widget: CheckButton) -> void:
	if not _toggle_before.has(widget):
		return
	var changed: Dictionary = {}
	for other: CheckButton in _toggle_before:
		if other.button_pressed != _toggle_before[other]:
			changed[other] = _toggle_before[other]
	_toggle_before.clear()
	if not changed.is_empty():
		remember_edit(_restore_toggles.bind(changed))

func _restore_toggles(previous: Dictionary) -> void:
	# Restore the clicked option first; it may also restore its dependent toggles.
	for widget: CheckButton in previous:
		if widget.button_pressed != previous[widget]:
			widget.button_pressed = previous[widget]

func _finish_choice(index: int, widget: OptionButton) -> void:
	var previous: int = _choice_before.get(widget, index)
	_choice_before.erase(widget)
	if previous >= 0 and previous != index:
		remember_edit(_restore_choice.bind(widget, previous))

func _restore_choice(widget: OptionButton, index: int) -> void:
	widget.select(index)
	widget.item_selected.emit(index)

func _toggle_open() -> void:
	set_open(not panel.visible)

func set_open(value: bool) -> void:
	if not value:
		_dragging = false
		_resizing = false
		_close_info()
		if search.has_focus():
			search.release_focus()
	panel.visible = value
	_shield.visible = value

func toggle_hud() -> void:
	if hud.visible:
		set_open(false)
	hud.visible = not hud.visible

func handle_escape() -> bool:
	if not panel.is_visible_in_tree():
		return false
	if _info != null:
		_close_info()
	elif search.has_focus():
		search.release_focus()
	else:
		set_open(false)
	return true

func _outside_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_shield.accept_event()
		set_open(false)

func update_phase(night: bool) -> void:
	if _night == night:
		return
	_night = night
	if _active == 0 and search.text.is_empty():
		_rebuild()

func _select_view(index: int) -> void:
	_active = index
	search.clear()
	_rebuild()

func _rebuild(_text: String = "") -> void:
	_close_info()
	for id: String in _widgets:
		var widget: Control = _widgets[id]
		if id != COMPARE and widget.get_parent() != _park:
			widget.reparent(_park)
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0
	var query := _fold(search.text.strip_edges())
	if not query.is_empty():
		_build_results(query)
	elif not _full:
		_add_row(_section("Điều khiển trong game"), "keys-help")
	elif _active == 0:
		_build_quick()
	else:
		var sections: Array = Copy.TABS[_active - 1].sections
		for index: int in sections.size():
			var section: Dictionary = sections[index]
			var rows := _section(section.title, index == 0, true)
			for id: String in section.ids:
				_add_row(rows, id)

func _build_quick() -> void:
	var time := _section("Thời điểm")
	_add_row_buttons(time, PHASES)
	_add_row(time, "original-gaf-day-night-preview")
	var mix := _section("Preset ánh sáng")
	_add_row_buttons(mix, ["preset"] + PRESETS)
	_add_row_buttons(mix, ["apply-forest"] + _map_mix_ids.slice(0, 1))
	for id: String in _map_mix_ids.slice(1):
		_add_row(mix, id)
	_add_row(mix, "preset-message")
	var main := _section("Điều chỉnh ban đêm" if _night else "Điều chỉnh ban ngày")
	for id: String in (NIGHT_QUICK if _night else DAY_QUICK):
		_add_row(main, id)

func _build_results(query: String) -> void:
	var results := _section("Kết quả tìm kiếm")
	var found := 0
	for id: String in _items:
		var entry: Array = _items[id]
		if id == COMPARE or not _widgets.has(id):
			continue
		if _fold(entry[0] + " " + entry[1]).contains(query):
			_add_row(results, id)
			found += 1
	if found == 0:
		results.add_child(_label("Không tìm thấy tùy chọn phù hợp."))

static func _fold(value: String) -> String:
	var result := value.to_lower()
	for chars: String in ["aàáảãạăằắẳẵặâầấẩẫậ", "eèéẻẽẹêềếểễệ",
			"iìíỉĩị", "oòóỏõọôồốổỗộơờớởỡợ", "uùúủũụưừứửữự", "yỳýỷỹỵ", "dđ"]:
		for index: int in range(1, chars.length()):
			result = result.replace(chars[index], chars[0])
	return result

func _section(title: String, expanded: bool = true, collapsible: bool = false) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("#23332b"), BORDER, 9, 9))
	_body.add_child(card)
	var layout := VBoxContainer.new()
	card.add_child(layout)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	if collapsible:
		var toggle := _button(("▾  " if expanded else "▸  ") + title)
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		toggle.toggle_mode = true
		toggle.button_pressed = expanded
		layout.add_child(toggle)
		toggle.toggled.connect(func(open: bool):
			_close_info()
			rows.visible = open
			toggle.text = ("▾  " if open else "▸  ") + title)
	else:
		var label := _label(title, 17)
		label.add_theme_color_override("font_color", ACCENT)
		layout.add_child(label)
	layout.add_child(rows)
	rows.visible = expanded
	return rows

func _add_row(parent: VBoxContainer, id: String) -> void:
	if not _widgets.has(id):
		return
	var widget: Control = _widgets[id]
	if widget is Label:
		widget.reparent(parent)
		return
	var stack := VBoxContainer.new()
	parent.add_child(stack)
	var row := HBoxContainer.new()
	stack.add_child(row)
	if widget is OptionButton:
		var caption := _label(_items[id][0])
		caption.custom_minimum_size.x = 138
		row.add_child(caption)
	widget.reparent(row)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_info_button(id, stack))

func _add_row_buttons(parent: VBoxContainer, ids: Array) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	for id: String in ids:
		if not _widgets.has(id):
			continue
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cell)
		var widget: Button = _widgets[id]
		widget.reparent(cell)
		widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(_info_button(id, parent))

func _info_button(id: String, parent: VBoxContainer) -> Button:
	var button := _button("ⓘ")
	button.name = "Info_" + id
	button.custom_minimum_size = Vector2(28, 30)
	button.tooltip_text = "Thông tin về " + _items[id][0]
	button.add_theme_color_override("font_color", ACCENT)
	button.pressed.connect(_toggle_info.bind(id, parent, button))
	return button

func _toggle_info(id: String, parent: VBoxContainer, button: Button) -> void:
	var was_open := _info_trigger == button
	_close_info()
	if was_open:
		return
	_info_trigger = button
	_info = PanelContainer.new()
	_info.name = "SettingExplanation"
	_info.add_theme_stylebox_override("panel", _box(Color("#172820"), BORDER, 8, 8))
	parent.add_child(_info)
	var layout := VBoxContainer.new()
	_info.add_child(layout)
	var entry: Array = _items[id]
	var title := _label(entry[0], 16)
	title.add_theme_color_override("font_color", ACCENT)
	layout.add_child(title)
	layout.add_child(_label("Tác dụng · " + entry[2]))
	layout.add_child(_label("Cách thử · " + entry[3]))
	if _sliders.has(id):
		var slider: HSlider = _sliders[id]
		var value := _label("")
		layout.add_child(value)
		var show_value := func(current: float):
			value.text = "Hiện tại %d%% · Phạm vi %d–%d%%" % [
				roundi(current * 100), roundi(slider.min_value * 100), roundi(slider.max_value * 100)]
		show_value.call(slider.value)
		slider.value_changed.connect(show_value)
		value.tree_exiting.connect(func(): slider.value_changed.disconnect(show_value))
	if scroll.is_ancestor_of(_info):
		_reveal_info(_info)

func _reveal_info(card: Control) -> void:
	# Wait for the containers to assign the wrapped text's height.
	await hud.get_tree().process_frame
	if is_instance_valid(card) and card == _info:
		scroll.ensure_control_visible(card)

func _close_info() -> void:
	if _info != null:
		_info.get_parent().remove_child(_info)
		_info.queue_free()
		_info = null
		_info_trigger = null

static func _label(value: String, font_size: int = 15) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

static func _button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 32
	return button

static func _box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

static func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_stylebox("panel", "PanelContainer", _box(Color("#25362f"), BORDER, 12, 12))
	for kind: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", kind, _box(Color("#293e33"), BORDER, 6, 6))
		theme.set_stylebox("hover", kind, _box(Color("#395347"), ACCENT, 6, 6))
		theme.set_stylebox("pressed", kind, _box(Color("#465b44"), ACCENT, 6, 6))
		theme.set_stylebox("disabled", kind, _box(Color("#24322b"), BORDER, 6, 6))
	theme.set_stylebox("normal", "LineEdit", _box(Color("#141f1a"), BORDER, 6, 7))
	return theme
