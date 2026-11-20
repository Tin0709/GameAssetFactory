extends RefCounted
## Bake two Lab-only loops on the verified adult rig. Timing accents are
## authored here, with the native walk supplying the zombie's upper-body pose.

const WALK := &"Zombie_ExpressiveWalk"
const RUN := &"Zombie_ExpressiveRun"
const WALK_DURATION := 0.78
const RUN_DURATION := 0.64
const WALK_SUPPORT := 0.50
const RUN_SUPPORT := 0.40
const PLANT := 0.04
const LEG_LENGTH := 0.75
const SOLE_HALF_WIDTH := 0.125
const SAMPLES := 100
const HIP_PATH := NodePath("Skeleton3D:J_Hip")

static func is_gait(clip: StringName) -> bool:
	return clip == WALK or clip == RUN

static func plant_phase(clip: StringName) -> float:
	# Use the left foot as the phase origin in both the native and Lab walks.
	return PLANT if is_gait(clip) else 0.427282363 / 1.6

static func build(library: AnimationLibrary, skeleton: Skeleton3D,
		source: Animation, walk_speed: float, run_speed: float) -> void:
	library.add_animation(WALK, _bake(source, skeleton, WALK_DURATION, WALK_SUPPORT, walk_speed, false))
	library.add_animation(RUN, _bake(source, skeleton, RUN_DURATION, RUN_SUPPORT, run_speed, true))

static func _bake(source: Animation, skeleton: Skeleton3D, duration: float,
		support: float, speed: float, running: bool) -> Animation:
	var clip := Animation.new()
	clip.length = duration
	clip.loop_mode = Animation.LOOP_LINEAR
	var source_tracks := source.get_track_count()
	var rests: Array[Transform3D] = []
	var bones: Array[StringName] = []
	for track in source_tracks:
		var path := source.track_get_path(track)
		var bone := path.get_subname(0)
		bones.append(bone)
		rests.append(skeleton.get_bone_rest(skeleton.find_bone(bone)))
		var type := source.track_get_type(track)
		clip.track_set_path(clip.add_track(type), path)
	var hip_track := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(hip_track, HIP_PATH)
	var hip_rest := skeleton.get_bone_rest(skeleton.find_bone(&"J_Hip")).origin
	var distance := speed * duration * support
	for frame in SAMPLES + 1:
		var phase := float(frame % SAMPLES) / SAMPLES
		var time := float(frame) * duration / SAMPLES
		var left_phase := fposmod(phase - PLANT, 1.0)
		var right_phase := fposmod(left_phase + 0.5, 1.0)
		var left := _leg_drive(left_phase, support, distance, 1.0, running)
		var right := _leg_drive(right_phase, support, distance, -1.0, running)
		var step := fposmod(left_phase, 0.5)
		var air := 0.0
		if running and step > support:
			var progress := inverse_lerp(support, 0.5, step)
			air = 0.060 * 4.0 * progress * (1.0 - progress)
		# The lower rolling edge supports the rig. In the run, both feet lift
		# during the short interval between push-off and the next contact.
		var height := -minf(_sole_y(left), _sole_y(right)) + air
		var weight_shift := sin(TAU * (left_phase + 0.14))
		clip.position_track_insert_key(hip_track, time, Vector3(hip_rest.x, hip_rest.y, -height))
		var compression := smoothstep(0.0, 0.065, step) * (1.0 - smoothstep(0.065, 0.23, step))
		var push := smoothstep(0.18, 0.34, step) * (1.0 - smoothstep(0.34, 0.50, step))
		var chest_dip := push * 0.022 - compression * (0.061 if running else 0.046)
		var source_time := fposmod(left_phase + plant_phase(&"Zombie_Walk"), 1.0) * source.length
		for track in source_tracks:
			var bone := bones[track]
			var rest := rests[track]
			if source.track_get_type(track) == Animation.TYPE_POSITION_3D:
				var position := rest.origin
				if bone == &"J_Spine":
					position.x += weight_shift * (0.018 if running else 0.028)
					position.z -= chest_dip
				clip.position_track_insert_key(track, time, position)
			else:
				var rotation := source.rotation_track_interpolate(track, source_time)
				match bone:
					&"J_L_Leg":
						rotation = _leg_rotation(left) * rest.basis.get_rotation_quaternion()
					&"J_R_Leg":
						rotation = _leg_rotation(right) * rest.basis.get_rotation_quaternion()
					&"J_L_Foot", &"J_R_Foot", &"J_L_Hand", &"J_R_Hand":
						rotation = rest.basis.get_rotation_quaternion()
					&"J_Spine":
						var lean := (0.31 if running else 0.10) + compression * 0.09 - push * 0.05
						rotation = Quaternion(Vector3.RIGHT, lean) * Quaternion(Vector3.UP, weight_shift * 0.074)
					&"J_Neck":
						rotation = Quaternion(Vector3.RIGHT, -0.12 if running else -0.05) * rotation
					&"J_L_Arm", &"J_R_Arm":
						var side := 1.0 if bone == &"J_L_Arm" else -1.0
						var reach := weight_shift * side * (0.36 if running else 0.14)
						rotation = Quaternion(Vector3.RIGHT, reach) * rotation
				clip.rotation_track_insert_key(track, time, rotation.normalized())
	return clip

static func _leg_drive(phase: float, support: float, distance: float,
		side: float, running: bool) -> Vector2:
	var forward: float
	var swing_roll := 0.0
	if phase < support:
		forward = distance * (0.5 - phase / support)
	else:
		var swing := inverse_lerp(support, 1.0, phase)
		# Swing begins and ends with the same backward velocity as stance.
		# The backswing and late reach make the change of direction readable.
		var swing_velocity := (support - 1.0) / support
		forward = cubic_interpolate(-0.5, 0.5, 0.5 - 2.0 * swing_velocity,
			-0.5 + 2.0 * swing_velocity, swing) * distance
		var recovery := smoothstep(0.06, 0.37, swing) * (1.0 - smoothstep(0.58, 0.95, swing))
		swing_roll = recovery * side * (0.32 if running else 0.22)
	return Vector2(-asin(clampf(forward / LEG_LENGTH, -0.95, 0.95)), swing_roll)

static func _leg_rotation(drive: Vector2) -> Quaternion:
	# The imported skeleton's neutral root maps local Y to model forward.
	return Quaternion(Vector3.UP, drive.y) * Quaternion(Vector3.RIGHT, drive.x)

static func _sole_y(drive: Vector2) -> float:
	var basis := Basis(Vector3.BACK, drive.y) * Basis(Vector3.RIGHT, drive.x)
	return -LEG_LENGTH * basis.y.y - SOLE_HALF_WIDTH * (absf(basis.x.y) + absf(basis.z.y))
