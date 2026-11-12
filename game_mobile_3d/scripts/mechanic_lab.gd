extends Node3D

const PlayerFactory := preload("res://scripts/world_map_player_factory.gd")
const PlayerPresentation := preload("res://scripts/world_map_presentation.gd")
const SourceTerrain := preload("res://scripts/world_map_source_terrain.gd")
const LocalExposure := preload("res://scripts/world_map_bloom_source.gd")
const CombatAudio := preload("res://scripts/mechanic_lab_combat_audio.gd")
const CAMERA_OFFSET := Vector3(12.0, 15.0, 16.0)
const SPAWN := Vector3(0.0, 0.03, 0.0)
const WORLD_MAP_NOON_EXPOSURE := 0.12
const MIN_CAMERA_SIZE := 4.5
const MAX_CAMERA_SIZE := 30.0
const ZOOM_STEP := 1.15
const SABRE_TAP_BUFFER := 0.16

var presentation: Node
var _exposure: CompositorEffect
var _previous_msaa: Viewport.MSAA
var _previous_hdr: bool
var _combat_audio: CombatAudio
var _shake_serial := -1
var _shake_age := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _shake_axis := Vector2.UP
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
	$HUD/CombatAudioToggle.disabled = $HUD/SpawnZombie.disabled
	if not $HUD/SpawnZombie.disabled:
		player.collision_mask |= 4
		_combat_audio = CombatAudio.new()
		_combat_audio.name = "CombatAudio"
		$CombatEffects.add_child(_combat_audio)
		_set_combat_audio(false)
		player.combo.native_tap_buffer_seconds = SABRE_TAP_BUFFER
		$Zombies.setup_combat(player.clips, player.combo.native_windows)
		player.connect("attack_pose_sample", $Zombies.sample_sabre)
		$Zombies.sabre_contact.connect(_on_sabre_contact)
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

func _process(delta: float) -> void:
	var focus: Vector3 = presentation.player_position()
	camera.position = CAMERA_OFFSET + Vector3(focus.x, 0.0, focus.z)
	if _shake_age < _shake_duration:
		_shake_age = minf(_shake_age + delta, _shake_duration)
		var decay := 1.0 - _shake_age / _shake_duration
		var pulse := cos(TAU * 15.0 * _shake_age) * decay * decay
		var offset := _shake_axis * camera.size * _shake_strength * pulse
		camera.h_offset = offset.x
		camera.v_offset = offset.y

func _set_combat_audio(enabled: bool) -> void:
	if _combat_audio == null:
		return
	if player.reference_audio != null:
		player.reference_audio.enabled = enabled
	_combat_audio.set_enabled(enabled)

func _on_sabre_contact(point: Vector3, direction: Vector3, clip: String, index: int, serial: int, lethal: bool) -> void:
	player.effects.contact(point, direction)
	_combat_audio.contact(point, serial, lethal)
	var heavy := index == 2 or clip == "AirAttack"
	var strength := 0.013 if lethal else (0.010 if heavy else 0.006)
	if _shake_serial == serial and strength <= _shake_strength:
		return
	_shake_serial = serial
	_shake_strength = strength
	_shake_age = 0.0
	_shake_duration = 0.19 if lethal or heavy else 0.14
	var screen_direction := Vector2(direction.dot(camera.basis.x), direction.dot(camera.basis.y))
	_shake_axis = screen_direction.normalized() if screen_direction.length_squared() > 0.01 else Vector2.UP

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
	if $Zombies.spawn(player, facing, $CombatEffects):
		$HUD/SpawnStatus.text = ""
	else:
		$HUD/SpawnStatus.text = "Không thể tạo zombie. Kiểm tra dữ liệu MD2 Research và chỗ trống."

func reset_player() -> void:
	_shake_serial = -1
	_shake_duration = 0.0
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	if _combat_audio != null:
		_combat_audio.reset()
	player.position = SPAWN
	player.velocity = Vector3.ZERO
	if player.has_method("cancel_jump"):
		player.cancel_jump()
	player.reset_physics_interpolation()
	camera.position = CAMERA_OFFSET
