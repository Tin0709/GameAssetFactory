extends Button
## Small, local-only bug-report helper. Explicit fields avoid exporting private paths.
var context_provider:Callable

func _init()->void:
	name="CopyLabDiagnostics"
	text="Copy lab info"
	tooltip_text="Copy runtime and meadow settings for a bug report"
	focus_mode=Control.FOCUS_NONE
	pressed.connect(_copy_report)

func _copy_report()->void:
	var state:Dictionary=context_provider.call() if context_provider.is_valid() else {}
	var lines:=PackedStringArray([
		"GameAssetFactory — Overworld lab",
		"Godot: "+str(Engine.get_version_info().get("string","unknown")),
		"OS: "+OS.get_name(),
		"Renderer: "+RenderingServer.get_current_rendering_method(),
		"Display: "+DisplayServer.get_name(),
		"Viewport: %d x %d"%[get_viewport_rect().size.x,get_viewport_rect().size.y],
		"FPS: %d | physics: %d Hz"%[Engine.get_frames_per_second(),Engine.physics_ticks_per_second],
	])
	for key:String in ["Scene","Wind","Vegetation interaction","Ambient audio","Footsteps","Speed (m/s)"]:
		if state.has(key):lines.append(key+": "+str(state[key]))
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		text="Clipboard unavailable";return
	DisplayServer.clipboard_set("\n".join(lines))
	text="Copied!"
	get_tree().create_timer(2.).timeout.connect(func():text="Copy lab info")
