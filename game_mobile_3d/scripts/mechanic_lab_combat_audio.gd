extends Node3D
## Extracted MD2 samples. Group selection and gains are local playback settings.

const ReferenceAudio := preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const SOURCE := "extracted/2026-10-26 12-46-42/Game/Spicewood/Audio/Wwise/Events/Spicewood"
const SABRE := "Items/Weapons/Weapon_Melee/5_weapons_melee_hitmarkers/sfx_sabre_hitmarker_%02d.ogg"
const HEAVY_LANDING := "Items/Weapons/Weapon_Melee/7_weapons_melee_heavyJumpAttack/weapons_melee_heavyJumpAttack/sfx_sword_jump_attack_heavy_Hit_%02d.ogg"
const ZOMBIE := "Mobs/Mob_Hostile/MobType1/Zombie/sfx_mob_zombieVariant1%s_%02d.ogg"
const HIT_HASHES := [
	"01b446de1994e109804c1379e19d13b93d271d826e30bfe211d2f560e4651cb9",
	"6322929e87d0ea43485ac7f436ecd7ef7601596c64b076a857a42863aa4959b6",
	"c5b535da7408fcc3ff4c24e6f7fb3576e58c90051ee4b4393d1473e0a86528e1",
	"39bea042b72c20fb35626cb78a5371ed05ae84efa9fe322c0e253dd6e7762d9c",
	"baa42ba5a6d2fe35401f135ac5c3348b60209974aa26722940410d74b2d3d23b",
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

var enabled := false
var _groups: Dictionary[StringName, Array] = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _next_choice: Dictionary[StringName, int] = {}
var _next_voice := 0
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
	_play(&"hit", preview_point, -4.0)

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
		_play(&"hit", point, -11.0)
	_play(&"death" if lethal else &"hurt", point, -10.0 if lethal else -15.0)

func slam_landed(point: Vector3) -> void:
	if enabled:
		_play(&"slam", point, -11.0)

func reset() -> void:
	_last_weapon_serial = -1
	for voice in _voices:
		voice.stop()
		voice.stream = null

func _load_audio() -> void:
	if not OS.has_feature("editor"):
		return
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	for i in 6:
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 10.0
		voice.max_distance = 35.0
		add_child(voice)
		_voices.append(voice)
	for i in HIT_HASHES.size():
		_load_sample(root, &"hit", SABRE % (i + 1), HIT_HASHES[i])
	for i in HURT_HASHES.size():
		_load_sample(root, &"hurt", ZOMBIE % ["Hurt", i + 1], HURT_HASHES[i])
	for i in DEATH_HASHES.size():
		_load_sample(root, &"death", ZOMBIE % ["Death", i + 1], DEATH_HASHES[i])
	for i in LANDING_HASHES.size():
		_load_sample(root, &"slam", HEAVY_LANDING % (i + 1), LANDING_HASHES[i])

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

func _play(group: StringName, point: Vector3, gain: float) -> void:
	var choices: Array = _groups.get(group, [])
	if choices.is_empty():
		return
	var choice: int = _next_choice.get(group, 0)
	var voice := _voices[_next_voice]
	_next_choice[group] = (choice + 1) % choices.size()
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stop()
	voice.stream = choices[choice]
	voice.global_position = point
	voice.volume_db = gain
	voice.play()
