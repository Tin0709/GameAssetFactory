extends SceneTree
## glTF import omits rest-constant PRS channels; clips must not inherit old values.
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a);a.set_physics_process(false)
	var left:int=a.skeleton.find_bone("J_L_Weapon");var pupil:int=a.skeleton.find_bone("J_R_EyePupil")
	# The source Run and attack left weapon is identity local TRS. Walk varies it.
	for key:String in ["Run","Attack1","JumpTakeoff","CombatReady"]:
		a.review("Walk");a._animate(.5)
		check(not a.skeleton.get_bone_pose(left).is_equal_approx(Transform3D.IDENTITY),"Fixture enters non-rest Walk left-weapon pose before "+key)
		a.review(key);a._animate(.1)
		check(a.skeleton.get_bone_pose(left).is_equal_approx(Transform3D.IDENTITY),"Rest-constant left weapon does not inherit Walk in "+key)
	# Idle moves the pupil; Walk/Run use original constant offset0.0325.
	for key:String in ["Walk","Run","Attack2"]:
		a.review("Idle");a._animate(.65)
		check(absf(a.skeleton.get_bone_pose(pupil).origin.x-.0324999988079071)>.00001,"Fixture enters varied Idle pupil before "+key)
		a.review(key);a._animate(.1)
		check(absf(a.skeleton.get_bone_pose(pupil).origin.x-.0324999988079071)<.000001,"Rest-constant pupil does not inherit Idle in "+key)
	print("SABRE_CONSTANT_CHANNELS ",JSON.stringify({"checks":checks,"failures":failures}));a.free();quit(0 if failures.is_empty() else 1)
