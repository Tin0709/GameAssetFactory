extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var script=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd")
	var a=script.new();root.add_child(a);a.set_physics_process(false)
	var sampler=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/source_gait.gd").new()
	var config:Dictionary=a.runtime_locomotion_profile.gait_blend.duplicate(true)
	config.input_floor=.25
	check(sampler.setup(a.skeleton,a.animation_player,a.clips,config),"Optional synthetic blend-input floor is accepted")
	check(absf(sampler.state(0.).input-.25)<.000001,"Blend input remains bounded independently of physical speed")
	check(absf(sampler.state(7.).period-a.source_gait.state(7.).period)<.000001,"Input floor preserves the established full-speed cadence")
	for invalid:Variant in [-.1,INF,NAN,"bad",true,10.]:
		var bad=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/source_gait.gd").new()
		config.input_floor=invalid
		check(not bad.setup(a.skeleton,a.animation_player,a.clips,config),"Malformed optional floor fails safely: "+str(invalid))
	a._grounded=true;a._move_requested=true;a._run_requested=true;a.current_speed=0.
	check(a._select_clip()=="Idle","Held movement against an immovable wall selects idle instead of a frozen running pose")
	a.current_speed=.4
	check(a._select_clip()=="Run","Actual movement along a wall remains eligible for locomotion")
	a.set_native_gait_enabled(false);a.current_speed=0.
	check(a._select_clip()=="Run","Diagnostic legacy source path stays independently available")
	var transition=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/source_transition.gd").new()
	var rig:=Skeleton3D.new();rig.add_bone("J_Head");root.add_child(rig);transition.setup(rig)
	var cursor:={"seconds":0.}
	var evaluate:=func(dt:float)->Array[Transform3D]:
		cursor.seconds+=dt
		return [Transform3D(Basis.IDENTITY,Vector3(cursor.seconds,0,0))]
	check(transition.has_method("begin_evaluated"),"Transition can evaluate its outgoing animation instead of freezing a snapshot")
	if transition.has_method("begin_evaluated"):
		transition.begin_evaluated(.4,evaluate,&"smoothstep")
		transition.apply(.1)
		check(absf(cursor.seconds-.1)<.000001,"Outgoing animation has its own advancing wall clock")
		check(absf(rig.get_bone_pose_position(0).x-.084375)<.000001,"Synthetic outgoing pose and Hermite weight compose correctly")
		var shown:=rig.get_bone_pose(0)
		transition.begin_evaluated(.4,evaluate,&"smoothstep");transition.apply(0.)
		check(rig.get_bone_pose(0).origin.distance_to(shown.origin)<.000001,"Reversing an unfinished transition preserves the current pose")
		transition.clear();rig.reset_bone_poses();cursor.seconds=0.
		transition.begin(.4);transition.apply(.1)
		check(cursor.seconds==0.,"Existing snapshot transitions retain their separate behavior")
	print("SABRE_EVALUATED_LOCOMOTION ",JSON.stringify({"checks":checks,"failures":failures}));a.free();rig.free();quit(0 if failures.is_empty() else 1)
