extends Node3D

const PlayerFactory := preload("res://scripts/world_map_player_factory.gd")
const PlayerPresentation := preload("res://scripts/world_map_presentation.gd")
const SourceTerrain := preload("res://scripts/world_map_source_terrain.gd")
const CAMERA_OFFSET := Vector3(12.0, 15.0, 16.0)
const SPAWN := Vector3(0.0, 0.03, 0.0)

var presentation: Node
@onready var player: CharacterBody3D = $Actors/Player
@onready var camera: Camera3D = $Camera3D

func _enter_tree() -> void:
	presentation = PlayerPresentation.new()
	presentation.name = "RenderPresentation"
	add_child(presentation)
	presentation.begin(self)
	var actor := PlayerFactory.create(PlayerFactory.uses_private_player())
	actor.name = "Player"
	actor.position = SPAWN
	$Actors.add_child(actor)

func _ready() -> void:
	var material := $Ground/Mesh.material_override as ShaderMaterial
	var tiles := SourceTerrain.load_tiles()
	if tiles != null:
		material.set_shader_parameter("tiles", tiles)
		material.set_shader_parameter("use_source_tiles", true)

	presentation.setup()
	reset_player()
	camera.look_at(Vector3.ZERO)
	DisplayServer.window_set_title("MechanicLab")

	var using_private := PlayerFactory.uses_private_player()
	var player_ready := not using_private or player.get("primary_ready") == true
	if not player_ready:
		$HUD/Controls.text = "Thiếu dữ liệu player của gameplay chính. Kiểm tra MD2_RESEARCH_ROOT."
	elif using_private:
		$HUD/Controls.text = "WASD di chuyển · Shift đi bộ · Space nhảy · Chuột trái / E dùng Sabre · R về giữa"
	else:
		$HUD/Controls.text = "WASD di chuyển · Shift chạy · Space nhảy · R về giữa"
	print("MECHANIC_LAB_READY floor=100x100 player_ready=%s source_tiles=%s" % [player_ready, tiles != null])

func _process(_delta: float) -> void:
	var focus: Vector3 = presentation.player_position()
	camera.position = CAMERA_OFFSET + Vector3(focus.x, 0.0, focus.z)

func _physics_process(_delta: float) -> void:
	if player.position.y < -5.0:
		reset_player()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_test"):
		reset_player()

func reset_player() -> void:
	player.position = SPAWN
	player.velocity = Vector3.ZERO
	if player.has_method("cancel_jump"):
		player.cancel_jump()
	player.reset_physics_interpolation()
	camera.position = CAMERA_OFFSET
