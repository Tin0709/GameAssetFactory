extends SceneTree
## Real controller/camera/material transition; offline movie, not an FPS benchmark.
var samples: Array = []
var player: CharacterBody3D
var level: Node3D
var phase := ""

func _initialize() -> void:
	call_deferred("run")

func tick(count: int) -> void:
	for i in count:
		await physics_frame
		samples.append({"phase":phase,"position":var_to_str(player.position),"on_floor":player.is_on_floor()})

func run() -> void:
	level = load("res://scenes/GameplayMap.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Actors/Player")
	player.position = Vector3(38,1.02,36)
	await tick(20)
	level.get_node("HUD").hide()
	phase = "Approach east / south corner"
	Input.action_press("move_right")
	await tick(90)
	Input.action_release("move_right")
	await tick(15)
	phase = "Move away; wall becomes solid again"
	Input.action_press("move_left")
	await tick(90)
	Input.action_release("move_left")
	await tick(15)
	var folder := "res://.validation/flat_map_100x100/"
	FileAccess.open(folder+"fade_movie.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":samples,"note":"Original R15 controller/animation. Actual Mobile/D3D12 material fade, Dummy audio, 30 FPS offline recording; no phone FPS measurement."},"\t"))
	print("BORDER_FADE_CAPTURE frames=",samples.size())
	quit()
