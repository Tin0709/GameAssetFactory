extends SceneTree
## Real main-map controller and Mobile renderer, including held-Space repetitions.
var level
var player
var label: Label
var frames: Array = []
var section := ""
const OUT := "res://.validation/jump_set_v002"
func _initialize() -> void: call_deferred("run")
func tick(count: int) -> void:
	for i in count:
		await process_frame
		frames.append({"frame":frames.size(),"section":section,"position":[player.position.x,player.position.y,player.position.z],"jump":player.jump_active,"kind":String(player.jump_kind),"pose_time":player.visual.jump_time,"floor":player.is_on_floor(),"attachment":String(player.visual.socket.current_attachment)})
func review(text: String, kind: String, held: bool=false) -> void:
	section=text;label.text="JUMP SET V002 · "+text+"\nActual WorldMap / Godot Mobile · 1× playback\nOffline 30 FPS capture · artistic review pending"
	level.reset_player();await tick(14)
	if kind!="stationary":Input.action_press("move_right")
	if kind=="run":Input.action_press("sprint")
	await tick(8)
	Input.action_press("jump");await tick(2)
	if not held:Input.action_release("jump")
	await tick(105 if held else 32)
	Input.action_release("jump")
	# Keep running after release: verify the existing jump completes, no next jump.
	await tick(30 if held else 8)
	Input.action_release("move_right");Input.action_release("sprint");await tick(12)
func run() -> void:
	level=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(level);current_scene=level;player=level.player
	level.get_node("HUD/Help").hide()
	var canvas:=CanvasLayer.new();root.add_child(canvas);label=Label.new();canvas.add_child(label)
	label.position=Vector2(22,18);label.add_theme_font_size_override("font_size",20)
	await tick(18)
	player.visual.set_weapon_equipped(false)
	await review("Stationary / gameplay camera","stationary")
	level.get_node("Camera3D").size=8.0
	await review("Stationary / closer inspection","stationary")
	await review("Walking / authored stride","walk")
	await review("Running / single jump","run")
	await review("Running / hold Space then release","run",true)
	player.get_node("WeaponBehavior").enabled=false;player.equip_test_weapon(1);await tick(12)
	await review("Rifle / running hold Space","run",true)
	DirAccess.make_dir_recursive_absolute(OUT)
	FileAccess.open(OUT+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"frames":frames,"note":"Real main WorldMap. Three distinct authored V002 poses; held running repeats only after contact/recovery. Offline 30FPS, not phone performance."},"\t"))
	print("V002_REVIEW_CAPTURE ",frames.size())
	level.queue_free();canvas.queue_free();await process_frame;await process_frame;quit()
