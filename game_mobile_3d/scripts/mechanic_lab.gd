extends Node3D

const PlayerFactory := preload("res://scripts/world_map_player_factory.gd")
const PlayerPresentation := preload("res://scripts/world_map_presentation.gd")
const SourceTerrain := preload("res://scripts/world_map_source_terrain.gd")
const WorldLook := preload("res://scripts/world_map_look.gd")
const WorldShowcase := preload("res://scripts/world_map_showcase.gd")
const WorldAmbient := preload("res://scripts/world_map_ambient.gd")
const CombatAudio := preload("res://scripts/mechanic_lab_combat_audio.gd")
const MovementAudio := preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/environment_audio.gd")
const MovementDust := preload("res://scripts/mechanic_lab_movement_dust.gd")
const ZombieStepDust := preload("res://scripts/mechanic_lab_zombie_step_dust.gd")
const MovementWind := preload("res://scripts/mechanic_lab_movement_wind.gd")
const PrivateOverworldBundle := preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/private_bundle.gd")
const Sword := preload("res://scripts/mechanic_lab_sword.gd")
const CurvedGreatsword := preload("res://scripts/mechanic_lab_curved_greatsword.gd")
const WeaponSource := preload("res://scripts/mechanic_lab_weapon_source.gd")
const CrossPollinator := preload("res://scripts/mechanic_lab_cross_pollinator.gd")
const Gauntlets := preload("res://scripts/mechanic_lab_gauntlets.gd")
const MeleeTools := preload("res://scripts/mechanic_lab_melee_tools.gd")
const Bow := preload("res://scripts/mechanic_lab_bow.gd")
const IDLE_NOVELTIES := {
	"NativeLabBowLook": ["Player_Idle_Novelty_LookAround",
		"0961de63ea6a6e30ae524952f937604ad574aac02fa9fd8cd0bf016862556661"],
	"NativeLabCrossbowLook": ["Player_Idle_Novelty_LookAround_Crossbow",
		"c335441d8c7cac9f55955c05af45f152d8f834cefef681c7bd027e19695a03cd"],
	"NativeLabFistsInspect": ["Player_Idle_Novelty_ExamineWeapon_Fists",
		"d33fc4646df532e404ad9e8ce9e74d7675b0e83795584b61e42755b0c4756c70"],
}
const DamageFeedback := preload("res://scripts/mechanic_lab_zombie_feedback.gd")
const HealthBars := preload("res://scripts/mechanic_lab_health_bars.gd")
const DamageNumbers := preload("res://scripts/mechanic_lab_damage_numbers.gd")
const PLAYER_HIT_FLASH_SHADER := preload("res://materials/mechanic_lab_player_hit_flash.gdshader")
const ContactSparks := preload("res://scripts/mechanic_lab_contact_sparks.gd")
const CAMERA_OFFSET := Vector3(12.0, 15.0, 16.0)
const SPAWN := Vector3(0.0, 0.03, 0.0)
const MIN_CAMERA_SIZE := 4.5
const MAX_CAMERA_SIZE := 30.0
const ZOOM_STEP := 1.15
const SABRE_TAP_BUFFER := 0.16
const MAX_PLAYER_HEALTH := 100
const CROWD_SPAWN_COUNT := 100
const CROWD_SPAWN_LIMIT_PER_FRAME := 5
const CROWD_SPAWN_BUDGET_USEC := 2500
const PLAYER_HIT_FLASH_DURATION := 0.10
const PLAYER_DAMAGE_TINT := Color(1.0, 0.18, 0.22)
const CONTACT_LIGHT_DURATION := 0.17
const HEAVY_SHAKE_DURATION := 0.20
const FINISHER_SHAKE_INNER_RADIUS := 1.5
const FINISHER_SHAKE_OUTER_RADIUS := 3.0
const FINISHER_SHAKE_HEIGHT_FRACTION := 0.008
const PRIVATE_CONTROLS := "WASD di chuyển · Shift đi bộ · Space nhảy · Chuột trái / E %s · R về giữa"
const TIME_PRESETS := [2.5, 7.0, 12.0, 16.5, 18.5, 19.5, 22.0]
# AM_Player_Sabre_JumpAttack: first PostAudioEvent minus LandingStart.
const SABRE_LANDING_SWING_DELAY := 0.033083633
# AM_Player_Sabre_JumpAttack: PlayDebrisEffect minus LandingStart.
const SABRE_LANDING_DEBRIS_DELAY := 0.045126423
# AM_Player_Sabre_JumpAttack: CameraShakeNotify_C minus LandingStart.
const SABRE_LANDING_SHAKE_DELAY := 0.052268848
# AM_Player_Sabre_JumpAttack: one-shot PlayNiagaraEffect minus LandingStart.
const SABRE_LANDING_BURST_DELAY := 0.056890413

enum Weapon { SABRE, SWORD, CURVED_GREATSWORD, CROSS_POLLINATOR, GAUNTLETS,
	CLEAVER, BOW, BASIC_GAUNTLETS, PICKAXE, SHOVEL }
const TOOL_TYPES := {
	Weapon.CLEAVER: MeleeTools.Tool.CLEAVER,
	Weapon.PICKAXE: MeleeTools.Tool.PICKAXE,
	Weapon.SHOVEL: MeleeTools.Tool.SHOVEL,
}
const MELEE_AUDIO_NAMES := {
	Weapon.CLEAVER: &"cleaver", Weapon.BASIC_GAUNTLETS: &"gauntlet",
	Weapon.PICKAXE: &"pickaxe", Weapon.SHOVEL: &"shovel",
}

var presentation: Node
var look: WorldLook
var showcase: WorldShowcase
var view_mode := "gameplay"
var spawn_position := SPAWN
var player_health := MAX_PLAYER_HEALTH
var _crowd_spawns_left := 0
var _crowd_base_health := false
var _previous_msaa: Viewport.MSAA
var _combat_audio: CombatAudio
var _zombie_step_dust: ZombieStepDust
var _slam_swing_frame := -1
var _slam_swing_serial := -1
var _slam_audio_frame := -1
var _slam_audio_point: Vector3
var _contact_sparks: ContactSparks
var _movement_audio: MovementAudio
var _weapon_mesh: MeshInstance3D
var _equipped_weapon := Weapon.SABRE
var _sabre_mesh: Mesh
var _sabre_mesh_transform: Transform3D
var _sword_mesh: Mesh
var _curved_mesh: Mesh
var _sabre_blade_base: Vector3
var _sabre_blade_tip: Vector3
var _sabre_profile: Dictionary
var _sword_profile: Dictionary
var _curved_profile: Dictionary
var _curved_locomotion: Dictionary
var _crossbow: CrossPollinator
var _crossbow_mount: MeshInstance3D
var _crossbow_profile: Dictionary
var _crossbow_locomotion: Dictionary
var _right_gauntlet: MeshInstance3D
var _left_gauntlet: MeshInstance3D
var _gauntlet_profile: Dictionary
var _basic_gauntlet_profile: Dictionary
var _basic_gauntlet_mounts: Array[MeshInstance3D]
var _tools := {}
var _bow: Bow
var _bow_mount: MeshInstance3D
var _bow_profile: Dictionary
var _sabre_air_clip: Dictionary
var _default_idle_novelty: Dictionary
var _sabre_air_rate := 1.0
var _sabre_audio_aliases: Dictionary
var _sabre_audio_rates: Dictionary
var _shake_serial := -1
var _shake_age := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _shake_pending := false
var _slam_shake_frame := -1
var _slam_burst_frame := -1
var _slam_burst_point: Vector3
var _slam_burst_serial := -1
var _light_serial := -1
var _light_remaining := 0.0
var _light_peak := 0.0
var _light_pending := false
var _player_flash_remaining := 0.0
var _player_flash_pending := false
var _player_flash_material: ShaderMaterial
var _player_flash_meshes: Array[MeshInstance3D] = []
var _player_overlays: Dictionary[MeshInstance3D, Material] = {}
var _player_damage_numbers: Node3D
var _pending_player_damage := 0
var _player_damage_tick := -1
var _player_damage_origin: Vector3
var _player_hit_serial := 0
var _foot_contact_tick := -1
var _foot_contact_sole: Vector3
var _foot_contact: Dictionary
var _landing_contact_tick := -1
var _landing_contact_point: Vector3
var _landing_contact: Dictionary
@onready var player: CharacterBody3D = $Actors/Player
@onready var camera: Camera3D = $Camera3D
@onready var _impact_light: OmniLight3D = $CombatImpactLight
@onready var _player_body := player.get_node_or_null("BodyCollision") as CollisionShape3D

func _enter_tree() -> void:
	presentation = PlayerPresentation.new()
	presentation.name = "RenderPresentation"
	add_child(presentation)
	presentation.begin(self)
	var using_private := PlayerFactory.uses_private_player()
	var actor: CharacterBody3D
	const LAB_PLAYER := "res://scripts/mechanic_lab_player.gd"
	if using_private and OS.has_feature("editor") and ResourceLoader.exists(LAB_PLAYER):
		actor = load(LAB_PLAYER).new()
	else:
		actor = PlayerFactory.create(using_private)
	if "native_jump_pose_enabled" in actor:
		actor.native_jump_pose_enabled = true
	actor.name = "Player"
	actor.position = SPAWN
	$Actors.add_child(actor)

func _ready() -> void:
	_setup_world_look()
	var material := $Ground/Mesh.material_override as ShaderMaterial
	var tiles := SourceTerrain.load_tiles()
	if tiles != null:
		material.set_shader_parameter("source_terrain_tiles", tiles)
		material.set_shader_parameter("use_source_terrain", true)

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
	$HUD/SpawnCrowd.disabled = $HUD/SpawnZombie.disabled
	$HUD/CombatAudioToggle.disabled = $HUD/SpawnZombie.disabled
	$HUD/BaseZombieToggle.disabled = $HUD/SpawnZombie.disabled
	$HUD/RagdollTuning.visible = not $HUD/SpawnZombie.disabled
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
		_combat_audio.zombie_listener = listener
		add_child(_combat_audio)
		_setup_movement_audio()
		var dust := MovementDust.new()
		dust.name = "MovementDust"
		if dust.setup(player, null, _player_foot_contact_at, _heavy_debris_delay, _grass_landing_contact_at,
				player.source_step_dust_size, true):
			dust.use_source_landing()
			add_child(dust)
			var zombie_dust := ZombieStepDust.new()
			zombie_dust.name = "ZombieStepDust"
			if dust.setup_zombie_steps(zombie_dust):
				_zombie_step_dust = zombie_dust
				add_child(zombie_dust)
			else:
				zombie_dust.free()
		else:
			dust.free()
		var wind := MovementWind.new()
		wind.name = "MovementWind"
		if wind.setup(player, _player_foot_contact_at, true):
			add_child(wind)
		else:
			wind.free()
		var contact_sparks := ContactSparks.new()
		contact_sparks.name = "ContactSparks"
		if contact_sparks.setup():
			_contact_sparks = contact_sparks
			add_child(_contact_sparks)
			player.presentation_reset.connect(_contact_sparks.clear)
		else:
			contact_sparks.free()
		_player_flash_material = ShaderMaterial.new()
		_player_flash_material.shader = PLAYER_HIT_FLASH_SHADER
		for mesh: MeshInstance3D in player.model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				_player_flash_meshes.append(mesh)
		_player_damage_numbers = Node3D.new()
		_player_damage_numbers.name = "PlayerDamageNumbers"
		$CombatEffects.add_child(_player_damage_numbers)
		_set_combat_audio(false)
		player.combo.native_tap_buffer_seconds = SABRE_TAP_BUFFER
		player.combo.use_sabre_air_sections = true
		player.attack_accepted_timed.disconnect(player.reference_audio.trigger_attack)
		player.attack_accepted_timed.connect(_on_attack_accepted_timed)
		var bars := HealthBars.new()
		bars.name = "ZombieHealthBars"
		add_child(bars)
		$Zombies.health_bars = bars
		$Zombies.setup_combat(player)
		var glyphs: Array[Texture2D] = $Zombies.damage_digits()
		if glyphs.size() == DamageNumbers.DIGIT_COUNT:
			var numbers := DamageNumbers.new()
			numbers.name = "ZombieDamageNumbers"
			numbers.setup(glyphs)
			$CombatEffects.add_child(numbers)
			$Zombies.damage_numbers = numbers
		player.grounded_melee_aim = $Zombies.aim_sabre
		player.bow_target = $Zombies.bow_aim_point
		player.bow_drawn.connect(_on_bow_drawn)
		player.bow_released.connect(_on_bow_released)
		player.connect("grounded_sabre_impact", _on_grounded_attack)
		player.connect("heavy_jump_landed", _on_heavy_jump_landed)
		player.presentation_reset.connect($Zombies.cancel_pending_landings)
		player.presentation_reset.connect(_cancel_slam_audio)
		player.presentation_reset.connect(_clear_camera_shake)
		player.presentation_reset.connect(_clear_contact_light)
		$Zombies.sabre_contact.connect(_on_sabre_contact)
		$Zombies.sabre_landing.connect(_on_sabre_landing)
		$Zombies.player_hit.connect(_on_player_hit)
		$Zombies.zombie_attack_audio.connect(_combat_audio.zombie_attack)
		$Zombies.zombie_step_audio.connect(_on_zombie_step)
		_setup_weapon_selector()
	print("MECHANIC_LAB_READY floor=100x100 player_ready=%s source_tiles=%s" % [player_ready, tiles != null])

func _setup_weapon_selector() -> void:
	$HUD/Weapon.add_item("Sabre")
	$HUD/Weapon.add_item("Sword")
	$HUD/Weapon.add_item("Curved Greatsword")
	_add_weapon_option("The Cross Pollinator", CrossPollinator.icon())
	_add_weapon_option("Prime Enchanter's Gauntlets", Gauntlets.icon())
	_add_weapon_option("Meat Cleaver", MeleeTools.icon(MeleeTools.Tool.CLEAVER))
	_add_weapon_option("Bow", Bow.icon())
	_add_weapon_option("Gauntlets", Gauntlets.icon(true))
	_add_weapon_option("Pickaxe", MeleeTools.icon(MeleeTools.Tool.PICKAXE))
	_add_weapon_option("Shovel", MeleeTools.icon(MeleeTools.Tool.SHOVEL))
	_weapon_mesh = player.model.find_child("SabrePrototypeSabre", true, false) as MeshInstance3D
	if _weapon_mesh == null or not player.combo.native_enabled:
		return
	_sabre_mesh = _weapon_mesh.mesh
	_sabre_mesh_transform = _weapon_mesh.transform
	# The light rig stores surface overrides for the original Sabre mesh.
	_sabre_blade_base = player.marker_base.position
	_sabre_blade_tip = player.marker_tip.position
	_sabre_profile = player.runtime_locomotion_profile.combat
	_sabre_air_clip = player.clips.AirAttack
	_default_idle_novelty = player.clips.InspectWeapon
	_sabre_air_rate = player.combo.air_attack_play_rate
	_sword_profile = Sword.combat_profile(_sabre_profile, player.clips)
	_sabre_audio_aliases = player.reference_audio.clip_aliases.duplicate()
	_sabre_audio_rates = player.reference_audio.clip_play_rates.duplicate()
	$HUD/Weapon.disabled = false
	$HUD/Weapon.item_selected.connect(_select_weapon)

func _add_weapon_option(label: String, icon: Texture2D) -> void:
	if icon == null:
		$HUD/Weapon.add_item(label)
	else:
		$HUD/Weapon.add_icon_item(icon, label)

func _select_weapon(index: int) -> void:
	if index == _equipped_weapon:
		return
	if player_health == 0 or not player.is_on_floor() or player.combo.active() or player.combo.held or player.bow_busy():
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
	var locomotion := {}
	var tool: int = TOOL_TYPES.get(index, -1)
	var tool_weapon: Dictionary = _tools.get(index, {})
	var bow_equipped := index == Weapon.BOW
	var basic_gauntlets := index == Weapon.BASIC_GAUNTLETS
	var gauntlets_equipped := index == Weapon.GAUNTLETS or basic_gauntlets
	_weapon_mesh.transform = _sabre_mesh_transform
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
			locomotion = _curved_locomotion
			blade_base = CurvedGreatsword.BLADE_BASE
			blade_tip = CurvedGreatsword.BLADE_TIP
			aliases = {}
			rates = {"NativeCurvedAttack1": CurvedGreatsword.PLAYBACK_RATE,
				"NativeCurvedAttack2": CurvedGreatsword.PLAYBACK_RATE,
				"NativeCurvedAttack3": CurvedGreatsword.PLAYBACK_RATE}
		Weapon.CROSS_POLLINATOR:
			locomotion = _crossbow_locomotion
			blade_tip = blade_base
			aliases = {}
			rates = {}
		Weapon.GAUNTLETS, Weapon.BASIC_GAUNTLETS, Weapon.BOW:
			blade_tip = blade_base
			aliases = {}
			rates = {}
	if tool >= 0:
		mesh = tool_weapon.mesh
		locomotion = tool_weapon.locomotion
		_weapon_mesh.transform = MeleeTools.mount_transform(tool)
		blade_base = _weapon_mesh.transform * MeleeTools.blade_base(tool)
		blade_tip = _weapon_mesh.transform * MeleeTools.blade_tip(tool)
		aliases = {}
		rates = {}
	# The original mount is tracked by the player lighting rig, which keeps
	# a Sabre surface override. Use the equipped tool's own texture instead.
	_weapon_mesh.material_override = mesh.surface_get_material(0) if tool >= 0 else null
	_weapon_mesh.visible = index != Weapon.CROSS_POLLINATOR and not bow_equipped and not gauntlets_equipped
	if _weapon_mesh.visible:
		_weapon_mesh.mesh = mesh
	if _crossbow_mount != null:
		_crossbow_mount.visible = index == Weapon.CROSS_POLLINATOR
	if _left_gauntlet != null:
		_left_gauntlet.visible = index == Weapon.GAUNTLETS
		_right_gauntlet.visible = index == Weapon.GAUNTLETS
	for mount in _basic_gauntlet_mounts:
		mount.visible = basic_gauntlets
	if _bow_mount != null:
		_bow_mount.visible = bow_equipped
	player.marker_base.position = blade_base
	player.marker_tip.position = blade_tip
	player.reference_audio.reset()
	player.reference_audio.clip_aliases = aliases
	player.reference_audio.clip_play_rates = rates
	player.effects.reset()
	_cancel_slam_audio()
	_combat_audio.reset()
	var was_crossbow := _equipped_weapon == Weapon.CROSS_POLLINATOR
	var was_bow := _equipped_weapon == Weapon.BOW
	_equipped_weapon = index as Weapon
	var sword_equipped := index == Weapon.SWORD
	var curved_equipped := index == Weapon.CURVED_GREATSWORD
	var crossbow_equipped := index == Weapon.CROSS_POLLINATOR
	if crossbow_equipped != was_crossbow:
		_combat_audio.crossbow_switched(crossbow_equipped, player.global_position + Vector3.UP)
	if bow_equipped != was_bow:
		_bow.play_switch(bow_equipped, player.global_position + Vector3.UP)
	player.active_clip = ""
	# Switching out of a special locomotion profile restores the source slots first.
	player.crossbow_equipped = crossbow_equipped
	player.bow_equipped = bow_equipped
	player.gauntlets_equipped = gauntlets_equipped
	player.clips.AirAttack = player.clips[Gauntlets.AIR] if gauntlets_equipped else _sabre_air_clip
	player.tool_air_hold = -1.0
	player.tool_air_loop = -1.0
	player.tool_air_landing = -1.0
	if tool >= 0:
		player.clips.AirAttack = player.clips[MeleeTools.air_clip(tool)]
		player.tool_air_hold = MeleeTools.air_hold_time(tool)
		player.tool_air_loop = MeleeTools.air_loop_time(tool)
		player.tool_air_landing = MeleeTools.air_landing_time(tool)
	player.combo.air_attack_play_rate = 1.0 if gauntlets_equipped else _sabre_air_rate
	if tool >= 0:
		player.combo.air_attack_play_rate = MeleeTools.air_rate(tool)
	player.combo.use_sabre_air_sections = index == Weapon.SABRE
	_combat_audio.sword_equipped = sword_equipped
	_combat_audio.curved_equipped = curved_equipped
	_combat_audio.gauntlets_equipped = gauntlets_equipped
	$Zombies.sword_equipped = sword_equipped
	$Zombies.curved_equipped = curved_equipped
	$Zombies.gauntlets_equipped = gauntlets_equipped
	$Zombies.crossbow_equipped = crossbow_equipped
	$Zombies.equipped_strikes = MeleeTools.strikes(tool) if tool >= 0 else (Gauntlets.BASE_STRIKES if basic_gauntlets else [])
	$Zombies.equipped_air_strike = MeleeTools.air_strike(tool) if tool >= 0 else (Gauntlets.BASE_AIR_STRIKE if basic_gauntlets else {})
	$Zombies.equipped_air_offset = MeleeTools.air_offset(tool) if tool >= 0 else Gauntlets.AIR_OFFSET
	$Zombies.equipped_air_delay = MeleeTools.air_contact_delay(tool) if tool >= 0 else 0.0
	$HUD/CrossbowAmmo.visible = crossbow_equipped or bow_equipped
	if bow_equipped:
		_set_bow_ammo(_bow.ammo)
	elif crossbow_equipped:
		_set_crossbow_ammo(_crossbow.ammo)
	player.aerial_melee_enabled = not curved_equipped and not bow_equipped
	player.set_weapon_locomotion({})
	player.clips.InspectWeapon = _default_idle_novelty
	player.set_weapon_locomotion(locomotion)
	_set_weapon_idle_novelty(index)
	$HUD/DropMedium.disabled = curved_equipped
	$HUD/DropHigh.disabled = curved_equipped
	var attack_hint := "chém dưới đất" if curved_equipped else "chém hoặc bổ trên không"
	if crossbow_equipped:
		attack_hint = "bắn nỏ"
	elif bow_equipped:
		attack_hint = "giữ để kéo cung, thả để bắn"
	elif gauntlets_equipped:
		attack_hint = "đấm hoặc bổ trên không"
	$HUD/Controls.text = (PRIVATE_CONTROLS % attack_hint) + " · Cuộn chuột để zoom"
	$HUD/SpawnStatus.text = "Thiếu dữ liệu tư thế hai tay đã xác minh." if curved_equipped and _curved_locomotion.is_empty() else ""

func _set_weapon_idle_novelty(index: int) -> void:
	var key := ""
	match index:
		Weapon.BOW:
			key = "NativeLabBowLook"
		Weapon.CROSS_POLLINATOR:
			key = "NativeLabCrossbowLook"
		Weapon.GAUNTLETS, Weapon.BASIC_GAUNTLETS:
			key = "NativeLabFistsInspect"
	if not key.is_empty():
		if not player.clips.has(key):
			var source: Array = IDLE_NOVELTIES[key]
			var clip := WeaponSource.clip(WeaponSource.research_root(), WeaponSource.ANIMATIONS + "Novelties/",
				source[0], key, 80, source[1], "inspection")
			player._load_private_clip_library([clip], StringName("private_" + key))
		if player.clips.has(key):
			player.clips.InspectWeapon = player.clips[key]
	if index == Weapon.CURVED_GREATSWORD and not _curved_locomotion.is_empty():
		_keep_idle_face_tracks_invertible(player.clips.InspectWeapon)
	elif index == Weapon.SHOVEL:
		_keep_idle_face_tracks_invertible(player.clips.Idle)
	player._idle_wait = 0.0
	player._inspect_age = 0.0
	player._inspecting = false

func _keep_idle_face_tracks_invertible(clip: Dictionary) -> void:
	var animation: Animation = player.animation_player.get_animation(clip.action)
	if animation.has_meta(&"lab_safe_face_scale"):
		return
	# The source hides some facial elements with exactly zero scale. Keep
	# them visually collapsed while allowing Godot to blend the basis.
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_SCALE_3D:
			continue
		if animation.track_get_path(track).get_subname(0) not in [
				&"J_L_EyeIris", &"J_L_EyePupil", &"J_R_EyeIris", &"J_R_EyePupil"]:
			continue
		for frame in animation.track_get_key_count(track):
			var scale: Vector3 = animation.track_get_key_value(track, frame)
			var original := scale
			for axis in 3:
				if absf(scale[axis]) < 0.0001:
					scale[axis] = -0.0001 if scale[axis] < 0.0 else 0.0001
			if scale != original:
				animation.track_set_key_value(track, frame, scale)
	animation.set_meta(&"lab_safe_face_scale", true)

func _weapon_profile(index: int) -> Dictionary:
	if _tools.has(index):
		return _tools[index].profile
	match index:
		Weapon.SWORD:
			return _sword_profile
		Weapon.CURVED_GREATSWORD:
			return _curved_profile
		Weapon.CROSS_POLLINATOR:
			return _crossbow_profile
		Weapon.GAUNTLETS:
			return _gauntlet_profile
		Weapon.BASIC_GAUNTLETS:
			return _basic_gauntlet_profile
		Weapon.BOW:
			return _bow_profile
	return _sabre_profile

func _load_weapon(index: int) -> bool:
	if index == Weapon.SABRE or (index == Weapon.SWORD and _sword_mesh != null) \
			or (index == Weapon.CURVED_GREATSWORD and not _curved_profile.is_empty()):
		return true
	var research_root := WeaponSource.research_root()
	if index == Weapon.CROSS_POLLINATOR:
		return _load_crossbow(research_root)
	if index == Weapon.BOW:
		return _load_bow(research_root)
	if index == Weapon.GAUNTLETS:
		return _load_gauntlets(research_root)
	if index == Weapon.BASIC_GAUNTLETS:
		return _load_gauntlets(research_root, true)
	if TOOL_TYPES.has(index):
		return _load_tool(index, research_root)
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

func _load_crossbow(root: String) -> bool:
	if _crossbow != null:
		return true
	var carry_mesh := CrossPollinator.load_mesh(player, root, false)
	var recoil_mesh := CrossPollinator.load_mesh(player, root, true)
	var bolt := CrossPollinator.load_bolt(player, root)
	if carry_mesh == null or recoil_mesh == null or bolt == null:
		return false
	var profile := CrossPollinator.combat_profile(root)
	if not player.animation_player.has_animation_library(CrossPollinator.LIBRARY):
		player._load_private_combat_clips(profile, CrossPollinator.LIBRARY)
		if not player.animation_player.has_animation_library(CrossPollinator.LIBRARY):
			return false
		CrossPollinator.interpolate_shot_poses(player)
	_crossbow_locomotion = CrossPollinator.load_locomotion(player, root)
	if _crossbow_locomotion.is_empty():
		return false
	if player.hybrid_motion != null:
		player.hybrid_motion.set_crossbow_carry(_crossbow_locomotion.gait.sample("Walk", 0.0))
	var socket := BoneAttachment3D.new()
	socket.name = "LabCrossbowSocket"
	socket.bone_name = &"J_L_Hand"
	player.skeleton.add_child(socket)
	_crossbow_mount = _mount_weapon(carry_mesh, socket, "LabCrossbow",
		Transform3D(Basis.IDENTITY, CrossPollinator.MESH_OFFSET), -CrossPollinator.MESH_OFFSET)
	player.configure_crossbow_mount(_crossbow_mount, carry_mesh, recoil_mesh)
	_crossbow_profile = profile
	_crossbow = CrossPollinator.new()
	_crossbow.name = "CrossPollinator"
	_crossbow.bolt_mesh = bolt
	_crossbow.ammo_changed.connect(_set_crossbow_ammo)
	_crossbow.shot_fired.connect(_combat_audio.crossbow_fired)
	_crossbow.bolt_impact.connect(_on_crossbow_impact)
	_crossbow.bolt_launched.connect(_combat_audio.crossbow_flight)
	_crossbow.bolt_ended.connect(_combat_audio.stop_crossbow_flight)
	$CombatEffects.add_child(_crossbow)
	_set_crossbow_ammo(_crossbow.ammo)
	_combat_audio.load_crossbow(root)
	return true

func _on_crossbow_impact(hit: Dictionary, direction: Vector3, serial: int) -> void:
	_combat_audio.crossbow_impact(hit.position)
	$Zombies.strike_bolt(hit, direction, serial)

func _load_gauntlets(root: String, basic := false) -> bool:
	if (basic and not _basic_gauntlet_mounts.is_empty()) or (not basic and _left_gauntlet != null):
		return true
	var mesh := Gauntlets.load_mesh(player, root, basic)
	if mesh == null:
		return false
	var profile := Gauntlets.combat_profile(root, basic)
	if not player.animation_player.has_animation_library(Gauntlets.LIBRARY):
		player._load_private_combat_clips(profile, Gauntlets.LIBRARY)
	if not player.animation_player.has_animation_library(Gauntlets.LIBRARY):
		return false
	if basic:
		_basic_gauntlet_mounts.assign([_mount_gauntlet(mesh, true, true), _mount_gauntlet(mesh, false, true)])
		_basic_gauntlet_profile = profile
	else:
		_left_gauntlet = _mount_gauntlet(mesh, true)
		_right_gauntlet = _mount_gauntlet(mesh, false)
		_gauntlet_profile = profile
	_combat_audio.load_gauntlets(root, basic)
	return true

func _mount_gauntlet(mesh: Mesh, left: bool, basic := false) -> MeshInstance3D:
	var socket := BoneAttachment3D.new()
	var mesh_name := "LabLeftGauntlet" if left else "LabRightGauntlet"
	if basic:
		mesh_name += "Basic"
	socket.name = mesh_name + "Socket"
	socket.bone_name = "J_L_Arm" if left else "J_R_Arm"
	player.skeleton.add_child(socket)
	var color := Gauntlets.LEFT_GLOW if left else Gauntlets.RIGHT_GLOW
	return _mount_weapon(mesh if basic else Gauntlets.with_edge_color(mesh, color), socket, mesh_name,
		Gauntlets.mount_transform(left, basic))

func _load_tool(index: int, root: String) -> bool:
	if _tools.has(index):
		return true
	var tool: int = TOOL_TYPES[index]
	var mesh := MeleeTools.load_mesh(player, root, tool)
	if mesh == null:
		return false
	var profile := MeleeTools.combat_profile(root, tool)
	if not MeleeTools.load_combat_clips(player, profile, tool):
		return false
	var locomotion := MeleeTools.load_locomotion(player, root, tool)
	if index == Weapon.SHOVEL and locomotion.is_empty():
		return false
	_tools[index] = {"mesh": mesh, "profile": profile, "locomotion": locomotion}
	_combat_audio.load_melee_tool(root, MELEE_AUDIO_NAMES[index])
	return true

func _load_bow(root: String) -> bool:
	if _bow != null:
		return true
	var meshes := Bow.load_bow_meshes(player, root)
	var arrow := Bow.load_bolt(player, root)
	if meshes.is_empty() or arrow == null or not Bow.load_action(player, root):
		return false
	var socket := BoneAttachment3D.new()
	socket.name = "LabBowSocket"
	socket.bone_name = &"J_L_Hand"
	player.skeleton.add_child(socket)
	_bow_mount = _mount_weapon(meshes[0], socket, "LabBow", Transform3D.IDENTITY)
	player.configure_bow_mount(_bow_mount, meshes)
	_bow_profile = Bow.combat_profile(root)
	_bow = Bow.new()
	_bow.name = "Bow"
	_bow.bolt_mesh = arrow
	_bow.ammo_changed.connect(_set_bow_ammo)
	_bow.arrow_impact.connect(_on_bow_impact)
	$CombatEffects.add_child(_bow)
	_bow.setup_audio(_combat_audio, root)
	player.bow_can_draw = func() -> bool: return _bow.ammo > 0
	return true

func _on_bow_drawn() -> void:
	if _bow.ammo > 0:
		_bow.play_charge(player.global_position + Vector3.UP)

func _on_bow_released(serial: int, charged: bool, target: Variant) -> void:
	var forward: Vector3 = player.visual.global_basis.z.normalized()
	var origin := _bow_mount.global_position + forward * Bow.ARROW_OFFSET.z
	var direction := forward
	if target is Vector3:
		var aim: Vector3 = target - origin
		if player.combat_requested:
			aim.y = 0.0
		if not aim.is_zero_approx():
			direction = aim.normalized()
	var clearance := Vector3(player.global_position.x, origin.y, player.global_position.z)
	_bow.fire_arrow(origin, direction, serial, clearance, charged)

func _on_bow_impact(hit: Dictionary, direction: Vector3, serial: int, strike: Dictionary) -> void:
	$Zombies.strike_bolt(hit, direction, serial, strike, Bow.ACTION)

func _mount_weapon(mesh: Mesh, socket: BoneAttachment3D, mesh_name: String, offset: Transform3D, pivot := Vector3.ZERO) -> MeshInstance3D:
	var mount := MeshInstance3D.new()
	mount.name = mesh_name
	mount.mesh = mesh
	mount.transform = offset
	mount.hide()
	socket.add_child(mount)
	player.render_presenter.track_bone_mesh(mount, socket, pivot)
	return mount

func _set_crossbow_ammo(amount: int) -> void:
	if _equipped_weapon == Weapon.CROSS_POLLINATOR:
		$HUD/CrossbowAmmo.text = "Đạn nỏ  %d / %d" % [amount, CrossPollinator.AMMO_MAX]

func _set_bow_ammo(amount: int) -> void:
	if _equipped_weapon == Weapon.BOW:
		$HUD/CrossbowAmmo.text = "Mũi tên  %d / %d" % [amount, Bow.AMMO_LIMIT]

func _on_grounded_attack(index: int, clip: String, serial: int) -> void:
	if clip != CrossPollinator.SHOT:
		$Zombies.strike_sabre(index, clip, serial)
		return
	var forward: Vector3 = player.visual.global_basis.z.normalized()
	var muzzle := _crossbow_mount.to_global(CrossPollinator.MUZZLE)
	var direction := forward
	if player.combat_requested:
		if player.has_aim_point:
			var aim: Vector3 = player.aim_point - player.global_position
			aim.y = 0.0
			if not aim.is_zero_approx():
				direction = aim.normalized()
	else:
		direction = $Zombies.bolt_direction(muzzle, forward, serial)
	var clearance_start := Vector3(player.global_position.x, muzzle.y, player.global_position.z)
	_crossbow.fire(muzzle, direction, serial, clearance_start)

func _setup_world_look() -> void:
	var viewport := get_viewport()
	_previous_msaa = viewport.msaa_3d
	viewport.msaa_3d = Viewport.MSAA_2X
	showcase = WorldShowcase.new()
	showcase.name = "WorldTime"
	showcase.private_primary = PlayerFactory.uses_private_player()
	add_child(showcase)
	look = WorldLook.new()
	look.name = "WorldLook"
	add_child(look)
	var ground := ShaderMaterial.new()
	$Ground/Mesh.material_override = ground
	look.setup_flat_lab(self, ground)
	ground.set_shader_parameter("albedo_tint", Color(0.4366, 0.5745, 0.2828))
	var ambient := WorldAmbient.new()
	ambient.name = "DirectionalAmbient"
	add_child(ambient)
	ambient.setup(self)
	showcase.setup_flat_lab(self)
	_update_time_label()

func _exit_tree() -> void:
	get_viewport().msaa_3d = _previous_msaa

func _update_time_label() -> void:
	var minutes := roundi(showcase.hour * 60.0)
	$HUD/TimeOfDay.text = "%02d:%02d  ·  T đổi giờ" % [floori(minutes / 60.0), minutes % 60]

func _process(delta: float) -> void:
	_flush_player_damage()
	if _combat_audio != null:
		_combat_audio.flush_zombie_combat_cues()
		_combat_audio.flush_zombie_steps()
	if _crowd_spawns_left > 0:
		_spawn_crowd_frame()
	var focus: Vector3 = presentation.player_position()
	camera.position = CAMERA_OFFSET + Vector3(focus.x, 0.0, focus.z)
	if not _player_overlays.is_empty():
		if _player_flash_pending:
			_player_flash_pending = false
		else:
			_player_flash_remaining = maxf(0.0, _player_flash_remaining - delta)
			if _player_flash_remaining <= 0.0:
				_clear_player_flash()
			else:
				var weight := smoothstep(0.0, PLAYER_HIT_FLASH_DURATION * 0.65, _player_flash_remaining)
				for mesh: MeshInstance3D in _player_overlays:
					mesh.set_instance_shader_parameter(&"player_hit_flash", weight)
	if _shake_duration > 0.0:
		# Begin at age zero and charge only intervals after the first frame.
		if _shake_pending:
			_shake_pending = false
		else:
			_shake_age = minf(_shake_age + delta, _shake_duration)
		var decay := 1.0 - _shake_age / _shake_duration
		var pulse := cos(TAU * 15.0 * _shake_age) * decay * decay
		camera.h_offset = camera.size * _shake_strength * pulse
		if _shake_age >= _shake_duration:
			_shake_duration = 0.0
	if _impact_light.visible:
		if _light_pending:
			_light_pending = false
		else:
			_light_remaining = maxf(0.0, _light_remaining - delta)
		var decay := _light_remaining / CONTACT_LIGHT_DURATION
		_impact_light.light_energy = _light_peak * decay * decay
		_impact_light.visible = _light_remaining > 0.0

func _setup_movement_audio() -> void:
	var manifest := PrivateOverworldBundle.default_path()
	var research := OS.get_environment("MD2_RESEARCH_ROOT")
	if not research.is_empty():
		manifest = research.path_join("godot_lab/overworld_fidelity_v001/bundle.private.json")
	var bundle := PrivateOverworldBundle.new()
	if not bundle.read_audio(manifest, "grass"):
		return
	_movement_audio = MovementAudio.new()
	_movement_audio.name = "MovementAudio"
	add_child(_movement_audio)
	_movement_audio.setup(player, null, bundle, _player_foot_contact_at)
	_movement_audio.landing_contact = _grass_landing_contact_at
	_movement_audio.protect_landing_voice = true

func _player_foot_contact_at(sole: Vector3) -> Dictionary:
	# Audio, dust and wind receive the same planted-foot event in the same tick.
	var tick := Engine.get_physics_frames()
	if tick != _foot_contact_tick or sole != _foot_contact_sole:
		_foot_contact_tick = tick
		_foot_contact_sole = sole
		_foot_contact = _grass_contact_at(sole)
		if not _foot_contact.is_empty():
			var support := _player_floor_support(sole)
			if not support.is_empty() and support.body != $Ground:
				_foot_contact = {}
	return _foot_contact

func _grass_contact_at(sole: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(sole + Vector3.UP * 0.08, sole - Vector3.UP * 0.30, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != $Ground or hit.normal.y < cos(player.floor_max_angle):
		return {}
	return {"position": hit.position, "surface": "grass"}

func _grass_landing_contact_at(point: Vector3) -> Dictionary:
	var tick := Engine.get_physics_frames()
	if tick != _landing_contact_tick or point != _landing_contact_point:
		_landing_contact_tick = tick
		_landing_contact_point = point
		var support := _player_floor_support(point)
		if support.is_empty():
			_landing_contact = _grass_contact_at(point)
		else:
			_landing_contact = {"position": support.position, "surface": "grass"} if support.body == $Ground else {}
	return _landing_contact

func _player_floor_support(point: Vector3) -> Dictionary:
	# A sole outside a ledge can raycast to the grass below. Prefer the
	# actual floor contact from this move_and_slide, including non-grass.
	var min_normal_y := cos(player.floor_max_angle)
	var closest := INF
	var nearest := Vector3.ZERO
	var floor_body: CollisionObject3D
	for i in player.get_slide_collision_count():
		var collision := player.get_slide_collision(i)
		for index in collision.get_collision_count():
			if collision.get_normal(index).y < min_normal_y:
				continue
			var collider := collision.get_collider(index) as CollisionObject3D
			if collider == null or (collider.collision_layer & 1) == 0:
				continue
			var position := collision.get_position(index)
			var distance := position.distance_squared_to(point)
			if distance < closest:
				closest = distance
				nearest = position
				floor_body = collider
	return {"position": nearest, "body": floor_body} if floor_body != null else {}

func _on_zombie_step(sole: Vector3) -> void:
	var support: Variant = null
	if _zombie_step_dust != null:
		support = _grass_contact_at(sole)
		if not support.is_empty():
			_zombie_step_dust.burst(support.position)
	_combat_audio.queue_zombie_step(sole, player.global_position, _grass_contact_at, support)

func _heavy_debris_delay() -> float:
	return SABRE_LANDING_DEBRIS_DELAY if _equipped_weapon == Weapon.SABRE else 0.0

func _on_attack_accepted_timed(index: int, clip: String, serial: int, at: float) -> void:
	# The Sabre aerial montage loops until support, so its cue follows the
	# landing section. Other attacks keep their existing sample timing.
	if MELEE_AUDIO_NAMES.has(_equipped_weapon):
		_combat_audio.tool_swung(MELEE_AUDIO_NAMES[_equipped_weapon], player.global_position + Vector3.UP, index, clip == "AirAttack")
	elif _equipped_weapon == Weapon.GAUNTLETS:
		_combat_audio.gauntlet_swung(player.global_position + Vector3.UP, index, clip == "AirAttack")
	elif clip != "AirAttack" or _equipped_weapon != Weapon.SABRE:
		player.reference_audio.trigger_attack(index, clip, serial, at)

func _cancel_slam_audio() -> void:
	_slam_audio_frame = -1
	_slam_swing_frame = -1

func _set_combat_audio(enabled: bool) -> void:
	if _combat_audio == null:
		return
	if not enabled:
		_cancel_slam_audio()
	if player.reference_audio != null:
		player.reference_audio.enabled = enabled
	if _movement_audio != null:
		_movement_audio.footsteps_enabled = enabled
		if not enabled:
			_movement_audio.reset_contacts()
	_combat_audio.set_enabled(enabled, player.global_position + Vector3.UP)

func _on_sabre_contact(point: Vector3, direction: Vector3, clip: String, _index: int, serial: int, lethal: bool) -> void:
	var has_arrow_sparks := clip == CrossPollinator.SHOT and _crossbow != null and _crossbow.impact_sparks != null
	has_arrow_sparks = has_arrow_sparks or (clip == Bow.ACTION and _bow != null and _bow.impact_sparks != null)
	if not has_arrow_sparks:
		if _contact_sparks != null:
			_contact_sparks.queue_contact(point, direction, player.global_position + Vector3.UP)
		else:
			player.effects.contact(point, direction)
	var tool_hit: StringName = MELEE_AUDIO_NAMES.get(_equipped_weapon, &"") if clip != Bow.ACTION and clip != CrossPollinator.SHOT else &""
	_combat_audio.contact(point, serial, lethal, clip, tool_hit)
	var finisher := clip in ["Attack3", "NativeFinisher", "NativeCurvedAttack3", "NativeGauntletAttack3", "NativeCleaverAttack3"]
	if clip != "AirAttack" or _equipped_weapon != Weapon.SABRE:
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
	_start_camera_shake(FINISHER_SHAKE_HEIGHT_FRACTION * falloff)

func _start_camera_shake(strength: float) -> void:
	_shake_strength = strength
	_shake_age = 0.0
	_shake_duration = HEAVY_SHAKE_DURATION
	_shake_pending = true

func _clear_camera_shake() -> void:
	_slam_shake_frame = -1
	_shake_serial = -1
	_shake_duration = 0.0
	_shake_pending = false
	camera.h_offset = 0.0
	camera.v_offset = 0.0

func _landing_floor_height(point: Vector3) -> float:
	var min_normal_y := cos(player.floor_max_angle)
	var probe := Vector3.UP * 0.08
	var ray := PhysicsRayQueryParameters3D.create(point + probe, point - probe, player.collision_mask, [player.get_rid()])
	var support := get_world_3d().direct_space_state.intersect_ray(ray)
	if not support.is_empty() and support.normal.y >= min_normal_y:
		return support.position.y

	# The capsule can land on the edge with its centre beyond the floor.
	# Reuse the upward contact reported by the same move_and_slide call.
	var height := point.y
	for i in player.get_slide_collision_count():
		var collision := player.get_slide_collision(i)
		for index in collision.get_collision_count():
			var normal_y := collision.get_normal(index).y
			if normal_y < min_normal_y:
				continue
			var collider := collision.get_collider(index) as CollisionObject3D
			if collider == null or (collider.collision_layer & 1) == 0:
				continue
			height = collision.get_position(index).y
			min_normal_y = normal_y
	return height

func _on_heavy_jump_landed(point: Vector3, facing: Vector3, serial: int, fall_height: float) -> void:
	if _equipped_weapon in [Weapon.GAUNTLETS, Weapon.BASIC_GAUNTLETS]:
		player.begin_gauntlet_landing()
	elif TOOL_TYPES.has(_equipped_weapon):
		player.begin_tool_landing()
	# Evaluate the height tiers against the support rather than the capsule origin.
	fall_height = maxf(0.0, fall_height + point.y - _landing_floor_height(point))
	$Zombies.land_sabre(point, facing, serial, fall_height)
	if not _combat_audio.enabled:
		return
	if _equipped_weapon == Weapon.SABRE:
		_slam_swing_serial = serial
		_slam_swing_frame = Engine.get_physics_frames() + ceili(SABRE_LANDING_SWING_DELAY * Engine.physics_ticks_per_second)
	var contact := _grass_landing_contact_at(point)
	if contact.is_empty():
		return
	var delay_ticks := ceili(_heavy_debris_delay() * Engine.physics_ticks_per_second)
	if delay_ticks > 0:
		_slam_audio_point = contact.position
		_slam_audio_frame = Engine.get_physics_frames() + delay_ticks
	else:
		_combat_audio.slam_landed(contact.position)

func _on_sabre_landing(point: Vector3, serial: int) -> void:
	if _equipped_weapon == Weapon.GAUNTLETS:
		_combat_audio.gauntlet_slam_landed(point)
	elif MELEE_AUDIO_NAMES.has(_equipped_weapon):
		_combat_audio.tool_landed(MELEE_AUDIO_NAMES[_equipped_weapon], point)
	if _equipped_weapon != Weapon.SABRE:
		_show_landing_burst(point, serial)
		return
	var frame := Engine.get_physics_frames()
	var rate := Engine.physics_ticks_per_second
	_slam_shake_frame = frame + ceili(SABRE_LANDING_SHAKE_DELAY * rate)
	_slam_burst_frame = frame + ceili(SABRE_LANDING_BURST_DELAY * rate)
	_slam_burst_point = point
	_slam_burst_serial = serial

func _show_landing_burst(point: Vector3, serial: int) -> void:
	player.effects.contact(point + Vector3.UP * 0.12, Vector3.UP)
	_start_contact_light(point + Vector3.UP * 0.60, serial, 2.3)

func _start_contact_light(point: Vector3, serial: int, energy: float) -> void:
	if _light_serial == serial:
		return
	_light_serial = serial
	_light_peak = energy
	_light_remaining = CONTACT_LIGHT_DURATION
	_light_pending = true
	_impact_light.global_position = point
	_impact_light.light_energy = _light_peak
	_impact_light.show()

func _clear_contact_light() -> void:
	_slam_burst_frame = -1
	_light_serial = -1
	_light_remaining = 0.0
	_light_pending = false
	_impact_light.light_energy = 0.0
	_impact_light.hide()

func _physics_process(_delta: float) -> void:
	if player.position.y < -5.0:
		reset_player()
	var frame := Engine.get_physics_frames()
	if _slam_shake_frame >= 0 and frame >= _slam_shake_frame:
		_slam_shake_frame = -1
		_start_camera_shake(FINISHER_SHAKE_HEIGHT_FRACTION)
	if _slam_burst_frame >= 0 and frame >= _slam_burst_frame:
		_slam_burst_frame = -1
		_show_landing_burst(_slam_burst_point, _slam_burst_serial)
	if _slam_swing_frame >= 0 and frame >= _slam_swing_frame:
		_slam_swing_frame = -1
		if player.combo.serial == _slam_swing_serial and player.combo.active():
			player.reference_audio.trigger_attack_at_notify("AirAttack", _slam_swing_serial)
	if _slam_audio_frame >= 0 and frame >= _slam_audio_frame:
		_cancel_slam_audio()
		_combat_audio.slam_landed(_slam_audio_point)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_T and event.pressed and not event.echo:
		var next_hour: float = TIME_PRESETS[0]
		for preset: float in TIME_PRESETS:
			if preset > showcase.hour:
				next_hour = preset
				break
		showcase.set_hour(next_hour)
		_update_time_label()
		get_viewport().set_input_as_handled()
		return
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

func _set_ragdoll_launch(percent: float) -> void:
	$Zombies.ragdoll_launch_multiplier = percent * 0.01
	$HUD/RagdollTuning/Launch/Value.text = "Lực văng ragdoll · %d%%" % roundi(percent)

func _set_ragdoll_gravity(percent: float) -> void:
	$Zombies.ragdoll_gravity_multiplier = percent * 0.01
	$HUD/RagdollTuning/Gravity/Value.text = "Trọng lực ragdoll · %d%%" % roundi(percent)

func _spawn_one_zombie(base_health: bool) -> bool:
	var facing := Basis(Vector3.UP, player.visual.rotation.y)
	return $Zombies.spawn(player, facing, $CombatEffects, base_health)

func _spawn_zombie() -> void:
	if _spawn_one_zombie($HUD/BaseZombieToggle.button_pressed):
		if _crowd_spawns_left == 0:
			$HUD/SpawnStatus.text = ""
	else:
		$HUD/SpawnStatus.text = "Không thể tạo zombie. Kiểm tra dữ liệu MD2 Research và chỗ trống."

func _start_crowd_spawn() -> void:
	if $HUD/SpawnCrowd.disabled or player_health == 0:
		return
	_crowd_spawns_left = CROWD_SPAWN_COUNT
	_crowd_base_health = $HUD/BaseZombieToggle.button_pressed
	$HUD/SpawnCrowd.disabled = true
	$HUD/SpawnStatus.text = "Đang tạo zombie… 0/%d" % CROWD_SPAWN_COUNT

func _spawn_crowd_frame() -> void:
	var deadline := Time.get_ticks_usec() + CROWD_SPAWN_BUDGET_USEC
	for i in mini(_crowd_spawns_left, CROWD_SPAWN_LIMIT_PER_FRAME):
		if not _spawn_one_zombie(_crowd_base_health):
			var created := CROWD_SPAWN_COUNT - _crowd_spawns_left
			_stop_crowd_spawn()
			$HUD/SpawnStatus.text = "Đã tạo %d/%d zombie. Hãy kiểm tra chỗ trống hoặc dữ liệu MD2." % [created, CROWD_SPAWN_COUNT]
			return
		_crowd_spawns_left -= 1
		if Time.get_ticks_usec() >= deadline:
			break
	if _crowd_spawns_left == 0:
		_stop_crowd_spawn()
		$HUD/SpawnStatus.text = "Đã tạo %d zombie." % CROWD_SPAWN_COUNT
	else:
		$HUD/SpawnStatus.text = "Đang tạo zombie… %d/%d" % [CROWD_SPAWN_COUNT - _crowd_spawns_left, CROWD_SPAWN_COUNT]

func _stop_crowd_spawn() -> void:
	if _crowd_spawns_left > 0:
		$HUD/SpawnStatus.text = ""
	_crowd_spawns_left = 0
	$HUD/SpawnCrowd.disabled = $HUD/SpawnZombie.disabled or player_health == 0

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
		_combat_audio.player_defeated()
		_stop_crowd_spawn()
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
	_player_flash_pending = true
	# Several physics ticks can run before the next frame is drawn.
	var tick := Engine.get_physics_frames()
	if _player_damage_tick != tick:
		_flush_player_damage()
		_player_damage_tick = tick
	if _pending_player_damage == 0:
		_player_damage_origin = player.global_position + Vector3.UP * 2.32
	_pending_player_damage += lost

func _flush_player_damage() -> void:
	if _pending_player_damage == 0:
		return
	var lateral := camera.global_basis.x * (1.0 if _player_hit_serial % 2 == 0 else -1.0)
	_player_hit_serial += 1
	DamageFeedback.spawn_number(_pending_player_damage, $Zombies.damage_digits(), _player_damage_numbers,
		_player_damage_origin, lateral, PLAYER_DAMAGE_TINT)
	_pending_player_damage = 0

func _clear_player_flash() -> void:
	for mesh: MeshInstance3D in _player_overlays:
		mesh.set_instance_shader_parameter(&"player_hit_flash", 0.0)
		mesh.material_overlay = _player_overlays[mesh]
	_player_overlays.clear()
	_player_flash_remaining = 0.0
	_player_flash_pending = false

func reset_player() -> void:
	_foot_contact_tick = -1
	_landing_contact_tick = -1
	if player_health == 0:
		player.is_dead = false
		player.set_process_input(true)
		player.set_process_unhandled_input(true)
		$HUD/Defeat.hide()
		$HUD/Weapon.disabled = _weapon_mesh == null or not player.combo.native_enabled
	player_health = MAX_PLAYER_HEALTH
	_stop_crowd_spawn()
	$HUD/PlayerHealth.text = "%d / %d HP" % [player_health, MAX_PLAYER_HEALTH]
	_clear_player_flash()
	_pending_player_damage = 0
	if _player_damage_numbers != null:
		for number: Node3D in _player_damage_numbers.get_children():
			number.hide()
			number.queue_free()
	_clear_camera_shake()
	_clear_contact_light()
	if _combat_audio != null:
		_combat_audio.reset()
	if _zombie_step_dust != null:
		_zombie_step_dust.clear()
	if _crossbow != null:
		_crossbow.reset()
	if _bow != null:
		_bow.reset()
	player.position = SPAWN
	player.velocity = Vector3.ZERO
	if player.has_method("cancel_jump"):
		player.cancel_jump()
	if _movement_audio != null:
		_movement_audio.reset_contacts()
	player.reset_physics_interpolation()
	camera.position = CAMERA_OFFSET
