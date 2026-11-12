extends Node3D
## Extracted MD2 samples. Group selection and gains are local playback settings.

const ReferenceAudio := preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const SOURCE := "extracted/2026-10-26 12-46-42/Game/Spicewood/Audio/Wwise/Events/Spicewood"
const SABRE := "Items/Weapons/Weapon_Melee/5_weapons_melee_hitmarkers/sfx_sabre_hitmarker_%02d.ogg"
const SWORD := "Items/Weapons/Weapon_Melee/5_weapons_melee_hitmarkers/sfx_weapon_hitmarker_sword_%02d.ogg"
const HEAVY_LANDING := "Items/Weapons/Weapon_Melee/7_weapons_melee_heavyJumpAttack/weapons_melee_heavyJumpAttack/sfx_sword_jump_attack_heavy_Hit_%02d.ogg"
const ZOMBIE := "Mobs/Mob_Hostile/MobType1/Zombie/sfx_mob_zombieVariant1%s_%02d.ogg"
const PLAYER_HURT := "Player/Hurt/sfx_multi_hit-%03d_soundWave.ogg"
const VOICES_PER_POOL := 3
const HIT_GAIN_DB := -9.0
const SLAM_GAIN_DB := -10.0
const HURT_GAIN_DB := -20.0
const DEATH_GAIN_DB := -14.0
const PLAYER_HURT_GAIN_DB := -14.0

const HIT_HASHES := [
	"01b446de1994e109804c1379e19d13b93d271d826e30bfe211d2f560e4651cb9",
	"6322929e87d0ea43485ac7f436ecd7ef7601596c64b076a857a42863aa4959b6",
	"c5b535da7408fcc3ff4c24e6f7fb3576e58c90051ee4b4393d1473e0a86528e1",
	"39bea042b72c20fb35626cb78a5371ed05ae84efa9fe322c0e253dd6e7762d9c",
	"baa42ba5a6d2fe35401f135ac5c3348b60209974aa26722940410d74b2d3d23b",
]
const SWORD_HIT_HASHES := [
	"f48696a70b3c38480811492cc570c17c7ef08bbe0c684f586341f7f09947de31",
	"57522a414b5ea426b73c2c8d24198bc42d60fbd6d4d48421388640709dd4f4b1",
	"6e6a712c4d47ae32cbb1cc1828004fb53a3494a9446eead9c66eecdfa9740bf8",
]
const HURT_HASHES := [
	"fa84b833daecb58d0f95b6470393732c7f66ef33bb5e27d1b869322586a3fa12",
	"015324c34aaa5c6d4cba7424f9a785cffe46f775a5270d47555390f052777fcc",
	"d0eee30a0f359ee3c64678e7c659e280c0abfe7d61b6434ef458b1cd9fbe488a",
]
const DEATH_HASHES := [
	"fe805a6d33650af6613dd4b837b88a6e0caa659192cf53af6dadd0b5d0f6dfad",
	"5c1aa88a0ba5306620d56247eb5a4a3fe7978fe233bf7ae9e5541f1670b20ef8",
	"f5350c3cc4af912ea411d5c5d921bf63a635f9686240669029d80cf2d6e74b52",
]
const LANDING_HASHES := [
	"ef64187aa4ff1b50d32fcfe617d04b3bde4ac7f8e045bbb687895ea60e3b81ab",
	"452771d3aec25299b9308f0d64c52dbbcdcc38ab3c2453112ec4796837b466f9",
	"a97f48e243ebb2665540255e7def73234c447432504d17e5f0ee941e4c8340f7",
]
const PLAYER_HURT_HASHES := [
	"3442fd3503fca76ccc78d29bfee9d16390fc3d5a62bd1cbbdb9213b880ab5494",
	"8ab4eba4ec92dd73368e3eb3302726d12861306b1fc9951757beb0111e291b32",
	"ef7f8eef33586be6322f5189b7a21653733986bbad63b8ca0e0cdbb860746e0a",
]

var enabled := false
var sword_equipped := false
var _groups: Dictionary[StringName, Array] = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _player_hurt_voice: AudioStreamPlayer
var _next_choice: Dictionary[StringName, int] = {}
var _next_voice: Array[int] = [0, 0]
var _last_weapon_serial := -1
var _master_was_muted := false

func set_enabled(value: bool, preview_point: Vector3) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		reset()
		_restore_master()
		return
	if _voices.is_empty():
		_load_audio()
	# The project starts with Master muted for quiet tests.
	_master_was_muted = AudioServer.is_bus_mute(0)
	if _master_was_muted:
		AudioServer.set_bus_mute(0, false)
	_play(&"sword_hit" if sword_equipped else &"hit", preview_point, HIT_GAIN_DB)

func _restore_master() -> void:
	if _master_was_muted:
		AudioServer.set_bus_mute(0, true)
		_master_was_muted = false

func _exit_tree() -> void:
	_restore_master()

func contact(point: Vector3, serial: int, lethal: bool) -> void:
	if not enabled:
		return
	if serial != _last_weapon_serial:
		_last_weapon_serial = serial
		_play(&"sword_hit" if sword_equipped else &"hit", point, HIT_GAIN_DB)
	_play(&"death" if lethal else &"hurt", point, DEATH_GAIN_DB if lethal else HURT_GAIN_DB)

func slam_landed(point: Vector3) -> void:
	if enabled:
		_play(&"slam", point, SLAM_GAIN_DB)

func player_hurt() -> void:
	if not enabled or _player_hurt_voice == null:
		return
	var stream := _next_stream(&"player_hurt")
	if stream != null:
		_player_hurt_voice.stream = stream
		_player_hurt_voice.play()

func reset() -> void:
	_last_weapon_serial = -1
	_next_voice = [0, 0]
	for voice in _voices:
		voice.stop()
		voice.stream = null
	if _player_hurt_voice != null:
		_player_hurt_voice.stop()
		_player_hurt_voice.stream = null

func _load_audio() -> void:
	if not OS.has_feature("editor"):
		return
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	# DefaultPlayer routes SW.Audio.Generic.Hurt to SW.Audio.Category.Player.Local.
	_player_hurt_voice = AudioStreamPlayer.new()
	_player_hurt_voice.name = "PlayerHurt"
	_player_hurt_voice.volume_db = PLAYER_HURT_GAIN_DB
	add_child(_player_hurt_voice)
	for i in 2 * VOICES_PER_POOL:
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 4.5
		voice.max_distance = 35.0
		# Keep distance and panning, while preserving the source transient spectrum.
		voice.attenuation_filter_db = 0.0
		voice.attenuation_filter_cutoff_hz = 20500.0
		add_child(voice)
		_voices.append(voice)
	for i in HIT_HASHES.size():
		_load_sample(root, &"hit", SABRE % (i + 1), HIT_HASHES[i])
	for i in SWORD_HIT_HASHES.size():
		_load_sample(root, &"sword_hit", SWORD % (i + 1), SWORD_HIT_HASHES[i])
	for i in HURT_HASHES.size():
		_load_sample(root, &"hurt", ZOMBIE % ["Hurt", i + 1], HURT_HASHES[i])
	for i in DEATH_HASHES.size():
		_load_sample(root, &"death", ZOMBIE % ["Death", i + 1], DEATH_HASHES[i])
	for i in LANDING_HASHES.size():
		_load_sample(root, &"slam", HEAVY_LANDING % (i + 1), LANDING_HASHES[i])
	for i in PLAYER_HURT_HASHES.size():
		_load_sample(root, &"player_hurt", PLAYER_HURT % (i + 1), PLAYER_HURT_HASHES[i])

func _load_sample(root: String, group: StringName, relative: String, checksum: String) -> void:
	var path := ReferenceAudio.resolve_private_file(root, SOURCE.path_join(relative))
	if path.is_empty() or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != checksum:
		return
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream != null:
		stream.loop = false
		if not _groups.has(group):
			_groups[group] = []
		_groups[group].append(stream)

func _next_stream(group: StringName) -> AudioStream:
	var choices: Array = _groups.get(group, [])
	if choices.is_empty():
		return null
	var choice: int = _next_choice.get(group, 0)
	_next_choice[group] = (choice + 1) % choices.size()
	return choices[choice]

func _play(group: StringName, point: Vector3, gain: float) -> void:
	var stream := _next_stream(group)
	if stream == null:
		return
	# Enemy reactions share their own budget so a crowd cannot cut weapon tails.
	var pool := 1 if group == &"hurt" or group == &"death" else 0
	var first := pool * VOICES_PER_POOL
	var slot := _next_voice[pool]
	for offset in VOICES_PER_POOL:
		var candidate := (slot + offset) % VOICES_PER_POOL
		if not _voices[first + candidate].playing:
			slot = candidate
			break
	var voice := _voices[first + slot]
	_next_voice[pool] = (slot + 1) % VOICES_PER_POOL
	voice.stop()
	voice.stream = stream
	voice.global_position = point
	voice.volume_db = gain
	voice.max_db = gain
	voice.play()
