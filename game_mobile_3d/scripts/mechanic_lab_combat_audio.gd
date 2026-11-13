extends Node3D
## Extracted MD2 samples. Group selection and gains are local playback settings.

const ReferenceAudio := preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const SOURCE := "extracted/2026-10-26 12-46-42/Game/Spicewood/Audio/Wwise/Events/Spicewood"
const SABRE := "Items/Weapons/Weapon_Melee/5_weapons_melee_hitmarkers/sfx_sabre_hitmarker_%02d.ogg"
const SWORD := "Items/Weapons/Weapon_Melee/5_weapons_melee_hitmarkers/sfx_weapon_hitmarker_sword_%02d.ogg"
const CURVED := "Items/Weapons/Weapon_Melee/5_weapons_melee_hitmarkers/sfx_hitmarker_curvedGreatsword-%03d.ogg"
const HEAVY_LANDING := "Items/Weapons/Weapon_Melee/7_weapons_melee_heavyJumpAttack/weapons_melee_heavyJumpAttack/sfx_sword_jump_attack_heavy_Hit_%02d.ogg"
const SURFACE_LANDING := "Items/Weapons/Weapon_Melee/7_weapons_melee_heavyJumpAttack/weapons_melee_heavyJumpAttackDebris/sfx_HJA_impact debris_%s_%02d.ogg"
const ZOMBIE := "Mobs/Mob_Hostile/MobType1/Zombie/sfx_mob_zombieVariant1%s_%02d.ogg"
# The exported waveforms matching the Zombie event names sit under BabyZombie.
const ZOMBIE_ATTACK := "Mobs/Mob_Hostile/MobType1/BabyZombie/sfx_mob_zombie%sAttack-%03d_soundWave.ogg"
# Zombie.Step names the adult event. The exported generic candidate is under BabyZombie.
const ZOMBIE_STEP := "Mobs/Mob_Hostile/MobType1/BabyZombie/sfx_mob_zombieStepGeneric-%03d_soundWave.ogg"
const PLAYER_HURT := "Player/Hurt/sfx_multi_hit-%03d_soundWave.ogg"
const VOICES_PER_POOL := 3
const STEP_POOL := 3
const HIT_GAIN_DB := -9.0
const SLAM_GAIN_DB := -10.0
const SURFACE_LANDING_GAIN_DB := -16.0
const HURT_GAIN_DB := -20.0
const DEATH_GAIN_DB := -14.0
const ZOMBIE_WINDUP_GAIN_DB := -16.0
const ZOMBIE_HIT_GAIN_DB := -14.0
const PLAYER_HURT_GAIN_DB := -14.0
const ZOMBIE_STEP_GAIN_DB := -21.0
const ZOMBIE_STEP_DISTANCE := 12.0

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
const CURVED_HIT_HASHES := [
	"522fcced9d4d8fc2f95934649f7a7841f1adfcf94886ce6e7ab6369f22239e83",
	"83e50a2ac88ad0c49cc82b86e13d2c0b24b9d48ea04880132debe130e76bcfe2",
	"ccfaa913edee16fa4fcd803855303e71c9a272bc0ff0900a6f1ff54de74c7738",
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
const GRASS_LANDING_HASHES := [
	"ee75570063f0cab520dd1f184dba12d80a863eefa247a0917fa79b096ed333a8",
	"b2630725de22fa7e841b244817623f58d675581b771eec5b3ae8b2e0c183b311",
	"6cec2b51dfe4abb81ce3762c3176f24a7008b3a2700748c74b58e69bdf136899",
	"59171aa40d29b5b0a28ad4caf5b99a97270bcad0ad183ca10219e8aeb77a06e0",
	"b46cc8bc85384043a08525675bf7c2eed52a0a3d4aba5f254b0874244be152bb",
	"7c34ccd9be1a3cd4c69561c12691cef32de62611cdaec422de6dd4a139cd2581",
]
const DIRT_LANDING_HASHES := [
	"01c211220ee8e1f90f5019c39fe5c982c779c3fc3bc2c6f921db289aaa61296a",
	"c8c3f6b73f7ed47c9d77755c5c4c73dea41007ff0670e86bcf1f1bb98986fb07",
	"83a8290eed8f4da1ca1917b56caef6f47588512220b1619aa1bbb8191d00355c",
	"afdd5e39a3716355240457b8db3d3e9a2659616bab6ab123b86dc3b7e146726f",
	"97a0b07070e4c5e2e98b8e61c2d78bc04a552ac077ca30a1101a276b1a94c097",
	"a6fe6818f94c5cdc41e81a6894a0d754939d85fe4e92b9c5ad973249b713c71d",
]
const STONE_LANDING_HASHES := [
	"dc2895e7e06ff17b531ddb16232486e9f7ba9d1e72de031cb1b0071c8efb9793",
	"a93e1cf67a9925765698d67326fb109e31d9af80b8c3e591e5c79b66c2f28037",
	"33b4e0dd7284dc0047eede14bc2ffb84d2ae36e955e769a62b6a58bfabc6779b",
	"1b1bfcbfb79b76c7d1280ff9e2ac963411edd0f832f1273c1fbbeca2f021b2e9",
	"50330cb48cc33200892c219cb873beb9475659ad780cf6ad1b24ac45d1871777",
	"54c0809157b3b21da885b538d7489b079be0664194bafa74744caf1a02994d38",
]
const PLAYER_HURT_HASHES := [
	"3442fd3503fca76ccc78d29bfee9d16390fc3d5a62bd1cbbdb9213b880ab5494",
	"8ab4eba4ec92dd73368e3eb3302726d12861306b1fc9951757beb0111e291b32",
	"ef7f8eef33586be6322f5189b7a21653733986bbad63b8ca0e0cdbb860746e0a",
]
const ZOMBIE_WINDUP_HASHES := [
	"27bfa4eff732d395c48e3588a839495323f600f211c50c22a5d9edb6578815c8",
	"df04bfaa8ad40658feb5032f5bc8136da433fd2e85fecb4bb5470fc1bb1e1a78",
	"6c3030dd813b6274e29add9e0cbfe8108d06aef8bc4c9a4cee7cc9ef726967a1",
	"4e9f93c97c06f6c95380e79e5fc468ccbc52e905edf1f75b5117e62a48c8834c",
]
const ZOMBIE_HIT_HASHES := [
	"1404784c14e40432f7b034467ab5193d27e20ab497afcf897824d34da3fc3e1e",
	"d507d72dbff70da024f4f1da548286b237a87880ed2e0b9e21d30ddadf92d246",
	"f8916ee7e6e40bc6eee912083d4bd8d67cf2c7fcbab1dab6602dac093f91975f",
	"1213567ddc6d28e5ce3f10a3571efce2e3d32e7224ec9530ef58f6bb0e50006e",
]
const ZOMBIE_STEP_HASHES := [
	"b6db306be20e08704880494dc3f8dfb90feae27bdd47374b6b0a8789f90d183b",
	"c77446a6e366ec815bb3c511ca0992778997939ffdc953b705be9b51bdd7f45f",
	"35ab10c0ed49602bf0abf0dc651ef1d9ba7367fa05c5002b1bdf69fd0c537b60",
	"728261296046771323209999a1d60b23d86052655bdf752027de1eaa526f0eec",
	"d447953adb0b0f692f241d42aee6662653843365e5306d6cfd159c8d0e4f9555",
]

var enabled := false
var sword_equipped := false
var curved_equipped := false
var _groups: Dictionary[StringName, Array] = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _player_hurt_voice: AudioStreamPlayer
var _next_choice: Dictionary[StringName, int] = {}
var _next_voice: Array[int] = [0, 0, 0, 0]
var _reaction_started_frame: Array[int] = []
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
	_play(_weapon_hit_group(), preview_point, HIT_GAIN_DB)

func set_surface_landing_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		reset()
	elif _voices.is_empty() and OS.has_feature("editor"):
		_create_voices(VOICES_PER_POOL)
		var root := _research_root()
		_load_surface_landing(root, "Grass", &"slam_grass", GRASS_LANDING_HASHES)
		_load_surface_landing(root, "Dirt", &"slam_dirt", DIRT_LANDING_HASHES)
		_load_surface_landing(root, "Stone", &"slam_stone", STONE_LANDING_HASHES)

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
		_play(_weapon_hit_group(), point, HIT_GAIN_DB)
	_play(&"death" if lethal else &"hurt", point, DEATH_GAIN_DB if lethal else HURT_GAIN_DB)

func _weapon_hit_group() -> StringName:
	if curved_equipped:
		return &"curved_hit"
	return &"sword_hit" if sword_equipped else &"hit"

func slam_landed(point: Vector3, surface: String = "grass") -> void:
	if not enabled:
		return
	if sword_equipped:
		_play(&"slam", point, SLAM_GAIN_DB)
	_play(StringName("slam_" + surface), point, SURFACE_LANDING_GAIN_DB)

func player_hurt() -> void:
	if not enabled or _player_hurt_voice == null:
		return
	var stream := _next_stream(&"player_hurt")
	if stream != null:
		_player_hurt_voice.stream = stream
		_player_hurt_voice.play()

func zombie_attack(point: Vector3, contact: bool) -> void:
	if enabled:
		_play(&"zombie_hit" if contact else &"zombie_windup", point,
			ZOMBIE_HIT_GAIN_DB if contact else ZOMBIE_WINDUP_GAIN_DB)

func can_play_zombie_step(point: Vector3, listener: Vector3) -> bool:
	if not enabled or not _groups.has(&"zombie_step") +			or point.distance_squared_to(listener) > ZOMBIE_STEP_DISTANCE * ZOMBIE_STEP_DISTANCE:
		return false
	for slot in VOICES_PER_POOL:
		if not _voices[STEP_POOL * VOICES_PER_POOL + slot].playing:
			return true
	return false

func zombie_step(point: Vector3) -> void:
	if enabled:
		_play(&"zombie_step", point, ZOMBIE_STEP_GAIN_DB)

func reset() -> void:
	_reaction_started_frame.fill(-1)
	_last_weapon_serial = -1
	_next_voice.fill(0)
	for voice in _voices:
		voice.stop()
		voice.stream = null
	if _player_hurt_voice != null:
		_player_hurt_voice.stop()
		_player_hurt_voice.stream = null

static func _research_root() -> String:
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	return OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research") if root.is_empty() else root

func _load_audio() -> void:
	if not OS.has_feature("editor"):
		return
	_reaction_started_frame.resize(VOICES_PER_POOL)
	_reaction_started_frame.fill(-1)
	var root := _research_root()
	# DefaultPlayer routes SW.Audio.Generic.Hurt to SW.Audio.Category.Player.Local.
	_player_hurt_voice = AudioStreamPlayer.new()
	_player_hurt_voice.name = "PlayerHurt"
	_player_hurt_voice.volume_db = PLAYER_HURT_GAIN_DB
	add_child(_player_hurt_voice)
	_create_voices(_next_voice.size() * VOICES_PER_POOL)
	for i in HIT_HASHES.size():
		_load_sample(root, &"hit", SABRE % (i + 1), HIT_HASHES[i])
	for i in SWORD_HIT_HASHES.size():
		_load_sample(root, &"sword_hit", SWORD % (i + 1), SWORD_HIT_HASHES[i])
	for i in CURVED_HIT_HASHES.size():
		_load_sample(root, &"curved_hit", CURVED % (i + 1), CURVED_HIT_HASHES[i])
	for i in HURT_HASHES.size():
		_load_sample(root, &"hurt", ZOMBIE % ["Hurt", i + 1], HURT_HASHES[i])
	for i in DEATH_HASHES.size():
		_load_sample(root, &"death", ZOMBIE % ["Death", i + 1], DEATH_HASHES[i])
	for i in LANDING_HASHES.size():
		_load_sample(root, &"slam", HEAVY_LANDING % (i + 1), LANDING_HASHES[i])
	_load_surface_landing(root, "Grass", &"slam_grass", GRASS_LANDING_HASHES)
	for i in PLAYER_HURT_HASHES.size():
		_load_sample(root, &"player_hurt", PLAYER_HURT % (i + 1), PLAYER_HURT_HASHES[i])
	for i in ZOMBIE_WINDUP_HASHES.size():
		_load_sample(root, &"zombie_windup", ZOMBIE_ATTACK % ["Pre", i + 1], ZOMBIE_WINDUP_HASHES[i])
	for i in ZOMBIE_HIT_HASHES.size():
		_load_sample(root, &"zombie_hit", ZOMBIE_ATTACK % ["", i + 1], ZOMBIE_HIT_HASHES[i])
	for i in ZOMBIE_STEP_HASHES.size():
		_load_sample(root, &"zombie_step", ZOMBIE_STEP % (i + 1), ZOMBIE_STEP_HASHES[i])

func _create_voices(count: int) -> void:
	for i in count:
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 4.5
		voice.max_distance = 35.0
		# Preserve the source transient spectrum with distance and panning.
		voice.attenuation_filter_db = 0.0
		voice.attenuation_filter_cutoff_hz = 20500.0
		add_child(voice)
		_voices.append(voice)

func _load_surface_landing(root: String, surface: String, group: StringName, hashes: Array) -> void:
	for i in hashes.size():
		_load_sample(root, group, SURFACE_LANDING % [surface, i + 1], hashes[i])

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
	if not _groups.has(group):
		return
	# Separate enemy attack and reaction budgets keep the weapon tails audible.
	var pool := 0
	match group:
		&"hurt", &"death":
			pool = 1
		&"zombie_windup", &"zombie_hit":
			pool = 2
		&"zombie_step":
			pool = STEP_POOL
	var first := pool * VOICES_PER_POOL
	var start := _next_voice[pool]
	var slot := -1
	for offset in VOICES_PER_POOL:
		var candidate := (start + offset) % VOICES_PER_POOL
		if not _voices[first + candidate].playing:
			slot = candidate
			break
	if pool == 1:
		var frame := Engine.get_physics_frames()
		if slot == -1:
			slot = _replace_reaction_slot(start, group == &"death", frame)
			if slot == -1:
				return
		_reaction_started_frame[slot] = frame
	elif slot == -1 and pool == STEP_POOL:
		return
	elif slot == -1:
		slot = start
	var stream := _next_stream(group)
	var voice := _voices[first + slot]
	_next_voice[pool] = (slot + 1) % VOICES_PER_POOL
	voice.stop()
	voice.stream = stream
	voice.global_position = point
	voice.volume_db = gain
	voice.max_db = gain
	voice.play()

func _replace_reaction_slot(start: int, lethal: bool, frame: int) -> int:
	# Keep the leading cues of a simultaneous hit. Death may replace hurt,
	# while hurt never cuts off a death cue.
	var death_streams: Array = _groups.get(&"death", [])
	var older_slot := -1
	for offset in VOICES_PER_POOL:
		var slot := (start + offset) % VOICES_PER_POOL
		var playing_death := _voices[VOICES_PER_POOL + slot].stream in death_streams
		if lethal and not playing_death:
			return slot
		if lethal == playing_death and older_slot == -1 and _reaction_started_frame[slot] != frame:
			older_slot = slot
	return older_slot
