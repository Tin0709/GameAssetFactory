extends Node3D
## The Cross Pollinator (MD2 RapidCrossbow_Unique1).

signal ammo_changed(amount: int)
signal bolt_impact(hit: Dictionary, direction: Vector3, serial: int)
signal shot_fired(origin: Vector3)
signal bolt_launched(bolt: Node3D)
signal bolt_ended(bolt: Node3D)

const Source := preload("res://scripts/mechanic_lab_weapon_source.gd")
const SourceGait := preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/source_gait.gd")
const DIRECTORY := Source.EQUIPMENT + "RapidCrossbow/RapidCrossbow_Unique/"
const CLIPS := Source.ANIMATIONS + "Weapons_Ranged/Crossbow/"
const LIBRARY := &"private_cross_pollinator"
const LOCOMOTION_LIBRARY := &"private_cross_pollinator_locomotion"
const SHOT := "NativeCrossPollinatorShot"
const RECOVERY := "NativeCrossPollinatorRecovery"
const AMMO_MAX := 25
const AIM_RANGE := 7.5
# RapidCrossbow_Unique1 base period, with HairtriggerUnique's +40% attack speed.
const ATTACK_PERIOD := 0.2 / 1.4
# At 18/30 s the source recoil has returned to its raised aim pose.
const RECOIL_END := 18.0 / 30.0
const RECHARGE_DELAY := 1.0
const RECHARGE_PERIOD := 0.8
const BOLT_SPEED := 35.0
const BOLT_LIFETIME := 5.0
const WORLD_MASK := 1
const BOLT_MASK := WORLD_MASK | 4
const STRIKE := {"damage": 8, "strength": 400.0, "angle": 25.0, "stagger": 8.1}
const ACTION_HASH := "09471c7fa549624245482513aefd2e2f8fa35a18152dfb9b23b04baabd4e65d0"
# BP_AlexCharacter: both Polaris meshes have +16 cm on UE Z at their
# respective left-weapon sockets. The GLB coordinate conversion maps it to +Y.
const MESH_OFFSET := Vector3(0.0, 0.16, 0.0)
const MUZZLE := Vector3(0.0, 0.075, 0.65)
# AM_Player_CrossBow_Action blend-out duration. The Lab blends from its
# interrupted recovery pose so the lowering starts promptly after firing.
const IDLE_BLEND_SECONDS := 0.25
const LOCOMOTION := {
	"Idle": ["Player_Crossbow_Idle", 80, "5efd6e1c0d15066ab98c1bd31262b499435e125512a75a972ee87f1a74bd222a"],
	"Walk": ["Player_Crossbow_Walk", 26, "a291db024a4b3d10ec01ecc66b068c364fb8bc22d8a245150cbd69dce1af2e9c"],
	"Run": ["Player_Crossbow_Run", 13, "174a96fe4e65ea7e3d775beb5c51f5bd65e88d7761d46c7940e6b2ef509287f3"],
	"JumpTakeoff": ["Player_Crossbow_Jump", 11, "4a09c04eecc2baea728fc16d94532cf805fd830768189b6629a9b7975594bcee"],
	"JumpAirborne": ["Player_Crossbow_Jump_Loop", 25, "76266b95a62c0290ab3f38b25058e7fdc467d3c4c0b02db48329680d7a5fc2d2"],
	"JumpLanding": ["Player_Crossbow_Jump_Land", 9, "6df8515495b431b0c95e8a1daa84e9494c4cc06ae83a75e5fee894921b57b24d"],
}

var ammo := AMMO_MAX
var bolt_mesh: Mesh
var _recharge_remaining := 0.0
var _bolts: Array[Dictionary] = []

static func icon() -> Texture2D:
	return Source.icon(DIRECTORY, "T_UI_RapidCrossbow_Unique_Icon",
		"0e457446c6ee40d65f7da6cc302602d7b96ac49f5f54bcbb38a7a20fbe77ae18")

static func load_mesh(actor: CharacterBody3D, root: String, recoil: bool) -> Mesh:
	var name := "SM_RapidCrossbow_Unique_F0" if recoil else "SM_RapidCrossbow_Unique_F1"
	var hash_value := "2a6f17f938b81f9c91a072b37dcbf6dabbed15999f7521437706fbe06037a6bc" if recoil \
		else "189bc26ff1e69cbe3175003c4e655d0dd3b659df85c99a14ecbf0124fb10b3af"
	return Source.load_mesh(actor, root, DIRECTORY, name, hash_value, "T_RapidCrossbow_Unique",
		"fcd97771bd152d8f3f1c772984de98eca0c68d0d48b9de0e8ac1a3bc4d64e501")

static func load_bolt(actor: CharacterBody3D, root: String) -> Mesh:
	return Source.load_mesh(actor, root, Source.SOURCE + "Actors/Equipment/RangedWeapons/Projectiles/",
		"SM_Arrow", "b68f888b24264d7db5b1fc1fe48852f33761cccc44e71ba7a65820f148cb33c3",
		"T_Arrow", "f0bf1ee4c8f45d2361fc73d0635bd8ac5ff9a10d0f63e5759959bef5e77bbd5d")

static func combat_profile(root: String) -> Dictionary:
	var result := Source.profile()
	var attack := Source.clip(root, CLIPS, "Player_CrossBow_Action", SHOT, 31, ACTION_HASH, "attack")
	var recovery := Source.clip(root, CLIPS, "Player_CrossBow_Action", RECOVERY, 31, ACTION_HASH, "recovery")
	result.additional_clips.append_array([attack, recovery])
	var shot := Source.window(attack, recovery, 1.0, 1.0 / 120.0, 1.0 / 60.0, ATTACK_PERIOD)
	shot.attack_duration = ATTACK_PERIOD
	shot.recovery_duration = RECOIL_END - ATTACK_PERIOD
	# The source has one shot animation. Combo reuses that slot for every round.
	result.windows = [shot, shot, shot]
	return result

static func load_locomotion(actor: CharacterBody3D, root: String) -> Dictionary:
	var entries: Array[Dictionary] = []
	for slot: String in LOCOMOTION:
		var source: Array = LOCOMOTION[slot]
		var is_jump := slot.begins_with("Jump")
		var category := "jump" if is_jump else ("idle" if slot == "Idle" else "locomotion")
		entries.append(Source.clip(root, CLIPS, source[0], "NativeCrossPollinator" + slot, source[1],
			source[2], category, not is_jump or slot == "JumpAirborne"))
	if not actor._load_private_clip_library(entries, LOCOMOTION_LIBRARY):
		return {}
	var slots := {}
	for slot: String in LOCOMOTION:
		slots[slot] = actor.clips["NativeCrossPollinator" + slot]
	slots.CombatReady = slots.Idle
	slots.InspectWeapon = slots.Idle
	var samples: Array[Dictionary] = []
	var keys := ["Idle", "Walk", "Run"]
	var inputs := [0.0, 0.3, 1.2]
	for i in keys.size():
		var clip: Dictionary = slots[keys[i]]
		samples.append({"semantic": keys[i], "source_name": clip.source_name,
			"input": inputs[i], "duration": clip.duration, "rate": 1.0})
	var gait := SourceGait.new()
	if not gait.setup(actor.skeleton, actor.animation_player, slots, {
		"schema": "md2-private-source-gait/1", "base_speed_cm_s": 700.0, "input_floor": 0.2, "samples": samples,
	}):
		return {}
	return {"clips": slots, "gait": gait}

func _ready() -> void:
	set_physics_process(false)

func fire(origin: Vector3, direction: Vector3, serial: int, clearance_start: Vector3) -> bool:
	if ammo == 0:
		return false
	ammo -= 1
	_recharge_remaining = RECHARGE_DELAY + RECHARGE_PERIOD
	ammo_changed.emit(ammo)
	shot_fired.emit(origin)
	var clearance := PhysicsRayQueryParameters3D.create(clearance_start, origin, WORLD_MASK)
	clearance.hit_from_inside = true
	var obstruction := get_world_3d().direct_space_state.intersect_ray(clearance)
	if not obstruction.is_empty():
		bolt_impact.emit(obstruction, direction, serial)
		set_physics_process(true)
		return true
	var bolt := MeshInstance3D.new()
	bolt.mesh = bolt_mesh
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bolt)
	bolt.global_position = origin
	bolt.look_at(origin + direction, Vector3.UP if absf(direction.y) < 0.999 else Vector3.FORWARD, true)
	bolt.rotate_object_local(Vector3.UP, -PI * 0.5)
	bolt.reset_physics_interpolation()
	_bolts.append({"node": bolt, "direction": direction, "life": BOLT_LIFETIME, "serial": serial})
	set_physics_process(true)
	bolt_launched.emit(bolt)
	return true

func reset() -> void:
	for bolt: Dictionary in _bolts:
		_remove_bolt(bolt.node)
	_bolts.clear()
	_recharge_remaining = 0.0
	ammo = AMMO_MAX
	ammo_changed.emit(ammo)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if ammo < AMMO_MAX:
		_recharge_remaining -= delta
		if _recharge_remaining <= 0.000001:
			_recharge_remaining += RECHARGE_PERIOD
			ammo += 1
			ammo_changed.emit(ammo)
	var space := get_world_3d().direct_space_state
	for index in range(_bolts.size() - 1, -1, -1):
		var bolt := _bolts[index]
		var node: MeshInstance3D = bolt.node
		var start := node.global_position
		var end := start + Vector3(bolt.direction) * BOLT_SPEED * minf(delta, bolt.life)
		var query := PhysicsRayQueryParameters3D.create(start, end, BOLT_MASK)
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		bolt.life -= delta
		if not hit.is_empty() or bolt.life <= 0.000001:
			_bolts.remove_at(index)
			_remove_bolt(node)
			if not hit.is_empty():
				bolt_impact.emit(hit, bolt.direction, bolt.serial)
		else:
			node.global_position = end
	if ammo == AMMO_MAX and _bolts.is_empty():
		set_physics_process(false)

func _remove_bolt(bolt: MeshInstance3D) -> void:
	bolt.hide()
	bolt.queue_free()
	bolt_ended.emit(bolt)
