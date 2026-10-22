extends CanvasLayer
## Event-driven batch controls; read-only telemetry refreshes four times/second.
var lab:Node3D
var encounter:Node3D
var panel:PanelContainer
var count_slider:HSlider
var count_label:Label
var spawn_button:Button
var kill_button:Button
var status:Label
var stats:Label
var selected_count:=20
var _timer:=0.

func setup(scene:Node3D)->void:
	lab=scene;encounter=lab.zombie_combat;layer=31
	panel=PanelContainer.new();add_child(panel)
	panel.anchor_top=1.;panel.anchor_bottom=1.;panel.offset_left=12.;panel.offset_right=294.;panel.offset_top=-230.;panel.offset_bottom=-12.
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.04,.055,.91);style.set_corner_radius_all(5)
	style.content_margin_left=10.;style.content_margin_right=10.;style.content_margin_top=8.;style.content_margin_bottom=8.;panel.add_theme_stylebox_override("panel",style)
	var theme:=Theme.new();theme.default_font_size=13;panel.theme=theme
	var stack:=VBoxContainer.new();stack.add_theme_constant_override("separation",5);panel.add_child(stack)
	var title:=Label.new();title.text="PERFORMANCE TEST · 30 × 30";stack.add_child(title)
	status=Label.new();stack.add_child(status)
	count_label=Label.new();stack.add_child(count_label)
	count_slider=HSlider.new();count_slider.min_value=0.;count_slider.max_value=50.;count_slider.step=1.;count_slider.focus_mode=Control.FOCUS_NONE;count_slider.custom_minimum_size.y=20.;stack.add_child(count_slider)
	count_slider.value_changed.connect(select_count)
	var row:=HBoxContainer.new();stack.add_child(row)
	for count:int in [0,10,20,50]:
		var button:=_button(str(count),select_count.bind(count));button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(button)
	row=HBoxContainer.new();stack.add_child(row)
	spawn_button=_button("Spawn 20",spawn_selected);spawn_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(spawn_button)
	kill_button=_button("Kill All",kill_all);kill_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(kill_button)
	stats=Label.new();stats.add_theme_font_size_override("font_size",11);stack.add_child(stats)
	var note:=Label.new();note.text="Spawn replaces group · R resets it\nV overview · no automatic respawn";note.add_theme_font_size_override("font_size",11);stack.add_child(note)
	select_count(encounter.spawn_count);_refresh()

func _button(text:String,callback:Callable)->Button:
	var button:=Button.new();button.text=text;button.focus_mode=Control.FOCUS_NONE;button.pressed.connect(callback);return button

func select_count(value:float)->void:
	selected_count=clampi(int(value),0,50)
	count_slider.set_value_no_signal(selected_count)
	count_label.text="Zombie count: %d / 50"%selected_count
	spawn_button.text="Spawn %d"%selected_count

func _clear_target_and_shots()->void:
	if lab.rifle_auto_aim!=null:lab.rifle_auto_aim.reset_target()
	if lab.rifle_fire!=null:lab.rifle_fire.reset_fire()

func spawn_selected()->void:
	_clear_target_and_shots()
	encounter.spawn_batch(selected_count)
	lab._sync_rifle_controls();_refresh()

func kill_all()->void:
	_clear_target_and_shots()
	encounter.kill_all()
	lab._sync_rifle_controls();_refresh()

func _process(delta:float)->void:
	_timer+=delta
	if _timer>=.25:_timer=0.;_refresh()

func _refresh()->void:
	status.text="Alive %d · Ragdolls %d / 4"%[encounter.living_count(),encounter.active_ragdolls()]
	var fps:=Engine.get_frames_per_second()
	stats.text="%d FPS · Frame %.1fms\nProcess %.2fms · Physics %.2fms"%[fps,1000./maxi(fps,1),Performance.get_monitor(Performance.TIME_PROCESS)*1000.,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.]
