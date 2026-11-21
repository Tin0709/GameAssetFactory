extends "res://tests/test_mechanic_lab_balanced_arm_rest.gd"

func run() -> void:
	var zombie := await launch_corner_zombie(3833, Vector3(3.28884363174438, 0.0, 3.24321866035461),
		-0.0256550312042236, &"Zombie_ExpressiveRun", 0.289620819091797,
		Vector3(0.61353725194931, 0.0, 0.789665758609772), 1150.0)
	if zombie == null:
		quit(1)
		return
	var initial_response := false
	var absorbed_before_landing := false
	var landing := -1.0
	for tick in 217:
		await physics_frame
		if zombie._corpse_parked:
			break
		if not zombie.ragdoll.running:
			continue
		var foot: PhysicalBone3D = zombie.ragdoll.bodies["Leg.L"]
		if tick == 45:
			initial_response = is_equal_approx(foot.bounce, 0.30) and not zombie._corpse_landed
		if is_zero_approx(foot.bounce) and not zombie._corpse_landed:
			var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
			absorbed_before_landing = is_equal_approx(foot.gravity_scale * gravity, 50.0)
		if landing < 0.0 and zombie._corpse_landed:
			landing = zombie._corpse_age
	var passed := initial_response and absorbed_before_landing and landing > 0.0 and landing <= 3.05 \
		and zombie._corpse_parked and zombie.ragdoll.bodies.is_empty()
	print("MECHANIC_LAB_LATE_FOOT_REBOUND initial=", initial_response, " absorbed=", absorbed_before_landing,
		" landing_s=", landing, " parked=", zombie._corpse_parked, " seconds=", zombie._corpse_age, " passed=", passed)
	quit(0 if passed else 1)
