extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
	var v=scene.player.visual;scene.player.set_physics_process(false);v.set_process(false)
	v.move_requested=true;v.gait_phase=.125;v.gait_run_weight=.20
	for i in 2:v.stance_duty[i]=.10;v.released[i]=false;v.foot_support[i]=false
	var passed: bool=not v._support(0)
	if not passed:push_error("Accelerating Walk to Run must not turn a free leg back into stance mid-exchange")
	print("SUPPORT_EXCHANGE ",passed)
	scene.queue_free();quit(0 if passed else 1)
