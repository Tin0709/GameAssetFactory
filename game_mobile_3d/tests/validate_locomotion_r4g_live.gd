extends SceneTree
var lab
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:failures.append(text);push_error(text)
func key(code: int, pressed: bool) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e)
func advance(frames: int) -> void:
	for i in frames:await physics_frame
func run() -> void:
	lab=load("res://scenes/dev/LocomotionTurningLab.tscn").instantiate();root.add_child(lab);current_scene=lab
	await advance(20)
	key(KEY_W,true);await advance(45)
	check(lab.actor.velocity.z< -4.24,"Physical W drives normal Walk")
	key(KEY_D,true);await advance(30)
	check(absf(lab.actor.current_speed-4.25)<0.001 and absf(lab.actor.velocity.x-3.0052)<0.01,"Diagonal input remains normalized")
	key(KEY_SHIFT,true);await advance(20)
	check(absf(lab.actor.current_speed-6.25)<0.001 and lab.actor.sprint_weight>0.999,"Physical Shift blends into Sprint")
	var before: float=lab.actor.phase
	key(KEY_TAB,true);key(KEY_TAB,false);await advance(1)
	check(not lab.actor.turning_enabled,"Tab switches to straight-only A")
	check(absf(wrapf(lab.actor.phase-before,-0.5,0.5))<0.07,"Tab does not restart gait")
	key(KEY_TAB,true);key(KEY_TAB,false);await advance(1)
	check(lab.actor.turning_enabled,"Tab switches back to B")
	key(KEY_F1,true);key(KEY_F1,false);await advance(1)
	check(not lab.debug.visible,"F1 hides debug text")
	key(KEY_F1,true);key(KEY_F1,false)
	key(KEY_C,true);key(KEY_C,false);await advance(1)
	check(lab.camera.size==6.0,"C selects closer fixed-axis view")
	key(KEY_W,false);key(KEY_D,false);key(KEY_SHIFT,false);await advance(3)
	var stopped:float=lab.actor.phase
	await advance(10);check(stopped==lab.actor.phase,"Released movement freezes gait phase")
	key(KEY_SPACE,true);key(KEY_SPACE,false);await advance(1)
	check(lab.automated,"Space enables isolated auto path")
	key(KEY_F2,true);key(KEY_F2,false);await advance(180)
	check(lab.path_index==1 and lab.actor.turn_amount>0.05,"Auto CW circle has stable right-turn intent")
	key(KEY_F3,true);key(KEY_F3,false);await advance(30)
	check(lab.auto_sprint and lab.actor.current_speed>6.24,"F3 selects auto Sprint")
	key(KEY_F2,true);key(KEY_F2,false);await advance(180)
	check(lab.path_index==2 and lab.actor.turn_amount< -0.05,"Auto CCW circle switches to local left")
	key(KEY_A,true);await advance(2)
	check(not lab.automated,"Manual input immediately takes over from auto")
	key(KEY_A,false)
	var result:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	FileAccess.open("res://.validation/locomotion_r4g/live_validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));lab.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
