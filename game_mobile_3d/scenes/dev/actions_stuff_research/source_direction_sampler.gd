extends RefCounted
## Literal directional research source. Negative weights are inactive and never
## normalized. This is the approved XYZ composite, independent of the stored
## immutable Walk ZYX take. set_snapshot evaluates once; getters read cached PRS.
const VM = preload("res://scenes/dev/actions_stuff_research/molang_vm.gd")
const DATA_PATH := "res://scenes/dev/actions_stuff_research/directional_channels.json"
const BASE_PATH := "res://scenes/dev/actions_stuff_research/run_source_profile.json"
const HEIGHT_PATH := "res://scenes/dev/actions_stuff_research/native_height_field.json"
const BONES := ["root","waist","body","head","rightarm","leftarm","rightleg","leftleg"]
const CHANNELS := ["rotation","position","scale"]
var data: Dictionary
var height_field: Dictionary
var base: Dictionary = {}
var parents: Dictionary
var names: Array[String] = []
var poses: Array[Transform3D] = []
var channels: Dictionary = {}
var unit := 0.0
# Preserve the immutable study's standard-item profile by default. Gameplay
# explicitly selects the unarmed profile; both samples use the same flags.
var holding_right := 1.0
var holding_left := 0.0

func set_item_holding(right: float, left: float) -> void:
	assert(is_finite(right) and is_finite(left) and right >= 0.0 and right <= 1.0 and left >= 0.0 and left <= 1.0)
	holding_right = right
	holding_left = left

func _init(rig: Skeleton3D) -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_cache_literal_vectors()
	height_field = JSON.parse_string(FileAccess.get_file_as_string(HEIGHT_PATH))
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE_PATH))
	parents = profile.parents
	unit = profile.unit
	for name in profile.base:
		base[name] = _matrix(profile.base[name])
	for i in rig.get_bone_count():
		names.append(rig.get_bone_name(i))
		poses.append(rig.get_bone_rest(i))

func _matrix(rows: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(rows[0][3],rows[1][3],rows[2][3]))

func _environment(snapshot: Dictionary, clock: float) -> Dictionary:
	var env: Dictionary = {}
	for pair in [["v","vars"],["q","query"]]:
		for key in snapshot.get(pair[1],{}):
			var full: String = str(key) if str(key).begins_with(pair[0]+".") else pair[0]+"."+str(key)
			env[full] = snapshot[pair[1]][key]
	env["q.anim_time"] = clock
	env["q.life_time"] = float(snapshot.get("life",0.0))
	for key in {"q.state_time":snapshot.get("state_time",0.0),"q.is_in_ui":0.0,"q.body_y_rotation":0.0,"q.target_x_rotation":0.0}:
		if not env.has(key):
			env[key] = snapshot.get("state_time",0.0) if key == "q.state_time" else 0.0
	return env

func _neutral() -> Dictionary:
	var out: Dictionary = {}
	for bone in BONES:
		out[bone] = {"rotation":Vector3.ZERO,"position":Vector3.ZERO,"scale":Vector3.ONE}
	return out

func _cache_literal_vectors()->void:
	# Most authored key vectors are numeric constants. Materialize their exact
	# float32 Vector3 once, retaining dynamic ASTs and all original key times.
	for clip:Dictionary in data.clips.values():
		for bone:Dictionary in clip.bones.values():
			for keys:Array in bone.values():
				for key:Array in keys:
					for side:int in [1,2]:
						var values:Array=key[side]
						if values[0][0]=="literal" and values[1][0]=="literal" and values[2][0]=="literal":
							key[side]=Vector3(float(values[0][1]),float(values[1][1]),float(values[2][1]))

func _vector(values: Variant, env: Dictionary, accumulated: Vector3) -> Vector3:
	if values is Vector3:
		# Preserve the evaluator's final `this` value even for constant channels.
		env["this"]=accumulated.z
		return values
	var out := Vector3.ZERO
	for axis in 3:
		# Holding evaluates `this` from the accumulated same-axis channel.
		env["this"] = accumulated[axis]
		out[axis] = float(VM.execute(values[axis],env))
	return out

func _channel(keys: Array, clock: float, env: Dictionary, accumulated: Vector3) -> Vector3:
	if clock <= float(keys[0][0]):
		return _vector(keys[0][1],env,accumulated)
	if clock >= float(keys[-1][0]):
		return _vector(keys[-1][2],env,accumulated)
	for i in keys.size()-1:
		var a: float = keys[i][0]
		var b: float = keys[i+1][0]
		if a <= clock and clock < b:
			# Post at the left key, pre at the right key; exact authored times
			# belong to the following interval, as in SourceChannels._channel.
			return _vector(keys[i][2],env,accumulated).lerp(_vector(keys[i+1][1],env,accumulated),(clock-a)/(b-a))
	return accumulated

func _add_clip(out: Dictionary, alias: String, environment: Dictionary, clock: float, controller_weight: float = 1.0) -> void:
	var clip: Dictionary = data.clips[alias]
	var env: Dictionary = environment.duplicate()
	env["q.anim_time"] = clock
	var weight := maxf(0.0,controller_weight)*maxf(0.0,float(VM.execute(clip.blend_weight,env)))
	if weight == 0.0:
		return
	for bone in BONES:
		for key in clip.bones[bone]:
			var identity: Vector3 = Vector3.ONE if key == "scale" else Vector3.ZERO
			out[bone][key] += weight*(_channel(clip.bones[bone][key],clock,env,out[bone][key])-identity)

func _directional(mode: String, env: Dictionary, clock: float) -> Dictionary:
	var out := _neutral()
	for row in data.directions[mode]:
		_add_clip(out,row[0],env,clock,float(VM.execute(row[1],env)))
	return out

func _source_transform(bone: String, pivot: Vector3) -> Transform3D:
	var r: Vector3 = channels[bone].rotation
	var p: Vector3 = channels[bone].position
	var s: Vector3 = channels[bone].scale
	# Native Y-up conversion of approved Blender C*Rz(z)*Ry(-y)*Rx(-x)*Ci.
	# Imported bone names Arm.L/R correspond to Blender UpperArm.L/R.
	var basis := Basis(Vector3.FORWARD,deg_to_rad(r.z))*Basis(Vector3.UP,deg_to_rad(-r.y))*Basis(Vector3.RIGHT,deg_to_rad(r.x))*Basis.from_scale(s)
	return Transform3D(basis,Vector3(p.x,p.y,-p.z)*unit+pivot-basis*pivot)

var diagnostic_channels_usec:=0
func set_snapshot(snapshot: Dictionary) -> void:
	var started:=Time.get_ticks_usec()
	_diagnostic_set_snapshot(snapshot)
	diagnostic_channels_usec+=Time.get_ticks_usec()-started
func _diagnostic_set_snapshot(snapshot: Dictionary) -> void:
	var run_weight := float(snapshot.get("run_weight",0.0))
	assert(is_finite(run_weight) and run_weight >= 0.0 and run_weight <= 1.0,"Source run_weight must be in [0,1]")
	# Preserve source's endpoint seam: phase1 wraps to0 with no closure repair.
	var clock := fposmod(float(snapshot.get("phase",0.0)),1.0)
	var env := _environment(snapshot,clock)
	var walk := _directional("walk",env,clock)
	var running := _directional("run",env,clock)
	channels = _neutral()
	for bone in BONES:
		for key in CHANNELS:
			channels[bone][key] = Vector3(walk[bone][key]).lerp(running[bone][key],run_weight)
	_add_clip(channels,"xfltzh",env,clock)
	_add_clip(channels,"hxfxxu",env,clock,run_weight*float(env.get("v.esnrkj",0.0)))
	_add_clip(channels,"xahrzd",env,2.0,run_weight)
	_add_clip(channels,"bob",env,clock)
	env["v.vbcdda"] = holding_right
	env["v.wfyvyl"] = holding_left
	_add_clip(channels,"holding",env,clock)
	_add_clip(channels,"look_at_target",env,clock)
	var desired: Dictionary = base.duplicate()
	var source_root := _source_transform("root",Vector3.ZERO)
	var waist := source_root*_source_transform("waist",base.Hips.origin)
	var body := waist*_source_transform("body",base.Head.origin)
	desired.Root = source_root*Transform3D(base.Root)
	for name in ["Hips","Spine"]:
		desired[name] = waist*Transform3D(base[name])
	for name in ["Chest","Neck","WeaponCarrier"]:
		desired[name] = body*Transform3D(base[name])
	# Rotation belongs to the entity; translation follows the animated body.
	var head := _source_transform("head",base.Head.origin)*Transform3D(base.Head)
	head.origin = (body*Transform3D(base.Head)).origin
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
		if desired.has(name):
			poses[i] = Transform3D(desired[parents[name]]).affine_inverse()*Transform3D(desired[name]) if parents[name] != "" else desired[name]

func _height(mode: String, forward: float, lateral: float) -> float:
	var grid: Array = height_field.grid[mode]
	var angle := fposmod(atan2(lateral,forward),TAU)*float(height_field.angles)/TAU
	var strength := minf(Vector2(forward,lateral).length()/.25,float(grid.size()-1))
	var row := mini(int(strength),grid.size()-2)
	var u := strength-float(row)
	var column := int(angle)%int(height_field.angles)
	var next_column := (column+1)%int(height_field.angles)
	var v := angle-floorf(angle)
	return lerpf(lerpf(grid[row][column],grid[row][next_column],v),lerpf(grid[row+1][column],grid[row+1][next_column],v),u)

func height_offset(snapshot: Dictionary) -> float:
	# Approved phase-independent direction/strength envelope; fixed padding only.
	# Source activation is the already updated pre_animation v.esnrkj value.
	var env := _environment(snapshot,0.0)
	var e := float(env.get("v.esnrkj",0.0))
	var f := float(env.get("v.cknrcn",0.0))
	var s := float(env.get("v.mrmeib",0.0))
	var w := float(snapshot.get("run_weight",0.0))
	var walk_activation := clampf(e*3.0,0.0,1.0)
	var run_activation := maxf(0.0,e)
	return lerpf(_height("walk",f*walk_activation,s*walk_activation),_height("run",f*run_activation,s*run_activation),w)+float(height_field.padding_m)

func position(bone: int) -> Vector3:
	return poses[bone].origin
func rotation(bone: int) -> Quaternion:
	return poses[bone].basis.orthonormalized().get_rotation_quaternion().normalized()
func scale(bone: int) -> Vector3:
	return poses[bone].basis.get_scale()
