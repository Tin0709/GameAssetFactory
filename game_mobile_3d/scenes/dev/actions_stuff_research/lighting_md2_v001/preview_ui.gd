extends CanvasLayer
## Small dev controls, no InputMap edits or gameplay key ownership.
var lighting:Node
var panel:PanelContainer
var body:VBoxContainer
var header:Button
var time_slider:HSlider
var time_label:Label
var speed_label:Label
var play:Button
var stats:Label
var timer:=0.

func setup(owner:Node)->void:
	lighting=owner;layer=30
	panel=PanelContainer.new();add_child(panel)
	panel.anchor_left=1.;panel.anchor_right=1.;panel.offset_left=-294.;panel.offset_right=-12.;panel.offset_top=12.
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.04,.055,.90);style.set_corner_radius_all(5)
	style.content_margin_left=10.;style.content_margin_right=10.;style.content_margin_top=8.;style.content_margin_bottom=8.
	panel.add_theme_stylebox_override("panel",style)
	var theme:=Theme.new();theme.default_font_size=13;panel.theme=theme
	var stack:=VBoxContainer.new();stack.add_theme_constant_override("separation",6);panel.add_child(stack)
	header=_button("Lighting · L to fold",toggle);stack.add_child(header)
	stats=Label.new();stats.add_theme_font_size_override("font_size",11);stack.add_child(stats)
	body=VBoxContainer.new();body.add_theme_constant_override("separation",6);stack.add_child(body)
	var row:=HBoxContainer.new();body.add_child(row)
	var names:=["07:00","12:00","16:30","18:30","22:00"]
	var hours:=[7.,12.,16.5,18.5,22.]
	for i in names.size():
		var button:=_button(names[i],_choose.bind(hours[i]));button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(button)
	time_label=Label.new();body.add_child(time_label)
	time_slider=HSlider.new();time_slider.min_value=0.;time_slider.max_value=24.;time_slider.step=.05;time_slider.value=12.;time_slider.focus_mode=Control.FOCUS_NONE;body.add_child(time_slider)
	time_slider.value_changed.connect(_choose)
	row=HBoxContainer.new();body.add_child(row)
	play=_button("▶ Auto",_play);row.add_child(play)
	var original:=CheckButton.new();original.text="Original A/B";original.focus_mode=Control.FOCUS_NONE;original.toggled.connect(lighting.set_original);row.add_child(original)
	row=HBoxContainer.new();body.add_child(row)
	var quality_label:=Label.new();quality_label.text="Quality";row.add_child(quality_label)
	var quality:=OptionButton.new();quality.focus_mode=Control.FOCUS_NONE
	for tier:Dictionary in lighting.TIERS:quality.add_item(tier.name)
	quality.select(lighting.quality);quality.item_selected.connect(lighting.set_quality);quality.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(quality)
	speed_label=Label.new();body.add_child(speed_label)
	var speed:=HSlider.new();speed.min_value=.02;speed.max_value=.8;speed.step=.02;speed.value=lighting.hours_per_second;speed.focus_mode=Control.FOCUS_NONE;speed.value_changed.connect(_speed);body.add_child(speed)
	row=HBoxContainer.new();body.add_child(row)
	for feature:String in ["Fog","Glow"]:
		var check:=CheckButton.new();check.text=feature;check.button_pressed=true;check.focus_mode=Control.FOCUS_NONE
		check.toggled.connect(lighting.set_fog if feature=="Fog" else lighting.set_glow);row.add_child(check)
	var note:=Label.new();note.text="07 Morning · 12 Noon · 16:30 Golden\n18:30 Dusk · 22 Night · dev only";note.add_theme_font_size_override("font_size",11);body.add_child(note)
	_refresh()

func _button(text:String,callback:Callable)->Button:
	var button:=Button.new();button.text=text;button.focus_mode=Control.FOCUS_NONE;button.pressed.connect(callback);return button
func _choose(hour:float)->void:
	lighting.automatic=false;lighting.set_time(hour)
func _play()->void:lighting.automatic=not lighting.automatic
func _speed(value:float)->void:lighting.hours_per_second=value
func toggle()->void:
	body.visible=not body.visible;panel.reset_size()
func _unhandled_key_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_L:
		toggle();get_viewport().set_input_as_handled()
func _process(delta:float)->void:
	timer+=delta
	if timer>=.25:timer=0.;_refresh()
func _refresh()->void:
	var m:Dictionary=lighting.metrics.sample()
	var gpu:="%.2fms"%m.gpu_ms if m.gpu_ms>0. else "N/A"
	var shadow:="%d"%m.shadow_draws if m.shadow_draws>0 or not lighting.sun.shadow_enabled else "N/A"
	stats.text="%d FPS · Render CPU %.2fms · GPU %s\nDraws %d · Shadow %s · %d objects"%[m.fps,m.render_cpu_ms,gpu,m.draws,shadow,m.objects]
	var minutes:=int(round(lighting.current_hour*60.))%1440
	header.text="Lighting · %02d:%02d · %s · L"%[minutes/60,minutes%60,"Original" if lighting.original else lighting.TIERS[lighting.quality].name]
	time_label.text="%02d:%02d · %s"%[minutes/60,minutes%60,"Original" if lighting.original else "GAF MD2 v001"]
	time_slider.set_value_no_signal(lighting.current_hour)
	play.text="Ⅱ Pause" if lighting.automatic else "▶ Auto"
	speed_label.text="24h preview in %.1f minutes"%(24./lighting.hours_per_second/60.)
