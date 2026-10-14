extends SceneTree
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var scene=load("res://scenes/dev/SnappyLocomotionFastJumpTest.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var v=scene.actor.visual
	check(v.has_method("set_run_recovery"),"Independent Run candidate selector exists")
	if not failures.is_empty():quit(1);return
	check(not v.run_recovery_enabled,"Approved Run remains the default")
	check(v.recovery_clip!=null,"Separate candidate export loads without replacing approved clips")
	check(not v.animation_player.is_playing() and not v.bounce_enabled,"Single existing pose writer and no added bounce")
	for phase in [.08,.31,.58,.81]:
		v.gait_phase=phase
		var anchors: Array=v.foot_anchors.duplicate()
		var ids: Array=v.contact_ids.duplicate()
		v.set_run_recovery(not v.run_recovery_enabled)
		check(v.gait_phase==phase,"Candidate switch preserves either lead phase")
		check(v.foot_anchors==anchors and v.contact_ids==ids,"Candidate switch preserves support anchors and receiving IDs")
	check(v.snappy_enabled,"Run A/B does not alter Snappy/Expressive selection")
	v.set_run_recovery(false)
	var key:=InputEventKey.new();key.physical_keycode=KEY_B;key.keycode=KEY_B;key.pressed=true
	Input.parse_input_event(key)
	await process_frame
	check(v.run_recovery_enabled,"B selects the independent Run experiment")
	key.pressed=false;Input.parse_input_event(key)
	print("RUN_RECOVERY_SELECTION_FAILURES ",failures)
	quit(0 if failures.is_empty() else 1)
