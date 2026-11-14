extends Node3D
## Extracted MD2 samples. Group selection and gains are local playback settings.

const ReferenceAudio := preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const CrossPollinator := preload("res://scripts/mechanic_lab_cross_pollinator.gd")
const SOURCE := "extracted/2026-10-26 12-46-42/Game/Spicewood/Audio/Wwise/Events/Spicewood"
const SABRE := "Items/Weapons/Weapon_Melee/5_weapons_melee_hitmarkers/sfx_sabre_hitmarker_%02d.ogg"
const SWORD := "Items/Weapons/Weapon_Melee/5_weapons_melee_hitmarkers/sfx_weapon_hitmarker_sword_%02d.ogg"
const CURVED := "Items/Weapons/Weapon_Melee/5_weapons_melee_hitmarkers/sfx_hitmarker_curvedGreatsword-%03d.ogg"
const CROSSBOW := "Items/Weapons/Weapon_Ranged/RapidCrossbow/RapidCrossbowUnique/sfx_item_rapidCrossbowUnique_"
const CROSSBOW_EQUIP_HASH := "838f1ed2b28a92389ccc78d6d68cd09bcbee73d2498f6f9dcb7a0f94a485d285"
const CROSSBOW_UNEQUIP_HASH := "9aac5b929e76b962d96cad6331d2a3e368df77e00202e41e673e93b06d3c3102"
const CROSSBOW_FIRE_HASHES := [
	"500b59e16faf185c10a4ef8b7a22b4f6f40c21a1884aafbf3e328e4e1b169157",
	"0a90dec3091bbcd16f181c16f214e8a928e9b50488d132d26b5440ae0590b06c",
	"891546a2cbf6e08322e0515ec8e33bed5c40e190f7ad8e386af6f163c4dffbed",
]
const CROSSBOW_IMPACT_HASHES := [
	"22693848bc6767c7c60454f5a0cfc3959f96f1d53d0021c357f8e18b5d9c4760",
	"f3f457ffb1a05b35e7a1b00e5f902b00a3487ffc6df197ad059809987da650a7",
	"d1538525efed7c2b0556ee0dff0f16cce4eb99542cb452f5ade26fc110e9d5f9",
]
const CROSSBOW_FLIGHT_HASHES := [
	"556e500b32ca597245925f34aa1e1b36a9917230076f8d28a2432b9cd75dc806",
	"fc1b8ed21fda302a2944980403c19d7861192f64d26efab7beaa1e1930c525b1",
	"6fbbf0fb7172df9564222117c1c33757e88be27e57b6db87b9182e0a6455afff",
	"505c42c4c85efa8ddf0fc8b4220797110dd76f4d4a8d9418036549b5ca4fae15",
]
const GAUNTLET_COMBO := "Items/Weapons/Weapon_Melee/6_weapons_melee_basicCombo/Attack%d/sfx_gauntlets_unique_attack_%s_%02d.ogg"
const GAUNTLET_HIT := "Items/Weapons/Weapon_Melee/5_weapons_melee_hitmarkers/sfx_weapon_hitmarker_gauntlets_%02d.ogg"
const GAUNTLET_HIT_HASHES := [
	"b5dd3f6184aec5dbaea52ae9e4b9b139487515f0b019004cc7523221ac1fa883",
	"a8071778b3ab4d2207f8a0185e66c8b1f3014020ce9e48581d017a457c10f402",
	"5c479488c4660c732c3de2902f4b98b28e154c8cb6c84b88a606127c3942fb4a",
]
const GAUNTLET_JUMP := "Items/Weapons/Weapon_Melee/7_weapons_melee_heavyJumpAttack/weapons_melee_heavyJumpAttack/sfx_gauntlets_unique_jump_%02d.ogg"
const GAUNTLET_SLAM := "Items/Weapons/Weapon_Melee/7_weapons_melee_heavyJumpAttack/weapons_melee_heavyJumpAttack/sfx_gauntlets_unique_jump_attack_%02d.ogg"
const TOOL_AUDIO := "Items/Weapons/Weapon_Melee/"
const TOOL_SWING_AUDIO := "6_weapons_melee_basicCombo/Attack%d/"
const TOOL_AIR_AUDIO := "7_weapons_melee_heavyJumpAttack/weapons_melee_heavyJumpAttack/"
const TOOL_SAMPLES := {
	&"cleaver": [
		["sfx_cleaver_attack1_01", "a5c93722ef4eadbe6764d08d300deab01a7760232d1b485c98e926af8c65b152"],
		["sfx_cleaver_attack2_01", "5f16fcbc14c5bd7de9882d0cbfde5fa981742a38c84ce88b3f3be43c46cbcee5"],
		["sfx_cleaver_attack3_01", "2b8c40a503378fd04f1d9aad2549ec3d6907b64ffc320f362326df4cc39cbb53"],
		[], ["sfx_cleaver_HJA_01", "45a8f478c1d583be77d7ad91e0edce7ceb006a508c549f0828ca77ef51fe7ebb"], [],
	],
	&"gauntlet": [
		["sfx_gauntlet_attack_combo2_light_01", "218f1dadb43722675b3d5a4883a539d18f03e9631fbfcbec074ccad253e1dec0"],
		["sfx_gauntlet_attack_combo2_mid_01", "1fb81a7b84c1fc590df8db448a2645f2b77054f303cb1b826fb819834a9b563f"],
		["sfx_gauntlet_attack_combo2_heavy_01", "481cc404977d9f0e0dceddae00277c19d0da5efa59ed4e6545801bb3d8b82bb9"],
		["sfx_gauntlet_HJA_start_01", "3481d1af85e89dec658a34e234c04ec684b87a2c0d220ed90eb65b2d5db16237"],
		["sfx_gauntlet_HJA_hit_01", "dfe9012b79877af6c4f5ed76bc5838df1f2b2f5c7e10cd4f40e5a9deceacdb8a"],
		["sfx_weapon_hitmarker_gauntlets_01", GAUNTLET_HIT_HASHES[0]],
	],
	&"pickaxe": [
		["sfx_pickaxe_attack_light_01", "528918dca461fb901e0879484cdf4caf94849db40365a74270838ea5d1694dc4"],
		["sfx_pickaxe_attack_medium_01", "a070a153337e7d2ad13bae9bf23e41cfb88463a47e620a76df592b836300464c"],
		["sfx_pickaxe_attack_heavy_01", "ef31d6f07ecfe34df7cf701c431fd4eab06507c7348c1465f15dbe463b6e7d3c"],
		["sfx_pickaxe_HJA_start_01", "e8e913bb5589730e09e8ae741c8a40284edd33e844ba19ea759364029d12774e"],
		["sfx_pickaxe_jump_attack_01", "ed9e8c6b6bca74c3cba8ea718c6297b2595b4473ba8e384647ede2295e506fd5"],
		["sfx_weapon_hitmarker_pickaxe_01", "be899f24da74a5463b02ef7eda01f27db723118091bd9b97dfcb52a250add2db"],
	],
	&"shovel": [
		["sfx_shovel_attack1", "068fc26cf43f010435cc4c19e8bf204a5d9281cd33e675dab8b302a5fe04a94d"],
		["sfx_shovel_attack2_01", "a825cb79c2985ab7d5615369a185fc4501cacac9dd3cd0eeda82ad10cc2d1bdb"],
		["sfx_shovel_attack3_01", "5d7d66541a8e9c240b5ae55ca445e0882386db11016d9116857e3281b0fbe304"],
		["sfx_shovel_HJA_whoosh", "45f1af854a05e277a7a97f5ff03eb1d65fbcd7e9214c4069833454424decf695"],
		["sfx_shovel_HJA_hit_02", "275f098f77c8191adfda4e4aa18decd64be0485ea389d26ff49337a4ee6a6749"],
		["sfx_weapon_hitmarker_shovel_01", "4453bb081a04947d98270b92b3ca5fd40b7425e47446289c81d7b61c06baa09b"],
	],
}
const GAUNTLET_SWING_HASHES := {
	"light": [
		"5ca970f981961963617c5903b5bb66505e76ceefc41ab0ad52286ecdd738e07f",
		"5bac59bacc2d8de291ab9e48d7d491e515ba06ef43495cfa891da88222b5cce1",
		"4abf9e81cae657f87bcc590f5bee8ac130ef8fc9be4082aaefa63aac1f25a3d0",
	],
	"medium": [
		"46eef63fa11387a9361eaf8bc7142267f392143de9eec35fe227d5ac6fdf0ccf",
		"91774ee223a968ecaf54808122faf041db488f6ab9fa5fdf37961c3fe4133a87",
		"01e7b6990b3b83138f1374f12429cfd93148a3f534d603581e88559dde639187",
		"dbf195696aba3ea0957dc005ce6bee79c00b4aa5475cd96adfe03fb857bd5b9c",
	],
	"heavy": [
		"560425504d85ca0b56e20f4ad07ec7a370aff34e5d90105fc365e7b83005a108",
		"4dd3f590253835382e3e6561d38cf64f2a5c388407cecd6cff287217e2629b8e",
		"9ea1378bfc777e06cfa54ecb2b2a736104efeb0ffd83b2e4696a9c2f042af083",
	],
}
const GAUNTLET_JUMP_HASHES := [
	"230dae33f21cd973a3067b847caa782f1ed8e31d13d11b7584a22a4f6b7aab03",
	"db1d1e7820566272a5e1369020d2b3f916c94f404fe3b60f4393190759d38707",
	"7044a9c787f1b5d3899af16cb54172a8206eb80798672a1394f41f4cb4b52f6c",
]
const GAUNTLET_SLAM_HASHES := [
	"31648091805b06775cb500bc319a6d167d2f9b02c8fcc5101449c3bddd1042a0",
	"e64bc9c59f7e1c7eb280dc410720abfc3cf7cc84e4d3f0bd7143b9650f971fe8",
	"7460d1a1176685546fb4aa0881818c6c27bc72f68f0e1761dfc41730903b5304",
	"3fa2cef3debb07c586fd84f11c280651a8233ab5050421f4aa6017482dc8cfdb",
]
const MAULER_DIVE := "Items/Enchantments/3_Activate/sfx_enchantment_maulerDive-%03d.ogg"
const MAULER_DIVE_HASHES := [
	"079834c484903bd6802992bc3e5daea5b3e0383fb115aba7e1a2188ac4073286",
	"d36cdcd95dc818c4bdf01fa4cc0099b88d9c6a0b2cef667e4e02c63bf85ada20",
	"76c22383b3ec293ea75bc231a0ac99f6931b74144b7f8e99c73690c58091a119",
]
const HEAVY_LANDING := "Items/Weapons/Weapon_Melee/7_weapons_melee_heavyJumpAttack/weapons_melee_heavyJumpAttack/sfx_sword_jump_attack_heavy_Hit_%02d.ogg"
const SURFACE_LANDING := "Items/Weapons/Weapon_Melee/7_weapons_melee_heavyJumpAttack/weapons_melee_heavyJumpAttackDebris/sfx_HJA_impact debris_%s_%02d.ogg"
const ZOMBIE := "Mobs/Mob_Hostile/MobType1/Zombie/sfx_mob_zombieVariant1%s_%02d.ogg"
# The exported waveforms matching the Zombie event names sit under BabyZombie.
const ZOMBIE_ATTACK := "Mobs/Mob_Hostile/MobType1/BabyZombie/sfx_mob_zombie%sAttack-%03d_soundWave.ogg"
# Zombie.Step names the adult event. The exported generic candidate is under BabyZombie.
const ZOMBIE_STEP := "Mobs/Mob_Hostile/MobType1/BabyZombie/sfx_mob_zombieStepGeneric-%03d_soundWave.ogg"
const PLAYER_HURT := "Player/Hurt/sfx_multi_hit-%03d_soundWave.ogg"
const PLAYER_DEFEAT := "Player/Death/sfx_playerDeath.ogg"
const PLAYER_DEFEAT_HASH := "3c15d66e2b2ce0bc571a8bfa3cadc7d532d2f559ecd45e894a0e44d7c2e0882c"
const VOICES_PER_POOL := 3
const REACTION_POOL := 1
const ATTACK_POOL := 2
const STEP_POOL := 3
const FLIGHT_POOL := 4
const SPATIAL_VOICE_DISTANCE := 35.0
const FLIGHT_GAIN_DB := -17.0
const HIT_GAIN_DB := -9.0
const EQUIP_GAIN_DB := -15.0
const SLAM_GAIN_DB := -10.0
const SURFACE_LANDING_GAIN_DB := -16.0
const HURT_GAIN_DB := -20.0
const DEATH_GAIN_DB := -14.0
const DEATH_ONSET_SECONDS := 0.05
const ZOMBIE_WINDUP_GAIN_DB := -16.0
const ZOMBIE_HIT_GAIN_DB := -14.0
const PLAYER_HURT_GAIN_DB := -14.0
const PLAYER_DEFEAT_GAIN_DB := -16.0
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
var gauntlets_equipped := false
var zombie_listener: AudioListener3D
var _groups: Dictionary[StringName, Array] = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _player_hurt_voice: AudioStreamPlayer
var _player_defeat_voice: AudioStreamPlayer
var _next_choice: Dictionary[StringName, int] = {}
var _next_voice: Array[int] = [0, 0, 0, 0, 0]
var _flight_targets: Dictionary[AudioStreamPlayer3D, Node3D]
var _started_frames: PackedInt64Array
var _player_hurt_frame := -1
var _zombie_cue_frame := -1
var _attack_contacts: Array[Dictionary] = []
var _attack_windups: Array[Dictionary] = []
var _reaction_deaths: Array[Dictionary] = []
var _reaction_hurts: Array[Dictionary] = []
var _zombie_step_frame := -1
var _step_points: Array[Vector3] = []
var _step_distances: Array[float] = []
var _last_weapon_serial := -1
var _master_was_muted := false

func _ready() -> void:
	set_process(false)

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

func contact(point: Vector3, serial: int, lethal: bool, clip := "", tool := &"") -> void:
	if not enabled:
		return
	# Projectiles and the gauntlet slam play their impact at the collision itself.
	var uses_collision_cue := clip in [CrossPollinator.SHOT, "NativeBowAction"] \
		or (clip == "AirAttack" and (gauntlets_equipped or tool != &""))
	if serial != _last_weapon_serial and not uses_collision_cue:
		_last_weapon_serial = serial
		var group := _weapon_hit_group()
		if tool != &"":
			group = _tool_group(tool, 5)
		elif clip.begins_with("NativeGauntlet"):
			group = &"gauntlet_hit"
		_play(group, point, HIT_GAIN_DB)
	var reaction := &"death" if lethal else &"hurt"
	if not is_instance_valid(zombie_listener):
		_play(reaction, point, DEATH_GAIN_DB if lethal else HURT_GAIN_DB)
	else:
		_queue_zombie_cue(reaction, point, _reaction_deaths if lethal else _reaction_hurts)

func _weapon_hit_group() -> StringName:
	if curved_equipped:
		return &"curved_hit"
	return &"sword_hit" if sword_equipped else &"hit"

func load_crossbow(root: String) -> void:
	# RapidCrossbow_Unique1's OnEquipped and OnUnequipped Wwise events.
	_load_sample(root, &"crossbow_equip", CROSSBOW + "equip.ogg", CROSSBOW_EQUIP_HASH)
	_load_sample(root, &"crossbow_unequip", CROSSBOW + "unequip.ogg", CROSSBOW_UNEQUIP_HASH)
	for i in CROSSBOW_FIRE_HASHES.size():
		_load_sample(root, &"crossbow_fire", CROSSBOW + ("fire_%02d.ogg" % (i + 1)), CROSSBOW_FIRE_HASHES[i])
	for i in CROSSBOW_IMPACT_HASHES.size():
		_load_sample(root, &"crossbow_hit", CROSSBOW + ("arrow_impact_%02d.ogg" % (i + 1)), CROSSBOW_IMPACT_HASHES[i])
	for i in CROSSBOW_FLIGHT_HASHES.size():
		_load_sample(root, &"crossbow_flight", CROSSBOW + ("arrow_whoosh_%02d.ogg" % (i + 1)), CROSSBOW_FLIGHT_HASHES[i])

func load_gauntlets(root: String, basic := false) -> void:
	if basic:
		load_melee_tool(root, &"gauntlet")
		return
	var weights := ["light", "medium", "heavy"]
	for i in weights.size():
		var weight: String = weights[i]
		var hashes: Array = GAUNTLET_SWING_HASHES[weight]
		var group := StringName("gauntlet_swing_%d" % i)
		for sample in hashes.size():
			_load_sample(root, group, GAUNTLET_COMBO % [i + 1, weight, sample + 1], hashes[sample])
	for i in GAUNTLET_HIT_HASHES.size():
		_load_sample(root, &"gauntlet_hit", GAUNTLET_HIT % (i + 1), GAUNTLET_HIT_HASHES[i])
	for i in GAUNTLET_JUMP_HASHES.size():
		_load_sample(root, &"gauntlet_jump", GAUNTLET_JUMP % (i + 1), GAUNTLET_JUMP_HASHES[i])
	for i in GAUNTLET_SLAM_HASHES.size():
		_load_sample(root, &"gauntlet_slam", GAUNTLET_SLAM % (i + 1), GAUNTLET_SLAM_HASHES[i])
	for i in MAULER_DIVE_HASHES.size():
		_load_sample(root, &"mauler_dive", MAULER_DIVE % (i + 1), MAULER_DIVE_HASHES[i])

func load_melee_tool(root: String, tool: StringName) -> void:
	var samples: Array = TOOL_SAMPLES[tool]
	for slot in samples.size():
		var sample: Array = samples[slot]
		if sample.is_empty():
			continue
		var folder := TOOL_SWING_AUDIO % (slot + 1) if slot < 3 else TOOL_AIR_AUDIO
		if slot == 5:
			folder = "5_weapons_melee_hitmarkers/"
		_load_sample(root, _tool_group(tool, slot), TOOL_AUDIO + folder + sample[0] + ".ogg", sample[1])

static func _tool_group(tool: StringName, slot: int) -> StringName:
	return StringName("tool_%s_%d" % [tool, slot])

func tool_swung(tool: StringName, point: Vector3, index: int, airborne: bool) -> void:
	if enabled:
		_play(_tool_group(tool, 3 if airborne else index), point, HIT_GAIN_DB)

func tool_landed(tool: StringName, point: Vector3) -> void:
	if enabled:
		_play(_tool_group(tool, 4), point, SLAM_GAIN_DB)

func crossbow_switched(equipped: bool, point: Vector3) -> void:
	if enabled:
		_play(&"crossbow_equip" if equipped else &"crossbow_unequip", point, EQUIP_GAIN_DB)

func crossbow_fired(point: Vector3) -> void:
	if enabled:
		_play(&"crossbow_fire", point, HIT_GAIN_DB)

func crossbow_impact(point: Vector3) -> void:
	if enabled:
		_play(&"crossbow_hit", point, HIT_GAIN_DB)

func crossbow_flight(bolt: Node3D) -> void:
	if not enabled or not _groups.has(&"crossbow_flight"):
		return
	if _voices.size() == FLIGHT_POOL * VOICES_PER_POOL:
		_create_voices(VOICES_PER_POOL)
	var voice := _play(&"crossbow_flight", bolt.global_position, FLIGHT_GAIN_DB)
	if voice != null:
		_flight_targets[voice] = bolt
		set_process(true)

func stop_crossbow_flight(bolt: Node3D) -> void:
	var slot := _flight_targets.find_key(bolt) as AudioStreamPlayer3D
	if slot == null:
		return
	slot.stop()
	_flight_targets.erase(slot)
	if _flight_targets.is_empty():
		set_process(false)

func _process(_delta: float) -> void:
	for voice: AudioStreamPlayer3D in _flight_targets.keys():
		var bolt: Variant = _flight_targets[voice]
		if not is_instance_valid(bolt) or bolt.is_queued_for_deletion() or not voice.playing:
			voice.stop()
			_flight_targets.erase(voice)
		else:
			voice.global_position = bolt.global_position
	if _flight_targets.is_empty():
		set_process(false)

func gauntlet_swung(point: Vector3, index: int, airborne: bool) -> void:
	if enabled:
		_play(&"gauntlet_jump" if airborne else StringName("gauntlet_swing_%d" % index), point, HIT_GAIN_DB)

func gauntlet_slam_landed(point: Vector3) -> void:
	if enabled:
		_play(&"gauntlet_slam", point, SLAM_GAIN_DB)
		_play(&"mauler_dive", point, SLAM_GAIN_DB)

func slam_landed(point: Vector3, surface: String = "grass") -> void:
	if not enabled:
		return
	if sword_equipped:
		_play(&"slam", point, SLAM_GAIN_DB)
	_play(StringName("slam_" + surface), point, SURFACE_LANDING_GAIN_DB)

func player_hurt() -> void:
	if not enabled or _player_hurt_voice == null:
		return
	var frame := Engine.get_physics_frames()
	if _player_hurt_frame == frame:
		return
	var stream := _next_stream(&"player_hurt")
	if stream != null:
		_player_hurt_frame = frame
		_player_hurt_voice.stream = stream
		_player_hurt_voice.play()

func player_defeated() -> void:
	if not enabled or _player_defeat_voice == null:
		return
	var stream := _next_stream(&"player_defeat")
	if stream != null:
		_player_defeat_voice.stream = stream
		_player_defeat_voice.play()

func zombie_attack(point: Vector3, contact: bool) -> void:
	var group := &"zombie_hit" if contact else &"zombie_windup"
	if enabled:
		_queue_zombie_cue(group, point, _attack_contacts if contact else _attack_windups)

func _queue_zombie_cue(group: StringName, point: Vector3, pending: Array[Dictionary]) -> void:
	if not _groups.has(group) or not is_instance_valid(zombie_listener):
		return
	var frame := Engine.get_physics_frames()
	if frame != _zombie_cue_frame:
		flush_zombie_combat_cues()
		_zombie_cue_frame = frame
	var distance := point.distance_squared_to(zombie_listener.global_position)
	if distance > SPATIAL_VOICE_DISTANCE * SPATIAL_VOICE_DISTANCE:
		return
	# Bound each priority to the number of playable voices, preserving ties
	# in event order. Only cues selected for playback advance sample rotation.
	var index := pending.size()
	while index > 0 and distance < float(pending[index - 1].distance):
		index -= 1
	if index < VOICES_PER_POOL:
		pending.insert(index, {"point": point, "distance": distance})
		if pending.size() > VOICES_PER_POOL:
			pending.pop_back()

func flush_zombie_combat_cues() -> void:
	_play_zombie_cues(_attack_contacts, &"zombie_hit", ZOMBIE_HIT_GAIN_DB)
	_play_zombie_cues(_attack_windups, &"zombie_windup", ZOMBIE_WINDUP_GAIN_DB)
	_play_zombie_cues(_reaction_deaths, &"death", DEATH_GAIN_DB)
	_play_zombie_cues(_reaction_hurts, &"hurt", HURT_GAIN_DB)

func _play_zombie_cues(pending: Array[Dictionary], group: StringName, gain: float) -> void:
	for cue: Dictionary in pending:
		_play(group, cue.point, gain, _zombie_cue_frame)
	pending.clear()

func queue_zombie_step(sole: Vector3, listener: Vector3, find_support: Callable, known_support: Variant = null) -> void:
	if not enabled or not _groups.has(&"zombie_step"):
		return
	var frame := Engine.get_physics_frames()
	if frame != _zombie_step_frame:
		flush_zombie_steps()
		_zombie_step_frame = frame
	var distance := sole.distance_squared_to(listener)
	if distance > ZOMBIE_STEP_DISTANCE * ZOMBIE_STEP_DISTANCE:
		return
	var available := 0
	for slot in VOICES_PER_POOL:
		available += int(not _voices[STEP_POOL * VOICES_PER_POOL + slot].playing)
	if available == 0:
		return
	var index := _step_distances.size()
	while index > 0 and distance < _step_distances[index - 1]:
		index -= 1
	if index >= available:
		return
	var support: Dictionary = find_support.call(sole) if known_support == null else known_support
	if support.is_empty():
		return
	_step_distances.insert(index, distance)
	_step_points.insert(index, support.position)
	if _step_points.size() > available:
		_step_distances.pop_back()
		_step_points.pop_back()

func flush_zombie_steps() -> void:
	for point: Vector3 in _step_points:
		_play(&"zombie_step", point, ZOMBIE_STEP_GAIN_DB)
	_step_points.clear()
	_step_distances.clear()

func reset() -> void:
	_flight_targets.clear()
	set_process(false)
	_attack_contacts.clear()
	_attack_windups.clear()
	_reaction_deaths.clear()
	_reaction_hurts.clear()
	_zombie_cue_frame = -1
	_step_points.clear()
	_step_distances.clear()
	_zombie_step_frame = -1
	_started_frames.fill(-1)
	_player_hurt_frame = -1
	_last_weapon_serial = -1
	_next_voice.fill(0)
	for voice in _voices:
		voice.stop()
		voice.stream = null
	if _player_hurt_voice != null:
		_player_hurt_voice.stop()
		_player_hurt_voice.stream = null
	if _player_defeat_voice != null:
		_player_defeat_voice.stop()
		_player_defeat_voice.stream = null

static func _research_root() -> String:
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	return OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research") if root.is_empty() else root

func _load_audio() -> void:
	if not OS.has_feature("editor"):
		return
	_started_frames.resize(_next_voice.size() * VOICES_PER_POOL)
	_started_frames.fill(-1)
	var root := _research_root()
	# DefaultPlayer routes SW.Audio.Generic.Hurt to SW.Audio.Category.Player.Local.
	_player_hurt_voice = AudioStreamPlayer.new()
	_player_hurt_voice.name = "PlayerHurt"
	_player_hurt_voice.volume_db = PLAYER_HURT_GAIN_DB
	add_child(_player_hurt_voice)
	_player_defeat_voice = AudioStreamPlayer.new()
	_player_defeat_voice.name = "PlayerDefeat"
	_player_defeat_voice.volume_db = PLAYER_DEFEAT_GAIN_DB
	add_child(_player_defeat_voice)
	_create_voices(FLIGHT_POOL * VOICES_PER_POOL)
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
	_load_sample(root, &"player_defeat", PLAYER_DEFEAT, PLAYER_DEFEAT_HASH)
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
		voice.max_distance = SPATIAL_VOICE_DISTANCE
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

func _play(group: StringName, point: Vector3, gain: float, event_frame := -1) -> AudioStreamPlayer3D:
	if not _groups.has(group):
		return null
	# Separate enemy attack and reaction budgets keep the weapon tails audible.
	var pool := 0
	match group:
		&"hurt", &"death":
			pool = REACTION_POOL
		&"zombie_windup", &"zombie_hit":
			pool = ATTACK_POOL
		&"zombie_step":
			pool = STEP_POOL
		&"crossbow_flight":
			pool = FLIGHT_POOL
	var first := pool * VOICES_PER_POOL
	if first >= _voices.size():
		return null
	var start := _next_voice[pool]
	var slot := -1
	for offset in VOICES_PER_POOL:
		var candidate := (start + offset) % VOICES_PER_POOL
		if not _voices[first + candidate].playing:
			slot = candidate
			break
	var frame := Engine.get_physics_frames() if event_frame < 0 else event_frame
	if slot == -1:
		match pool:
			REACTION_POOL:
				slot = _replace_priority_slot(first, start, &"death", group, frame, point)
			ATTACK_POOL:
				slot = _replace_priority_slot(first, start, &"zombie_hit", group, frame)
			0:
				if group == &"crossbow_hit" or group == &"crossbow_fire":
					# An impact burst shares the weapon pool. Leave room for the
					# local firing cue and let only the admitted impacts rotate.
					slot = _replace_priority_slot(first, start, &"crossbow_fire", group, frame)
				else:
					slot = start
		if slot == -1:
			return null
	var stream := _next_stream(group)
	var voice_index := first + slot
	var voice := _voices[voice_index]
	_next_voice[pool] = (slot + 1) % VOICES_PER_POOL
	if voice_index < _started_frames.size():
		_started_frames[voice_index] = frame
	voice.stop()
	voice.stream = stream
	voice.global_position = point
	voice.volume_db = gain
	voice.max_db = gain
	voice.play()
	return voice

func _replace_priority_slot(first: int, start: int, priority_group: StringName, group: StringName,
		frame: int, point := Vector3.ZERO) -> int:
	# Same-tick cues already arrive nearest first. Preserve nearby death onsets
	# across short gaps between ticks, too, while the mixer starts the samples.
	var priority_streams: Array = _groups.get(priority_group, [])
	var priority := group == priority_group
	var compare_onsets := priority and group == &"death" and is_instance_valid(zombie_listener)
	var listener := zombie_listener.global_position if compare_onsets else Vector3.ZERO
	var onset_ticks := ceili(DEATH_ONSET_SECONDS * Engine.physics_ticks_per_second)
	var farthest := point.distance_squared_to(listener)
	var farther_onset := -1
	var older_slot := -1
	for offset in VOICES_PER_POOL:
		var slot := (start + offset) % VOICES_PER_POOL
		var voice_index := first + slot
		var playing_priority := _voices[voice_index].stream in priority_streams
		if priority and not playing_priority:
			return slot
		var age := frame - _started_frames[voice_index]
		if priority != playing_priority or age <= 0:
			continue
		if compare_onsets and age <= onset_ticks:
			var distance := _voices[voice_index].global_position.distance_squared_to(listener)
			if distance > farthest:
				farthest = distance
				farther_onset = slot
		elif older_slot == -1:
			older_slot = slot
	return older_slot if older_slot >= 0 else farther_onset
