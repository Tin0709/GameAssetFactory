extends CharacterBody3D
## R4-G only. Imported AnimationPlayer is a read-only library; this is the sole pose writer.
@export var walk_speed := 4.25
@export var sprint_speed := 6.25
@export var facing_response := 12.0
@export var max_yaw_rate := 6.0
@export var full_turn_rate := 3.0
@export var turn_filter_seconds := 0.10
@export var gait_blend_seconds := 0.14
var phase := 0.0
var sprint_weight := 0.0
var turn_amount := 0.0 # -1 left / +1 right
var angular_velocity := 0.0 # positive world-Y yaw is local left (+Z forward)
var turning_enabled := true
var current_speed := 0.0
var visual: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var clips := {}
var moving := false

class PoseClip:
	var animation: Animation
	var positions := PackedInt32Array()
	var rotations := PackedInt32Array()
	var rests: Array[Transform3D] = []
	func _init(a: Animation, s: Skeleton3D) -> void:
		animation=a; positions.resize(s.get_bone_count()); rotations.resize(s.get_bone_count()); positions.fill(-1); rotations.fill(-1)
		for i in s.get_bone_count(): rests.append(s.get_bone_rest(i))
		for t in a.get_track_count():
			var path := a.track_get_path(t)
			if path.get_subname_count()==0: continue
			var i := s.find_bone(path.get_subname(0))
			if i<0: continue
			if a.track_get_type(t)==Animation.TYPE_POSITION_3D: positions[i]=t
			if a.track_get_type(t)==Animation.TYPE_ROTATION_3D: rotations[i]=t
	func position(i: int, p: float) -> Vector3:
		return animation.position_track_interpolate(positions[i],p*animation.length) if positions[i]>=0 else rests[i].origin
	func rotation(i: int, p: float) -> Quaternion:
		return animation.rotation_track_interpolate(rotations[i],p*animation.length).normalized() if rotations[i]>=0 else rests[i].basis.get_rotation_quaternion()

func _ready() -> void:
	visual = $Facing
	skeleton = visual.find_child("Skeleton3D",true,false)
	animation_player = visual.find_child("AnimationPlayer",true,false)
	animation_player.stop(); animation_player.active=false
	for name in ["Walk","WalkTurnLeft","WalkTurnRight","Sprint","SprintTurnLeft","SprintTurnRight"]:
		assert(animation_player.has_animation(name),"Missing lab clip "+name)
		clips[name] = PoseClip.new(animation_player.get_animation(name),skeleton)
	evaluate_pose()

func step(dt: float, direction: Vector3, sprint: bool) -> void:
	moving = direction.length_squared()>0.0001
	sprint_weight = move_toward(sprint_weight,1.0 if sprint and moving else 0.0,dt/maxf(gait_blend_seconds,0.001))
	current_speed = lerpf(walk_speed,sprint_speed,sprint_weight) if moving else 0.0
	velocity.x=direction.x*current_speed; velocity.z=direction.z*current_speed
	velocity.y = -0.5 if is_on_floor() else velocity.y-20.0*dt
	move_and_slide()
	angular_velocity=0.0
	if moving:
		var heading := atan2(direction.x,direction.z)
		var error := wrapf(heading-visual.rotation.y,-PI,PI)
		var yaw_delta := clampf(error*(1.0-exp(-facing_response*dt)),-max_yaw_rate*dt,max_yaw_rate*dt)
		visual.rotation.y=wrapf(visual.rotation.y+yaw_delta,-PI,PI)
		angular_velocity=yaw_delta/dt
		# No independent clip clocks: all six sample this phase * their own duration.
		phase=fposmod(phase+dt*lerpf(1.0/clips.Walk.animation.length,1.0/clips.Sprint.animation.length,sprint_weight),1.0)
	var target_turn := clampf(-angular_velocity/maxf(full_turn_rate,0.001),-1.0,1.0)
	turn_amount=lerpf(turn_amount,target_turn,1.0-exp(-dt/maxf(turn_filter_seconds,0.001)))
	evaluate_pose()

func evaluate_pose() -> void:
	var amount := turn_amount if turning_enabled else 0.0
	var weight := absf(amount)
	var walk: PoseClip = clips.Walk
	var sprint: PoseClip = clips.Sprint
	var walk_turn: PoseClip = clips.WalkTurnLeft if amount<0 else clips.WalkTurnRight
	var sprint_turn: PoseClip = clips.SprintTurnLeft if amount<0 else clips.SprintTurnRight
	for i in skeleton.get_bone_count():
		var wp := walk.position(i,phase).lerp(walk_turn.position(i,phase),weight)
		var sp := sprint.position(i,phase).lerp(sprint_turn.position(i,phase),weight)
		var wr := walk.rotation(i,phase).slerp(walk_turn.rotation(i,phase),weight)
		var sr := sprint.rotation(i,phase).slerp(sprint_turn.rotation(i,phase),weight)
		skeleton.set_bone_pose_position(i,wp.lerp(sp,sprint_weight))
		skeleton.set_bone_pose_rotation(i,wr.slerp(sr,sprint_weight))
	skeleton.force_update_all_bone_transforms()

func active_names() -> String:
	var side := "Left" if turn_amount<0 else "Right"
	return "Walk / Sprint (straight only)" if not turning_enabled else "Walk ↔ WalkTurn%s | Sprint ↔ SprintTurn%s"%[side,side]
