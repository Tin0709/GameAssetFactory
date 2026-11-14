extends "res://scripts/mechanic_lab_cross_pollinator.gd"
## Standard Bow (MD2 SW.Item.Bow and SW.Projectile.Type.PlayerBow).

signal arrow_impact(hit: Dictionary, direction: Vector3, serial: int, strike: Dictionary)

const BOW_DIRECTORY := Source.EQUIPMENT + "Bow/"
const BOW_CLIPS := Source.ANIMATIONS + "Weapons_Ranged/Bow/"
const BOW_LIBRARY := &"private_standard_bow"
const ACTION := "NativeBowAction"
const RELEASE := "NativeBowRelease"
const AMMO_LIMIT := 15
const ATTACK_PERIOD_SECONDS := 0.4
const CHARGE_TIME := 0.35
const DRAW_START := 19.0 / 30.0
const DRAW_HOLD := 35.0 / 30.0
const RELEASE_START := 40.0 / 30.0
const RELEASE_END := 49.0 / 30.0
const ARROW_OFFSET := Vector3(0.05, 0.25, 0.25)
# The visible source helper has this same grip in all four mesh states.
# Hidden helpers translate away and collapse. Keep their visibility swap
# separate from transform blending when entering or leaving the action.
const ACTION_GRIP := Transform3D(Basis(Vector3(0.988020, 0.0, -0.154326), Vector3.UP,
	Vector3(0.154326, 0.0, 0.988020)), Vector3(-0.063292, 0.0, 0.0))
const BOW_TEXTURE_HASH := "de26aae28cad9cadbbe66690e9dd64e0f214cbc855ef6181136c200785e3774f"
const BOW_ACTION_HASH := "0a1c257e8f65b37137d3a9883bb6bc92dfd127d97944f3961e6fdc0f375d9775"
const MESH_HASHES := [
	"94c3a91ed8c1612801bd67eed7b3004b171b6aec37218bd563a38dde544e3032",
	"ccadf0abfd8dfe5e909c04d61a46ad5b7cc75af6031923943ca60e70f64d601c",
	"a2f0ad9e71e9e51e890322fd138164e38399e67c8ba6573fb4536782d2849f98",
	"7f1ebbd85281a36e6baa1a6725f40cd38bc0466369ea5e9aca4b4bc12581a5fc",
]
const BOW_AUDIO := "Items/Weapons/Weapon_Ranged/Bow/sfx_item_bow_"
const FIRE_HASHES := [
	"87d65b42844e98537291112f60ffe8794ca4518a0f391a88b9af4d318886ae83",
	"ec0add126304f2ac31e72f6cc2734d0a8914b792c98f209c2fb0d23d58f67017",
	"08194b49d8f9787292fdd1d5b1d3f54131d24baea81d3386bc09cbd1464dad47",
]
const DRAW_HASHES := [
	"466d1ce590f2a99a67032504ad57c951b6c453237ff3839590d05d2a586fe176",
	"027c8abc258adce6ac341a6012902610effd7ab33b1039c3d654e3558bf141cb",
	"695f40788b872b48666c37bbb2c657bcc2b003174abb4ed1cf99f27e9971301a",
	"769745bc1c4087777b2e44b34544dd0120dcc5305d5798ea108d59619897fdfe",
]
const UNEQUIP_HASH := "239661f95e473b6fabf68a4eda7a0e2848560d22eb915c7f32d970a98ed6dcfc"
const NORMAL_STRIKE := {"damage": 18, "strength": 500.0, "angle": 25.0, "stagger": 22.5}
const CHARGED_STRIKE := {"damage": 54, "strength": 500.0, "angle": 25.0, "stagger": 22.5}

var _combat_audio: Node

static func icon() -> Texture2D:
	return Source.icon(BOW_DIRECTORY, "T_UI_Bow_Icon",
		"882cb02d019ce04fda985984a8d52575fa7bcce79070f40cd3f26b4859c19eb3")

static func load_bow_meshes(actor: CharacterBody3D, root: String) -> Array[Mesh]:
	var meshes: Array[Mesh] = []
	for frame in MESH_HASHES.size():
		var mesh := Source.load_mesh(actor, root, BOW_DIRECTORY, "SM_Bow_F%d" % frame,
			MESH_HASHES[frame], "T_Bow", BOW_TEXTURE_HASH)
		if mesh == null:
			return []
		meshes.append(mesh)
	return meshes

static func combat_profile(root: String) -> Dictionary:
	var result := Source.profile()
	var action := Source.clip(root, BOW_CLIPS, "Player_Bow_Action", ACTION, 49, BOW_ACTION_HASH, "attack")
	var recovery := Source.clip(root, BOW_CLIPS, "Player_Bow_Action", RELEASE, 49, BOW_ACTION_HASH, "recovery")
	result.additional_clips.assign([action, recovery])
	var shot := Source.window(action, recovery, 1.0, 1.0 / 120.0, 1.0 / 60.0, ATTACK_PERIOD_SECONDS)
	shot.attack_duration = ATTACK_PERIOD_SECONDS
	shot.recovery_duration = RELEASE_END - RELEASE_START
	# The actor owns hold/release and samples the authored action on its own clock.
	result.windows.assign([shot, shot, shot])
	return result

static func load_action(actor: CharacterBody3D, root: String) -> bool:
	if not actor.animation_player.has_animation_library(BOW_LIBRARY):
		actor._load_private_combat_clips(combat_profile(root), BOW_LIBRARY)
	return actor.animation_player.has_animation_library(BOW_LIBRARY)

static func mesh_state(action_time: float) -> int:
	# Scale helpers in Player_Bow_Action switch the four authored mesh frames.
	var frame := floori(action_time * 30.0 + 0.0001)
	if (frame >= 33 and frame < 41) or frame == 0:
		return 3
	if frame >= 29 and frame < 33:
		return 2
	if (frame >= 25 and frame < 29) or frame == 1 or frame == 41:
		return 1
	return 0

func _ammo_capacity() -> int:
	return AMMO_LIMIT

func _ammo_recharge_period() -> float:
	return 1.2

func fire_arrow(origin: Vector3, direction: Vector3, serial: int, clearance_start: Vector3, charged: bool) -> bool:
	if ammo == 0:
		return false
	_play_audio(&"bow_fire", origin, -9.0)
	return _fire_projectile(origin, direction, serial, clearance_start, 90.0 if charged else 45.0,
		CHARGED_STRIKE if charged else NORMAL_STRIKE)

func _report_impact(hit: Dictionary, direction: Vector3, serial: int, strike: Dictionary) -> void:
	super._report_impact(hit, direction, serial, strike)
	arrow_impact.emit(hit, direction, serial, strike)

func setup_audio(audio: Node, root: String) -> void:
	_combat_audio = audio
	for i in FIRE_HASHES.size():
		audio._load_sample(root, &"bow_fire", BOW_AUDIO + ("fire-%03d.ogg" % (i + 1)), FIRE_HASHES[i])
	for i in DRAW_HASHES.size():
		audio._load_sample(root, &"bow_draw", BOW_AUDIO + ("load-%03d.ogg" % (i + 1)), DRAW_HASHES[i])
	audio._load_sample(root, &"bow_unequip", BOW_AUDIO + "unequip.ogg", UNEQUIP_HASH)

func play_charge(point: Vector3) -> void:
	_play_audio(&"bow_draw", point, -15.0)

func play_switch(equipped: bool, point: Vector3) -> void:
	if not equipped:
		_play_audio(&"bow_unequip", point, -15.0)

func _play_audio(group: StringName, point: Vector3, gain: float) -> void:
	if is_instance_valid(_combat_audio) and _combat_audio.enabled:
		_combat_audio._play(group, point, gain)
