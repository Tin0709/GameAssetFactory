extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a);a.set_physics_process(false)
	for heading:float in [1.3,-PI,.66]:
		a.visual.rotation.y=heading;a.direction_adapter.deactivate();a.reset_actor()
		check(absf(wrapf(a.direction_adapter.current_world_yaw,-PI,PI))<.00001,"Reset clears the old world leg heading after facing "+str(heading))
		a._move_requested=true;a._run_requested=true;a._grounded=true;a.current_speed=7.;a.velocity=Vector3(0,0,7);a._animate(1./60.)
		check(absf(a.direction_adapter.current_yaw)<.00001,"First forward step after reset has no stale lateral leg twist: "+str(heading))
	print("SABRE_CONTROLLER_HEADING ",JSON.stringify({"checks":checks,"failures":failures}));a.free();quit(0 if failures.is_empty() else 1)
