extends Node3D

const PlayerFactory := preload("res://scripts/world_map_player_factory.gd")
const PlayerPresentation := preload("res://scripts/world_map_presentation.gd")
const SourceTerrain := preload("res://scripts/world_map_source_terrain.gd")
const WorldLook := preload("res://scripts/world_map_look.gd")
const WorldShowcase := preload("res://scripts/world_map_showcase.gd")
const WorldAmbient := preload("res://scripts/world_map_ambient.gd")
const CombatAudio := preload("res://scripts/mechanic_lab_combat_audio.gd")
const MovementAudio := preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/environment_audio.gd")
const STEP_DIRECTORY := "extracted/2026-10-26 12-46-42/Game/Spicewood/Audio/Wwise/Events/Spicewood/Mobs/Mob_Companion/Blub"
# The same checksum-pinned families used by the private terrain ambience manifest.
const FLOOR_STEP_BANKS := {
	"grass": ["sfx_player_stepGrass-%03d_soundWave", [
		["563c4a955a79801b18792cdf18540f7174d26422112d031c4c6f234a3b946fc8", 0.4109583333333333],
		["489163367e0aa59ca62831612dc4d569ba09a81d667d30acf67459410fce708f", 0.5076875],
		["b620f2dce941577f0187926514650fa0c473002a61d0c0e6d4b04c01e914cb80", 0.42802083333333335],
		["d69e3759473ca778bbf93e7e8699d3b0b27694947356c5455c08fa126f5adde2", 0.45277083333333334],
		["4c0e995a7f8493e99a81ac56d9157c7c0d1297e97cdb3949f4ff171d1e918072", 0.5732708333333333],
		["9ee5b276ce70dac9fd60349f3caf1bfef533d2f87ed4cebacbcdbf978380e05f", 0.5477291666666667],
	]],
	"dirt": ["sfx_player_step_carapaceDryDirt-%03d", [
		["00eb92e0d76759bf6cd759237a747946ccbf0b5c5595ad417c61d2064079ef81", 0.2720416666666667],
		["ecff9809f2eab8c68f9fdc38a7dfbddd163dfd44b2cdbb0a9c2529f64ff8a6c7", 0.30285416666666665],
		["b90e7ac6d5b43d738c6e1a9303ed150318ac7577295efabf037bb17dbd1bc27c", 0.368375],
		["6518f75ffe39612af951d02d3d057efd5d040b2316ab47a5b9e9709abd0d7253", 0.5289791666666667],
		["e36cad2fd7e5996af3055a8dc5f02163ce1fe37277584d763e71e47302cb2b3b", 0.40697916666666667],
		["a22a71e0e2c5121e10dd751dc930d208a4036c112bf7ef85f8e0e49c0b3f83d8", 0.41002083333333333],
	]],
	"stone": ["sfx_player_stepStone-%03d_soundWave", [
		["09d68ffcb4fe957525e00202c23dc76104a538c2469125325a39f8307f40c5b0", 0.3658125],
		["94d20506c3a390f86b3020e22441570622e5021d21e2f12256d5293f9a6c8d0d", 0.25397916666666664],
		["0cb0c0d9186a66ece757e4519c81d36da89949b7985bde1a044d0be777f69495", 0.336375],
		["18643c8a0cf9d9fd07ea6f9e9e5fea2cc87db4cabcafbf97212467a6306d4374", 0.303375],
		["7ed8bfe965ada0659afb87f1d1245f97c045e9cb97b93737ae0643d415a63f2e", 0.29654166666666665],
		["c18e06e5c20c27318ed7a4f4fb9187ce059cb31e3b3bfde671bc00014ff9b2b8", 0.31616666666666665],
	]],
}
const MovementDust := preload("res://scripts/mechanic_lab_movement_dust.gd")
const ImpactMarks := preload("res://scripts/mechanic_lab_impact_marks.gd")
const GROUND_SLAM_SHADER := preload("res://materials/mechanic_lab_ground_slam.gdshader")
const BLADE_WALL_SHADER := preload("res://materials/mechanic_lab_axe_wall.gdshader")
const SABRE_WALL_SHADER := preload("res://materials/mechanic_lab_sabre_wall.gdshader")
const BLADE_WALL_LIMIT := 4
const SPLASH_FLASH_UNDIMMED_COUNT := 6
const SPLASH_FLASH_MIN_SCALE := 0.45
const GROUND_SLAM_RADIUS := 0.68
const GROUND_SLAM_DURATION := 0.23
const GROUND_SLAM_MAX_CLIPS := 8
const GROUND_SLAM_HEIGHT := 0.025
const GROUND_SLAM_CORNERS := [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]
const GROUND_SLAM_SIDES := [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
const TOOL_SHAKE_HEIGHT_FRACTION := 0.0056
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
const PROJECTILE_SHADERS := [CrossPollinator.TRAIL_SHADER, CrossPollinator.ImpactSparks.SHADER,
	Bow.CHARGE_CUE_SHADER, CrossPollinator.EMBEDDED_SHADER]
const KaiSkin := preload("res://scripts/mechanic_lab_kai_skin.gd")
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
const LabAudioMix := preload("res://scripts/mechanic_lab_audio_mix.gd")
const CAMERA_OFFSET := Vector3(12.0, 15.0, 16.0)
const SPAWN := Vector3(0.0, 0.03, 0.0)
const MIN_CAMERA_SIZE := 4.5
const MAX_CAMERA_SIZE := 30.0
const ZOOM_STEP := 1.15
const SABRE_TAP_BUFFER := 0.16
const MAX_PLAYER_HEALTH := 100
const CROWD_SPAWN_COUNTS := [1, 10, 25, 50, 100, 150, 200]
const DEFAULT_CROWD_SPAWN_COUNT := 100
const CROWD_SPAWN_LIMIT_PER_FRAME := 5
const CROWD_SPAWN_BUDGET_USEC := 2500
const PLAYER_HIT_FLASH_DURATION := 0.10
const PLAYER_DAMAGE_TINT := Color(1.0, 0.18, 0.22)
const CONTACT_LIGHT_DURATION := 0.17
const HEAVY_SHAKE_DURATION := 0.20
const FINISHER_SHAKE_INNER_RADIUS := 1.5
const FINISHER_SHAKE_OUTER_RADIUS := 3.0
const FINISHER_SHAKE_HEIGHT_FRACTION := 0.008
# Both Gauntlets rows use MD2's SubtleFlashCameraShake class. Its amplitude
# is unrecovered, so use a quieter version of the Lab's existing pulse.
const GAUNTLET_FINISHER_SHAKE_HEIGHT_FRACTION := 0.004
const PRIVATE_CONTROLS := "WASD di chuyển · Shift đi bộ · Space nhảy · Chuột trái / E %s · R về giữa"
const TIME_PRESETS := [2.5, 7.0, 12.0, 16.5, 18.5, 19.5, 22.0]
# AM_Player_Sabre_JumpAttack: first PostAudioEvent minus LandingStart.
const SABRE_LANDING_SWING_DELAY := 0.033083633
# AM_Player_Sabre_JumpAttack: PlayDebrisEffect minus LandingStart.
const SABRE_LANDING_DEBRIS_DELAY := 0.045126423
const SABRE_LANDING_BURST_REACH := 1.5
const SABRE_LANDING_CUES := [
	{"time": 0.281534761, "effect": MeleeTools.GroundEffect.DUST, "offset": Vector2(0.0, 0.90)},
	{"time": 0.285736203, "effect": MeleeTools.GroundEffect.SHAKE, "medium": true},
	{"time": 0.290357769, "effect": MeleeTools.GroundEffect.SHOCKWAVE, "offset": Vector2(0.0, 1.75), "impact_burst": true},
]
# The Gauntlets debris notify names the impact decal at local Y 180 cm.
# The Lab maps that axis along the strike direction.

enum PlayerSkin { MD2, KAI }
enum PresetAction { SAVE_A, LOAD_A, SAVE_B, LOAD_B, DEFAULTS }
enum SparkBudget { FULL, LOW, BALANCED }

const SPARK_SPAWN_SCALES := {
	SparkBudget.FULL: 1.0,
	SparkBudget.LOW: 0.6,
	SparkBudget.BALANCED: 0.8,
}

const MIX_ROWS := {
	LabAudioMix.Layer.MASTER: [&"Master", "Tổng"],
	LabAudioMix.Layer.WEAPON: [&"Weapon", "Vũ khí"],
	LabAudioMix.Layer.ZOMBIE: [&"Zombie", "Zombie"],
	LabAudioMix.Layer.SURFACE: [&"Surface", "Bước / tiếp đất"],
}
const RAGDOLL_PHYSICS_ROWS := {
	&"Mass": ["Khối lượng", 50.0, 200.0, &"ragdoll_mass_multiplier", "Đổi khối lượng của từng phần cơ thể."],
	&"Damping": ["Độ hãm", 25.0, 200.0, &"ragdoll_damping_multiplier", "Đổi độ hãm khi di chuyển và xoay."],
	&"JointSpan": ["Biên độ khớp", 50.0, 150.0, &"ragdoll_joint_span_multiplier", "Đổi góc xoay tối đa của các khớp."],
}
const PRESET_RANGES := {
	"launch": ^"HUD/RagdollTuning/Launch/Slider",
	"gravity": ^"HUD/RagdollTuning/Gravity/Slider",
	"ragdoll_mass": ^"HUD/RagdollPhysicsPanel/Rows/Mass/Slider",
	"ragdoll_damping": ^"HUD/RagdollPhysicsPanel/Rows/Damping/Slider",
	"ragdoll_joint_span": ^"HUD/RagdollPhysicsPanel/Rows/JointSpan/Slider",
	"corpse_seconds": ^"HUD/RagdollLifetime/Slider",
	"camera_shake": ^"HUD/CameraShake/Slider",
	"hitstop_ms": ^"HUD/Hitstop/Slider",
	"impact_opacity": ^"HUD/ImpactFxPanel/Rows/Opacity/Slider",
	"impact_duration": ^"HUD/ImpactFxPanel/Rows/Duration/Slider",
	"ribbon_opacity": ^"HUD/ImpactFxPanel/Rows/RibbonOpacity/Slider",
	"slam_opacity": ^"HUD/ImpactFxPanel/Rows/SlamOpacity/Slider",
	"slam_duration": ^"HUD/ImpactFxPanel/Rows/SlamDuration/Slider",
	"sfx_master": ^"HUD/AudioMixPanel/Rows/Master/Slider",
	"sfx_weapon": ^"HUD/AudioMixPanel/Rows/Weapon/Slider",
	"sfx_zombie": ^"HUD/AudioMixPanel/Rows/Zombie/Slider",
	"sfx_surface": ^"HUD/AudioMixPanel/Rows/Surface/Slider",
}
const PRESET_OPTIONS := {
	"crowd_count": ^"HUD/CrowdSpawnCount",
	"zombie_animation": ^"HUD/ZombieGait",
	"render_scale": ^"HUD/RenderScale",
	"frame_rate": ^"HUD/FrameRate",
	"contact_spark_quality": ^"HUD/ImpactFxPanel/Rows/ContactSparkQuality",
	"debris_quality": ^"HUD/ImpactFxPanel/Rows/DebrisQuality",
	"floor_surface": ^"HUD/FloorSurface",
}
const FLOOR_SURFACES := ["grass", "dirt", "stone"]

enum Weapon { SABRE, SWORD, CURVED_GREATSWORD, CROSS_POLLINATOR, GAUNTLETS,
	CLEAVER, BOW, BASIC_GAUNTLETS, PICKAXE, SHOVEL, AXE }
const TOOL_TYPES := {
	Weapon.CLEAVER: MeleeTools.Tool.CLEAVER,
	Weapon.PICKAXE: MeleeTools.Tool.PICKAXE,
	Weapon.SHOVEL: MeleeTools.Tool.SHOVEL,
	Weapon.AXE: MeleeTools.Tool.AXE,
}
const MELEE_AUDIO_NAMES := {
	Weapon.CLEAVER: &"cleaver", Weapon.BASIC_GAUNTLETS: &"gauntlet",
	Weapon.PICKAXE: &"pickaxe", Weapon.SHOVEL: &"shovel", Weapon.AXE: &"axe",
}
const WEAPON_AUDIO_PREVIEWS := {
	Weapon.CROSS_POLLINATOR: &"crossbow_fire",
	Weapon.GAUNTLETS: &"gauntlet_hit",
	Weapon.BOW: &"bow_fire",
}

const MELEE_EQUIPMENT_NAMES := {
	Weapon.SABRE: &"sabre",
	Weapon.SWORD: &"sword",
	Weapon.CURVED_GREATSWORD: &"curved_greatsword",
	Weapon.GAUNTLETS: &"prime_gauntlet",
	Weapon.CLEAVER: &"cleaver",
	Weapon.BASIC_GAUNTLETS: &"gauntlet",
	Weapon.PICKAXE: &"pickaxe",
	Weapon.SHOVEL: &"shovel",
	Weapon.AXE: &"axe",
}

var presentation: Node
var look: WorldLook
var showcase: WorldShowcase
# The flat lab has no forest canopy. The shared lighting expects this property.
var grove: Node3D
var view_mode := "gameplay"
var spawn_position := SPAWN
var player_health := MAX_PLAYER_HEALTH
var _crowd_spawns_left := 0
var _crowd_spawn_total := 0
var _crowd_base_health := false
var tuning_preset_directory := "user://mechanic_lab_presets"
var _default_tuning := {}
var _previous_msaa: Viewport.MSAA
var _previous_3d_scale: float
var _previous_3d_scaling_mode: Viewport.Scaling3DMode
var _render_scale_overridden := false
var _previous_max_fps := 0
var _frame_rate_override := 0
var _combat_audio: CombatAudio
var _lab_audio_mix: LabAudioMix
var _zombie_step_dust: ZombieStepDust
var _floor_snap_contact := KinematicCollision3D.new()
var _floor_surface := "grass"
var _gauntlet_impact_marks: ImpactMarks
var _movement_dust: MovementDust
var _tool_slam_ring: MeshInstance3D
var _tool_slam_material: ShaderMaterial
var _tool_slam_footprint := PhysicsShapeQueryParameters3D.new()
var _tool_slam_time := -1.0
var _tool_slam_pending := false
var _tool_slam_duration := GROUND_SLAM_DURATION
var _tool_slam_duration_scale := 1.0
var _tool_slam_opacity := 1.0
var _pending_tool_ground_cues: Array[Dictionary] = []
var _tool_touchdown: Dictionary = {}
var _floor_tiles: Dictionary[String, Texture2DArray] = {}
var _slam_swing_frame := -1
var _slam_swing_serial := -1
var _slam_audio_frame := -1
var _slam_audio_point: Vector3
var _slam_audio_surface := "grass"
var _contact_sparks: ContactSparks
var _grounded_impact_dispatch := false
var _pending_melee_contact_fx: Array[Dictionary] = []
var _pending_melee_feedback: Array[Dictionary] = []
var _combat_pose_frame := -1
var _previous_blade_serial := -1
var _previous_blade_base := Vector3.ZERO
var _previous_blade_tip := Vector3.ZERO
var _movement_audio: MovementAudio
var _kai_skin: KaiSkin
var _md2_skin_visibility: Dictionary[MeshInstance3D, bool] = {}
var _weapon_mesh: MeshInstance3D
var _blade_wall_material: ShaderMaterial
var _blade_wall_materials: Dictionary[Mesh, ShaderMaterial] = {}
var _blade_wall_probe: PhysicsShapeQueryParameters3D
var _blade_base_override: Material
var _blade_blocker_count := 0
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
var _curved_air_ready := false
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
var _bow_display_mesh_index := -1
var _bow_profile: Dictionary
var _next_projectile_shader := 0
var _last_ranged_preparation_frame_us := 0
var _pending_crossbow_clips: Array[Dictionary]
var _sabre_air_clip: Dictionary
var _default_idle_novelty: Dictionary
var _sabre_air_rate := 1.0
var _sabre_audio_aliases: Dictionary
var _sabre_audio_rates: Dictionary
var _shake_serial := -1
var _shake_age := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _shake_intensity := 1.0
var _shake_pending := false
var _shake_sample_time := -1.0
var _slam_burst_frame := -1
var _slam_burst_point: Vector3
var _slam_burst_serial := -1
var _light_serial := -1
var _light_remaining := 0.0
var _light_peak := 0.0
var _light_pending := false
var _light_sample_time := -1.0
var _player_flash_remaining := 0.0
var _player_flash_pending := false
var _player_flash_material: ShaderMaterial
var _player_flash_meshes: Array[MeshInstance3D] = []
var _player_overlays: Dictionary[MeshInstance3D, Material] = {}
var _player_damage_numbers: Node3D
var _zombie_damage_numbers: DamageNumbers
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
	_setup_render_scale()
	_setup_frame_rate()
	var tiles := _setup_floor_surfaces()

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
	$HUD/SpawnBabyZombie.disabled = $HUD/SpawnZombie.disabled
	$HUD/SpawnCrowd.disabled = $HUD/SpawnZombie.disabled
	var crowd_picker: OptionButton = $HUD/CrowdSpawnCount
	for count: int in CROWD_SPAWN_COUNTS:
		crowd_picker.add_item(str(count), count)
	var default_count := crowd_picker.get_item_index(DEFAULT_CROWD_SPAWN_COUNT)
	crowd_picker.select(default_count)
	crowd_picker.disabled = $HUD/SpawnCrowd.disabled
	crowd_picker.item_selected.connect(_set_crowd_spawn_label)
	_set_crowd_spawn_label(default_count)
	var gait_picker: OptionButton = $HUD/ZombieGait
	gait_picker.add_item("Zombie · MD2")
	gait_picker.add_item("Zombie · Actions & Stuff")
	gait_picker.select(0)
	gait_picker.disabled = $HUD/SpawnZombie.disabled
	gait_picker.item_selected.connect(func(index: int): $Zombies.set_actions_stuff_animation(index == 1))
	$HUD/CombatAudioToggle.disabled = $HUD/SpawnZombie.disabled
	$HUD/BaseZombieToggle.disabled = $HUD/SpawnZombie.disabled
	$HUD/RagdollTuning.visible = not $HUD/SpawnZombie.disabled
	$HUD/RagdollLifetime.visible = $HUD/RagdollTuning.visible
	$HUD/CameraShake.visible = $HUD/RagdollTuning.visible
	var lifetime_slider: HSlider = $HUD/RagdollLifetime/Slider
	lifetime_slider.set_value_no_signal($Zombies.corpse_lifetime)
	_set_ragdoll_lifetime(lifetime_slider.value)
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
		_lab_audio_mix = LabAudioMix.new()
		_lab_audio_mix.name = "LabAudioMix"
		add_child(_lab_audio_mix)
		_combat_audio = CombatAudio.new()
		_combat_audio.name = "CombatAudio"
		_combat_audio.zombie_listener = listener
		_combat_audio.lab_mix = _lab_audio_mix
		add_child(_combat_audio)
		_combat_audio.queue_base_samples()
		if OS.has_feature("editor"):
			_pending_crossbow_clips = CrossPollinator.locomotion_entries(WeaponSource.research_root())
		_setup_movement_audio()
		_gauntlet_impact_marks = ImpactMarks.new()
		_gauntlet_impact_marks.setup($Ground/Mesh)
		_gauntlet_impact_marks.name = "GauntletImpactMarks"
		$CombatEffects.add_child(_gauntlet_impact_marks)
		player.presentation_reset.connect(_gauntlet_impact_marks.clear)
		var dust := MovementDust.new()
		dust.name = "MovementDust"
		if dust.setup(player, null, _player_foot_contact_at, _heavy_debris_delay, _floor_landing_contact_at,
				player.source_step_dust_size, true):
			dust.use_source_landing(true)
			dust.use_gauntlet_debris(func() -> bool: return player.gauntlets_equipped)
			add_child(dust)
			_movement_dust = dust
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
		# M_WhirlWind_Emissive uses a two-sided material.
		if wind.setup(player, _player_foot_contact_at, true, BaseMaterial3D.CULL_DISABLED):
			add_child(wind)
			if is_instance_valid(dust):
				dust.wind_overlaps = wind.overlaps_smoke
		else:
			wind.free()
		var contact_sparks := ContactSparks.new()
		contact_sparks.name = "ContactSparks"
		if contact_sparks.setup(func() -> float: return player.render_presenter.display_clock):
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
				_md2_skin_visibility[mesh] = mesh.visible
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
		gait_picker.set_item_disabled(1, not $Zombies.actions_stuff_available)
		if $Zombies.full_actions_stuff_available:
			gait_picker.select(1)
			$Zombies.set_actions_stuff_animation(true)
		elif $Zombies.actions_stuff_available:
			gait_picker.set_item_text(1, "Zombie · A&S cơ bản")
			gait_picker.set_item_tooltip(1, "Cần thư viện Actions & Stuff 1.13 để dùng đủ animation.")
		var glyphs: Array[Texture2D] = $Zombies.damage_digits()
		if glyphs.size() == DamageNumbers.DIGIT_COUNT:
			_zombie_damage_numbers = DamageNumbers.new()
			_zombie_damage_numbers.name = "ZombieDamageNumbers"
			_zombie_damage_numbers.setup(glyphs)
			_zombie_damage_numbers.health_bars = bars
			$CombatEffects.add_child(_zombie_damage_numbers)
			$Zombies.damage_numbers = _zombie_damage_numbers
		player.grounded_melee_aim = $Zombies.aim_sabre
		player.bow_target = $Zombies.bow_aim_point
		player.bow_drawn.connect(_on_bow_drawn)
		player.bow_released.connect(_on_bow_released)
		player.connect("grounded_sabre_impact", _on_grounded_attack)
		player.connect("heavy_jump_landed", _on_heavy_jump_landed)
		_setup_tool_slam_ring()
		player.tool_ground_cue.connect(_queue_tool_ground_cue)
		player.tool_audio_cue.connect(_on_tool_audio_cue)
		player.tool_landing_accent_cue.connect(_on_tool_landing_accent_cue)
		player.tool_recovery_landing_cue.connect(_on_tool_recovery_landing_cue)
		player.physics_pose_ready.connect(_sample_combat_fx)
		player.presentation_reset.connect($Zombies.cancel_pending_landings)
		player.presentation_reset.connect(_cancel_slam_audio)
		player.presentation_reset.connect(_clear_camera_shake)
		player.presentation_reset.connect(_clear_contact_light)
		$Zombies.sabre_contact.connect(_on_sabre_contact)
		$Zombies.melee_contact_visual.connect(_on_melee_contact_visual)
		$Zombies.sabre_landing.connect(_on_sabre_landing)
		$Zombies.player_hit.connect(_on_player_hit)
		$Zombies.zombie_attack_audio.connect(_combat_audio.zombie_attack)
		$Zombies.baby_attack_audio.connect(_combat_audio.zombie_attack.bind(true))
		$Zombies.zombie_swing_audio.connect(_combat_audio.baby_swing)
		$Zombies.zombie_reaction_audio.connect(_combat_audio.zombie_reaction)
		$Zombies.zombie_step_audio.connect(_on_zombie_step)
		$Zombies.zombie_idle_audio.connect(_combat_audio.queue_zombie_idle)
		_setup_weapon_selector()
	_setup_skin_selector(using_private and player_ready)
	_setup_impact_fx_controls()
	_setup_audio_mix_controls()
	_setup_ragdoll_physics_controls()
	_setup_tuning_presets()
	print("MECHANIC_LAB_READY floor=100x100 player_ready=%s source_tiles=%s" % [player_ready, tiles != null])

func _setup_skin_selector(player_ready: bool) -> void:
	var picker: OptionButton = $HUD/PlayerSkin
	picker.add_item("Skin · MD2")
	picker.add_item("Skin · Kai Survival 3D")
	picker.select(PlayerSkin.MD2)
	picker.set_item_disabled(PlayerSkin.KAI, not (player_ready and KaiSkin.source_available()))
	picker.disabled = not player_ready
	picker.item_selected.connect(_select_skin)

func _select_skin(index: int) -> void:
	if index == PlayerSkin.KAI and _kai_skin == null:
		var candidate := KaiSkin.new()
		if not candidate.setup(player):
			candidate.free()
			$HUD/PlayerSkin.select(PlayerSkin.MD2)
			$HUD/PlayerSkin.set_item_disabled(PlayerSkin.KAI, true)
			$HUD/SpawnStatus.text = "Thiếu bản xuất Kai hợp lệ trong MD2 Research."
			return
		_kai_skin = candidate
		var flash_weight := 0.0
		if not _player_overlays.is_empty():
			var flashing: MeshInstance3D = _player_flash_meshes[0]
			flash_weight = float(flashing.get_instance_shader_parameter(&"player_hit_flash"))
		for mesh: MeshInstance3D in _kai_skin.meshes:
			_player_flash_meshes.append(mesh)
			if not _player_overlays.is_empty():
				_player_overlays[mesh] = mesh.material_overlay
				mesh.material_overlay = _player_flash_material
				mesh.set_instance_shader_parameter(&"player_hit_flash", flash_weight)
	var use_kai := index == PlayerSkin.KAI
	for mesh: MeshInstance3D in _md2_skin_visibility:
		mesh.visible = not use_kai and _md2_skin_visibility[mesh]
	var source_lantern := player.get("lantern") as Node3D
	if source_lantern != null:
		source_lantern.visible = not use_kai
	if _kai_skin != null:
		_kai_skin.show_skin(use_kai)

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
	_add_weapon_option("Axe", MeleeTools.icon(MeleeTools.Tool.AXE))
	_weapon_mesh = player.model.find_child("SabrePrototypeSabre", true, false) as MeshInstance3D
	if _weapon_mesh == null or not player.combo.native_enabled:
		return
	player.effects.interpolate_ground_trail_edges = true
	_sabre_mesh = _weapon_mesh.mesh
	_sabre_mesh_transform = _weapon_mesh.transform
	_setup_blade_wall_probe()
	_blade_wall_material = _blade_mask_for(_sabre_mesh)
	# The light rig stores surface overrides for the original Sabre mesh.
	_sabre_blade_base = player.marker_base.position
	_sabre_blade_tip = player.marker_tip.position
	_sabre_profile = player.runtime_locomotion_profile.combat
	_sabre_air_clip = player.clips.AirAttack
	player.sabre_landing_cues = SABRE_LANDING_CUES
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
	# The lighting rig binds Sabre's atlas to this shared mount. Other blades
	# need their own material in both open terrain and the near-wall pass.
	_clear_blade_wall_mask()
	var own_blade_material := tool >= 0 or index in [Weapon.SWORD, Weapon.CURVED_GREATSWORD]
	_weapon_mesh.material_override = mesh.surface_get_material(0) if own_blade_material else null
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
	player.effects.blade_trail_enabled = not blade_base.is_equal_approx(blade_tip)
	_blade_wall_material = _blade_mask_for(mesh) if _weapon_mesh.visible and player.effects.blade_trail_enabled else null
	player.reference_audio.reset()
	player.reference_audio.clip_aliases = aliases
	player.reference_audio.clip_play_rates = rates
	player.effects.reset()
	_cancel_slam_audio()
	# Projectiles and enemy cues keep their own lifetimes through a weapon switch.
	_combat_audio.clear_weapon_cues()
	var previous := _equipped_weapon
	var was_crossbow := previous == Weapon.CROSS_POLLINATOR
	var was_bow := previous == Weapon.BOW
	_equipped_weapon = index as Weapon
	var sword_equipped := index == Weapon.SWORD
	var ribbon_material := player.effects.ribbon.material_override as ShaderMaterial
	if ribbon_material != null:
		ribbon_material.set_shader_parameter(&"sword_ribbon_head", sword_equipped)
	var curved_equipped := index == Weapon.CURVED_GREATSWORD
	var curved_air := curved_equipped and _curved_air_ready
	var crossbow_equipped := index == Weapon.CROSS_POLLINATOR
	var switch_point := player.global_position + Vector3.UP
	if _combat_audio.enabled and MELEE_AUDIO_NAMES.has(index):
		_combat_audio.prepare_melee_tool(WeaponSource.research_root(), MELEE_AUDIO_NAMES[index])
	_combat_audio.melee_switched(MELEE_EQUIPMENT_NAMES.get(previous, &""), false, switch_point)
	if crossbow_equipped != was_crossbow:
		_combat_audio.crossbow_switched(crossbow_equipped, switch_point)
	if bow_equipped != was_bow:
		_bow.play_switch(bow_equipped, switch_point)
	_combat_audio.melee_switched(MELEE_EQUIPMENT_NAMES.get(index, &""), true, switch_point)
	player.active_clip = ""
	# Switching out of a special locomotion profile restores the source slots first.
	player.crossbow_equipped = crossbow_equipped
	player.bow_equipped = bow_equipped
	player.gauntlets_equipped = gauntlets_equipped
	player.basic_gauntlets_equipped = basic_gauntlets
	player.clips.AirAttack = player.clips[Gauntlets.AIR] if gauntlets_equipped else _sabre_air_clip
	player.tool_air_hold = -1.0
	player.tool_air_loop = -1.0
	player.tool_air_landing = -1.0
	if tool >= 0:
		player.clips.AirAttack = player.clips[MeleeTools.air_clip(tool)]
		player.tool_air_hold = MeleeTools.air_hold_time(tool)
		player.tool_air_loop = MeleeTools.air_loop_time(tool)
		player.tool_air_landing = MeleeTools.air_landing_time(tool)
	elif curved_air:
		player.clips.AirAttack = player.clips[CurvedGreatsword.AIR]
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
	if curved_air:
		$Zombies.equipped_air_strike = CurvedGreatsword.AIR_STRIKE
		$Zombies.equipped_air_offset = CurvedGreatsword.AIR_OFFSET
		$Zombies.equipped_air_delay = CurvedGreatsword.AIR_CONTACT_DELAY
	$HUD/CrossbowAmmo.visible = crossbow_equipped or bow_equipped
	if bow_equipped:
		_set_bow_ammo(_bow.ammo)
	elif crossbow_equipped:
		_set_crossbow_ammo(_crossbow.ammo)
	player.aerial_melee_enabled = (not curved_equipped or curved_air) and not bow_equipped
	player.set_weapon_locomotion({})
	player.clips.InspectWeapon = _default_idle_novelty
	player.set_weapon_locomotion(locomotion)
	_set_weapon_idle_novelty(index)
	$HUD/DropMedium.disabled = curved_equipped and not curved_air
	$HUD/DropHigh.disabled = curved_equipped and not curved_air
	var attack_hint := "chém hoặc bổ trên không"
	if curved_equipped:
		attack_hint = "chém hoặc bổ trên không (thử nghiệm)" if curved_air else "chém dưới đất"
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
		_pending_crossbow_clips.clear()
		var loaded := _load_crossbow(research_root)
		player.clear_prepared_crossbow_clips()
		return loaded
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
	_curved_air_ready = CurvedGreatsword.load_air_attack(player, research_root)
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
	_crossbow.bolt_launched.connect(func(bolt: Node3D, _charged: bool) -> void:
		_combat_audio.start_projectile_flight(bolt, &"crossbow_flight"))
	_crossbow.bolt_ended.connect(_combat_audio.stop_projectile_flight)
	$CombatEffects.add_child(_crossbow)
	_apply_impact_fx_settings()
	_set_crossbow_ammo(_crossbow.ammo)
	_combat_audio.queue_crossbow_samples(root)
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
		_combat_audio.queue_gauntlet_samples(root)
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

func _gauntlet_knuckle(attack_index: int) -> Vector3:
	var left := attack_index == Gauntlets.LEFT_PUNCH_INDEX
	var glove: MeshInstance3D
	if player.basic_gauntlets_equipped:
		glove = _basic_gauntlet_mounts[0 if left else 1]
	else:
		glove = _left_gauntlet if left else _right_gauntlet
	var socket := glove.get_parent() as BoneAttachment3D
	var bounds := glove.get_aabb()
	var knuckle := bounds.get_center()
	knuckle.z = bounds.end.z
	# BoneAttachment transforms update later. Use the pose just sampled
	# by the player, matching the transform used for the rendered glove.
	var skeleton: Skeleton3D = player.skeleton
	return skeleton.global_transform * skeleton.get_bone_global_pose(socket.bone_idx) * glove.transform * knuckle

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
	if index == Weapon.AXE:
		mesh.surface_set_material(0, _blade_mask_for(mesh))
	_tools[index] = {"mesh": mesh, "profile": profile, "locomotion": locomotion}
	return true

func _setup_blade_wall_probe() -> void:
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(4.8, 5.0, 4.8)
	_blade_wall_probe = PhysicsShapeQueryParameters3D.new()
	_blade_wall_probe.shape = bounds
	_blade_wall_probe.collision_mask = 1
	_blade_wall_probe.exclude = [$Ground.get_rid(), player.get_rid()]

func _blade_mask_for(mesh: Mesh) -> ShaderMaterial:
	if _blade_wall_materials.has(mesh):
		return _blade_wall_materials[mesh]
	var source := mesh.surface_get_material(0) as BaseMaterial3D if mesh.get_surface_count() == 1 else null
	if source == null or source.albedo_texture == null:
		return null
	var material := ShaderMaterial.new()
	material.shader = SABRE_WALL_SHADER if mesh == _sabre_mesh else BLADE_WALL_SHADER
	material.set_shader_parameter(&"blade_texture", source.albedo_texture)
	material.set_shader_parameter(&"blade_blocker_count", 0)
	if mesh == _sabre_mesh:
		# Sabre packs roughness into green and metal into blue, and multiplies
		# its white emission by a separate texture.
		material.set_shader_parameter(&"metallic_map", source.metallic_texture)
		material.set_shader_parameter(&"roughness_map", source.roughness_texture)
		material.set_shader_parameter(&"emission_map", source.emission_texture)
	_blade_wall_materials[mesh] = material
	return material

func _sample_blade_wall_boxes() -> void:
	if not player.combo.active() or not player.review_clip.is_empty():
		_clear_blade_wall_mask()
		return
	_blade_wall_probe.transform = Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP)
	var hits := get_world_3d().direct_space_state.intersect_shape(_blade_wall_probe, BLADE_WALL_LIMIT)
	var axes := PackedVector4Array()
	for hit in hits:
		axes.append_array(_upright_box_axes(hit))
	if axes.is_empty():
		_clear_blade_wall_mask()
		return
	if _blade_blocker_count == 0:
		_blade_base_override = _weapon_mesh.material_override
		_weapon_mesh.material_override = _blade_wall_material
	var count := floori(axes.size() / 3.0)
	if count != _blade_blocker_count:
		_blade_blocker_count = count
		_blade_wall_material.set_shader_parameter(&"blade_blocker_count", count)
	axes.resize(3 * BLADE_WALL_LIMIT)
	_blade_wall_material.set_shader_parameter(&"blocker_axes", axes)

func _clear_blade_wall_mask() -> void:
	if _blade_blocker_count == 0:
		return
	_blade_blocker_count = 0
	_blade_wall_material.set_shader_parameter(&"blade_blocker_count", 0)
	_weapon_mesh.material_override = _blade_base_override
	_blade_base_override = null

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
	_bow_display_mesh_index = player.render_presenter.meshes.find(_bow_mount)
	player.configure_bow_mount(_bow_mount, meshes)
	_bow_profile = Bow.combat_profile(root)
	_bow = Bow.new()
	_bow.name = "Bow"
	_bow.bolt_mesh = arrow
	_bow.ammo_changed.connect(_set_bow_ammo)
	_bow.arrow_impact.connect(_on_bow_impact)
	$CombatEffects.add_child(_bow)
	_apply_impact_fx_settings()
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
		_grounded_impact_dispatch = true
		$Zombies.strike_sabre(index, clip, serial)
		_grounded_impact_dispatch = false
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

func _setup_floor_surfaces() -> Texture2DArray:
	var picker: OptionButton = $HUD/FloorSurface
	for title in ["Nền thử · Cỏ", "Nền thử · Đất", "Nền thử · Đá"]:
		picker.add_item(title)
	picker.select(0)
	_floor_tiles = SourceTerrain.load_lab_tiles()
	for index in range(1, FLOOR_SURFACES.size()):
		picker.set_item_disabled(index, not _floor_tiles.has(FLOOR_SURFACES[index]))
	var tiles: Texture2DArray = _floor_tiles.get("grass")
	picker.disabled = tiles == null
	if tiles != null:
		var material := $Ground/Mesh.material_override as ShaderMaterial
		material.set_shader_parameter("source_terrain_tiles", tiles)
		material.set_shader_parameter("use_source_terrain", true)
		picker.item_selected.connect(_select_floor_surface)
	return tiles

func _select_floor_surface(index: int) -> void:
	var surface: String = FLOOR_SURFACES[index]
	if surface == _floor_surface:
		return
	var tiles: Texture2DArray = _floor_tiles.get(surface)
	if tiles == null:
		$HUD/FloorSurface.select(FLOOR_SURFACES.find(_floor_surface))
		$HUD/SpawnStatus.text = "Thiếu texture nền đã xác minh trong MD2 Research."
		return
	var material := $Ground/Mesh.material_override as ShaderMaterial
	material.set_shader_parameter("source_terrain_tiles", tiles)
	_floor_surface = surface
	if _gauntlet_impact_marks != null:
		_gauntlet_impact_marks.clear()
	_foot_contact_tick = -1
	_landing_contact_tick = -1
	if _combat_audio != null:
		_combat_audio.queue_landing_surface(WeaponSource.research_root(), surface)
	if _movement_audio != null and not _movement_audio.groups.has(surface):
		var bundle := PrivateOverworldBundle.new()
		if _use_local_movement_bank(bundle, surface):
			_movement_audio.load_surface_bank(surface, bundle)

func _setup_render_scale() -> void:
	var picker: OptionButton = $HUD/RenderScale
	if RenderingServer.get_current_rendering_method() != &"mobile":
		picker.hide()
		return
	var viewport := get_viewport()
	_previous_3d_scale = viewport.scaling_3d_scale
	_previous_3d_scaling_mode = viewport.scaling_3d_mode
	picker.add_item("3D · Mặc định (%d%%)" % roundi(_previous_3d_scale * 100.0), 0)
	for percent in [85, 75]:
		picker.add_item("3D · %d%%" % percent, percent)
	picker.select(0)
	picker.item_selected.connect(_set_render_scale)

func _set_render_scale(index: int) -> void:
	var percent: int = $HUD/RenderScale.get_item_id(index)
	var viewport := get_viewport()
	_render_scale_overridden = percent > 0
	if _render_scale_overridden:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = percent * 0.01
	else:
		viewport.scaling_3d_mode = _previous_3d_scaling_mode
		viewport.scaling_3d_scale = _previous_3d_scale

func _setup_frame_rate() -> void:
	var picker: OptionButton = $HUD/FrameRate
	picker.add_item("FPS · Theo ứng dụng", 0)
	for fps in [60, 30]:
		picker.add_item("FPS · %d" % fps, fps)
	picker.select(0)
	picker.item_selected.connect(_set_frame_rate)

func _set_frame_rate(index: int) -> void:
	# The cap belongs to the process. Snapshot it when this Lab begins an
	# override, and respect any newer change made outside the Lab.
	if _frame_rate_override == 0 or Engine.max_fps != _frame_rate_override:
		_previous_max_fps = Engine.max_fps
	_frame_rate_override = $HUD/FrameRate.get_item_id(index)
	Engine.max_fps = _previous_max_fps if _frame_rate_override == 0 else _frame_rate_override

func _exit_tree() -> void:
	if _frame_rate_override > 0 and Engine.max_fps == _frame_rate_override:
		Engine.max_fps = _previous_max_fps
	# Drop the tool override before Forward Mobile tears down the mount's dependencies.
	if is_instance_valid(_weapon_mesh) and _weapon_mesh.material_override != null:
		_weapon_mesh.material_override = null
	var viewport := get_viewport()
	viewport.msaa_3d = _previous_msaa
	if _render_scale_overridden:
		viewport.scaling_3d_mode = _previous_3d_scaling_mode
		viewport.scaling_3d_scale = _previous_3d_scale

func _update_time_label() -> void:
	var minutes := roundi(showcase.hour * 60.0)
	$HUD/TimeOfDay.text = "%02d:%02d  ·  T đổi giờ" % [floori(minutes / 60.0), minutes % 60]

func _process(delta: float) -> void:
	_flush_player_damage()
	if _combat_audio != null:
		_combat_audio.flush_zombie_combat_cues()
		_combat_audio.flush_zombie_steps()
		_combat_audio.flush_zombie_idle()
	if _crowd_spawns_left > 0:
		_spawn_crowd_frame()
	elif _combat_audio != null:
		_combat_audio.prepare_queued_samples()
		_prepare_ranged_resource()
	if _bow != null:
		# The player presenter has already sampled the interpolated grip.
		var presenter = player.render_presenter
		var charge_age: float = player.bow_charge_cue_age(presenter.display_clock) if _bow_mount.is_visible_in_tree() else -1.0
		_bow.present_charge_cue(charge_age, presenter.display_meshes[_bow_display_mesh_index])
	var focus: Vector3 = presentation.player_position()
	if _blade_blocker_count > 0:
		_blade_wall_material.set_shader_parameter(&"actor_xz", Vector2(focus.x, focus.z))
	camera.position = CAMERA_OFFSET + Vector3(focus.x, 0.0, focus.z)
	if not _pending_melee_feedback.is_empty():
		_present_melee_feedback(player.render_presenter.display_clock)
	if _tool_slam_time >= 0.0:
		var display_time: float = player.render_presenter.display_clock
		var age := display_time - _tool_slam_time
		if _tool_slam_pending and age >= 0.0:
			_tool_slam_pending = false
			# Preserve interpolation on normal frames. After a hitch, the
			# first visible wave should still expand from the impact point.
			var first_step := get_physics_process_delta_time()
			if age > first_step:
				age = first_step
				_tool_slam_time = display_time - age
		_tool_slam_ring.visible = _tool_slam_opacity > 0.0 and age >= 0.0 and age < _tool_slam_duration
		if age >= _tool_slam_duration:
			_tool_slam_time = -1.0
		elif age >= 0.0:
			_tool_slam_material.set_shader_parameter(&"progress", age / _tool_slam_duration)
	# Publish glyphs even when this frame activated a previously idle batch.
	if _zombie_damage_numbers != null:
		_zombie_damage_numbers.present(delta)
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
		# Start the pulse at its full kick on the first eligible display frame.
		if _shake_sample_time >= 0.0:
			var display_time: float = player.render_presenter.display_clock
			_shake_age = minf(display_time - _shake_sample_time, _shake_duration)
			if _shake_pending and _shake_age >= 0.0 and _shake_age < _shake_duration:
				_shake_sample_time = display_time
				_shake_age = 0.0
				_shake_pending = false
		elif _shake_pending:
			_shake_pending = false
		else:
			_shake_age = minf(_shake_age + delta, _shake_duration)
		var decay := 1.0 - _shake_age / _shake_duration
		var pulse := cos(TAU * 15.0 * _shake_age) * decay * decay if _shake_age >= 0.0 else 0.0
		camera.h_offset = camera.size * _shake_strength * pulse * _shake_intensity
		if _shake_age >= _shake_duration:
			_shake_duration = 0.0
	if _light_pending:
		# Wait for the same pose as the spark burst. Start fading only after
		# the light has had its first visible frame, even after a hitch.
		if _light_sample_time < 0.0 or player.render_presenter.display_clock >= _light_sample_time:
			_light_pending = false
			_impact_light.show()
	elif _impact_light.visible:
		_light_remaining = maxf(0.0, _light_remaining - delta)
		var decay := _light_remaining / CONTACT_LIGHT_DURATION
		_impact_light.light_energy = _light_peak * decay * decay
		_impact_light.visible = _light_remaining > 0.0
		if not _impact_light.visible:
			_light_sample_time = -1.0

func _prepare_ranged_resource() -> void:
	var has_shader := _next_projectile_shader < PROJECTILE_SHADERS.size()
	if not has_shader and _pending_crossbow_clips.is_empty():
		return
	var now := Time.get_ticks_usec()
	var previous := _last_ranged_preparation_frame_us
	_last_ranged_preparation_frame_us = now
	var frame_rate := Engine.max_fps if Engine.max_fps > 0 else Engine.physics_ticks_per_second
	# Let the first rendered frame and any already-slow frame finish
	# before adding optional renderer work to the next idle update.
	if previous == 0 or now - previous > 1500000.0 / frame_rate or not player.is_on_floor() \
			or player.combat_requested or player.combo.active() or player.bow_busy():
		return
	if has_shader:
		# The preloaded resources submit their code on first RID access.
		PROJECTILE_SHADERS[_next_projectile_shader].get_rid()
		_next_projectile_shader += 1
	else:
		player.prepare_crossbow_clip(_pending_crossbow_clips.pop_front())

func _setup_movement_audio() -> void:
	var configured_manifest := OS.get_environment("MD2_OVERWORLD_BUNDLE")
	var bundle := PrivateOverworldBundle.new()
	bundle.rebase_extracted_audio = true
	# The pinned Lab bank has the same default samples and mix. Read the
	# larger ambience manifest first only when it was explicitly configured.
	var uses_manifest := not configured_manifest.is_empty() and bundle.read_audio(configured_manifest, "grass")
	if not uses_manifest and not _use_local_movement_bank(bundle):
		return
	_movement_audio = _prepare_movement_audio(bundle)
	if _movement_audio.groups.grass.is_empty():
		var fallback := PrivateOverworldBundle.new()
		fallback.rebase_extracted_audio = true
		var has_fallback := false
		if uses_manifest:
			has_fallback = _use_local_movement_bank(fallback)
		elif configured_manifest.is_empty():
			var manifest := WeaponSource.research_root().path_join("godot_lab/overworld_fidelity_v001/bundle.private.json")
			has_fallback = fallback.read_audio(manifest, "grass")
		if has_fallback:
			var alternative := _prepare_movement_audio(fallback)
			if alternative.groups.grass.is_empty():
				alternative.free()
			else:
				_movement_audio.free()
				_movement_audio = alternative
	_movement_audio.name = "MovementAudio"
	add_child(_movement_audio)

func _prepare_movement_audio(bundle: PrivateOverworldBundle) -> MovementAudio:
	var source_root := WeaponSource.research_root().simplify_path().replace("\\", "/").trim_suffix("/")
	var landing_fallback: PrivateOverworldBundle
	# A relocated ambience bundle may contain steps without the Jump bank.
	if bundle.root != source_root:
		landing_fallback = PrivateOverworldBundle.new()
		landing_fallback.root = source_root
	var movement := MovementAudio.new()
	movement.setup(player, null, bundle, _player_foot_contact_at, landing_fallback)
	movement.landing_contact = _floor_landing_contact_at
	movement.protect_landing_voice = true
	movement.allow_footstep_as_landing = false
	for voice: AudioStreamPlayer3D in movement.step_voices:
		voice.bus = _lab_audio_mix.bus_name(LabAudioMix.Layer.SURFACE)
	return movement

func _use_local_movement_bank(bundle: PrivateOverworldBundle, surface := "grass") -> bool:
	bundle.root = WeaponSource.research_root().simplify_path().replace("\\", "/").trim_suffix("/")
	var directory := bundle.root.path_join(STEP_DIRECTORY)
	if not bundle.permitted(directory):
		return false
	var bank: Array = FLOOR_STEP_BANKS[surface]
	var samples: Array[Dictionary] = []
	for i in bank[1].size():
		var name: String = bank[0] % (i + 1)
		var sample: Array = bank[1][i]
		samples.append({
			"name": name, "path": directory.path_join(name + ".ogg"),
			"sha256": sample[0], "seconds": sample[1],
		})
	bundle.data = {
		"audio": {surface: samples},
		"audio_config": {"footstep_radius_m": 70.0, "footsteps_db": -8.0, "landing_db": -5.0},
		"audio_scope": "Checksum-pinned MechanicLab surface media. Native Wwise routing and mix unverified.",
	}
	bundle.error = ""
	return true

func _player_foot_contact_at(sole: Vector3) -> Dictionary:
	# Audio, dust and wind receive the same planted-foot event in the same tick.
	var tick := Engine.get_physics_frames()
	if tick != _foot_contact_tick or sole != _foot_contact_sole:
		_foot_contact_tick = tick
		_foot_contact_sole = sole
		# Wall slides can move the capsule sideways without an advancing step.
		_foot_contact = _floor_step_contact_at(sole, player) if player.accepts_step_during_wall_contact() else {}
	return _foot_contact

func _floor_step_contact_at(sole: Vector3, actor: CharacterBody3D) -> Dictionary:
	var ground := _floor_contact_at(sole)
	if not ground.is_empty() and actor != null:
		# A snapped capsule can stay on a slope with no recorded floor slide.
		# Probe when the sole ray lands at a different height from the capsule.
		var verify_snap: bool = actor.is_on_floor() and absf(actor.global_position.y - ground.position.y) > actor.safe_margin * 2.0
		var support := _actor_floor_support(actor, sole, verify_snap)
		var supported_by_ground: bool = not support.is_empty() and support.body == $Ground
		if not supported_by_ground and (verify_snap or not support.is_empty()):
			return {}
	return ground

func _floor_contact_at(sole: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(sole + Vector3.UP * 0.08, sole - Vector3.UP * 0.30, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != $Ground or hit.normal.y < cos(player.floor_max_angle):
		return {}
	return {"position": hit.position, "surface": _floor_surface}

func _floor_landing_contact_at(point: Vector3) -> Dictionary:
	var tick := Engine.get_physics_frames()
	if tick != _landing_contact_tick or point != _landing_contact_point:
		_landing_contact_tick = tick
		_landing_contact_point = point
		var support := _actor_floor_support(player, point)
		if support.is_empty():
			_landing_contact = _floor_contact_at(point)
		else:
			_landing_contact = {"position": support.position, "surface": _floor_surface} if support.body == $Ground else {}
	return _landing_contact

func _actor_floor_support(actor: CharacterBody3D, point: Vector3, verify_snap := false) -> Dictionary:
	# A sole outside a ledge can raycast to the stage below. Prefer the
	# actual floor contact from this move_and_slide, including other bodies.
	var min_normal_y := cos(actor.floor_max_angle)
	var closest := INF
	var nearest := Vector3.ZERO
	var floor_body: CollisionObject3D
	var slide_count := actor.get_slide_collision_count()
	for i in slide_count + int(verify_snap):
		var collision: KinematicCollision3D
		if i < slide_count:
			collision = actor.get_slide_collision(i)
		else:
			var snap := -actor.up_direction * maxf(actor.floor_snap_length, actor.safe_margin)
			if floor_body != null or not actor.test_move(actor.global_transform, snap,
					_floor_snap_contact, actor.safe_margin, true, 4):
				break
			collision = _floor_snap_contact
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

func _on_zombie_step(sole: Vector3, actor: CharacterBody3D = null) -> void:
	if _zombie_step_dust == null and not _combat_audio.enabled:
		return
	# Snapshot the support now, before later physics ticks move the actor.
	var support := _floor_step_contact_at(sole, actor)
	if support.is_empty():
		return
	if _zombie_step_dust != null:
		_zombie_step_dust.burst(support.position, support.surface)
	_combat_audio.queue_zombie_step(support.position)

func _heavy_debris_delay() -> float:
	if _equipped_weapon == Weapon.SABRE:
		return SABRE_LANDING_DEBRIS_DELAY
	# The Axe uses the blade contact. Other tools with ground cues
	# dispatch their debris independently of the physical touchdown.
	if _equipped_weapon == Weapon.AXE or player.clips.get("AirAttack", {}).has("ground_effects"):
		return -1.0
	return 0.0

func _on_attack_accepted_timed(index: int, clip: String, serial: int, at: float) -> void:
	if MELEE_AUDIO_NAMES.has(_equipped_weapon):
		var airborne := clip == "AirAttack"
		if airborne and player.clips.AirAttack.has("flight_audio_time"):
			return
		# Positive montage offsets are dispatched as the clip crosses the notify.
		if not airborne and player.combo.native_enabled \
				and player.combo.native_windows[index].get("swing_audio_time", 0.0) > 0.0:
			return
		_combat_audio.tool_swung(MELEE_AUDIO_NAMES[_equipped_weapon], player.global_position + Vector3.UP, index, airborne)
	elif _equipped_weapon == Weapon.GAUNTLETS:
		_combat_audio.gauntlet_swung(player.global_position + Vector3.UP, index, clip == "AirAttack")
	elif clip != "AirAttack" or _equipped_weapon != Weapon.SABRE:
		player.reference_audio.trigger_attack(index, clip, serial, at)

func _on_tool_audio_cue(index: int, landing: bool, serial: int) -> void:
	var tool: StringName = MELEE_AUDIO_NAMES[_equipped_weapon]
	if not landing:
		_combat_audio.tool_swung(tool, player.global_position + Vector3.UP, index, player.combo.phase == &"air_attack")
	elif _tool_touchdown.get("serial") == serial:
		var point: Vector3 = _tool_touchdown.origin + _tool_touchdown.forward * $Zombies.air_centre_offset()
		_combat_audio.tool_landed(tool, point)

func _on_tool_landing_accent_cue(serial: int) -> void:
	if _tool_touchdown.get("serial") != serial:
		return
	var point: Vector3 = _tool_touchdown.surface_contact.get("position", _tool_touchdown.origin)
	_combat_audio.tool_landing_accent(MELEE_AUDIO_NAMES[_equipped_weapon], point)

func _on_tool_recovery_landing_cue(serial: int) -> void:
	if _movement_audio != null and _tool_touchdown.get("serial") == serial:
		_movement_audio.play_landing_at(player.global_position)

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
	var melee_tool: StringName = MELEE_AUDIO_NAMES.get(_equipped_weapon, &"")
	var preview: StringName = WEAPON_AUDIO_PREVIEWS.get(_equipped_weapon, &"")
	_combat_audio.set_enabled(enabled, player.global_position + Vector3.UP, melee_tool, preview)

func _on_sabre_contact(point: Vector3, direction: Vector3, clip: String, index: int, serial: int, _lethal: bool) -> void:
	if _grounded_impact_dispatch:
		player.confirm_melee_hitstop(serial)
	var tool_hit: StringName = MELEE_AUDIO_NAMES.get(_equipped_weapon, &"") if clip != Bow.ACTION and clip != CrossPollinator.SHOT else &""
	_combat_audio.weapon_contact(point, serial, clip, tool_hit)
	if _grounded_impact_dispatch or clip == "AirAttack":
		_pending_melee_contact_fx.append({"point": point, "direction": direction, "clip": clip, "serial": serial, "index": index})
		return
	_show_contact_fx(point, direction, clip, serial)

func _on_melee_contact_visual(zombie: CharacterBody3D, point: Vector3, serial: int, visual: Dictionary) -> void:
	visual.zombie = zombie
	visual.serial = serial
	var pose_ready := _combat_pose_frame == Engine.get_physics_frames()
	if not _pending_melee_contact_fx.is_empty():
		var contact: Dictionary = _pending_melee_contact_fx.back()
		if contact.serial == serial and contact.point == point:
			contact.feedback = visual
			if _grounded_impact_dispatch and (player.effects.blade_trail_enabled or player.gauntlets_equipped):
				contact.capsule = zombie.contact_capsule_dimensions()
			elif contact.clip == "AirAttack" and not visual.splash and player.effects.blade_trail_enabled:
				# Damage uses a lower visibility probe. The body spark instead
				# uses the actual capsule and this strike's blade pose.
				contact.spark_center = zombie.combat_center()
				contact.capsule = zombie.contact_capsule_dimensions()
			if pose_ready:
				_pending_melee_contact_fx.pop_back()
				_publish_melee_contact(contact, player.effects.clock, _blade_contact_points())
			return
	if pose_ready:
		visual.time = player.effects.clock
		_pending_melee_feedback.append(visual)

func _show_contact_fx(point: Vector3, direction: Vector3, clip: String, serial: int, sample_time := -1.0,
		capsule := Vector2.ZERO, weapon_points := PackedVector3Array(), punch_axis := Vector3.ZERO,
		splash := false, sweep_axis := Vector3.ZERO) -> void:
	var effect_point := point
	if not punch_axis.is_zero_approx():
		# Light the same point on the target as the punch streaks.
		effect_point = ContactSparks.contact_surface_point(point, capsule, weapon_points, direction)
		capsule = Vector2.ZERO
	var has_arrow_sparks := clip == CrossPollinator.SHOT and _crossbow != null and _crossbow.impact_sparks != null
	has_arrow_sparks = has_arrow_sparks or (clip == Bow.ACTION and _bow != null and _bow.impact_sparks != null)
	if not has_arrow_sparks:
		if _contact_sparks != null:
			_contact_sparks.queue_contact(effect_point, direction, player.global_position + Vector3.UP,
				sample_time, capsule, weapon_points, punch_axis, clip == "AirAttack" and capsule.x > 0.0, splash, sweep_axis)
		else:
			player.effects.contact(effect_point, direction, sample_time >= 0.0)
	var finisher := clip in ["Attack3", "NativeFinisher", "NativeCurvedAttack3", "NativeGauntletAttack3",
		"NativeCleaverAttack3", "NativeAxeAttack3"]
	if _light_serial != serial and (clip != "AirAttack" or _equipped_weapon != Weapon.SABRE):
		var light_point := effect_point
		if capsule.x > 0.0 and not weapon_points.is_empty():
			light_point = ContactSparks.contact_surface_point(point, capsule, weapon_points, direction)
		_start_contact_light(light_point, serial, 2.3 if finisher else 1.8, sample_time)
	# These finishers share the source radii and non-oriented shake.
	# Approximate StartMatineeCameraShakeAtPawn using the capsule center.
	if not finisher or _shake_serial == serial or _player_body == null:
		return
	var distance := _player_body.global_position.distance_to(point)
	var falloff := 1.0 - clampf(inverse_lerp(FINISHER_SHAKE_INNER_RADIUS, FINISHER_SHAKE_OUTER_RADIUS, distance), 0.0, 1.0)
	if falloff <= 0.0:
		return
	_shake_serial = serial
	var strength := GAUNTLET_FINISHER_SHAKE_HEIGHT_FRACTION if clip == "NativeGauntletAttack3" else FINISHER_SHAKE_HEIGHT_FRACTION
	_start_camera_shake(strength * falloff, sample_time)

func _start_camera_shake(strength: float, sample_time := -1.0) -> void:
	_shake_strength = strength
	_shake_age = 0.0
	_shake_duration = HEAVY_SHAKE_DURATION
	_shake_pending = true
	_shake_sample_time = sample_time

func _clear_camera_shake() -> void:
	_shake_serial = -1
	_shake_duration = 0.0
	_shake_pending = false
	_shake_sample_time = -1.0
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
	var debris_delay := _heavy_debris_delay()
	if _equipped_weapon == Weapon.SABRE or player.clips.get("AirAttack", {}).has("ground_effects"):
		_tool_touchdown = {"origin": point, "forward": facing.slide(Vector3.UP).normalized(),
			"surface_contact": _floor_landing_contact_at(point), "serial": serial}
	# Evaluate the height tiers against the support rather than the capsule origin.
	var floor_height := _landing_floor_height(point)
	fall_height = maxf(0.0, fall_height + point.y - floor_height)
	var burst_reach: float = SABRE_LANDING_BURST_REACH if _equipped_weapon == Weapon.SABRE else $Zombies.air_centre_offset()
	# Tools can contact several frames later, when this touchdown's slide
	# contacts may already be gone.
	_slam_burst_point = _landing_impact_anchor(point, facing, floor_height, burst_reach)
	_slam_burst_serial = serial
	$Zombies.land_sabre(point, facing, serial, fall_height)
	if player.gauntlets_equipped:
		var support := _floor_landing_contact_at(point)
		if not support.is_empty():
			_show_gauntlet_ground_impact(support.position, facing, support.surface)
		return
	if not _combat_audio.enabled or debris_delay < 0.0:
		return
	if _equipped_weapon == Weapon.SABRE:
		_slam_swing_serial = serial
		_slam_swing_frame = Engine.get_physics_frames() + ceili(SABRE_LANDING_SWING_DELAY * Engine.physics_ticks_per_second)
	var contact := _floor_landing_contact_at(point)
	if contact.is_empty():
		# The Sword impact belongs to the weapon. It still has a confirmed
		# contact on a solid floor whose material has no debris cue.
		if _equipped_weapon == Weapon.SWORD:
			var support := _actor_floor_support(player, point, true)
			if not support.is_empty():
				_combat_audio.slam_landed(support.position, "")
		return
	var delay_ticks := ceili(debris_delay * Engine.physics_ticks_per_second)
	if delay_ticks > 0:
		_slam_audio_point = contact.position
		_slam_audio_surface = contact.surface
		_slam_audio_frame = Engine.get_physics_frames() + delay_ticks
	else:
		_combat_audio.slam_landed(contact.position, contact.surface)

func _show_gauntlet_ground_impact(touchdown: Vector3, facing: Vector3, surface: String) -> void:
	# The source debris notify owns the crack and the surface sound as well.
	var anchor := _gauntlet_impact_anchor(touchdown, facing, MovementDust.GAUNTLET_DEBRIS_FORWARD)
	if not _gauntlet_impact_marks.stamp(anchor, surface) and anchor != touchdown:
		anchor = touchdown
		_gauntlet_impact_marks.stamp(anchor, surface)
	if _movement_dust != null:
		var puff := _gauntlet_impact_anchor(touchdown, facing, MovementDust.GAUNTLET_IMPACT_DUST_FORWARD)
		_movement_dust.emit_gauntlet_impact(anchor, puff, surface)
	_combat_audio.slam_landed(anchor, surface)

func _gauntlet_impact_anchor(touchdown: Vector3, facing: Vector3, reach: float) -> Vector3:
	var forward := facing.slide(Vector3.UP).normalized()
	var start := touchdown + Vector3.UP * 0.12
	var ray := PhysicsRayQueryParameters3D.create(start, start + forward * (reach + 0.08), 1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return touchdown
	var contact := _floor_contact_at(touchdown + forward * reach)
	return contact.get("position", touchdown)

func _landing_impact_anchor(point: Vector3, facing: Vector3, floor_height: float, reach: float) -> Vector3:
	var origin := Vector3(point.x, floor_height, point.z)
	var forward := facing.slide(Vector3.UP).normalized()
	var probe := Vector3.UP * 0.12
	var space := get_world_3d().direct_space_state
	var distance := reach
	var ray := PhysicsRayQueryParameters3D.create(origin + probe, origin - probe, 1, [player.get_rid()])
	if distance > 0.0 and not forward.is_zero_approx():
		ray.to = ray.from + forward * distance
		var obstruction := space.intersect_ray(ray)
		if not obstruction.is_empty():
			distance = maxf(0.0, (Vector3(obstruction.position) - origin).dot(forward) - 0.08)
	var candidate := origin + forward * distance
	ray.from = candidate + probe
	ray.to = candidate - probe
	var floor_contact := space.intersect_ray(ray)
	if not floor_contact.is_empty() and floor_contact.normal.y >= cos(player.floor_max_angle):
		return floor_contact.position

	# At a ledge, use the sole's actual touchdown support even if the
	# projected burst would reach the lower floor or empty space.
	var support := _actor_floor_support(player, point)
	return support.get("position", origin)

func _on_sabre_landing(point: Vector3, serial: int) -> void:
	if _equipped_weapon == Weapon.SABRE:
		return
	elif _equipped_weapon == Weapon.GAUNTLETS:
		_combat_audio.gauntlet_slam_landed(point)
	elif MELEE_AUDIO_NAMES.has(_equipped_weapon) and not player.clips.AirAttack.has("landing_audio_time"):
		_combat_audio.tool_landed(MELEE_AUDIO_NAMES[_equipped_weapon], point)
	if _slam_burst_serial != serial:
		_slam_burst_point = point
		_slam_burst_serial = serial
	var frame := Engine.get_physics_frames()
	if _combat_pose_frame == frame:
		_show_landing_burst(_slam_burst_point, serial, player.effects.clock)
		return
	_slam_burst_frame = frame

func _show_landing_burst(point: Vector3, serial: int, sample_time: float) -> void:
	player.effects.contact(point + Vector3.UP * 0.12, Vector3.UP, true, sample_time)
	_start_contact_light(point + Vector3.UP * 0.60, serial, 2.3, sample_time)
	if _equipped_weapon == Weapon.AXE:
		var contact := _floor_contact_at(point)
		if not contact.is_empty() and absf(contact.position.y - point.y) <= 0.06:
			if _movement_dust != null:
				_movement_dust.emit_heavy_ground_contact(contact.position, contact.surface)
			_combat_audio.slam_landed(contact.position, contact.surface)

func _setup_tool_slam_ring() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * GROUND_SLAM_RADIUS * 2.0
	_tool_slam_material = ShaderMaterial.new()
	_tool_slam_material.shader = GROUND_SLAM_SHADER
	_tool_slam_ring = MeshInstance3D.new()
	_tool_slam_ring.name = "ToolGroundSlam"
	_tool_slam_ring.mesh = mesh
	_tool_slam_ring.material_override = _tool_slam_material
	_tool_slam_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tool_slam_ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_tool_slam_ring.hide()
	$CombatEffects.add_child(_tool_slam_ring)
	# Match the ring's maximum footprint and keep the query thin around its
	# render plane so distant props and overhangs leave clipping slots free.
	var disc := CylinderShape3D.new()
	disc.radius = GROUND_SLAM_RADIUS
	disc.height = 0.01
	_tool_slam_footprint.shape = disc
	_tool_slam_footprint.collision_mask = 1

func _queue_tool_ground_cue(cue: Dictionary, serial: int, sample_time: float) -> void:
	_pending_tool_ground_cues.append({"cue": cue, "serial": serial, "sample_time": sample_time,
		"landing": player.combo.phase == &"air_attack"})

func _tool_ground_contact(offset: Vector2, forward: Vector3, origin: Vector3, support: Dictionary) -> Dictionary:
	if support.is_empty():
		return {}
	origin.y = support.position.y
	var lateral := Vector3.UP.cross(forward)
	var path := lateral * offset.x + forward * offset.y
	# The offset must be supported at the same height and on this side of
	# the wall. An interrupted swing cannot stamp a lower floor or a wall.
	var start := origin + Vector3.UP * 0.12
	var ray := PhysicsRayQueryParameters3D.create(start, start + path + path.normalized() * 0.08, 1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return {}
	var contact := _floor_contact_at(origin + path)
	if contact.is_empty() or absf(contact.position.y - origin.y) > 0.06:
		return {}
	return contact

func _show_tool_slam_ring(point: Vector3, surface: String, sample_time: float) -> void:
	var planes := PackedVector3Array()
	var blocker_axes := PackedVector4Array()
	if not _clip_slam_to_stage(point, planes) or not _clip_slam_at_walls(point, planes, blocker_axes):
		return
	_tool_slam_material.set_shader_parameter(&"blocker_count", blocker_axes.size() / 2)
	if not blocker_axes.is_empty():
		blocker_axes.resize(2 * GROUND_SLAM_MAX_CLIPS)
		_tool_slam_material.set_shader_parameter(&"blocker_axes", blocker_axes)
	_tool_slam_material.set_shader_parameter(&"clip_count", planes.size())
	if not planes.is_empty():
		planes.resize(GROUND_SLAM_MAX_CLIPS)
		_tool_slam_material.set_shader_parameter(&"clip_planes", planes)
	_tool_slam_ring.global_position = point + Vector3.UP * GROUND_SLAM_HEIGHT
	_tool_slam_ring.hide()
	_tool_slam_material.set_shader_parameter(&"tint", MovementDust.SURFACE_DUST[surface].lightened(0.36))
	_tool_slam_duration = GROUND_SLAM_DURATION * _tool_slam_duration_scale
	_tool_slam_time = sample_time
	_tool_slam_pending = true

func _clip_slam_to_stage(point: Vector3, planes: PackedVector3Array) -> bool:
	var floor: CollisionShape3D = $Ground/Collision
	var box := floor.shape as BoxShape3D
	if box == null or not floor.global_basis.y.normalized().is_equal_approx(Vector3.UP):
		for corner: Vector3 in GROUND_SLAM_CORNERS:
			if _floor_contact_at(point + corner * GROUND_SLAM_RADIUS).is_empty():
				return false
		return true
	var to_floor := floor.global_transform.affine_inverse()
	var centre := to_floor * point
	var half := box.size * 0.5
	# Express the inside of the receiver box in coordinates relative to
	# the ring, so the shader can cut the same plane on a rotated stage.
	var floor_x := Vector2(to_floor.basis.x.x, to_floor.basis.z.x)
	var floor_z := Vector2(to_floor.basis.x.z, to_floor.basis.z.z)
	for plane in [Vector3(floor_x.x, floor_x.y, half.x + centre.x),
			Vector3(-floor_x.x, -floor_x.y, half.x - centre.x),
			Vector3(floor_z.x, floor_z.y, half.z + centre.z),
			Vector3(-floor_z.x, -floor_z.y, half.z - centre.z)]:
		if plane.z < GROUND_SLAM_RADIUS * (absf(plane.x) + absf(plane.y)):
			planes.append(plane)
	return true

func _clip_slam_at_walls(point: Vector3, planes: PackedVector3Array, blocker_axes: PackedVector4Array) -> bool:
	var space := get_world_3d().direct_space_state
	var start := point + Vector3.UP * GROUND_SLAM_HEIGHT
	_tool_slam_footprint.transform = Transform3D(Basis.IDENTITY, start)
	var available := GROUND_SLAM_MAX_CLIPS - planes.size()
	var blockers := space.intersect_shape(_tool_slam_footprint, available + 1)
	if blockers.size() > available:
		return false
	if blockers.is_empty():
		return true
	for i in range(blockers.size() - 1, -1, -1):
		if _append_slam_box(blockers[i], start, blocker_axes):
			blockers.remove_at(i)
	if blockers.is_empty():
		return true
	var ray := PhysicsRayQueryParameters3D.create(start, start, 1)
	for direction: Vector3 in GROUND_SLAM_SIDES + GROUND_SLAM_CORNERS:
		ray.to = start + direction * GROUND_SLAM_RADIUS
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			continue
		var index := blockers.find_custom(func(blocker): return blocker.rid == hit.rid and blocker.shape == hit.shape)
		if index < 0:
			continue
		var normal: Vector3 = Vector3(hit.normal).slide(Vector3.UP).normalized()
		if normal.is_zero_approx():
			continue
		var distance := (start - Vector3(hit.position)).dot(normal)
		planes.append(Vector3(normal.x, normal.z, distance - 0.004))
		blockers.remove_at(index)
		if blockers.is_empty():
			return true
	# Preserve the conservative behavior for obstructions without a sampled
	# face at the ring height.
	return false

func _append_slam_box(blocker: Dictionary, origin: Vector3, axes: PackedVector4Array) -> bool:
	var box := _upright_box_axes(blocker)
	if box.is_empty():
		return false
	var height := box[2]
	# A box above or below the ring does not cross its render plane.
	if absf(origin.y * height.x + height.z) <= height.w:
		var x := box[0]
		var z := box[1]
		x.z += origin.x * x.x + origin.z * x.y
		z.z += origin.x * z.x + origin.z * z.y
		axes.append(x)
		axes.append(z)
	return true

func _upright_box_axes(blocker: Dictionary) -> PackedVector4Array:
	var body := blocker.collider as CollisionObject3D
	if body == null:
		return PackedVector4Array()
	var shape_index: int = blocker.shape
	var owner := body.shape_find_owner(shape_index)
	for local_index in body.shape_owner_get_shape_count(owner):
		if body.shape_owner_get_shape_index(owner, local_index) != shape_index:
			continue
		var box := body.shape_owner_get_shape(owner, local_index) as BoxShape3D
		if box == null:
			return PackedVector4Array()
		var shape_to_world := body.global_transform * body.shape_owner_get_transform(owner)
		var to_shape := shape_to_world.affine_inverse()
		if not is_zero_approx(to_shape.basis.x.y) or not is_zero_approx(to_shape.basis.z.y):
			return PackedVector4Array()
		var half_size := box.size * 0.5
		return PackedVector4Array([
			Vector4(to_shape.basis.x.x, to_shape.basis.z.x, to_shape.origin.x, half_size.x),
			Vector4(to_shape.basis.x.z, to_shape.basis.z.z, to_shape.origin.z, half_size.z),
			Vector4(to_shape.basis.y.y, 0.0, to_shape.origin.y, half_size.y),
		])
	return PackedVector4Array()

func _show_tool_ground_cues() -> void:
	for event in _pending_tool_ground_cues:
		var cue: Dictionary = event.cue
		var sample_time: float = event.sample_time
		if event.landing and _tool_touchdown.get("serial") != event.serial:
			continue
		if cue.get("impact_burst", false):
			_show_landing_burst(_slam_burst_point, event.serial, sample_time)
		if cue.effect == MeleeTools.GroundEffect.SHAKE:
			_shake_serial = event.serial
			var strength := FINISHER_SHAKE_HEIGHT_FRACTION if cue.get("medium", false) else TOOL_SHAKE_HEIGHT_FRACTION
			_start_camera_shake(strength, sample_time)
			continue
		var origin: Vector3 = _tool_touchdown.origin if event.landing else player.global_position
		var forward: Vector3 = _tool_touchdown.forward if event.landing else player.visual.global_basis.z.slide(Vector3.UP).normalized()
		var support: Dictionary = _tool_touchdown.surface_contact if event.landing else _floor_landing_contact_at(origin)
		var contact := _tool_ground_contact(cue.offset, forward, origin, support)
		if contact.is_empty():
			continue
		var elapsed_ticks: float = (player.effects.clock - sample_time) / get_physics_process_delta_time()
		var tick := Engine.get_physics_frames() - elapsed_ticks
		match cue.effect:
			MeleeTools.GroundEffect.SHOCKWAVE:
				_show_tool_slam_ring(contact.position, contact.surface, sample_time)
			MeleeTools.GroundEffect.DEBRIS:
				if _movement_dust != null:
					var basis := Basis.looking_at(forward, Vector3.UP, true) \
						* Basis(Vector3.UP, deg_to_rad(cue.get("yaw", 0.0))) \
						* Basis(Vector3.RIGHT, deg_to_rad(cue.get("roll", 0.0)))
					_movement_dust.emit_combat_debris(contact.position, contact.surface, tick, cue.get("medium", false), basis)
				if cue.get("mark", false) and _gauntlet_impact_marks != null:
					_gauntlet_impact_marks.stamp(contact.position, contact.surface, elapsed_ticks)
				_combat_audio.slam_landed(contact.position, contact.surface)
			MeleeTools.GroundEffect.DUST:
				if _movement_dust != null:
					_movement_dust.emit_combat_puff(contact.position, contact.surface, tick)
	_pending_tool_ground_cues.clear()

func _sample_combat_fx() -> void:
	# Immediate melee can be dispatched before this sample. Delayed air contacts
	# can also arrive after it and use the pose already sampled in this tick.
	_combat_pose_frame = Engine.get_physics_frames()
	if _blade_wall_material != null:
		_sample_blade_wall_boxes()
	if not _pending_tool_ground_cues.is_empty():
		_show_tool_ground_cues()
	if _pending_melee_contact_fx.is_empty() and _slam_burst_frame < 0:
		_remember_blade_pose()
		return
	var sample_time: float = player.effects.clock
	# Keep the floor flash first when both contacts request light for the same swing.
	if _slam_burst_frame >= 0 and _combat_pose_frame >= _slam_burst_frame:
		_slam_burst_frame = -1
		_show_landing_burst(_slam_burst_point, _slam_burst_serial, sample_time)
	if not _pending_melee_contact_fx.is_empty():
		var weapon_points := _blade_contact_points()
		var punch_index := -1
		var impact_axis := Vector3.ZERO
		for contact in _pending_melee_contact_fx:
			var capsule: Vector2 = contact.get("capsule", Vector2.ZERO)
			var is_punch: bool = player.gauntlets_equipped and capsule.x > 0.0
			if is_punch and contact.index != punch_index:
				punch_index = contact.index
				weapon_points = PackedVector3Array([_gauntlet_knuckle(punch_index)])
				impact_axis = player.visual.global_basis * Gauntlets.CONTACT_AXES[punch_index]
			_publish_melee_contact(contact, sample_time, weapon_points, impact_axis if is_punch else Vector3.ZERO)
	_pending_melee_contact_fx.clear()
	_remember_blade_pose()

func _remember_blade_pose() -> void:
	if player.combo.phase != &"attack" or not player.effects.blade_trail_enabled:
		_previous_blade_serial = -1
		return
	_previous_blade_base = player.marker_base.global_position
	_previous_blade_tip = player.marker_tip.global_position
	_previous_blade_serial = player.combo.serial

func _blade_contact_points() -> PackedVector3Array:
	if not player.effects.blade_trail_enabled:
		return PackedVector3Array()
	return PackedVector3Array([player.marker_base.global_position, player.marker_tip.global_position])

func _publish_melee_contact(contact: Dictionary, sample_time: float, weapon_points: PackedVector3Array,
		punch_axis := Vector3.ZERO) -> void:
	var visual: Dictionary = contact.get("feedback", {})
	if not visual.is_empty():
		visual.time = sample_time
		_pending_melee_feedback.append(visual)
	var spark_center: Vector3 = contact.get("spark_center", contact.point)
	var capsule: Vector2 = contact.get("capsule", Vector2.ZERO)
	var splash: bool = visual.get("splash", false)
	var sweep_axis := Vector3.ZERO
	if contact.clip != "AirAttack" and not splash and capsule.x > 0.0 and weapon_points.size() == 2 \
			and contact.serial == _previous_blade_serial:
		var base := weapon_points[0]
		var tip := weapon_points[1]
		var cut := tip - base
		if not cut.is_zero_approx():
			var surface := ContactSparks.contact_surface_point(spark_center, capsule, weapon_points, contact.direction)
			var fraction := clampf((surface - base).dot(cut) / cut.length_squared(), 0.0, 1.0)
			var travel := base.lerp(tip, fraction) - _previous_blade_base.lerp(_previous_blade_tip, fraction)
			# Hold the radial burst if the blade scarcely moved during this interval.
			if travel.length_squared() >= 0.000025:
				sweep_axis = travel.normalized()
	_show_contact_fx(spark_center, contact.direction, contact.clip, contact.serial,
		sample_time, capsule, weapon_points, punch_axis, splash, sweep_axis)

func _present_melee_feedback(display_time: float) -> void:
	# Tone down overlapping splash highlights by attack. A separate strike
	# queued during a slow frame keeps its own feedback strength.
	var splashes_by_strike: Dictionary[int, int] = {}
	if _pending_melee_feedback.size() > SPLASH_FLASH_UNDIMMED_COUNT:
		for visual in _pending_melee_feedback:
			if visual.time > display_time:
				break
			if visual.splash and is_instance_valid(visual.zombie) and not visual.zombie.is_queued_for_deletion():
				splashes_by_strike[visual.serial] = splashes_by_strike.get(visual.serial, 0) + 1
	var presented := 0
	for visual in _pending_melee_feedback:
		if visual.time > display_time:
			break
		if is_instance_valid(visual.zombie) and not visual.zombie.is_queued_for_deletion():
			if visual.splash:
				var count: int = splashes_by_strike.get(visual.serial, 0)
				if count > SPLASH_FLASH_UNDIMMED_COUNT:
					var scale := sqrt(float(SPLASH_FLASH_UNDIMMED_COUNT) / count)
					visual.peak *= maxf(SPLASH_FLASH_MIN_SCALE, scale)
			visual.zombie.show_deferred_hit(visual)
		presented += 1
	if presented == _pending_melee_feedback.size():
		_pending_melee_feedback.clear()
	elif presented > 0:
		_pending_melee_feedback = _pending_melee_feedback.slice(presented)

func _start_contact_light(point: Vector3, serial: int, energy: float, sample_time := -1.0) -> void:
	if _light_serial == serial:
		return
	_light_serial = serial
	_light_peak = energy
	_light_remaining = CONTACT_LIGHT_DURATION
	_light_pending = true
	_light_sample_time = sample_time
	_impact_light.global_position = point
	_impact_light.light_energy = _light_peak
	_impact_light.visible = sample_time < 0.0

func _clear_contact_light() -> void:
	_clear_blade_wall_mask()
	if not _pending_melee_contact_fx.is_empty() or not _pending_melee_feedback.is_empty():
		# A reset discards the old pose and transient effects. Show the health
		# already committed by simulation, even if its last cue was pending.
		for zombie in $Zombies.get_children():
			zombie.sync_hit_health()
	_pending_melee_contact_fx.clear()
	_pending_melee_feedback.clear()
	_pending_tool_ground_cues.clear()
	_tool_touchdown.clear()
	_tool_slam_time = -1.0
	_tool_slam_pending = false
	if _tool_slam_ring != null:
		_tool_slam_ring.hide()
	_combat_pose_frame = -1
	_previous_blade_serial = -1
	_slam_burst_frame = -1
	_slam_burst_serial = -1
	_light_serial = -1
	_light_remaining = 0.0
	_light_pending = false
	_light_sample_time = -1.0
	_impact_light.light_energy = 0.0
	_impact_light.hide()

func _physics_process(_delta: float) -> void:
	if player.position.y < -5.0:
		reset_player()
	var frame := Engine.get_physics_frames()
	if _slam_swing_frame >= 0 and frame >= _slam_swing_frame:
		_slam_swing_frame = -1
		if player.combo.serial == _slam_swing_serial and player.combo.active():
			player.reference_audio.trigger_attack_at_notify("AirAttack", _slam_swing_serial)
	if _slam_audio_frame >= 0 and frame >= _slam_audio_frame:
		_cancel_slam_audio()
		_combat_audio.slam_landed(_slam_audio_point, _slam_audio_surface)

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

func _set_ragdoll_lifetime(seconds: float) -> void:
	$Zombies.corpse_lifetime = seconds
	$HUD/RagdollLifetime/Value.text = "Xác biến mất · %.1f s" % seconds

func _set_camera_shake_intensity(percent: float) -> void:
	_shake_intensity = percent * 0.01
	$HUD/CameraShake/Value.text = "Rung camera · %d%%" % roundi(percent)
	if _shake_intensity == 0.0:
		camera.h_offset = 0.0

func _set_hitstop(milliseconds: float) -> void:
	$HUD/Hitstop/Value.text = "Hitstop thử · %d ms" % roundi(milliseconds)
	if is_instance_valid(player):
		player.hitstop_seconds = milliseconds / 1000.0

func _setup_impact_fx_controls() -> void:
	var button: Button = $HUD/ImpactFxButton
	var panel: PanelContainer = $HUD/ImpactFxPanel
	button.visible = _contact_sparks != null or _tool_slam_material != null
	if not button.visible:
		return
	button.toggled.connect(panel.set_visible)
	var picker := panel.get_node("Rows/ContactSparkQuality") as OptionButton
	picker.add_item("Số tia · Đầy đủ", SparkBudget.FULL)
	picker.add_item("Số tia · Cân bằng", SparkBudget.BALANCED)
	picker.add_item("Số tia · Nhẹ", SparkBudget.LOW)
	picker.select(0)
	picker.item_selected.connect(_apply_impact_fx_settings.unbind(1))
	var debris := panel.get_node("Rows/DebrisQuality") as OptionButton
	debris.add_item("Mảnh văng · Gọn", 0)
	debris.add_item("Mảnh văng · Có va chạm", 1)
	debris.select(0)
	debris.disabled = _movement_dust == null
	debris.item_selected.connect(_apply_impact_fx_settings.unbind(1))
	for row in ["Opacity", "Duration", "RibbonOpacity", "SlamOpacity", "SlamDuration"]:
		var slider := panel.get_node("Rows/" + row + "/Slider") as HSlider
		slider.value_changed.connect(_apply_impact_fx_settings.unbind(1))
	_apply_impact_fx_settings()

func _apply_impact_fx_settings() -> void:
	var opacity: float = $HUD/ImpactFxPanel/Rows/Opacity/Slider.value
	var duration: float = $HUD/ImpactFxPanel/Rows/Duration/Slider.value
	var budget: int = $HUD/ImpactFxPanel/Rows/ContactSparkQuality.get_selected_id()
	var spawn_scale: float = SPARK_SPAWN_SCALES.get(budget, 1.0)
	if _movement_dust != null:
		_movement_dust.detailed_debris = $HUD/ImpactFxPanel/Rows/DebrisQuality.get_selected_id() == 1
	$HUD/ImpactFxPanel/Rows/Opacity/Value.text = "Độ rõ tia · %d%%" % roundi(opacity)
	$HUD/ImpactFxPanel/Rows/Duration/Value.text = "Thời gian tia · %d%%" % roundi(duration)
	if _contact_sparks != null:
		_contact_sparks.set_opacity(opacity * 0.01)
		_contact_sparks.duration_scale = duration * 0.01
		_contact_sparks.set_budget_scale(spawn_scale)
	for projectile: CrossPollinator in [_crossbow, _bow]:
		if projectile != null and projectile.impact_sparks != null:
			var sparks := projectile.impact_sparks
			sparks.set_opacity(opacity * 0.01)
			sparks.duration_scale = duration * 0.01
			sparks.spawn_count_scale = spawn_scale
	_apply_weapon_vfx_settings()

func _apply_weapon_vfx_settings() -> void:
	var rows := $HUD/ImpactFxPanel/Rows
	var ribbon: float = rows.get_node("RibbonOpacity/Slider").value
	var slam: float = rows.get_node("SlamOpacity/Slider").value
	var duration: float = rows.get_node("SlamDuration/Slider").value
	rows.get_node("RibbonOpacity/Value").text = "Vệt vũ khí · %d%%" % roundi(ribbon)
	rows.get_node("SlamOpacity/Value").text = "Vòng xung kích · %d%%" % roundi(slam)
	rows.get_node("SlamDuration/Value").text = "Thời gian vòng · %d%%" % roundi(duration)
	_tool_slam_duration_scale = duration * 0.01
	_tool_slam_opacity = slam * 0.01
	if _tool_slam_material != null:
		_tool_slam_material.set_shader_parameter(&"opacity_scale", _tool_slam_opacity)
		if _tool_slam_opacity == 0.0:
			_tool_slam_ring.hide()
	var trail_opacity := ribbon * 0.01
	if player.effects != null and player.effects.ribbon != null:
		var blade_ribbon: MeshInstance3D = player.effects.ribbon
		blade_ribbon.visible = trail_opacity > 0.0
		var melee_material := blade_ribbon.material_override
		if melee_material is ShaderMaterial:
			melee_material.set_shader_parameter(&"opacity_scale", trail_opacity)
		elif melee_material is StandardMaterial3D:
			melee_material.albedo_color = Color(melee_material.albedo_color, trail_opacity)
	for projectile: CrossPollinator in [_crossbow, _bow]:
		if projectile != null:
			projectile.set_trail_opacity(trail_opacity)

func _setup_audio_mix_controls() -> void:
	var button: Button = $HUD/AudioMixButton
	var panel: PanelContainer = $HUD/AudioMixPanel
	button.visible = _lab_audio_mix != null
	if not button.visible:
		return
	if player.reference_audio != null:
		for voice: AudioStreamPlayer in player.reference_audio.voices:
			voice.bus = _lab_audio_mix.bus_name(LabAudioMix.Layer.WEAPON)
	button.toggled.connect(panel.set_visible)
	for layer: int in MIX_ROWS:
		var row := HBoxContainer.new()
		row.name = MIX_ROWS[layer][0]
		panel.get_node("Rows").add_child(row)
		var label := Label.new()
		label.custom_minimum_size.x = 148.0
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = "Slider"
		slider.custom_minimum_size.y = 32.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.focus_mode = Control.FOCUS_NONE
		slider.step = 5.0
		slider.scrollable = false
		slider.value = 100.0
		slider.value_changed.connect(_set_mix_level.bind(layer, label))
		row.add_child(slider)
		_set_mix_level(slider.value, layer, label)

func _set_mix_level(percent: float, layer: int, label: Label) -> void:
	label.text = "%s · %d%%" % [MIX_ROWS[layer][1], roundi(percent)]
	_lab_audio_mix.set_level(layer, percent)

func _setup_ragdoll_physics_controls() -> void:
	var button: Button = $HUD/RagdollPhysicsButton
	var panel: PanelContainer = $HUD/RagdollPhysicsPanel
	button.visible = $HUD/RagdollTuning.visible
	if not button.visible:
		return
	button.toggled.connect(panel.set_visible)
	for name: StringName in RAGDOLL_PHYSICS_ROWS:
		var settings: Array = RAGDOLL_PHYSICS_ROWS[name]
		var row := HBoxContainer.new()
		row.name = name
		panel.get_node("Rows").add_child(row)
		var label := Label.new()
		label.custom_minimum_size.x = 145.0
		label.add_theme_font_size_override("font_size", 14)
		label.text = "%s · 100%%" % settings[0]
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = "Slider"
		slider.custom_minimum_size.y = 32.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.focus_mode = Control.FOCUS_NONE
		slider.scrollable = false
		slider.tooltip_text = settings[4] + " Áp dụng từ cú kết liễu tiếp theo."
		slider.min_value = settings[1]
		slider.max_value = settings[2]
		slider.step = 5.0
		slider.value = 100.0
		slider.value_changed.connect(_set_ragdoll_physics.bind(settings[3], settings[0], label))
		row.add_child(slider)

func _set_ragdoll_physics(percent: float, property: StringName, title: String, label: Label) -> void:
	$Zombies.set(property, percent * 0.01)
	label.text = "%s · %d%%" % [title, roundi(percent)]

func _setup_tuning_presets() -> void:
	var button: MenuButton = $HUD/TuningPresets
	button.visible = $HUD/RagdollTuning.visible
	if not button.visible:
		return
	_default_tuning = _capture_tuning()
	var menu := button.get_popup()
	menu.add_item("Lưu ô A", PresetAction.SAVE_A)
	menu.add_item("Nạp ô A", PresetAction.LOAD_A)
	menu.add_item("Lưu ô B", PresetAction.SAVE_B)
	menu.add_item("Nạp ô B", PresetAction.LOAD_B)
	menu.add_item("Khôi phục mặc định", PresetAction.DEFAULTS)
	menu.id_pressed.connect(_apply_preset_action)

func _capture_tuning() -> Dictionary:
	var settings := {"base_zombie": $HUD/BaseZombieToggle.button_pressed}
	for key: String in PRESET_RANGES:
		settings[key] = (get_node(PRESET_RANGES[key]) as Range).value
	for key: String in PRESET_OPTIONS:
		settings[key] = (get_node(PRESET_OPTIONS[key]) as OptionButton).get_selected_id()
	return settings

func _apply_tuning(settings: Dictionary) -> void:
	var values := _default_tuning.merged(settings, true)
	for key: String in PRESET_RANGES:
		var value: Variant = values[key]
		if (value is float or value is int) and is_finite(float(value)):
			(get_node(PRESET_RANGES[key]) as Range).value = float(value)
	for key: String in PRESET_OPTIONS:
		var id: Variant = values[key]
		if id is int:
			var picker := get_node(PRESET_OPTIONS[key]) as OptionButton
			var index := picker.get_item_index(id)
			if index >= 0 and not picker.is_item_disabled(index):
				picker.select(index)
				picker.item_selected.emit(index)
	var base_zombie: Variant = values.base_zombie
	if base_zombie is bool:
		$HUD/BaseZombieToggle.button_pressed = base_zombie

func _apply_preset_action(action: int) -> void:
	if action == PresetAction.DEFAULTS:
		_apply_tuning(_default_tuning)
		$HUD/SpawnStatus.text = "Đã khôi phục thiết lập mặc định."
		return
	var slot := "A" if action in [PresetAction.SAVE_A, PresetAction.LOAD_A] else "B"
	var path := tuning_preset_directory.path_join(slot.to_lower() + ".cfg")
	var config := ConfigFile.new()
	if action in [PresetAction.SAVE_A, PresetAction.SAVE_B]:
		config.set_value("preset", "settings", _capture_tuning())
		var error := DirAccess.make_dir_recursive_absolute(tuning_preset_directory)
		var staging := "%s.%d.%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
		if error == OK:
			error = config.save(staging)
		if error == OK:
			error = DirAccess.rename_absolute(staging, path)
		if error != OK and FileAccess.file_exists(staging):
			DirAccess.remove_absolute(staging)
		$HUD/SpawnStatus.text = ("Đã lưu cấu hình %s." if error == OK else "Không thể lưu cấu hình %s.") % slot
		return
	if not FileAccess.file_exists(path):
		$HUD/SpawnStatus.text = "Ô %s chưa có cấu hình." % slot
		return
	var error := config.load(path)
	var settings: Variant = config.get_value("preset", "settings", null) if error == OK else null
	if settings is Dictionary:
		_apply_tuning(settings)
		$HUD/SpawnStatus.text = "Đã nạp cấu hình %s." % slot
	else:
		$HUD/SpawnStatus.text = "Không thể đọc cấu hình %s." % slot

func _spawn_one_zombie(base_health: bool) -> bool:
	var facing := Basis(Vector3.UP, player.visual.rotation.y)
	return $Zombies.spawn(player, facing, $CombatEffects, base_health)

func _spawn_zombie() -> void:
	if _spawn_one_zombie($HUD/BaseZombieToggle.button_pressed):
		if _crowd_spawns_left == 0:
			$HUD/SpawnStatus.text = ""
	else:
		$HUD/SpawnStatus.text = "Không thể tạo zombie. Kiểm tra dữ liệu MD2 Research và chỗ trống."

func _spawn_baby_zombie() -> void:
	if $HUD/SpawnBabyZombie.disabled or player_health == 0:
		return
	var facing := Basis(Vector3.UP, player.visual.rotation.y)
	if $Zombies.spawn(player, facing, $CombatEffects, true, true):
		if _crowd_spawns_left == 0:
			$HUD/SpawnStatus.text = ""
	else:
		$HUD/SpawnStatus.text = "Không thể tạo Baby Zombie. Kiểm tra dữ liệu MD2 Research và chỗ trống."

func _set_crowd_spawn_label(index: int) -> void:
	$HUD/SpawnCrowd.text = "Spawn %d zombie" % $HUD/CrowdSpawnCount.get_item_id(index)

func _start_crowd_spawn() -> void:
	if $HUD/SpawnCrowd.disabled or player_health == 0:
		return
	var count: int = $HUD/CrowdSpawnCount.get_selected_id()
	if count <= 0:
		return
	_crowd_spawn_total = count
	_crowd_spawns_left = count
	_crowd_base_health = $HUD/BaseZombieToggle.button_pressed
	$HUD/SpawnCrowd.disabled = true
	$HUD/CrowdSpawnCount.disabled = true
	$HUD/SpawnStatus.text = "Đang tạo zombie… 0/%d" % count

func _spawn_crowd_frame() -> void:
	var deadline := Time.get_ticks_usec() + CROWD_SPAWN_BUDGET_USEC
	var facing := Basis(Vector3.UP, player.visual.rotation.y)
	var limit := mini(_crowd_spawns_left, CROWD_SPAWN_LIMIT_PER_FRAME)
	var batch: Dictionary = $Zombies.spawn_batch(player, facing, $CombatEffects, _crowd_base_health, limit, deadline)
	_crowd_spawns_left -= int(batch.count)
	var created := _crowd_spawn_total - _crowd_spawns_left
	if batch.blocked:
		_stop_crowd_spawn()
		$HUD/SpawnStatus.text = "Đã tạo %d/%d zombie. Hãy kiểm tra chỗ trống hoặc dữ liệu MD2." % [created, _crowd_spawn_total]
		return
	if _crowd_spawns_left == 0:
		_stop_crowd_spawn()
		$HUD/SpawnStatus.text = "Đã tạo %d zombie." % created
	else:
		$HUD/SpawnStatus.text = "Đang tạo zombie… %d/%d" % [created, _crowd_spawn_total]

func _stop_crowd_spawn() -> void:
	if _crowd_spawns_left > 0:
		$HUD/SpawnStatus.text = ""
	_crowd_spawns_left = 0
	$HUD/SpawnCrowd.disabled = $HUD/SpawnZombie.disabled or player_health == 0
	$HUD/CrowdSpawnCount.disabled = $HUD/SpawnCrowd.disabled

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
		$HUD/PlayerSkin.get_popup().hide()
		$HUD/CrowdSpawnCount.get_popup().hide()
		$HUD/Weapon.disabled = true
		$HUD/PlayerSkin.disabled = true
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
		$HUD/PlayerSkin.disabled = false
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
