extends Node3D

const PlayerFactory := preload("res://scripts/world_map_player_factory.gd")
const PlayerPresentation := preload("res://scripts/world_map_presentation.gd")
const SourceTerrain := preload("res://scripts/world_map_source_terrain.gd")
const LocalExposure := preload("res://scripts/world_map_bloom_source.gd")
const CombatAudio := preload("res://scripts/mechanic_lab_combat_audio.gd")
const Sword := preload("res://scripts/mechanic_lab_sword.gd")
const CurvedGreatsword := preload("res://scripts/mechanic_lab_curved_greatsword.gd")
const DamageFeedback := preload("res://scripts/mechanic_lab_zombie_feedback.gd")
const PLAYER_HIT_FLASH_SHADER := preload("res://materials/mechanic_lab_player_hit_flash.gdshader")
const SABRE_RIBBON_SHADER := preload("res://materials/mechanic_lab_sabre_ribbon.gdshader")
const CAMERA_OFFSET := Vector3(12.0, 15.0, 16.0)
const SPAWN := Vector3(0.0, 0.03, 0.0)
const WORLD_MAP_NOON_EXPOSURE := 0.12
const MIN_CAMERA_SIZE := 4.5
const MAX_CAMERA_SIZE := 30.0
const ZOOM_STEP := 1.15
const SABRE_TAP_BUFFER := 0.16
const MAX_PLAYER_HEALTH := 100
const PLAYER_HIT_FLASH_DURATION := 0.10
const PLAYER_DAMAGE_TINT := Color(1.0, 0.18, 0.22)
const CONTACT_LIGHT_DURATION := 0.17
const HEAVY_SHAKE_DURATION := 0.20
const FINISHER_SHAKE_INNER_RADIUS := 1.5
const FINISHER_SHAKE_OUTER_RADIUS := 3.0
const FINISHER_SHAKE_HEIGHT_FRACTION := 0.008
const PRIVATE_CONTROLS := "WASD di chuyển · Shift đi bộ · Space nhảy · Chuột trái / E %s · R về giữa"

enum Weapon { SABRE, SWORD, CURVED_GREATSWORD }

var presentation: Node
var player_health := MAX_PLAYER_HEALTH
var _exposure: CompositorEffect
var _previous_msaa: Viewport.MSAA
var _previous_hdr: bool
var _combat_audio: CombatAudio
var _weapon_mesh: MeshInstance3D
var _equipped_weapon := Weapon.SABRE
var _sabre_mesh: Mesh
var _sword_mesh: Mesh
var _curved_mesh: Mesh
var _sabre_blade_base: Vector3
var _sabre_blade_tip: Vector3
var _sabre_profile: Dictionary
var _sword_profile: Dictionary
var _curved_profile: Dictionary
var _curved_locomotion: Dictionary
var _sabre_audio_aliases: Dictionary
var _sabre_audio_rates: Dictionary
var _shake_serial := -1
var _shake_age := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _light_serial := -1
var _light_remaining := 0.0
var _light_peak := 0.0
var _player_flash_remaining := 0.0
var _player_flash_material: ShaderMaterial
var _player_flash_meshes: Array[MeshInstance3D] = []
var _player_overlays: Dictionary[MeshInstance3D, Material] = {}
var _player_damage_numbers: Node3D
var _player_hit_serial := 0
@onready var player: CharacterBody3D = $Actors/Player
@onready var camera: Camera3D = $Camera3D
@onready var _impact_light: OmniLight3D = $CombatImpactLight
@onready var _player_body := player.get_node_or_null("BodyCollision") as CollisionShape3D

func _enter_tree() -> void:
	presentation = PlayerPresentation.new()
	presentation.name = "RenderPresentation"
	add_child(presentation)
	presentation.begin(self)
	var actor := PlayerFactory.create(PlayerFactory.uses_private_player())
	if "native_jump_pose_enabled" in actor:
		actor.native_jump_pose_enabled = true
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
		$HUD/Controls.text = PRIVATE_CONTROLS % "chém hoặc bổ trên không"
	else:
		$HUD/Controls.text = "WASD di chuyển · Shift chạy · Space nhảy · R về giữa"
	$HUD/Controls.text += " · Cuộn chuột để zoom"
	$HUD/SpawnZombie.disabled = not (using_private and player_ready)
	$HUD/CombatAudioToggle.disabled = $HUD/SpawnZombie.disabled
	$HUD/BaseZombieToggle.disabled = $HUD/SpawnZombie.disabled
	$HUD/DropMedium.disabled = $HUD/SpawnZombie.disabled
	$HUD/DropHigh.disabled = $HUD/SpawnZombie.disabled
	$HUD/PlayerHealth.visible = not $HUD/SpawnZombie.disabled
	$HUD/Weapon.disabled = true
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
		_player_flash_material = ShaderMaterial.new()
		_player_flash_material.shader = PLAYER_HIT_FLASH_SHADER
		for mesh: MeshInstance3D in player.model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				_player_flash_meshes.append(mesh)
		_player_damage_numbers = Node3D.new()
		_player_damage_numbers.name = "PlayerDamageNumbers"
		$CombatEffects.add_child(_player_damage_numbers)
		_set_combat_audio(false)
		var ribbon_material := ShaderMaterial.new()
		ribbon_material.shader = SABRE_RIBBON_SHADER
		player.effects.ribbon.material_override = ribbon_material
		player.combo.native_tap_buffer_seconds = SABRE_TAP_BUFFER
		$Zombies.setup_combat(player)
		player.grounded_melee_aim = $Zombies.aim_sabre
		player.connect("grounded_sabre_impact", $Zombies.strike_sabre)
		player.connect("heavy_jump_landed", $Zombies.land_sabre)
		$Zombies.sabre_contact.connect(_on_sabre_contact)
		$Zombies.sabre_landing.connect(_on_sabre_landing)
		$Zombies.player_hit.connect(_on_player_hit)
		$Zombies.zombie_attack_audio.connect(_combat_audio.zombie_attack)
		_setup_weapon_selector()
	print("MECHANIC_LAB_READY floor=100x100 player_ready=%s source_tiles=%s" % [player_ready, tiles != null])

func _setup_weapon_selector() -> void:
	$HUD/Weapon.add_item("Sabre")
	$HUD/Weapon.add_item("Sword")
	$HUD/Weapon.add_item("Curved Greatsword")
	_weapon_mesh = player.model.find_child("SabrePrototypeSabre", true, false) as MeshInstance3D
	if _weapon_mesh == null or not player.combo.native_enabled:
		return
	_sabre_mesh = _weapon_mesh.mesh
	_sabre_blade_base = player.marker_base.position
	_sabre_blade_tip = player.marker_tip.position
	_sabre_profile = player.runtime_locomotion_profile.combat
	_sword_profile = Sword.combat_profile(_sabre_profile, player.clips)
	_sabre_audio_aliases = player.reference_audio.clip_aliases.duplicate()
	_sabre_audio_rates = player.reference_audio.clip_play_rates.duplicate()
	$HUD/Weapon.disabled = false
	$HUD/Weapon.item_selected.connect(_select_weapon)

func _select_weapon(index: int) -> void:
	if index == _equipped_weapon:
		return
	if player_health == 0 or not player.is_on_floor() or player.combo.active() or player.combo.held:
		$HUD/Weapon.select(_equipped_weapon)
		$HUD/SpawnStatus.text = "Chờ đứng trên đất và kết thúc đòn để đổi vũ khí."
		return
	if not _load_weapon(index):
		$HUD/Weapon.select(_equipped_weapon)
		$HUD/SpawnStatus.text = "Không tải được dữ liệu %s đã xác minh trong MD2 Research." % $HUD/Weapon.get_item_text(index)
		return
	if not player.combo.configure_native(_weapon_profile(index)):
		player.combo.configure_native(_weapon_profile(_equipped_weapon))
		$HUD/Weapon.select(_equipped_weapon)
		$HUD/SpawnStatus.text = "Không thể tải combo của vũ khí này."
		return
	var mesh := _sabre_mesh
	var blade_base := _sabre_blade_base
	var blade_tip := _sabre_blade_tip
	var aliases := _sabre_audio_aliases
	var rates := _sabre_audio_rates
	match index:
		Weapon.SWORD:
			mesh = _sword_mesh
			blade_base = Sword.BLADE_BASE
			blade_tip = Sword.BLADE_TIP
			aliases = Sword.AUDIO_ALIASES
			rates = {"SwordAttack1": 1.0, "SwordAttack2": 1.0, "SwordAttack3": 1.4,
				"SwordAirAttack": player.combo.air_attack_play_rate}
		Weapon.CURVED_GREATSWORD:
			mesh = _curved_mesh
			blade_base = CurvedGreatsword.BLADE_BASE
			blade_tip = CurvedGreatsword.BLADE_TIP
			aliases = {}
			rates = {"NativeCurvedAttack1": CurvedGreatsword.PLAYBACK_RATE,
				"NativeCurvedAttack2": CurvedGreatsword.PLAYBACK_RATE,
				"NativeCurvedAttack3": CurvedGreatsword.PLAYBACK_RATE}
	_weapon_mesh.mesh = mesh
	player.marker_base.position = blade_base
	player.marker_tip.position = blade_tip
	player.reference_audio.reset()
	player.reference_audio.clip_aliases = aliases
	player.reference_audio.clip_play_rates = rates
	player.effects.reset()
	_combat_audio.reset()
	_equipped_weapon = index as Weapon
	var sword_equipped := index == Weapon.SWORD
	var curved_equipped := index == Weapon.CURVED_GREATSWORD
	_combat_audio.sword_equipped = sword_equipped
	_combat_audio.curved_equipped = curved_equipped
	$Zombies.sword_equipped = sword_equipped
	$Zombies.curved_equipped = curved_equipped
	player.aerial_melee_enabled = not curved_equipped
	player.set_weapon_locomotion(_curved_locomotion if curved_equipped else {})
	$HUD/DropMedium.disabled = curved_equipped
	$HUD/DropHigh.disabled = curved_equipped
	var attack_hint := "chém dưới đất" if curved_equipped else "chém hoặc bổ trên không"
	$HUD/Controls.text = (PRIVATE_CONTROLS % attack_hint) + " · Cuộn chuột để zoom"
	$HUD/SpawnStatus.text = "Thiếu dữ liệu tư thế hai tay đã xác minh." if curved_equipped and _curved_locomotion.is_empty() else ""

func _weapon_profile(index: int) -> Dictionary:
	match index:
		Weapon.SWORD:
			return _sword_profile
		Weapon.CURVED_GREATSWORD:
			return _curved_profile
	return _sabre_profile

func _load_weapon(index: int) -> bool:
	if index == Weapon.SABRE or (index == Weapon.SWORD and _sword_mesh != null) \
			or (index == Weapon.CURVED_GREATSWORD and not _curved_profile.is_empty()):
		return true
	var research_root := OS.get_environment("MD2_RESEARCH_ROOT")
	if research_root.is_empty():
		research_root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	if index == Weapon.SWORD:
		_sword_mesh = Sword.load_mesh(player, research_root)
		if _sword_mesh == null:
			return false
		player.reference_audio.add_manifest(research_root, Sword.MEDIA_MANIFEST)
		return true
	_curved_mesh = CurvedGreatsword.load_mesh(player, research_root)
	if _curved_mesh == null:
		return false
	var profile := CurvedGreatsword.combat_profile(research_root)
	player._load_private_combat_clips(profile, CurvedGreatsword.LIBRARY)
	if not player.animation_player.has_animation_library(CurvedGreatsword.LIBRARY):
		return false
	_curved_profile = profile
	_curved_locomotion = CurvedGreatsword.load_locomotion(player, research_root)
	player.reference_audio.add_manifest(research_root, CurvedGreatsword.MEDIA_MANIFEST)
	return true

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
	if not _player_overlays.is_empty():
		if _player_flash_remaining <= 0.0:
			_clear_player_flash()
		else:
			var weight := smoothstep(0.0, PLAYER_HIT_FLASH_DURATION * 0.65, _player_flash_remaining)
			for mesh: MeshInstance3D in _player_overlays:
				mesh.set_instance_shader_parameter(&"player_hit_flash", weight)
			_player_flash_remaining = maxf(0.0, _player_flash_remaining - delta)
	if _shake_duration > 0.0:
		# Sample the hit at age zero on its first displayed frame.
		var decay := 1.0 - _shake_age / _shake_duration
		var pulse := cos(TAU * 15.0 * _shake_age) * decay * decay
		camera.h_offset = camera.size * _shake_strength * pulse
		if _shake_age >= _shake_duration:
			_shake_duration = 0.0
		else:
			_shake_age = minf(_shake_age + delta, _shake_duration)
	if _impact_light.visible:
		var decay := _light_remaining / CONTACT_LIGHT_DURATION
		_impact_light.light_energy = _light_peak * decay * decay
		_impact_light.visible = _light_remaining > 0.0
		_light_remaining = maxf(0.0, _light_remaining - delta)

func _set_combat_audio(enabled: bool) -> void:
	if _combat_audio == null:
		return
	if player.reference_audio != null:
		player.reference_audio.enabled = enabled
	_combat_audio.set_enabled(enabled, player.global_position + Vector3.UP)

func _on_sabre_contact(point: Vector3, direction: Vector3, clip: String, _index: int, serial: int, lethal: bool) -> void:
	player.effects.contact(point, direction)
	_combat_audio.contact(point, serial, lethal)
	var finisher := clip in ["Attack3", "NativeFinisher", "NativeCurvedAttack3"]
	_start_contact_light(point, serial, 2.3 if finisher else 1.8)
	# These finishers share the source radii and non-oriented shake.
	# Approximate StartMatineeCameraShakeAtPawn using the capsule center.
	if not finisher or _shake_serial == serial or _player_body == null:
		return
	var distance := _player_body.global_position.distance_to(point)
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
	if player_health == 0:
		return
	if player.drop_for_lab(height):
		$HUD/SpawnStatus.text = ""
	else:
		$HUD/SpawnStatus.text = "Chờ player chạm đất để thử lại."

func _on_player_hit(amount: int) -> void:
	if player_health == 0 or amount <= 0:
		return
	var lost := mini(player_health, amount)
	player_health -= lost
	$HUD/PlayerHealth.text = "%d / %d HP" % [player_health, MAX_PLAYER_HEALTH]
	_combat_audio.player_hurt()
	_show_player_hit(lost)
	if player_health == 0:
		player.enter_lab_defeat()
		# The popup captures keyboard input while it is open, including R.
		$HUD/Weapon.get_popup().hide()
		$HUD/Weapon.disabled = true
		$HUD/Defeat.show()

func _show_player_hit(lost: int) -> void:
	if _player_overlays.is_empty():
		for mesh: MeshInstance3D in _player_flash_meshes:
			_player_overlays[mesh] = mesh.material_overlay
			mesh.material_overlay = _player_flash_material
	for mesh: MeshInstance3D in _player_overlays:
		mesh.set_instance_shader_parameter(&"player_hit_flash", 1.0)
	_player_flash_remaining = PLAYER_HIT_FLASH_DURATION
	var lateral := camera.global_basis.x * (1.0 if _player_hit_serial % 2 == 0 else -1.0)
	_player_hit_serial += 1
	DamageFeedback.spawn_number(lost, $Zombies.damage_digits(), _player_damage_numbers,
		player.global_position + Vector3.UP * 2.08, lateral, PLAYER_DAMAGE_TINT)

func _clear_player_flash() -> void:
	for mesh: MeshInstance3D in _player_overlays:
		mesh.set_instance_shader_parameter(&"player_hit_flash", 0.0)
		mesh.material_overlay = _player_overlays[mesh]
	_player_overlays.clear()
	_player_flash_remaining = 0.0

func reset_player() -> void:
	if player_health == 0:
		player.is_dead = false
		player.set_process_input(true)
		player.set_process_unhandled_input(true)
		$HUD/Defeat.hide()
		$HUD/Weapon.disabled = _weapon_mesh == null or not player.combo.native_enabled
	player_health = MAX_PLAYER_HEALTH
	$HUD/PlayerHealth.text = "%d / %d HP" % [player_health, MAX_PLAYER_HEALTH]
	_clear_player_flash()
	if _player_damage_numbers != null:
		for number: Node3D in _player_damage_numbers.get_children():
			number.hide()
			number.queue_free()
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
