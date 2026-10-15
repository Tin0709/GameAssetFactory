extends "res://scenes/dev/actions_stuff_research/source_direction_sampler.gd"
## Approved Jump PRS: source uniform Catmull with duplicate endpoints, exact-key
## post side, additive unnormalized clips. Root/leg scale and entity-relative head
## use the approved JumpRetarget transform adapter without pose repair.
const JUMP_DATA_PATH := "res://scenes/dev/actions_stuff_research/jump_program.json"

func _init(rig: Skeleton3D) -> void:
	super(rig)
	data = JSON.parse_string(FileAccess.get_file_as_string(JUMP_DATA_PATH))
	holding_right = 0.0
	holding_left = 0.0

func _channel(keys: Array, clock: float, env: Dictionary, accumulated: Vector3) -> Vector3:
	for key in keys:
		if absf(clock-float(key[0])) < 1e-11: return _vector(key[2],env,accumulated)
	if clock < float(keys[0][0]): return _vector(keys[0][1],env,accumulated)
	if clock > float(keys[-1][0]): return _vector(keys[-1][2],env,accumulated)
	for i in keys.size()-1:
		var a: float = keys[i][0]
		var b: float = keys[i+1][0]
		if a < clock and clock < b:
			var x := _vector(keys[i][2],env,accumulated)
			var y := _vector(keys[i+1][1],env,accumulated)
			var t := (clock-a)/(b-a)
			if not keys[i][3] and not keys[i+1][3]: return x.lerp(y,t)
			var p0 := _vector(keys[maxi(0,i-1)][2],env,accumulated)
			var p3 := _vector(keys[mini(keys.size()-1,i+2)][1],env,accumulated)
			return .5*((2.0*x)+(-p0+y)*t+(2.0*p0-5.0*x+4.0*y-p3)*t*t+(-p0+3.0*x-3.0*y+p3)*t*t*t)
	return accumulated

func sample_clip(alias: String, clock: float, snapshot: Dictionary = {}) -> Dictionary:
	var env := _environment(snapshot,clock)
	var out := _neutral()
	for bone in BONES:
		for key in CHANNELS:
			out[bone][key] = _channel(data.clips[alias].bones[bone][key],clock,env,out[bone][key])
	return out

func _pure_rotation(bone: String) -> Basis:
	var r: Vector3 = channels[bone].rotation
	return Basis(Vector3.FORWARD,deg_to_rad(r.z))*Basis(Vector3.UP,deg_to_rad(-r.y))*Basis(Vector3.RIGHT,deg_to_rad(r.x))

func set_snapshot(snapshot: Dictionary) -> void:
	var env := _environment(snapshot,0.0)
	env["v.vbcdda"] = holding_right
	env["v.wfyvyl"] = holding_left
	channels = _neutral()
	for layer in snapshot.get("layers",[]):
		_add_clip(channels,layer.alias,env,float(layer.clock),float(layer.controller_weight))
	_retarget()

func _retarget() -> void:
	var desired: Dictionary = base.duplicate()
	var source_root := _source_transform("root",Vector3.ZERO)
	var waist := source_root*_source_transform("waist",base.Hips.origin)
	var body := waist*_source_transform("body",base.Head.origin)
	desired.Root = source_root*Transform3D(base.Root)
	for name in ["Hips","Spine"]: desired[name] = waist*Transform3D(base[name])
	for name in ["Chest","Neck","WeaponCarrier"]: desired[name] = body*Transform3D(base[name])
	# Cancel pure ancestor rotations only; retain inherited authored squash.
	var ancestor := _pure_rotation("root")*_pure_rotation("waist")*_pure_rotation("body")
	var head := body*Transform3D(ancestor.inverse(),Vector3.ZERO)*_source_transform("head",base.Head.origin)*Transform3D(base.Head)
	var p: Vector3 = channels.head.position
	head.origin = (body*Transform3D(base.Head)).origin+body.basis*(Vector3(p.x,p.y,-p.z)*unit)
	desired.Head = head
	for side in ["L","R"]:
		var name: String = "Arm."+side
		var arm := body*_source_transform("leftarm" if side == "L" else "rightarm",base[name].origin-Vector3(0,2*unit,0))
		desired[name] = arm*Transform3D(base[name])
		desired["ForeArm."+side] = arm*Transform3D(base["ForeArm."+side])
		name = "Leg."+side
		desired[name] = source_root*_source_transform("leftleg" if side == "L" else "rightleg",base[name].origin)*Transform3D(base[name])
	for i in names.size():
		var name := names[i]
		if desired.has(name): poses[i] = Transform3D(desired[parents[name]]).affine_inverse()*Transform3D(desired[name]) if parents[name] != "" else desired[name]

func future_snapshot(snapshot: Dictionary, ahead: float) -> Dictionary:
	## Finite-difference pose probe, no controller transitions or timeline firing.
	## Freeze state/weights/other smoothed variables; advance authored clip clocks
	## and age only. Never mutates the live source environment or its snapshot.
	assert(is_finite(ahead) and ahead >= 0.0)
	var future: Dictionary = snapshot.duplicate(true)
	future.life = float(snapshot.get("life",0.0))+ahead
	future.phase = float(snapshot.get("phase",0.0))+ahead*float(snapshot.get("cadence",0.0))
	future.phase01 = fposmod(float(future.phase),1.0)
	future.vars["v.eqhdel"] = future.phase
	future.vars["v.ifcvde"] = future.phase01
	if future.has("state_time"): future.state_time = float(future.state_time)+ahead
	future.query["q.life_time"] = future.life
	future.query["q.delta_time"] = ahead
	var environment := _environment(future,0.0)
	for layer in future.get("layers",[]):
		var clip: Dictionary = data.clips[layer.alias]
		environment["q.anim_time"] = float(layer.clock)
		var clock := float(VM.execute(clip.anim_time_update,environment)) if clip.anim_time_update != null else float(layer.clock)+ahead
		if clip.loop is bool and clip.loop and clip.animation_length:
			clock = fposmod(clock,float(clip.animation_length))
		elif clip.animation_length:
			clock = minf(clock,float(clip.animation_length))
		layer.clock = clock
	return future
