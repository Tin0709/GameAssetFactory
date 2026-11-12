extends Node3D

const PlayerFactory := preload("res://scripts/world_map_player_factory.gd")
const PlayerPresentation := preload("res://scripts/world_map_presentation.gd")
const SourceTerrain := preload("res://scripts/world_map_source_terrain.gd")
const LocalExposure := preload("res://scripts/world_map_bloom_source.gd")
const CombatAudio := preload("res://scripts/mechanic_lab_combat_audio.gd")
const SABRE_RIBBON_SHADER := preload("res://materials/mechanic_lab_sabre_ribbon.gdshader")
const CAMERA_OFFSET := Vector3(12.0, 15.0, 16.0)
const SPAWN := Vector3(0.0, 0.03, 0.0)
const WORLD_MAP_NOON_EXPOSURE := 0.12
const MIN_CAMERA_SIZE := 4.5
const MAX_CAMERA_SIZE := 30.0
const ZOOM_STEP := 1.15
const SABRE_TAP_BUFFER := 0.16
const CONTACT_LIGHT_DURATION := 0.17
const HEAVY_SHAKE_DURATION := 0.20
const FINISHER_SHAKE_INNER_RADIUS := 1.5
const FINISHER_SHAKE_OUTER_RADIUS := 3.0
const FINISHER_SHAKE_HEIGHT_FRACTION := 0.008

var presentation: Node
var _exposure: CompositorEffect
var _previous_msaa: Viewport.MSAA
var _previous_hdr: bool
var _combat_audio: CombatAudio
var _shake_serial := -1
var _shake_age := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _light_serial := -1
var _light_remaining := 0.0
var _light_peak := 0.0
@onready var player: CharacterBody3D = $Actors/Player
@onready var camera: Camera3D = $Camera3D
@onready var _impact_light: OmniLight3D = $CombatImpactLight

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
		$HUD/Controls.text = "WASD di chuyển · Shift đi bộ · Space nhảy · Chuột trái / E chém hoặc bổ trên không · R về giữa"
	else:
		$HUD/Controls.text = "WASD di chuyển · Shift chạy · Space nhảy · R về giữa"
	$HUD/Controls.text += " · Cuộn chuột để zoom"
	$HUD/SpawnZombie.disabled = not (using_private and player_ready)
	$HUD/CombatAudioToggle.disabled = $HUD/SpawnZombie.disabled
	$HUD/BaseZombieToggle.disabled = $HUD/SpawnZombie.disabled
	$HUD/DropMedium.disabled = $HUD/SpawnZombie.disabled
	$HUD/DropHigh.disabled = $HUD/SpawnZombie.disabled
	$HUD/DropMedium.pressed.connect(_drop_player.bind(5.0))
	$HUD/DropHigh.pressed.connect(_drop_player.bind(7.0))
	if not $HUD/SpawnZombie.disabled:
		player.collision_mask |= 4
		var listener := AudioListener3D.new()
		listener.name = "CombatAudioListener"
		player.add_child(listener)
		listener.position.y = 1.55
		listener.global_basis = camera.global_basis
		listener.make_current()
		_combat_audio = CombatAudio.new()
		_combat_audio.name = "CombatAudio"
		add_child(_combat_audio)
		_set_combat_audio(false)
		var ribbon_material := ShaderMaterial.new()
		ribbon_material.shader = SABRE_RIBBON_SHADER
		player.effects.ribbon.material_override = ribbon_material
		player.combo.native_tap_buffer_seconds = SABRE_TAP_BUFFER
		$Zombies.setup_combat(player, player.clips, player.combo.native_windows)
		player.connect("attack_pose_sample", $Zombies.sample_sabre)
		player.connect("heavy_jump_landed", $Zombies.land_sabre)
		$Zombies.sabre_contact.connect(_on_sabre_contact)
		$Zombies.sabre_landing.connect(_on_sabre_landing)
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
		camera.h_offset = camera.size * _shake_strength * pulse
	if _light_remaining > 0.0:
		_light_remaining = maxf(0.0, _light_remaining - delta)
		var decay := _light_remaining / CONTACT_LIGHT_DURATION
		_impact_light.light_energy = _light_peak * decay * decay
		_impact_light.visible = _light_remaining > 0.0

func _set_combat_audio(enabled: bool) -> void:
	if _combat_audio == null:
		return
	if player.reference_audio != null:
		player.reference_audio.enabled = enabled
	_combat_audio.set_enabled(enabled, player.global_position + Vector3.UP)

func _on_sabre_contact(point: Vector3, direction: Vector3, clip: String, _index: int, serial: int, lethal: bool) -> void:
	player.effects.contact(point, direction)
	_combat_audio.contact(point, serial, lethal)
	var finisher := clip in ["Attack3", "NativeFinisher"]
	_start_contact_light(point, serial, 2.3 if finisher else 1.8)
	# Sabre_3 is the only grounded variant with a shake class. Its radius and
	# non-oriented flag come from the row; the lab waveform is an approximation.
	if not finisher or _shake_serial == serial:
		return
	var offset := point - player.global_position
	var distance := Vector2(offset.x, offset.z).length()
	var falloff := 1.0 - clampf(inverse_lerp(FINISHER_SHAKE_INNER_RADIUS, FINISHER_SHAKE_OUTER_RADIUS, distance), 0.0, 1.0)
	if falloff <= 0.0:
		return
	_shake_serial = serial
	_shake_strength = FINISHER_SHAKE_HEIGHT_FRACTION * falloff
	_shake_age = 0.0
	_shake_duration = HEAVY_SHAKE_DURATION

func _on_sabre_landing(point: Vector3, serial: int) -> void:
	player.effects.contact(point + Vector3.UP * 0.12, Vector3.UP)
	_start_contact_light(point + Vector3.UP * 0.60, serial, 2.3)
	_combat_audio.slam_landed(point)

func _start_contact_light(point: Vector3, serial: int, energy: float) -> void:
	if _light_serial == serial:
		return
	_light_serial = serial
	_light_peak = energy
	_light_remaining = CONTACT_LIGHT_DURATION
	_impact_light.global_position = point
	_impact_light.light_energy = _light_peak
	_impact_light.show()

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
	if $Zombies.spawn(player, facing, $CombatEffects, $HUD/BaseZombieToggle.button_pressed):
		$HUD/SpawnStatus.text = ""
	else:
		$HUD/SpawnStatus.text = "Không thể tạo zombie. Kiểm tra dữ liệu MD2 Research và chỗ trống."

func _drop_player(height: float) -> void:
	if player.drop_for_lab(height):
		$HUD/SpawnStatus.text = ""
	else:
		$HUD/SpawnStatus.text = "Chờ player chạm đất để thử lại."

func reset_player() -> void:
	_shake_serial = -1
	_shake_duration = 0.0
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	_light_serial = -1
	_light_remaining = 0.0
	_impact_light.light_energy = 0.0
	_impact_light.hide()
	if _combat_audio != null:
		_combat_audio.reset()
	player.position = SPAWN
	player.velocity = Vector3.ZERO
	if player.has_method("cancel_jump"):
		player.cancel_jump()
	player.reset_physics_interpolation()
	camera.position = CAMERA_OFFSET
