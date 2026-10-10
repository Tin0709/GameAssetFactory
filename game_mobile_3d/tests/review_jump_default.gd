extends SceneTree
## Actual WorldMap/controller/renderer recording, not a Blender pose playback.
var level
var player
var label: Label
var frames: Array = []
var section := ""
var out := "res://.validation/jump_default_v001"
func _initialize() -> void: call_deferred("run")
func tick(count: int) -> void:
	for i in count:
		await process_frame
		frames.append({"frame":frames.size(),"section":section,"position":[player.position.x,player.position.y,player.position.z],"jump":player.jump_active,"pose_time":player.visual.jump_time,"floor":player.is_on_floor(),"attachment":String(player.visual.socket.current_attachment)})
func jump_review(text: String, moving: bool=false) -> void:
	section=text; label.text="JUMP DEFAULT V001 · "+text+"\nActual WorldMap / Godot Mobile · 1× playback\nOffline 30 FPS capture · artistic review pending"
	level.reset_player(); await tick(18)
	if moving: Input.action_press("move_right")
	Input.action_press("jump"); await tick(2); Input.action_release("jump")
	await tick(31)
	Input.action_release("move_right"); await tick(15)
func run() -> void:
	level=load("res://scenes/WorldMap.tscn").instantiate(); root.add_child(level); current_scene=level
	player=level.player
	level.get_node("HUD/Help").hide()
	var canvas:=CanvasLayer.new(); root.add_child(canvas); label=Label.new();canvas.add_child(label)
	label.position=Vector2(22,18);label.add_theme_font_size_override("font_size",20)
	await tick(18)
	player.visual.set_weapon_equipped(false)
	await jump_review("Unarmed / gameplay camera")
	level.get_node("Camera3D").size=8.0
	await jump_review("Unarmed / closer inspection")
	await jump_review("Moving jump",true)
	player.get_node("WeaponBehavior").enabled=false
	player.equip_test_weapon(1)
	await tick(10)
	await jump_review("Rifle / retained grip")
	DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"frames":frames,"note":"Actual main WorldMap. Authored unarmed Action; armed jump retains current gun grip. Offline 30FPS recording, no phone performance claim."},"\t"))
	print("JUMP_REVIEW_CAPTURE ",frames.size())
	level.queue_free();canvas.queue_free();await process_frame;await process_frame;quit()
