extends "res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/world_map_actor.gd"
## MechanicLab-only routing for ranged input and the gauntlet jump pose.

const CrossPollinator := preload("res://scripts/mechanic_lab_cross_pollinator.gd")
const Gauntlets := preload("res://scripts/mechanic_lab_gauntlets.gd")

var crossbow_equipped := false
var gauntlets_equipped := false
var _crossbow_pose_serial := -1

func attack(value: bool) -> void:
	if crossbow_equipped:
		if value:
			resume_gameplay()
		# The crossbow uses the same action in the air and on the ground.
		# Using the aerial melee phase would start the heavy-slam gravity path.
		combo.attack(value, false)
		if novelty_jump != null and combo.active():
			novelty_jump.cancel()
		return
	super.attack(value)

func _play(key: String, blend: float = 0.04) -> void:
	if crossbow_equipped and combo.active() and review_clip.is_empty():
		if key == CrossPollinator.SHOT and _crossbow_pose_serial != combo.serial:
			_crossbow_pose_serial = combo.serial
			if active_clip == key:
				animation_player.seek(0.0, true)
		elif key == CrossPollinator.RECOVERY and active_clip != key:
			super._play(key, blend)
			animation_player.seek(CrossPollinator.ATTACK_PERIOD, true)
			return
	super._play(key, blend)

func begin_gauntlet_landing() -> void:
	combo.air_landing_started = true
	combo.time = Gauntlets.AIR_CONTACT
	if active_clip == "AirAttack":
		animation_player.seek(combo.time, true)

func _animate(delta: float) -> void:
	if gauntlets_equipped and combo.phase == &"air_attack" and active_clip == "AirAttack":
		if not combo.air_landing_started and combo.time >= 18.0 / 30.0:
			# Hold the airborne pose until physics reports support.
			combo.time = 18.0 / 30.0 - delta * combo.playback_rate()
			animation_player.seek(combo.time, true)
		elif combo.air_landing_started and combo.time >= 31.0 / 30.0 and combo.time < 71.0 / 30.0:
			# The export contains a long static segment between impact and recovery.
			combo.time = 71.0 / 30.0
			animation_player.seek(combo.time, true)
	super._animate(delta)
