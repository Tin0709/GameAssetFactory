extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var script=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd")
	var a=script.new();var b=script.new();root.add_child(a);root.add_child(b);a.set_physics_process(false);b.set_physics_process(false)
	check(a.has_method("input_order_snapshot"),"Existing actor can export a bounded causal input/physics trace")
	if not a.has_method("input_order_snapshot"):
		print("SABRE_INPUT_ORDER_TRACE ",JSON.stringify({"checks":checks,"failures":failures}));a.free();b.free();quit(1);return
	b.input_order_trace.enabled=false
	for actor in [a,b]:actor._grounded=true;actor._move_requested=true;actor.current_speed=7.;actor._run_requested=true;actor.attack(true)
	var worst:=0.
	for i in 180:
		if i==110:a.attack(false);b.attack(false)
		a._animate(1./120.);b._animate(1./120.)
		for bone in a.skeleton.get_bone_count():
			var x:Transform3D=a.skeleton.get_bone_pose(bone);var y:Transform3D=b.skeleton.get_bone_pose(bone)
			worst=maxf(worst,x.origin.distance_to(y.origin));worst=maxf(worst,x.basis.x.distance_to(y.basis.x));worst=maxf(worst,x.basis.y.distance_to(y.basis.y));worst=maxf(worst,x.basis.z.distance_to(y.basis.z))
	check(worst<.000001 and a.combo.serial==b.combo.serial and a.combo.time==b.combo.time,"Tracing changes no source pose, combo clock or command acceptance")
	for i in 1300:a.note_input_source(&"LMB",i%2==0,&"test_dispatch")
	var snapshot:Dictionary=a.input_order_snapshot();var rows:Array=snapshot.events
	check(rows.size()==512 and snapshot.summary.total>=1300,"Trace retains a fixed memory bound")
	check(rows[0].sequence<rows[-1].sequence,"Ring export preserves causal event order")
	check(rows.all(func(x:Dictionary)->bool:return x.has("wall_usec") and x.has("physics_frame") and x.has("process_frame") and x.has("simulation_seconds") and x.has("combo_clock")),"Input receipt, simulation clock and engine frame labels stay distinct")
	rows[0].kind="modified"
	check(a.input_order_snapshot().events[0].kind!="modified","Exported records cannot mutate the live trace")
	var before:int=a.input_order_snapshot().summary.total;a.input_order_trace.enabled=false;a.note_input_source(&"LMB",true,&"test_dispatch")
	check(a.input_order_snapshot().summary.total==before,"Disabled diagnostics do not collect new input")
	print("SABRE_INPUT_ORDER_TRACE ",JSON.stringify({"checks":checks,"failures":failures,"pose_error":worst}));a.free();b.free();quit(0 if failures.is_empty() else 1)
