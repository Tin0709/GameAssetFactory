extends RefCounted
## MD2 Meat Cleaver, Pickaxe and Shovel for MechanicLab.

enum Tool { CLEAVER, PICKAXE, SHOVEL }

const Source := preload("res://scripts/mechanic_lab_weapon_source.gd")
const SourceGait := preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/source_gait.gd")
const HEAVY := Source.ANIMATIONS + "Weapons_Melee/1H_Heavy/Combat/"
const MEDIUM := Source.ANIMATIONS + "Weapons_Melee/1H_Medium/Combat/"
const SPEEDY := Source.ANIMATIONS + "Weapons_Melee/1H_Speedy/Combat/"
const SPECIAL := Source.ANIMATIONS + "Weapons_Melee/Special/"
const SHOVEL_COMBAT := SPECIAL + "Combat/"
const LOCOMOTION_LIBRARY := &"private_shovel_locomotion"

const NAMES := ["Cleaver", "Pickaxe", "Shovel"]
const MESH_HASHES := [
	"ba6b162413123870b1b3312c4556d7e255e26f7ad93c685ae372c49842e88443",
	"5ba4315be354b8a29a9491c2bdc5f9c0e8e4301ee24e244f8b5a398e29c206e7",
	"e8ab77c67aa8f7f5df9e7bc9406916d95d8d7a36056e49164a561ed4e969f621",
]
const TEXTURE_HASHES := [
	"dc98f8ec5e5196fa4ecd15188c8f9f517f65fc2d1995f9a93b4860ad4be533b6",
	"244f2def2add25e65807827c88fde8207ec08052bae7476db036cf8634d0d094",
	"c2648b4753113f1d6629e23dc21ecfa13b63e6952aa75ac071243f8cd7ed03f6",
]
const ICON_HASHES := [
	"b33d18469f72d9762253f3558c32c76ac5ef38ad53d1cab7740e0b5dfe7af8fb",
	"8c6fc4108dd4decabb2719d0537d34cda086e4a7151418eb3bd036104ea0577d",
	"c234df5f78a8b8347bfb9703d7842207842be721a6ff492d90de2e6a55f2a502",
]

const SWORD_ATTACK_1 := [MEDIUM, "Player_SwordCombo_Attack1", 13,
	"a316bab9b26310adb4985ec2b07718aa8e76630420a78a19dc21bbd45da9111e"]
const SWORD_RECOVERY_1 := [MEDIUM, "Player_SwordCombo_Attack1Recovery", 11,
	"1ed634d15d6de48664d04cd5ecc6bd3dcee50bbda74354327f4239977d60fa87"]
const SWORD_ATTACK_2 := [MEDIUM, "Player_SwordCombo_Attack2", 12,
	"1965f796a758f59ccaca2a527aaa81cee70c55f4a3c810eb712b3022b8bced7c"]
const SWORD_RECOVERY_2 := [MEDIUM, "Player_SwordCombo_Attack2Recovery", 10,
	"e3f648faf99577412fb23aa8804443c420ee4cad67727104a73433ab22c01c47"]
const ATTACKS := [
	[
		[HEAVY, "Player_AxeCombo_Attack1", 14, "f579befb029ed60443c77d727048db8b9162548190228ccd920f43a7cb705133"],
		SWORD_ATTACK_2,
		[SPEEDY, "Player_CleaverCombo_Attack3", 25, "83811a24e23f6cf7b2dd70eff1c321ca18494e87aee34dac19ca3a61b0755b57"],
	],
	[
		SWORD_ATTACK_1,
		SWORD_ATTACK_2,
		[HEAVY, "Player_PickAxeCombo_Attack3", 26, "562a17bf33fd4f79ec7016be8f48c820d6973cedeef62180af74cfb2f9aa9ba0"],
	],
	[
		[SHOVEL_COMBAT, "Player_Shovel_Attack1", 23, "659aa2714c0d4d83d188d656c4d72f838ab2f9fee42eb92722dd6c4903a4f1db"],
		[SHOVEL_COMBAT, "Player_Shovel_Attack2", 57, "6fab07b118855acd2687a80c958501f2be61d5eb2562788f5621a09ce5126908"],
		[SHOVEL_COMBAT, "Player_Shovel_Attack3", 20, "2a6d12c92dfac0236fcea2ddf0970a02d4f6beb733b2c3671875ef65404d52eb"],
	],
]
const RECOVERIES := [
	[
		SWORD_RECOVERY_1,
		SWORD_RECOVERY_2,
		[SPEEDY, "Player_CleaverCombo_Attack3Recovery", 8, "2a256e26958f11bbe61b94c459018bb5f7697948b213744d0b5bb4458d2758b1"],
	],
	[
		SWORD_RECOVERY_1,
		SWORD_RECOVERY_2,
		[HEAVY, "Player_PickAxeCombo_Attack3Recovery", 11, "9dedbe59e9d1c2efa4a7a8abf5ccb83200b78dd83d93bd40b091892e1ac3efa8"],
	],
	[
		[SHOVEL_COMBAT, "Player_Shovel_Attack1Recovery", 12, "20eb4dcb312170bbe1831b407cba33f640cb777a0a308b463d1ee58b5bfcbdac"],
		[SHOVEL_COMBAT, "Player_Shovel_Attack2Recovery", 18, "d665bebabc381cc2f510354f71451d91a25ecb875dd9080526c5a5da559f6462"],
		[SHOVEL_COMBAT, "Player_Shovel_Attack3Recovery", 15, "61f7d15466380cc5d069fb65864cb945a49445b73515a4757a2ae72ca3f3089d"],
	],
]
const AIR_CLIPS := [
	[MEDIUM, "Player_1H_Medium_JumpAttack", 26, "7f3e6e95fc8e5a2bcedbef3a1980b34c334eb1ff8f4ad0f65c608abd48b22fbb"],
	[HEAVY, "Player_1H_Heavy_JumpAttack_v2", 44, "e580452a52db4337aadafd2a14c3fce7b5ff016fb9fb5692b77ab526e419f86b"],
	[SHOVEL_COMBAT, "Player_Shovel_JumpAttack", 54, "d6578ab9cac7b9761ef388e744e497a34b2dd3f9896c702d13dcc0f38124834b"],
]

# AN_MeleeAttack, AN_ResumeMovement, AN_RecoveryStart and montage segment
# end, mapped to the source clip clock. DT_MeleePropertyDefinition rates
# multiply the montage segment rate (1.1 for all three Cleaver attacks).
const WINDOWS := [
	[Vector4(0.101934, 0.108253, 0.381204, 0.833333), Vector4(0.136538, 0.149695, 0.394166, 0.716533),
		Vector4(0.261867, 0.269902, 1.099997, 1.100000)],
	[Vector4(0.112690, 0.166032, 0.437465, 0.781817), Vector4(0.163472, 0.213492, 0.423431, 0.716533),
		Vector4(0.224718, 0.418574, 0.829549, 1.333333)],
	[Vector4(0.118083, 0.597601, 0.699838, 1.166650), Vector4(0.383572, 1.780749, 1.858310, 2.500000),
		Vector4(0.203482, 0.669863, 0.898273, 1.066667)],
]
const RATES := [Vector3(1.43, 1.43, 1.43), Vector3(0.9, 0.9, 1.0), Vector3(1.4, 1.4, 1.2)]
const AIR_LOOP := [0.139664, 0.033285, 0.428704]
const AIR_RATES := [1.2, 1.0, 1.0]
const AIR_LANDING := [0.214319, 0.607441, 0.431681]
const AIR_CONTACT := [0.279693, 0.628606, 0.444457]
const AIR_END := [0.866667, 1.302315, 1.290120]
const STRIKES := [
	[
		{"damage": 13, "stagger": 15.0, "range_m": 2.5, "cone_degrees": 100.0, "cone_cutoff": 1.2, "cone_offset": -1.2, "strength": 500.0, "angle": 15.0},
		{"damage": 13, "stagger": 15.0, "range_m": 2.5, "cone_degrees": 100.0, "cone_cutoff": 1.2, "cone_offset": -1.2, "strength": 500.0, "angle": 15.0},
		{"damage": 18, "stagger": 30.0, "range_m": 3.5, "cone_degrees": 180.0, "cone_cutoff": 0.0, "cone_offset": 0.0, "strength": 700.0, "angle": 25.0, "radial": true},
	],
	[
		{"damage": 16, "stagger": 30.0, "range_m": 2.75, "cone_degrees": 80.0, "cone_cutoff": 1.2, "cone_offset": -1.2, "strength": 500.0, "angle": 15.0},
		{"damage": 16, "stagger": 30.0, "range_m": 2.75, "cone_degrees": 80.0, "cone_cutoff": 1.2, "cone_offset": -1.2, "strength": 500.0, "angle": 15.0},
		{"damage": 24, "stagger": 60.0, "range_m": 3.0, "cone_degrees": 180.0, "cone_cutoff": 0.0, "cone_offset": 1.6, "strength": 800.0, "angle": 25.0, "radial": true},
	],
	[
		{"damage": 15, "stagger": 30.0, "range_m": 2.5, "cone_degrees": 180.0, "cone_cutoff": 0.0, "cone_offset": 0.0, "strength": 400.0, "angle": 25.0},
		{"damage": 15, "stagger": 30.0, "range_m": 2.5, "cone_degrees": 180.0, "cone_cutoff": 0.0, "cone_offset": 0.0, "strength": 750.0, "angle": 35.0},
		{"damage": 60, "stagger": 80.0, "range_m": 4.0, "cone_degrees": 60.0, "cone_cutoff": 4.0, "cone_offset": -4.0, "strength": 850.0, "angle": 55.0, "radial": true, "splash_stagger": 1.0},
	],
]
const AIR_STRIKES := [
	{"damage": 20, "stagger": 37.0, "primary_range": 1.25, "range_m": 2.5, "strength": 1150.0, "angle": 25.0, "radial": true},
	{"damage": 28, "stagger": 45.0, "primary_range": 1.5, "range_m": 2.5, "strength": 1250.0, "angle": 25.0, "radial": true},
	{"damage": 30, "stagger": 75.0, "primary_range": 1.85, "range_m": 2.5, "strength": 850.0, "angle": 25.0, "radial": false, "splash_stagger": 0.5},
]
const AIR_OFFSETS := [0.0, 1.5, 0.25]
const BLADE_BASES := [Vector3(0, -0.31, 0), Vector3(0, -0.49, 0), Vector3(0, -0.44, 0)]
const BLADE_TIPS := [Vector3(0, -0.928, -0.133), Vector3(0, -0.821, 0), Vector3(0, -0.750, 0)]

const LOCOMOTION := {
	"Idle": [SPECIAL, "Player_Shovel_Idle", 80, "ade1ae2d2411370497cd2f346c21b2132608560ddfb8a77b1bf02dae765f6273"],
	"Walk": [SPECIAL, "Player_Shovel_Walk", 26, "621814ca1d90f533d527a618b80fe841e457c9604a313bab768e080f01dd9d1f"],
	"Run": [SPECIAL, "PLayer_Shovel_Run", 13, "65a1eed274fef0d623e0b1ab07fab4f8e982fe4373784269a6a3a368d0601e4e"],
	"JumpTakeoff": [SPECIAL, "Player_Shovel_Jump", 9, "4a8e91a0aacd2b67eb579cbcdf2ffe942bb1dfaea128a7cc2bdc7a4602fe02a7"],
	"JumpAirborne": [SPECIAL, "Player_Shovel_Jump_Loop", 27, "37acf319c54a2d2bcc9612af837de60503a08186b7e0131083af7014004d3ace"],
	"JumpLanding": [SPECIAL, "Player_Shovel_Jump_Land", 13, "a2476f491b90bb443691d04634e70d564e707ecd8bbd0b5f57395488c8d63a54"],
	"InspectWeapon": [Source.ANIMATIONS + "Novelties/", "Player_Idle_Novelty_ExamineWeapon_Shovel", 80, "ca0be00d051fdff33646b8d931d2f5f2dff9d9fa30247927b6077a2f3da60319"],
}

static func library(tool: int) -> StringName:
	return StringName("private_tool_" + NAMES[tool].to_lower())

static func icon(tool: int) -> Texture2D:
	var name: String = NAMES[tool]
	return Source.icon(Source.EQUIPMENT + name + "/", "T_UI_" + name + "_Icon", ICON_HASHES[tool])

static func load_mesh(actor: CharacterBody3D, root: String, tool: int) -> Mesh:
	var name: String = NAMES[tool]
	return Source.load_mesh(actor, root, Source.EQUIPMENT + name + "/", "SM_" + name, MESH_HASHES[tool],
		"T_" + name, TEXTURE_HASHES[tool])

static func mount_transform(_tool: int) -> Transform3D:
	# The equipped BP mesh is at the right weapon socket origin.
	return Transform3D.IDENTITY

static func blade_base(tool: int) -> Vector3:
	return BLADE_BASES[tool]

static func blade_tip(tool: int) -> Vector3:
	return BLADE_TIPS[tool]

static func strikes(tool: int) -> Array:
	return STRIKES[tool]

static func air_strike(tool: int) -> Dictionary:
	return AIR_STRIKES[tool]

static func air_offset(tool: int) -> float:
	return AIR_OFFSETS[tool]

static func air_clip(tool: int) -> String:
	return "Native" + NAMES[tool] + "Air"

static func air_hold_time(tool: int) -> float:
	return AIR_LANDING[tool]

static func air_loop_time(tool: int) -> float:
	return AIR_LOOP[tool]

static func air_landing_time(tool: int) -> float:
	return AIR_LANDING[tool]

static func air_rate(tool: int) -> float:
	return AIR_RATES[tool]

static func air_contact_delay(tool: int) -> float:
	return (AIR_CONTACT[tool] - AIR_LANDING[tool]) / AIR_RATES[tool]

static func combat_profile(root: String, tool: int) -> Dictionary:
	var result := Source.profile()
	result.blend_seconds = 0.05
	result.input.airborne_press_interrupts_ground = true
	var prefix: String = "Native" + NAMES[tool]
	for i in 3:
		var attack := _clip(root, ATTACKS[tool][i], prefix + "Attack%d" % (i + 1), "attack")
		var recovery := _clip(root, RECOVERIES[tool][i], prefix + "Recovery%d" % (i + 1), "recovery")
		var timings: Vector4 = WINDOWS[tool][i]
		var window := Source.window(attack, recovery, RATES[tool][i], timings.x, timings.y, timings.z)
		var trail_start := maxf(timings.x - 0.03, 0.0)
		window.trail_window = [trail_start, minf(timings.x + 0.12, timings.w)]
		# Keep the native movement and input gates, including those in the
		# recovery sequence. The Lab's two states split the source composite
		# after the queued chain gate, with one final frame on terminal links.
		window.attack_duration = minf(timings.w, maxf(attack.duration, timings.z + 1.0 / 30.0))
		window.recovery_duration = maxf(0.001, timings.w - float(window.attack_duration))
		result.additional_clips.append_array([attack, recovery])
		result.windows.append(window)
	var air := _clip(root, AIR_CLIPS[tool], air_clip(tool), "attack")
	air.vfx_window = [AIR_CONTACT[tool], minf(AIR_CONTACT[tool] + 0.12, AIR_END[tool])]
	result.additional_clips.append(air)
	return result

static func load_combat_clips(actor: CharacterBody3D, profile: Dictionary, tool: int) -> bool:
	var name := library(tool)
	if actor.animation_player.has_animation_library(name):
		return true
	actor._load_private_combat_clips(profile, name)
	if not actor.animation_player.has_animation_library(name):
		return false
	for index in profile.windows.size():
		var window: Dictionary = profile.windows[index]
		var attack := _animation(actor, window.attack_key)
		var recovery := _animation(actor, window.recovery_key)
		# The Pickaxe montage shares Sword Attack1. Its composite starts
		# recovery at frame 14 even though the GLB export ends at frame 13.
		var boundary := 14.0 / 30.0 if tool == Tool.PICKAXE and index == 0 else attack.length
		var prefix := maxf(float(window.attack_duration) - boundary, 0.0)
		if prefix > 0.0:
			_append_recovery(attack, recovery, boundary, prefix)
		attack.length = window.attack_duration
		_trim_recovery(recovery, prefix, window.recovery_duration)
	var air := _animation(actor, air_clip(tool))
	air.length = AIR_END[tool]
	var air_entry: Dictionary = actor.clips[air_clip(tool)]
	air_entry.duration = air.length
	return true

static func _clip(root: String, data: Array, key: String, category: String, loop := false) -> Dictionary:
	return Source.clip(root, data[0], data[1], key, data[2], data[3], category, loop)

static func _animation(actor: CharacterBody3D, key: String) -> Animation:
	return actor.animation_player.get_animation(actor.clips[key].action)

static func _append_recovery(attack: Animation, recovery: Animation, boundary: float, duration: float) -> void:
	attack.length = boundary + duration
	for i in attack.get_track_count():
		var track := recovery.find_track(attack.track_get_path(i), attack.track_get_type(i))
		if track < 0:
			continue
		for key in recovery.track_get_key_count(track):
			var time := recovery.track_get_key_time(track, key)
			if time >= duration:
				break
			attack.track_insert_key(i, boundary + time, recovery.track_get_key_value(track, key))
		attack.track_insert_key(i, boundary + duration, _sample_key(recovery, track, minf(duration, recovery.length)))

static func _trim_recovery(recovery: Animation, start: float, duration: float) -> void:
	for track in recovery.get_track_count():
		var first: Variant = _sample_key(recovery, track, minf(start, recovery.length))
		var last: Variant = _sample_key(recovery, track, minf(start + duration, recovery.length))
		for key in range(recovery.track_get_key_count(track) - 1, -1, -1):
			var time := recovery.track_get_key_time(track, key)
			if time <= start or time > start + duration:
				recovery.track_remove_key(track, key)
		for key in recovery.track_get_key_count(track):
			var time := recovery.track_get_key_time(track, key)
			recovery.track_set_key_time(track, key, time - start)
		recovery.track_insert_key(track, 0.0, first)
		recovery.track_insert_key(track, duration, last)
	recovery.length = duration

static func _sample_key(animation: Animation, track: int, time: float) -> Variant:
	match animation.track_get_type(track):
		Animation.TYPE_POSITION_3D:
			return animation.position_track_interpolate(track, time)
		Animation.TYPE_ROTATION_3D:
			return animation.rotation_track_interpolate(track, time)
		Animation.TYPE_SCALE_3D:
			return animation.scale_track_interpolate(track, time)
	return animation.track_get_key_value(track, maxi(0, animation.track_find_key(track, time, Animation.FIND_MODE_NEAREST)))

static func load_locomotion(actor: CharacterBody3D, root: String, tool: int) -> Dictionary:
	if tool != Tool.SHOVEL:
		return {}
	var entries: Array[Dictionary] = []
	for slot: String in LOCOMOTION:
		var category := "jump" if slot.begins_with("Jump") else "locomotion"
		if slot == "Idle":
			category = "idle"
		elif slot == "InspectWeapon":
			category = "inspection"
		entries.append(_clip(root, LOCOMOTION[slot], "NativeShovel" + slot, category,
			slot in ["Idle", "Walk", "Run", "JumpAirborne"]))
	if not actor._load_private_clip_library(entries, LOCOMOTION_LIBRARY):
		return {}
	var slots := {}
	for slot: String in LOCOMOTION:
		slots[slot] = actor.clips["NativeShovel" + slot]
	slots.CombatReady = slots.Idle
	var samples: Array[Dictionary] = []
	var keys := ["Idle", "Walk", "Run"]
	var inputs := [0.0, 0.3, 1.2]
	for i in keys.size():
		var entry: Dictionary = slots[keys[i]]
		samples.append({"semantic": keys[i], "source_name": entry.source_name,
			"input": inputs[i], "duration": entry.duration, "rate": 1.0})
	var gait := SourceGait.new()
	if not gait.setup(actor.skeleton, actor.animation_player, slots, {
		"schema": "md2-private-source-gait/1", "base_speed_cm_s": 700.0, "input_floor": 0.2, "samples": samples,
	}):
		return {}
	return {"clips": slots, "gait": gait}
