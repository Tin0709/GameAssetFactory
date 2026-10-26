extends SceneTree
## Actual capsule flight; thresholds are a new study adapter, not native MD2 constants.
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func tick()->void:await physics_frame;await process_frame
func ticks(count:int)->void:
	for i in count:await tick()
func run()->void:
	var floor:=StaticBody3D.new();var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.4,100);col.shape=box;col.position.y=-.2;floor.add_child(col);root.add_child(floor)
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();a.scripted_input=true;root.add_child(a)
	check(a.using_original_source,"Jump test exercises current original-source actor")
	var reports:Array[Dictionary]=[]
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second=hz;a.reset_actor();await ticks(4)
		var start:float=a.simulation_clock;var peak:=0.;var apex:=0.;var first_fall_clip:="";var guard:=0
		a.requested_jump=true;await tick()
		while not a._grounded and guard<hz*2:
			if a.global_position.y>peak:peak=a.global_position.y;apex=a.simulation_clock-start
			if a.velocity.y<-.001 and first_fall_clip.is_empty():first_fall_clip=a.active_clip
			guard+=1;await tick()
		var flight:float=a.simulation_clock-start
		check(guard<hz*2 and a._grounded,"Jump returns to actual floor at%dHz"%hz)
		check(absf(peak-1.2)<.015,"Faster jump preserves previous1.2-unit height at%dHz"%hz)
		check(apex<=.28 and flight<=.55,"Ordinary rise and fall no longer take.8seconds at%dHz"%hz)
		check(first_fall_clip=="JumpAirborne","Descending physics is not stuck in takeoff clip at%dHz"%hz)
		check(a.active_clip=="JumpLanding","Actual contact starts landing at%dHz"%hz)
		await ticks(ceili(.16*hz))
		check(a._grounded and a.active_clip=="JumpLanding","Holding jump cannot auto-repeat; stationary original landing continues")
		await ticks(hz/2);check(a.active_clip=="Idle","Stationary full landing returns Idle")
		a.requested_jump=false;a.reset_actor();await ticks(4)
		a.requested_direction=Vector2(0,-1);a.requested_run=true;await ticks(hz/2)
		a.requested_jump=true;await tick();a.requested_jump=false;guard=0
		while not a._grounded and guard<hz*2:guard+=1;await tick()
		var landed:float=a.simulation_clock;await ticks(ceili(.075*hz))
		check(a.active_clip=="Run" and absf(a.current_speed-7.)<.01,"Moving landing resumes distance-synchronized Run without300ms pose lock at%dHz"%hz)
		check(a._jump_stage.is_empty(),"Released landing stage cannot reappear during ground motion")
		reports.append({"hz":hz,"height":peak,"up_seconds":apex,"down_seconds":flight-apex,"flight_seconds":flight,"first_descending_clip":first_fall_clip,"moving_run_by_seconds":a.simulation_clock-landed})
		a.reset_actor();await ticks(4)
	# Ceiling collision, not elapsed clip duration, must end takeoff.
	var ceiling:=StaticBody3D.new();var cc:=CollisionShape3D.new();var cb:=BoxShape3D.new();cb.size=Vector3(8,.4,8);cc.shape=cb;ceiling.position.y=2.45;ceiling.add_child(cc);root.add_child(ceiling)
	a.requested_jump=true;await tick();a.requested_jump=false;var ceiling_seen:=false
	for i in 35:
		if a.is_on_ceiling():ceiling_seen=true;check(a.active_clip=="JumpAirborne","Low ceiling immediately hands takeoff to falling pose")
		await tick()
	check(ceiling_seen and a._grounded,"Low-ceiling jump collides and lands without stuck air state")
	a.set_physics_process(false);a.review("JumpTakeoff");a._animate(.2)
	check(absf(a.animation_player.current_animation_position-.2)<.00001 and a._playback_speed==1.,"Raw original jump review still plays1x")
	check(absf(float(a.clips.JumpTakeoff.duration)-.4)<.00001 and absf(float(a.clips.JumpLanding.duration)-.3)<.00001,"Original jump clip durations remain intact")
	var out:={"checks":checks,"failures":failures,"trials":reports,"native_md2_jump_values_verified":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation/md2_sabre_movement"));FileAccess.open("res://.validation/md2_sabre_movement/jump-responsiveness.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("SABRE_JUMP_RESPONSIVENESS ",JSON.stringify(out));ceiling.free();a.free();floor.free();quit(0 if failures.is_empty() else 1)
