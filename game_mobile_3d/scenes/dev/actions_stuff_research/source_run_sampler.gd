extends RefCounted
## Literal declared source profile. Beyond the immutable six-second take this
## continues its source expressions; it does not fabricate a six-second loop.
const DATA_PATH:="res://scenes/dev/actions_stuff_research/run_source_profile.json"
var data: Dictionary
var base: Dictionary={}
var parents: Dictionary
var names: Array[String]=[]
var poses: Array[Transform3D]=[]
var phase:=-1.0
var life:=-1.0
var unit:=0.0
func _init(rig: Skeleton3D) -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	parents=data.parents;unit=data.unit
	for name in data.base:base[name]=_matrix(data.base[name])
	for i in rig.get_bone_count():names.append(rig.get_bone_name(i));poses.append(rig.get_bone_rest(i))
func _matrix(rows: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(rows[0][3],rows[1][3],rows[2][3]))
func expression(node: Array) -> float:
	match node[0]:
		"n":return float(node[1])
		"phase":return phase
		"life":return life
		"neg":return -expression(node[1])
		"pos":return expression(node[1])
		"+":return expression(node[1])+expression(node[2])
		"-":return expression(node[1])-expression(node[2])
		"*":return expression(node[1])*expression(node[2])
		"/":return expression(node[1])/expression(node[2])
		"sin":return sin(deg_to_rad(expression(node[1])))
		"cos":return cos(deg_to_rad(expression(node[1])))
		"min":return minf(expression(node[1]),expression(node[2]))
		"max":return maxf(expression(node[1]),expression(node[2]))
	assert(false,"Unsupported restricted source expression")
	return 0.
func _vector(values: Array) -> Vector3:
	return Vector3(expression(values[0]),expression(values[1]),expression(values[2]))
func channel(clip: Dictionary,bone: String,key: String) -> Vector3:
	var fallback:=Vector3.ONE if key=="scale" else Vector3.ZERO
	if not clip.has(bone) or not clip[bone].has(key):return fallback
	var keys: Array=clip[bone][key]
	if phase<=float(keys[0][0]):return _vector(keys[0][1])
	if phase>=float(keys[-1][0]):return _vector(keys[-1][1])
	for i in keys.size()-1:
		var a: float=keys[i][0];var b: float=keys[i+1][0]
		if a<=phase and phase<=b:return _vector(keys[i][1]).lerp(_vector(keys[i+1][1]),(phase-a)/(b-a))
	return fallback
func _source_transform(bone: String,pivot: Vector3) -> Transform3D:
	var r:=channel(data.run,bone,"rotation")+channel(data.bob,bone,"rotation")+channel(data.sprint,bone,"rotation")
	if bone=="rightarm":r.x*=.5
	var p:=channel(data.run,bone,"position")+channel(data.bob,bone,"position")+channel(data.sprint,bone,"position")
	var s:=channel(data.run,bone,"scale")
	var basis:=Basis(Vector3.FORWARD,deg_to_rad(r.z))*Basis(Vector3.UP,deg_to_rad(-r.y))*Basis(Vector3.RIGHT,deg_to_rad(r.x))*Basis.from_scale(s)
	return Transform3D(basis,Vector3(p.x,p.y,-p.z)*unit+pivot-basis*pivot)
func set_clocks(gait_phase: float,life_time: float) -> void:
	gait_phase=fposmod(gait_phase,1.)
	if is_equal_approx(phase,gait_phase) and life==life_time:return
	phase=gait_phase;life=life_time
	var desired: Dictionary=base.duplicate()
	var waist:=_source_transform("waist",base.Hips.origin)
	var body:=waist*_source_transform("body",base.Head.origin)
	for name in ["Hips","Spine"]:desired[name]=waist*base[name]
	for name in ["Chest","Neck","WeaponCarrier"]:desired[name]=body*base[name]
	var head:=_source_transform("head",base.Head.origin)*Transform3D(base.Head)
	head.origin=(body*Transform3D(base.Head)).origin;desired.Head=head
	for side in ["L","R"]:
		var name: String="Arm."+side
		var arm:=body*_source_transform("leftarm" if side=="L" else "rightarm",base[name].origin-Vector3(0,2*unit,0))
		desired[name]=arm*base[name];desired["ForeArm."+side]=arm*base["ForeArm."+side]
		name="Leg."+side
		desired[name]=_source_transform("leftleg" if side=="L" else "rightleg",base[name].origin)*base[name]
	for i in names.size():
		var name:=names[i]
		if desired.has(name):poses[i]=Transform3D(desired[parents[name]]).affine_inverse()*Transform3D(desired[name]) if parents[name]!="" else desired[name]
func position(bone: int) -> Vector3:return poses[bone].origin
func rotation(bone: int) -> Quaternion:return poses[bone].basis.orthonormalized().get_rotation_quaternion().normalized()
func scale(bone: int) -> Vector3:return poses[bone].basis.get_scale()
