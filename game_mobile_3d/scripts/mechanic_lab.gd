extends Node3D

const PlayerFactory := preload("res://scripts/world_map_player_factory.gd")
const PlayerPresentation := preload("res://scripts/world_map_presentation.gd")
const SourceTerrain := preload("res://scripts/world_map_source_terrain.gd")
const LocalExposure := preload("res://scripts/world_map_bloom_source.gd")
const CAMERA_OFFSET := Vector3(12.0, 15.0, 16.0)
const SPAWN := Vector3(0.0, 0.03, 0.0)
const WORLD_MAP_NOON_EXPOSURE := 0.12
const MIN_CAMERA_SIZE := 4.5
const MAX_CAMERA_SIZE := 30.0
const ZOOM_STEP := 1.15

var presentation: Node
var _exposure: CompositorEffect
var _previous_msaa: Viewport.MSAA
var _previous_hdr: bool
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
	_apply_daylight_render_settings()
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
	var player_ready: bool = not using_private or player.get("primary_ready") == true
	if not player_ready:
		$HUD/Controls.text = "Thiếu dữ liệu player của gameplay chính. Kiểm tra MD2_RESEARCH_ROOT."
	elif using_private:
		$HUD/Controls.text = "WASD di chuyển · Shift đi bộ · Space nhảy · Chuột trái / E dùng Sabre · R về giữa"
	else:
		$HUD/Controls.text = "WASD di chuyển · Shift chạy · Space nhảy · R về giữa"
	$HUD/Controls.text += " · Cuộn chuột để zoom"
	$HUD/SpawnZombie.disabled = not (using_private and player_ready)
	if not $HUD/SpawnZombie.disabled:
		player.connect("impact_ready", $Zombies.on_sabre_impact)
	print("MECHANIC_LAB_READY floor=100x100 player_ready=%s source_tiles=%s" % [player_ready, tiles != null])

func _apply_daylight_render_settings() -> void:
	if RenderingServer.get_rendering_device() == null:
		return
	var viewport := get_viewport()
	_previous_msaa = viewport.msaa_3d
	_previous_hdr = viewport.use_hdr_2d
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.use_hdr_2d = true
	_exposure = LocalExposure.new()
	_exposure.set_review_strength(WORLD_MAP_NOON_EXPOSURE)
	_exposure.set_air_bloom(true)
	var compositor := Compositor.new()
	compositor.compositor_effects = [_exposure]
	camera.compositor = compositor

func _exit_tree() -> void:
	if _exposure == null:
		return
	_exposure.enabled = false
	camera.compositor = null
	var effect := _exposure
	_exposure = null
	RenderingServer.call_on_render_thread(func(): effect.release_on_render_thread())
	var viewport := get_viewport()
	viewport.msaa_3d = _previous_msaa
	viewport.use_hdr_2d = _previous_hdr

func _process(_delta: float) -> void:
	var focus: Vector3 = presentation.player_position()
	camera.position = CAMERA_OFFSET + Vector3(focus.x, 0.0, focus.z)

func _physics_process(_delta: float) -> void:
	if player.position.y < -5.0:
		reset_player()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_test"):
		reset_player()
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				camera.size = maxf(MIN_CAMERA_SIZE, camera.size / ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				camera.size = minf(MAX_CAMERA_SIZE, camera.size * ZOOM_STEP)
			_:
				return
		get_viewport().set_input_as_handled()

func _spawn_zombie() -> void:
	var facing := Basis(Vector3.UP, player.visual.rotation.y)
	if $Zombies.spawn(player.global_position, facing):
		$HUD/SpawnStatus.text = ""
	else:
		$HUD/SpawnStatus.text = "Không thể tạo zombie. Kiểm tra dữ liệu MD2 Research và chỗ trống."

func reset_player() -> void:
	player.position = SPAWN
	player.velocity = Vector3.ZERO
	if player.has_method("cancel_jump"):
		player.cancel_jump()
	player.reset_physics_interpolation()
	camera.position = CAMERA_OFFSET
