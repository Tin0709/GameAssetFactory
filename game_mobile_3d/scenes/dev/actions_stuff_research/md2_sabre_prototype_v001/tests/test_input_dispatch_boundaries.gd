extends SceneTree
## Exact source-clock boundary experiments through SceneTree input dispatch.
## These rates label physics configuration; manual clock control is deliberate.
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func button(down:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=Vector2(640,240);e.global_position=e.position;e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e);Input.flush_buffered_events()
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(lab);current_scene=lab
	var a=lab.player;a.set_physics_process(false)
	var rows:Array=[]
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second=hz
		for strike in 3:
			for order:String in ["release_before","release_after","tie_input_first","tie_evaluation_first"]:
				lab.sabre_mode.reset();a._grounded=true;a.combo._start_attack(strike);button(true)
				var serial:int=a.combo.serial;var gate:float=a.combo.chain_source_gate()/a.combo.playback_rate();var epsilon:=.000001
				if order=="release_before":a._animate(gate-epsilon);button(false);a._animate(epsilon*2.)
				elif order=="release_after":a._animate(gate+epsilon);button(false)
				else:
					a._animate(gate-epsilon)
					# Set the exact boundary without evaluating it, then permute
					# event delivery versus callback resolution at the same clock.
					a.combo.time=a.combo.chain_source_gate()
					if order=="tie_input_first":button(false);a.combo.advance(0.)
					else:a.combo.advance(0.);button(false)
				var should_chain:bool=order in ["release_after","tie_evaluation_first"]
				check(a.combo.serial==serial+(1 if should_chain else 0),"Causal release/evaluation order is explicit: "+str(hz)+"/"+str(strike)+"/"+order)
				check(not a.combo.held and not lab.sabre_mode._left_held,"SceneTree release actually reaches the existing controller")
				var snapshot:Dictionary=a.input_order_snapshot()
				check(snapshot.events.any(func(x:Dictionary)->bool:return x.kind=="input_receipt" and x.get("dispatch_stage")=="_input" and x.get("pressed")==false),"Trace separates actual input receipt from evaluator state")
				rows.append({"hz":hz,"strike":strike,"order":order,"chained":should_chain,"trace":snapshot.events})
				a.combo.advance(2.)
				check(not a.combo.active(),"Released input cannot create a later ghost chain")
	var folder:String=a.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/runtime_locomotion/compiled_logic/input_ordering")
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder.path_join("dispatch-boundaries.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":rows,"scope":"Actual SceneTree dispatch with precisely controlled source clock. Same-time order is specified explicitly, not evidence of unrecorded native micro-order or a new cancel window."},"\t"))
	print("SABRE_INPUT_DISPATCH_BOUNDARIES ",JSON.stringify({"checks":checks,"failures":failures,"cases":rows.size()}));lab.free();await process_frame;quit(0 if failures.is_empty() else 1)
