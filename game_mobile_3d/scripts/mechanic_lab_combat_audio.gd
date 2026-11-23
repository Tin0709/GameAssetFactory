extends Node3D
## Extracted MD2 samples. Group selection and gains are local playback settings.

const SourceFilePath := preload("res://scripts/source_file_path.gd")
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
		["sfx_cleaver_attack1_%02d", [
			"a5c93722ef4eadbe6764d08d300deab01a7760232d1b485c98e926af8c65b152",
			"8afe9966b8372fa93ffef44eb1a910e2bf22adf51d861aad4de23e29805e3b4a",
			"f2bdcb51148b71fc723a059ca03717eae04bf248d9d0ff54f84512d9dbb60bcf",
		]],
		["sfx_cleaver_attack2_%02d", [
			"5f16fcbc14c5bd7de9882d0cbfde5fa981742a38c84ce88b3f3be43c46cbcee5",
			"fc4efd16b687ae27280a136619c0d51df7ce651d54847b54514fbca5323af430",
			"3a7fa08bfcd0e9e32fd3aade5213cefc167560ba2ea482ba6d0cdf329cdbf9dd",
		]],
		["sfx_cleaver_attack3_%02d", [
			"2b8c40a503378fd04f1d9aad2549ec3d6907b64ffc320f362326df4cc39cbb53",
			"054d570d118ff6b0bf07e6bc73adc840b595bcb2ff878183a5968ea3b28c951e",
		]],
		[],
		["sfx_cleaver_HJA_%02d", [
			"45a8f478c1d583be77d7ad91e0edce7ceb006a508c549f0828ca77ef51fe7ebb",
			"56df3b34cff5fca7a3ae9f1e3eb199a940e023f7aacbf62d68f00ef8930bd6ac",
		]],
		[],
	],
	&"gauntlet": [
		["sfx_gauntlet_attack_combo2_light_%02d", [
			"218f1dadb43722675b3d5a4883a539d18f03e9631fbfcbec074ccad253e1dec0",
			"233a5c346ccd4117b81bd78b7e53bf7826679bfd98438302b57c0aeef4568aac",
			"ae3029801547f549e1a7c00bfeee7a2b96b439c30f7a389691f9a49bb035f4f7",
			"98aa2df629b1197c1fcf59e45fa4ad105ff6fd41c1012ea90ec0471a8c5e7708",
		]],
		["sfx_gauntlet_attack_combo2_mid_%02d", [
			"1fb81a7b84c1fc590df8db448a2645f2b77054f303cb1b826fb819834a9b563f",
			"3337a7982f9dc4274a92d75cffbf771c6a438b857637bdfd96e4cea885ae6b6c",
			"5af48a7254a2918a7125c4ac5884045e91c96f88508b7423402862c87bc700e6",
		]],
		["sfx_gauntlet_attack_combo2_heavy_%02d", [
			"481cc404977d9f0e0dceddae00277c19d0da5efa59ed4e6545801bb3d8b82bb9",
			"fc9cd25c8934b3d9f2d8ea8c77440de0fba7a0ce54138233cd35fe1fc56cdede",
			"2514e92c3c58a0be99fb0b464d5f105353d53e889a6755303e1c5e5c5d3a4f65",
		]],
		["sfx_gauntlet_HJA_start_%02d", [
			"3481d1af85e89dec658a34e234c04ec684b87a2c0d220ed90eb65b2d5db16237",
			"f8edb35576db3acc0329ccd2095540d92dd837e8444888aa4345bb6ce0b85f1c",
			"f963b957d47a6992ca67b65a10e7529c3d8d2e3784b69d3420e9e5ebc09be653",
		]],
		["sfx_gauntlet_HJA_hit_%02d", [
			"dfe9012b79877af6c4f5ed76bc5838df1f2b2f5c7e10cd4f40e5a9deceacdb8a",
			"d90eb9f888690a83dc65741c8d1d0e3d252e57adce586740a6b2d078fe038374",
			"2c7faf3251ce5f504b38c4a398c303804196b4293be24fd2388417521a979419",
		]],
		["sfx_weapon_hitmarker_gauntlets_%02d", GAUNTLET_HIT_HASHES],
	],
	&"pickaxe": [
		["sfx_pickaxe_attack_light_%02d", [
			"528918dca461fb901e0879484cdf4caf94849db40365a74270838ea5d1694dc4",
			"e91697a592464de43426ee035b85aff693b4abeac1c71b8b1fb3fe069b8b59b0",
			"6ae329b0c28af8d7f366c9abfa5aa3219bb18f0e8c63a0b8cd665c5f407bb46b",
		]],
		["sfx_pickaxe_attack_medium_%02d", [
			"a070a153337e7d2ad13bae9bf23e41cfb88463a47e620a76df592b836300464c",
			"50aeaf01882a2d505bb3f078832118cf1cb764356b93747f8132a61a908f1093",
			"b77c131f51b47c8cf364a0b27a90f75fb363c7c52bb12ba24d8edcd7fbc531e9",
		]],
		["sfx_pickaxe_attack_heavy_%02d", [
			"ef31d6f07ecfe34df7cf701c431fd4eab06507c7348c1465f15dbe463b6e7d3c",
			"a8360a7f2f890b0091c0ce220da5fd0d09a701baab0d468a8b6fb8b2334cf50b",
			"c0ea2b2f0b9bc67b7d21a4e03a6ac69021ae25fb3e7335eaeb2929c9b3bde045",
		]],
		["sfx_pickaxe_HJA_start_%02d", [
			"e8e913bb5589730e09e8ae741c8a40284edd33e844ba19ea759364029d12774e",
			"78626aa82479c7995bfbf089c22abce164ecdad3bd6e6a04883592fa0c7febd7",
			"ceeccf383c963a688d4b624844116d5729327b375e167ddf07f984ffe324efa6",
		]],
		["sfx_pickaxe_jump_attack_%02d", [
			"ed9e8c6b6bca74c3cba8ea718c6297b2595b4473ba8e384647ede2295e506fd5",
			"ab51b7299db4b970b634dcc52f4356b3d6169ecf5e220d83e166362b92f52f9d",
			"1fa91cfcb519e976d417193adf864400242dc357858acf8ad4b32940b26da451",
		]],
		["sfx_weapon_hitmarker_pickaxe_%02d", [
			"be899f24da74a5463b02ef7eda01f27db723118091bd9b97dfcb52a250add2db",
			"824b527be4da9ed633bf615ef7626ae36346a58deaa200aec4410c98ed816aab",
			"77dcf17ae4580a27a0015b3fa64e1dbb850e8ea36c438aab86a07bc72b2756a5",
		]],
	],
	&"shovel": [
		["sfx_shovel_attack1", ["068fc26cf43f010435cc4c19e8bf204a5d9281cd33e675dab8b302a5fe04a94d"]],
		["sfx_shovel_attack2_%02d", [
			"a825cb79c2985ab7d5615369a185fc4501cacac9dd3cd0eeda82ad10cc2d1bdb",
			"28e01aef3b1bb798cb2318641d2d2e25f4e6df21798e7ae037fd38dd29315a53",
			"399bedc3c2374f614e24f2b7e7a31a59de611134835c12187d99d63029479742",
		]],
		["sfx_shovel_attack3_%02d", [
			"5d7d66541a8e9c240b5ae55ca445e0882386db11016d9116857e3281b0fbe304",
			"60c5f1b61bfc7eb619797a1c5ee53bd1cbae1711eebb91915183d2a6239e76ea",
			"1900f93e191075c783fa92f17cb6be77ac0118783736e4779d477f3625ecc438",
		]],
		["sfx_shovel_HJA_whoosh", ["45f1af854a05e277a7a97f5ff03eb1d65fbcd7e9214c4069833454424decf695"]],
		["sfx_shovel_HJA_hit_02", ["275f098f77c8191adfda4e4aa18decd64be0485ea389d26ff49337a4ee6a6749"]],
		["sfx_weapon_hitmarker_shovel_%02d", [
			"4453bb081a04947d98270b92b3ca5fd40b7425e47446289c81d7b61c06baa09b",
			"81f6c1432abe583495723495b4f246e376d58931ba2ad3fd325ddcd6976d57ec",
			"9cc6d9d3cef4f4672ef1f647cdb2789d3138853d41cfc3b647ea23096b1e0d38",
		]],
	],
	&"axe": [
		["sfx_axe_attack_combo_01", ["bee4c3e4572bcc33a91d448c52aebbe3de7f814502ba02bde31b5831b6a195ef"]],
		["sfx_axe_attack_combo_02", ["baf9210e80e2a6e736cbd7fe16fa656951fdd8fc7e983fe867f3e8c28490c8c7"]],
		["sfx_axe_attack_combo_03", ["0e5f24a0ead9ad8eddaa685c169a43273868bd81bc87f1458573a0bba129cdc9"]],
		["sfx_axe_HJA_start_%02d", [
			"80b72d591c9aca57bb4414f07b3afd22fb958d58e423ab6450d3d9827db09744",
			"18df36965bc6b92ac93a60caa3081578b4365bc52f19414edba76b9e7b379960",
			"999a78ecb9889b552586eb70a826df49ec5057e9449fe984686afdc426704539",
		]],
		["sfx_axe_HJA_hit_%02d", [
			"b7536f0aa90c601dd40b22c85e4451204a2a8e4d99d147dd517a364495207956",
			"37493bf31fe6bf265240d94f4ed4d46fa33f733d47481ab03a5c0928e1ced648",
			"295793b2336f7bbde0379566dd1496cda03f5309d692ef6e623695e6216d8ff9",
		]],
		[], # The base Axe hitmarker has no matching local export.
	],
}
# DT_MeleePropertyDefinition uses shared events with a switch for each weapon.
# The exported samples below match the weapon name and event folder.
const MELEE_SWITCH_SAMPLES := {
	&"sabre_equip": {
		"sfx_sabre_equip_01": "655a0c40a00fc7c223fe3fd746ef24768b4ed6c682c41769085244516620f8ac",
	},
	&"sabre_unequip": {
		"sfx_sabre_unequp_01": "1bc13d53843ff68a30cd0f561b33dbd700e14f6146437cd30663aa91aac47128",
	},
	&"sword_equip": {
		"sfx_sword_equip": "ddbb9925fab548575418e2d7e6bc4bbd26530eba379e2918f38979c40f1c497f",
	},
	&"sword_unequip": {
		"sfx_sword_unequip": "83695d219518b086dfda0205f78a74185a082daa766680fe61adc728cbffebce",
	},
	&"curved_greatsword_equip": {
		"sfx_item_curvedgreatsword_equip": "d70229684a5aa102d48b4218dfb3d7a45a7bf32f0a777f7ae35bf198fd6cd412",
	},
	&"curved_greatsword_unequip": {
		"sfx_item_curvedgreatsword_unequip": "41d2812815ab3511f19f465df52301f8f492c0a40f788bc6bd386f071e27c1c7",
	},
	&"cleaver_equip": {
		"sfx_cleaver_equip": "42fe8c444dd612959bf10263fb1f1ca5ed5d5a800025fbffd5c1371815d3a885",
	},
	&"cleaver_unequip": {
		"sfx_cleaver_unequip": "2075385ebc5ae98c2d6f96358410609a27a9648eb67984f25d80e4a6a52d9817",
	},
	&"gauntlet_unequip": {
		"sfx_gauntlet_unequip": "4d5256b4b2139b02a7e7e0eeec2bfca68f9a6f476a0542be47128558e4f82c31",
	},
	&"prime_gauntlet_equip": {
		"sfx_gauntlets_unique_equip_01": "4a56c22d92d2995009c79ba0a5d41b4ba35f6cdcfb38ec5597102c4b9ca69561",
		"sfx_gauntlets_unique_equip_02": "b0791549020179df002d1e7b94a2b0f2a3ddaed2f9f5b041ab7e7cb86ee9df07",
		"sfx_gauntlets_unique_equip_03": "fc5545a4a6597a73eb468ef108853774f60e65e18251d7eff4dee52537cb98d2",
	},
	&"prime_gauntlet_unequip": {
		"sfx_gauntlets_unique_unequip_01": "7d9f48d7548d7287f4a1543679efb091e4065e3d6e6f8cb20c6290d7a5152b78",
		"sfx_gauntlets_unique_unequip_02": "9a1ac20f78424262d8672ba17a3b1179a875395630511f4eeeec9d091f42b900",
		"sfx_gauntlets_unique_unequip_03": "72fdc8db62cf7ffb914065c8fee8b0df5793e378bddecfd77e7737d3f63f0e81",
		"sfx_gauntlets_unique_unequip_04": "c48c4755d82822e60c71d3354116bd8d24c4596938ba5ba34217bad75c61c5ac",
	},
	&"pickaxe_equip": {
		"sfx_pickaxe_equip_01": "02b7945e8fc82f749eb7019fecb442217240f14725a14d2f92aa1c8ea64e4938",
		"sfx_pickaxe_equip_02": "7a5942053fd6f149d006e534b824b0c870d02c7f7f36eff0e7db596cd1150fe0",
		"sfx_pickaxe_equip_03": "f1d6a59f8423c03879ad8aba0016107df825130686e9babbc49e946e69c7cfd1",
	},
	&"pickaxe_unequip": {
		"sfx_pickaxe_unequip_01": "6779bdccf10ee49081303ec743c5ca7738dbcc30eea94652ed649652c6aad1ed",
		"sfx_pickaxe_unequip_02": "2fbf5f60da21602f94f234dbfe2062410845500828b47bf686166d3a573c57e3",
		"sfx_pickaxe_unequip_03": "0eb88ac3f9a843eed9776340f718661357e196f056e1ccb8dc81524233cbffe3",
	},
	&"shovel_equip": {
		"sfx_shovel_equip": "cca527841a727925f491678f00c01c0674795a08ad29bb089cd50a12c420fed5",
	},
	&"shovel_unequip": {
		"sfx_shovel_unequip": "4ab811f6ef1737cb7702e50f8308c2aaa8186fe3763332d0f43993da44d34c20",
	},
	&"axe_equip": {
		"sfx_axe_equip": "258fdf6d1eeef5cb17da337c9f89254b89c8cf17cdfc5ce26e56bade96fb5663",
	},
	&"axe_unequip": {
		"sfx_axe_unequip": "17ff9a8c75a602c67c79db675a90eec3714705d29815d5330cc81ea9c86b7291",
	},
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
const ZOMBIE_VOCAL := "Mobs/Mob_Hostile/MobType1/BabyZombie/sfx_mob_zombie%s-%03d_soundWave.ogg"
# The exported waveforms matching the Zombie event names sit under BabyZombie.
# Zombie.Step names the adult event. The exported generic candidate is under BabyZombie.
const ZOMBIE_STEP := "Mobs/Mob_Hostile/MobType1/BabyZombie/sfx_mob_zombieStepGeneric-%03d_soundWave.ogg"
# Three raw variants corroborated by the adult event duration and quest exports.
const ZOMBIE_IDLE := "Mobs/Mob_Hostile/MobType1/BabyZombie/sfx_mob_zombieIdle-%03d_soundWave.ogg"
const ZOMBIE_IDLE_HASHES := [
	"d1becf75743e832d27e853b9a7532d5510a0beba2bd3d12763c29f31690bc56d",
	"92c73a27e23c316cb75585e11817c61ed54b68804b1f682de5cb759a264dce73",
	"d74e22c23a173ebaf65382cdf55f72423ec1e1dcddeaac142673f45bdd8691a8",
]
const PLAYER_HURT := "Player/Hurt/sfx_multi_hit-%03d_soundWave.ogg"
const PLAYER_DEFEAT := "Player/Death/sfx_playerDeath.ogg"
const PLAYER_DEFEAT_HASH := "3c15d66e2b2ce0bc571a8bfa3cadc7d532d2f559ecd45e894a0e44d7c2e0882c"
const VOICES_PER_POOL := 3
const CROWD_SAMPLE_BUDGET_USEC := 500
const WEAPON_POOL := 0
const REACTION_POOL := 1
const ATTACK_POOL := 2
const STEP_POOL := 3
const FLIGHT_POOL := 4
# Fast successive dives can land 16 ticks apart at 60 Hz, within the 0.57 s samples.
const SURFACE_LANDING_VOICE_COUNT := 3
const SPATIAL_VOICE_DISTANCE := 35.0
const FLIGHT_GAIN_DB := -17.0
const HIT_GAIN_DB := -9.0
const EQUIP_GAIN_DB := -15.0
const SLAM_GAIN_DB := -10.0
const SURFACE_LANDING_GAIN_DB := -16.0
const HURT_GAIN_DB := -20.0
const DEATH_GAIN_DB := -14.0
const WEAPON_ONSET_SECONDS := 0.05
const ZOMBIE_ONSET_SECONDS := 0.05
const ZOMBIE_WINDUP_GAIN_DB := -16.0
const ZOMBIE_HIT_GAIN_DB := -14.0
const BABY_SWING_GAIN_DB := -20.0
const PLAYER_HURT_GAIN_DB := -14.0
const PLAYER_HURT_ONSET_SECONDS := 0.05
const PLAYER_DEFEAT_GAIN_DB := -16.0
const ZOMBIE_STEP_GAIN_DB := -21.0
const ZOMBIE_STEP_DISTANCE := 12.0
const ZOMBIE_IDLE_GAIN_DB := -24.0
const ZOMBIE_IDLE_DISTANCE := 12.0
# Inferred from the ordinary zombie's cooked event durations and raw wave lengths.
const ZOMBIE_PITCH_MIN_CENTS := -200.0
const ZOMBIE_PITCH_MAX_CENTS := 300.0
const PITCHED_ZOMBIE_VOCALS := [&"hurt", &"death", &"zombie_windup"]
const SHARED_BABY_VOCALS := {&"baby_hurt": &"hurt", &"baby_death": &"death",
	&"baby_windup": &"zombie_windup", &"baby_swing": &"zombie_hit"}

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
	"88bacea29d9cdd5ed5edfe75fa260b8f49a7d5b3adf98f488173848784647f10",
	"c67b02cd19dfdc1a83f8cd3d295ce28a74ac7a63010628880ffd017655207e23",
]
const DEATH_HASHES := [
	"4f37c8fbfa63b116cc7afe6930ba1d403a54cf32bb19e04db4a4815ae2628deb",
	"0396d7f66dd11827ac94b1384b9a8ecf55127d9072363ec259ad01f8bb32e1e4",
	"578017fb1cc8213e1b15f39f8208a6c947fa705bb8e603c242c5091e6377ee72",
]
const ZOMBIE_HIT_HASHES := [
	"5dbc65f67fcd3336628c7a35a4576b237735cb17d209205a8d94e642708be59c",
	"ae4008449f238d65576d53c99f9dff67fb51151e48df94669a8dedf55bb6e32e",
	"5a610689ac0dc8ea0100e183e1814c0ed4378bb8bf8a68d4e7a5eeea40b1d3f8",
	"d38a3dfb4a38b5a71eb8cd52dfeff5ff04ca97f9bdee0625c295d92cdac47366",
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
const BABY_HIT_HASHES := [
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

class ZombieCueBatch:
	var points := PackedVector3Array()
	var groups: Array[StringName] = []

	func clear() -> void:
		points.clear()
		groups.clear()

var enabled := false
var sword_equipped := false
var curved_equipped := false
var gauntlets_equipped := false
var zombie_listener: AudioListener3D
var _groups: Dictionary[StringName, Array] = {}
var _loaded_melee_tools: Dictionary[StringName, bool] = {}
var _base_sample_jobs: Array[Callable] = []
var _base_samples_queued := false
var _voices: Array[AudioStreamPlayer3D] = []
var _surface_landing_voices: Array[AudioStreamPlayer3D] = []
var _next_surface_landing_voice := 0
var _player_hurt_voice: AudioStreamPlayer
var _player_defeat_voice: AudioStreamPlayer
var _zombie_idle_voice: AudioStreamPlayer3D
var _zombie_idle_points := PackedVector3Array()
var _zombie_idle_pitch := RandomNumberGenerator.new()
var _zombie_vocal_pitch := RandomNumberGenerator.new()
var _next_choice: Dictionary[StringName, int] = {}
var _next_voice: Array[int] = [0, 0, 0, 0, 0]
var _flight_targets: Dictionary[AudioStreamPlayer3D, Node3D]
var _started_frames: PackedInt64Array
var _voice_groups: Array[StringName] = []
var _weapon_onsets: Array[bool] = []
var _player_hurt_frame := -1
var _attack_contacts := ZombieCueBatch.new()
var _attack_windups := ZombieCueBatch.new()
var _attack_swings := ZombieCueBatch.new()
var _reaction_deaths := ZombieCueBatch.new()
var _reaction_hurts := ZombieCueBatch.new()
var _step_points := PackedVector3Array()
var _last_weapon_serial := -1
var _master_was_muted := false

func _ready() -> void:
	# Projectiles move at the default physics priority before their flight voices follow.
	process_physics_priority = 1
	set_physics_process(false)

func set_enabled(value: bool, preview_point: Vector3, melee_tool := &"", preview_group := &"") -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		reset()
		_restore_master()
		return
	if _voices.is_empty():
		_load_audio()
	if not melee_tool.is_empty():
		load_melee_tool(_research_root(), melee_tool)
	# The project starts with Master muted for quiet tests.
	_master_was_muted = AudioServer.is_bus_mute(0)
	if _master_was_muted:
		AudioServer.set_bus_mute(0, false)
	var preview := preview_group
	if preview.is_empty():
		preview = _weapon_hit_group()
		if not melee_tool.is_empty():
			preview = _tool_group(melee_tool, 5)
			if not _groups.has(preview):
				# Some tools only have a verified swing in the local export.
				preview = _tool_group(melee_tool, 0)
	# Preview the next sample without spending a combat variant or priority slot.
	_play(preview, preview_point, HIT_GAIN_DB, -1, false, true)

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
	weapon_contact(point, serial, clip, tool)
	zombie_reaction(point, lethal)

func weapon_contact(point: Vector3, serial: int, clip := "", tool := &"") -> void:
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
		_play(group, point, HIT_GAIN_DB, -1, true)

func zombie_reaction(point: Vector3, lethal: bool, baby := false) -> void:
	if not enabled:
		return
	var reaction := &"death" if lethal else &"hurt"
	if baby:
		reaction = &"baby_death" if lethal else &"baby_hurt"
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

func load_gauntlets(root: String) -> void:
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
	if root.is_empty() or not TOOL_SAMPLES.has(tool) or _loaded_melee_tools.has(tool):
		return
	_loaded_melee_tools[tool] = true
	var samples: Array = TOOL_SAMPLES[tool]
	for slot in samples.size():
		var sample: Array = samples[slot]
		if sample.is_empty():
			continue
		var folder := TOOL_SWING_AUDIO % (slot + 1) if slot < 3 else TOOL_AIR_AUDIO
		if slot == 5:
			folder = "5_weapons_melee_hitmarkers/"
		var group := _tool_group(tool, slot)
		var pattern: String = sample[0]
		var hashes: Array = sample[1]
		for i in hashes.size():
			var stem := pattern % (i + 1) if "%02d" in pattern else pattern
			_load_sample(root, group, TOOL_AUDIO + folder + stem + ".ogg", hashes[i])

static func _tool_group(tool: StringName, slot: int) -> StringName:
	return StringName("tool_%s_%d" % [tool, slot])

func tool_swung(tool: StringName, point: Vector3, index: int, airborne: bool) -> void:
	if enabled:
		_play(_tool_group(tool, 3 if airborne else index), point, HIT_GAIN_DB)

func tool_landed(tool: StringName, point: Vector3) -> void:
	if enabled:
		_play(_tool_group(tool, 4), point, SLAM_GAIN_DB, -1, true)

func melee_switched(weapon: StringName, equipped: bool, point: Vector3) -> void:
	if not enabled or _voices.is_empty() or weapon.is_empty():
		return
	var group := StringName("%s_%s" % [weapon, "equip" if equipped else "unequip"])
	if not _groups.has(group):
		var samples: Dictionary = MELEE_SWITCH_SAMPLES.get(group, {})
		if samples.is_empty():
			return
		var folder := "3_weapons_melee_equip/" if equipped else "4_weapons_melee_unequip/"
		var root := _research_root()
		for stem: String in samples:
			_load_sample(root, group, TOOL_AUDIO + folder + stem + ".ogg", samples[stem])
	_play(group, point, EQUIP_GAIN_DB)

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
		set_physics_process(true)

func stop_crossbow_flight(bolt: Node3D) -> void:
	var slot := _flight_targets.find_key(bolt) as AudioStreamPlayer3D
	if slot == null:
		return
	slot.stop()
	_flight_targets.erase(slot)
	if _flight_targets.is_empty():
		set_physics_process(false)

func _physics_process(_delta: float) -> void:
	for voice: AudioStreamPlayer3D in _flight_targets.keys():
		var bolt: Variant = _flight_targets[voice]
		if not is_instance_valid(bolt) or bolt.is_queued_for_deletion() or not voice.playing:
			voice.stop()
			_flight_targets.erase(voice)
		else:
			voice.global_position = bolt.global_position
	if _flight_targets.is_empty():
		set_physics_process(false)

func gauntlet_swung(point: Vector3, index: int, airborne: bool) -> void:
	if enabled:
		_play(&"gauntlet_jump" if airborne else StringName("gauntlet_swing_%d" % index), point, HIT_GAIN_DB)

func gauntlet_slam_landed(point: Vector3) -> void:
	if enabled:
		_play(&"gauntlet_slam", point, SLAM_GAIN_DB, -1, true)
		_play(&"mauler_dive", point, SLAM_GAIN_DB)

func slam_landed(point: Vector3, surface: String = "grass") -> void:
	if not enabled:
		return
	if sword_equipped:
		_play(&"slam", point, SLAM_GAIN_DB, -1, true)
	if surface.is_empty():
		return
	var group := StringName("slam_" + surface)
	if _surface_landing_voices.is_empty():
		_play(group, point, SURFACE_LANDING_GAIN_DB)
		return
	var stream := _next_stream(group)
	if stream == null:
		return
	# Ground contacts have independent spatial tails, even during weapon bursts.
	var slot := _next_surface_landing_voice
	for offset in _surface_landing_voices.size():
		var candidate := (slot + offset) % _surface_landing_voices.size()
		if not _surface_landing_voices[candidate].playing:
			slot = candidate
			break
	_next_surface_landing_voice = (slot + 1) % _surface_landing_voices.size()
	_start_spatial_voice(_surface_landing_voices[slot], stream, point, SURFACE_LANDING_GAIN_DB)

func player_hurt() -> void:
	if not enabled or _player_hurt_voice == null:
		return
	var frame := Engine.get_physics_frames()
	# Several hits can arrive before the local voice has mixed its onset.
	if (_player_hurt_frame == frame or (_player_hurt_voice.get_playback_position() < PLAYER_HURT_ONSET_SECONDS
			and _player_hurt_voice.playing)):
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

func zombie_attack(point: Vector3, contact: bool, baby := false) -> void:
	var group := &"zombie_hit" if contact else &"zombie_windup"
	if baby:
		group = &"baby_hit" if contact else &"baby_windup"
	if enabled:
		_queue_zombie_cue(group, point, _attack_contacts if contact else _attack_windups)

func baby_swing(point: Vector3) -> void:
	if enabled:
		_queue_zombie_cue(&"baby_swing", point, _attack_swings)

func _queue_zombie_cue(group: StringName, point: Vector3, pending: ZombieCueBatch) -> void:
	if not _groups.has(group) or not is_instance_valid(zombie_listener):
		return
	pending.points.append(point)
	pending.groups.append(group)

func flush_zombie_combat_cues() -> void:
	if not enabled:
		return
	var ear := _zombie_listener_position()
	_play_zombie_cues(_attack_contacts, ear, ZOMBIE_HIT_GAIN_DB)
	_play_zombie_cues(_attack_windups, ear, ZOMBIE_WINDUP_GAIN_DB)
	_play_zombie_cues(_attack_swings, ear, BABY_SWING_GAIN_DB)
	_play_zombie_cues(_reaction_deaths, ear, DEATH_GAIN_DB)
	_play_zombie_cues(_reaction_hurts, ear, HURT_GAIN_DB)

func _play_zombie_cues(pending: ZombieCueBatch, ear: Vector3, gain: float) -> void:
	if pending.points.is_empty():
		return
	for i in _closest_audible_points(pending.points, ear, SPATIAL_VOICE_DISTANCE, VOICES_PER_POOL):
		_play(pending.groups[i], pending.points[i], gain)
	pending.clear()

func _zombie_listener_position() -> Vector3:
	return zombie_listener.global_position if is_instance_valid(zombie_listener) else Vector3.INF

static func _closest_audible_points(points: PackedVector3Array, ear: Vector3, radius: float, limit: int) -> Array[int]:
	# Physics catch-up can move the listener between requests. Rank every
	# cue against the same ear position, keeping event order on a tie.
	var closest: Array[int] = []
	if limit <= 0 or not ear.is_finite():
		return closest
	var radius_squared := radius * radius
	var distances: Array[float] = []
	for i in points.size():
		var distance := points[i].distance_squared_to(ear)
		if distance > radius_squared:
			continue
		var rank := distances.size()
		while rank > 0 and distance < distances[rank - 1]:
			rank -= 1
		if rank < limit:
			distances.insert(rank, distance)
			closest.insert(rank, i)
			if closest.size() > limit:
				distances.pop_back()
				closest.pop_back()
	return closest

func queue_zombie_idle(point: Vector3) -> void:
	if not enabled or _zombie_idle_voice == null or _zombie_idle_voice.playing or not is_instance_valid(zombie_listener):
		return
	_zombie_idle_points.append(point)

func flush_zombie_idle() -> void:
	if _zombie_idle_points.is_empty():
		return
	var nearest := _closest_audible_points(_zombie_idle_points, _zombie_listener_position(), ZOMBIE_IDLE_DISTANCE, 1)
	if nearest.is_empty() or _zombie_idle_voice.playing:
		_zombie_idle_points.clear()
		return
	var voice := _zombie_idle_voice
	voice.stream = _next_stream(&"zombie_idle")
	voice.global_position = _zombie_idle_points[nearest[0]]
	var cents := _zombie_idle_pitch.randf_range(ZOMBIE_PITCH_MIN_CENTS, ZOMBIE_PITCH_MAX_CENTS)
	voice.pitch_scale = pow(2.0, cents / 1200.0)
	voice.play()
	_zombie_idle_points.clear()

func queue_zombie_step(point: Vector3) -> void:
	if enabled and _groups.has(&"zombie_step") and is_instance_valid(zombie_listener):
		_step_points.append(point)

func flush_zombie_steps() -> void:
	if _step_points.is_empty():
		return
	var available := 0
	for slot in VOICES_PER_POOL:
		available += int(not _voices[STEP_POOL * VOICES_PER_POOL + slot].playing)
	for i in _closest_audible_points(_step_points, _zombie_listener_position(), ZOMBIE_STEP_DISTANCE, available):
		_play(&"zombie_step", _step_points[i], ZOMBIE_STEP_GAIN_DB)
	_step_points.clear()

func clear_weapon_cues() -> void:
	_last_weapon_serial = -1
	_next_voice[WEAPON_POOL] = 0
	_weapon_onsets.fill(false)
	for slot in mini(VOICES_PER_POOL, _voices.size()):
		var voice := _voices[slot]
		voice.stop()
		voice.stream = null
		if slot < _started_frames.size():
			_started_frames[slot] = -1
			_voice_groups[slot] = &""

func reset() -> void:
	_flight_targets.clear()
	set_physics_process(false)
	_attack_contacts.clear()
	_attack_windups.clear()
	_attack_swings.clear()
	_reaction_deaths.clear()
	_reaction_hurts.clear()
	_zombie_idle_points.clear()
	if _zombie_idle_voice != null:
		_zombie_idle_voice.stop()
		_zombie_idle_voice.stream = null
	_step_points.clear()
	_started_frames.fill(-1)
	_voice_groups.fill(&"")
	_weapon_onsets.fill(false)
	_player_hurt_frame = -1
	_last_weapon_serial = -1
	_next_voice.fill(0)
	_next_surface_landing_voice = 0
	for voice in _voices + _surface_landing_voices:
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

func queue_base_samples() -> void:
	if OS.has_feature("editor"):
		_queue_base_samples()

func prepare_queued_samples() -> void:
	if _base_sample_jobs.is_empty():
		return
	var deadline := Time.get_ticks_usec() + CROWD_SAMPLE_BUDGET_USEC
	for sample in mini(_base_sample_jobs.size(), 2):
		_base_sample_jobs.pop_front().call()
		if Time.get_ticks_usec() >= deadline:
			break

func _queue_base_samples() -> void:
	if _base_samples_queued:
		return
	_base_samples_queued = true
	var root := _research_root()
	_queue_series(root, &"hit", SABRE, HIT_HASHES)
	_queue_series(root, &"sword_hit", SWORD, SWORD_HIT_HASHES)
	_queue_series(root, &"curved_hit", CURVED, CURVED_HIT_HASHES)
	_queue_series(root, &"hurt", ZOMBIE_VOCAL.replace("%s", "Hurt"), HURT_HASHES)
	_queue_series(root, &"death", ZOMBIE_VOCAL.replace("%s", "Death"), DEATH_HASHES)
	_queue_series(root, &"slam", HEAVY_LANDING, LANDING_HASHES)
	_queue_series(root, &"slam_grass", SURFACE_LANDING.replace("%s", "Grass"), GRASS_LANDING_HASHES)
	_queue_series(root, &"player_hurt", PLAYER_HURT, PLAYER_HURT_HASHES)
	_base_sample_jobs.append(_load_sample.bind(root, &"player_defeat", PLAYER_DEFEAT, PLAYER_DEFEAT_HASH))
	_queue_series(root, &"zombie_windup", ZOMBIE_VOCAL.replace("%s", "PreAttack"), ZOMBIE_WINDUP_HASHES)
	_queue_series(root, &"zombie_hit", ZOMBIE_VOCAL.replace("%s", "Whoosh"), ZOMBIE_HIT_HASHES)
	_queue_series(root, &"zombie_step", ZOMBIE_STEP, ZOMBIE_STEP_HASHES)
	if is_instance_valid(zombie_listener):
		_queue_series(root, &"zombie_idle", ZOMBIE_IDLE, ZOMBIE_IDLE_HASHES)
		# Retain the existing Baby Zombie contact layer beside its release cue.
		_queue_series(root, &"baby_hit", ZOMBIE_VOCAL.replace("%s", "Attack"), BABY_HIT_HASHES)

func _queue_series(root: String, group: StringName, pattern: String, hashes: Array) -> void:
	for index in hashes.size():
		_base_sample_jobs.append(_load_sample.bind(root, group, pattern % (index + 1), hashes[index]))

func _load_audio() -> void:
	if not OS.has_feature("editor"):
		return
	_started_frames.resize(_next_voice.size() * VOICES_PER_POOL)
	_started_frames.fill(-1)
	_voice_groups.resize(_started_frames.size())
	_weapon_onsets.resize(VOICES_PER_POOL)
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
	_queue_base_samples()
	while not _base_sample_jobs.is_empty():
		_base_sample_jobs.pop_front().call()
	if is_instance_valid(zombie_listener):
		for baby_group: StringName in SHARED_BABY_VOCALS:
			var source_group: StringName = SHARED_BABY_VOCALS[baby_group]
			if _groups.has(source_group):
				_groups[baby_group] = _groups[source_group]
	if _groups.has(&"slam_grass"):
		for i in SURFACE_LANDING_VOICE_COUNT:
			var voice := _new_spatial_voice(SPATIAL_VOICE_DISTANCE)
			voice.name = "HeavyLandingSurface%d" % (i + 1)
			_surface_landing_voices.append(voice)
	if is_instance_valid(zombie_listener) and _groups.has(&"zombie_idle"):
		_zombie_idle_voice = _new_spatial_voice(ZOMBIE_IDLE_DISTANCE)
		_zombie_idle_voice.name = "ZombieIdle"
		_zombie_idle_voice.volume_db = ZOMBIE_IDLE_GAIN_DB
		_zombie_idle_voice.max_db = ZOMBIE_IDLE_GAIN_DB

func _create_voices(count: int) -> void:
	for i in count:
		_voices.append(_new_spatial_voice(SPATIAL_VOICE_DISTANCE))

func _new_spatial_voice(max_distance: float) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.unit_size = 4.5
	voice.max_distance = max_distance
	# Preserve the source transient spectrum with distance and panning.
	voice.attenuation_filter_db = 0.0
	voice.attenuation_filter_cutoff_hz = 20500.0
	add_child(voice)
	return voice

func _load_surface_landing(root: String, surface: String, group: StringName, hashes: Array) -> void:
	for i in hashes.size():
		_load_sample(root, group, SURFACE_LANDING % [surface, i + 1], hashes[i])

func _load_sample(root: String, group: StringName, relative: String, checksum: String) -> void:
	var path := SourceFilePath.resolve_private_file(root, SOURCE.path_join(relative))
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data := file.get_buffer(file.get_length())
	var digest := HashingContext.new()
	if (digest.start(HashingContext.HASH_SHA256) != OK or digest.update(data) != OK
			or digest.finish().hex_encode() != checksum):
		return
	# Decode the exact bytes that passed verification.
	var stream := AudioStreamOggVorbis.load_from_buffer(data)
	if stream != null:
		stream.loop = false
		if not _groups.has(group):
			_groups[group] = []
		_groups[group].append(stream)

func _next_stream(group: StringName, advance := true) -> AudioStream:
	var choices: Array = _groups.get(group, [])
	if choices.is_empty():
		return null
	var choice: int = _next_choice.get(group, 0)
	if advance:
		_next_choice[group] = (choice + 1) % choices.size()
	return choices[choice]

func _play(group: StringName, point: Vector3, gain: float, event_frame := -1,
		weapon_onset := false, preview := false) -> AudioStreamPlayer3D:
	if not _groups.has(group):
		return null
	# Separate enemy attack and reaction budgets keep the weapon tails audible.
	var pool := WEAPON_POOL
	match group:
		&"hurt", &"death", &"baby_hurt", &"baby_death":
			pool = REACTION_POOL
		&"zombie_windup", &"zombie_hit", &"baby_windup", &"baby_hit", &"baby_swing":
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
	weapon_onset = weapon_onset or (not preview and (group == &"crossbow_fire" or group == &"bow_fire"))
	if slot == -1:
		match pool:
			REACTION_POOL:
				slot = _replace_priority_slot(first, start, &"death", group, frame, point, &"baby_death")
			ATTACK_POOL:
				slot = _replace_attack_slot(first, start, group, frame, point)
			WEAPON_POOL:
				slot = _replace_weapon_slot(start, weapon_onset, frame)
		if slot == -1:
			return null
	var stream := _next_stream(group, not preview)
	var voice_index := first + slot
	var voice := _voices[voice_index]
	_next_voice[pool] = (slot + 1) % VOICES_PER_POOL
	if voice_index < _started_frames.size():
		_started_frames[voice_index] = frame
		_voice_groups[voice_index] = group
	if pool == WEAPON_POOL and not _weapon_onsets.is_empty():
		_weapon_onsets[slot] = weapon_onset
	var pitch := 1.0
	if group in PITCHED_ZOMBIE_VOCALS:
		var cents := _zombie_vocal_pitch.randf_range(ZOMBIE_PITCH_MIN_CENTS, ZOMBIE_PITCH_MAX_CENTS)
		pitch = pow(2.0, cents / 1200.0)
	_start_spatial_voice(voice, stream, point, gain, pitch)
	return voice

func _start_spatial_voice(voice: AudioStreamPlayer3D, stream: AudioStream, point: Vector3,
		gain: float, pitch := 1.0) -> void:
	voice.stop()
	voice.stream = stream
	voice.global_position = point
	voice.volume_db = gain
	voice.max_db = gain
	voice.pitch_scale = pitch
	voice.play()

func _replace_weapon_slot(start: int, onset: bool, frame: int) -> int:
	if _weapon_onsets.is_empty():
		return start # Surface-only audio uses round-robin.
	var older_slot := -1
	for offset in VOICES_PER_POOL:
		var slot := (start + offset) % VOICES_PER_POOL
		var playing_onset := _weapon_onsets[slot]
		if onset and not playing_onset:
			return slot
		if older_slot >= 0 or onset != playing_onset or _started_frames[slot] >= frame:
			continue
		# Physics may advance several ticks before the mixer starts a queued voice.
		if onset and _voices[slot].get_playback_position() < WEAPON_ONSET_SECONDS:
			continue
		older_slot = slot
	return older_slot

func _replace_attack_slot(first: int, start: int, group: StringName, frame: int, point: Vector3) -> int:
	# A swing fills spare voices. Telegraphs and confirmed hits take precedence.
	if group == &"baby_swing":
		return -1
	for offset in VOICES_PER_POOL:
		var slot := (start + offset) % VOICES_PER_POOL
		if _voice_groups[first + slot] == &"baby_swing":
			return slot
	return _replace_priority_slot(first, start, &"zombie_hit", group, frame, point, &"baby_hit")

func _replace_priority_slot(first: int, start: int, priority_group: StringName, group: StringName,
		frame: int, point: Vector3, secondary_priority := &"") -> int:
	# Each render flush submits the nearest cues first. Protect a nearby
	# voice from later frames while the mixer starts its sample.
	# Playback cues can share decoded waveforms and still have different priorities.
	var priority := group == priority_group or group == secondary_priority
	var compare_onsets := is_instance_valid(zombie_listener)
	var listener := zombie_listener.global_position if compare_onsets else Vector3.ZERO
	var onset_ticks := ceili(ZOMBIE_ONSET_SECONDS * Engine.physics_ticks_per_second)
	var farthest := point.distance_squared_to(listener)
	var farther_onset := -1
	var older_slot := -1
	for offset in VOICES_PER_POOL:
		var slot := (start + offset) % VOICES_PER_POOL
		var voice_index := first + slot
		var voice := _voices[voice_index]
		var playing_group := _voice_groups[voice_index]
		var playing_priority := playing_group == priority_group or playing_group == secondary_priority
		if priority and not playing_priority:
			return slot
		var age := frame - _started_frames[voice_index]
		if priority != playing_priority or age <= 0:
			continue
		# Physics can catch up several ticks while the audio mixer is still
		# at the start of a voice. Check the stream's playhead as well.
		if compare_onsets and (age <= onset_ticks
				or voice.get_playback_position() < ZOMBIE_ONSET_SECONDS * voice.pitch_scale):
			var distance := voice.global_position.distance_squared_to(listener)
			if distance > farthest:
				farthest = distance
				farther_onset = slot
		elif older_slot == -1:
			older_slot = slot
	return older_slot if older_slot >= 0 else farther_onset
