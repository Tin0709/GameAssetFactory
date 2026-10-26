extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var actor=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();actor.prefer_private_skin=false;root.add_child(actor);actor.set_physics_process(false)
	for key:String in ["Walk","Run","StrafeLeft","CombatStrafeRight"]:
		var duration:float=actor.clips[key].duration
		actor.current_speed=0.;actor.review_loop=true;actor.review(key)
		actor._animate(duration*.75)
		check(actor.animation_player.current_animation_position>duration*.70,"Stationary review plays full-rate "+key)
		actor.review_loop=false;actor.review(key);actor._animate(duration*1.1)
		check(absf(actor.animation_player.current_animation_position-duration)<.00001,"Nonloop review holds endpoint of "+key)
		actor._animate(duration*.5)
		check(absf(actor.animation_player.current_animation_position-duration)<.00001,"Nonloop review does not restart "+key)
		actor.resume_gameplay()
		check(actor.animation_player.get_animation(actor.clips[key].action).loop_mode==Animation.LOOP_LINEAR,"Gameplay loop restored after review "+key)
	actor.free();print("SABRE_REVIEW ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
