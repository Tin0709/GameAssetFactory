extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func tick()->void:await physics_frame;await process_frame
func run()->void:
	var floor:=StaticBody3D.new();var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1000,.4,1000);col.shape=box;col.position.y=-.2;floor.add_child(col);root.add_child(floor)
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();a.scripted_input=true;root.add_child(a)
	check(a.combo.native_enabled and a.supplemental_combat_clips==2,"Native montage references load two additional existing private source clips")
	check(a.clips.Attack3.source_name=="Player_SwordCombo_Attack3" and a.clips.NativeFinisher.source_name=="Player_AxeCombo_Attack3","Verified Sword3 retained and actual Sabre finisher added separately")
	var trials:Array=[]
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second=hz;a.reset_actor();await tick();await tick();a.requested_direction=Vector2(0,-1);a.requested_run=true
		for i in hz/2:await tick()
		var period:float=a.source_gait.state(7.).period
		a.attack(true)
		var oracle=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/combo_state.gd").new()
		oracle.setup(a.clips);oracle.configure_native(a.runtime_locomotion_profile.combat);oracle.attack(true)
		var measured:={"expected":0.,"path":0.,"locked_path":0.,"open_time":0.,"phase":0.,"previously_open":false,"position":a.position,"clock":a.simulation_clock}
		# A process_frame waiter can span multiple physics ticks under CPU load.
		# Monitor each actual actor tick instead of assuming one tick per waiter.
		var monitor:=func()->void:
			var dt:float=a.simulation_clock-float(measured.clock)
			var open:=0.
			for segment:Dictionary in oracle.movement_plan(dt):
				if segment.move:
					if not measured.previously_open:measured.phase=0.
					measured.phase=fposmod(float(measured.phase)+float(segment.duration)/period,1.);open+=segment.duration
				measured.previously_open=segment.move
			oracle.advance(dt)
			var from:Vector3=measured.position
			var distance:=Vector2(a.position.x-from.x,a.position.z-from.z).length()
			measured.expected+=open*7.;measured.open_time+=open;measured.path+=distance
			if open<.00000001:measured.locked_path+=distance
			measured.position=a.position;measured.clock=a.simulation_clock
		a.physics_pose_ready.connect(monitor)
		for i in hz*4:
			a.requested_direction=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][int(i/(hz/2))%4]
			await tick()
		a.physics_pose_ready.disconnect(monitor)
		check(absf(float(measured.path)-float(measured.expected))<.003,"Collision-resolved distance follows7m/s permission integral at "+str(hz))
		check(float(measured.locked_path)<.0001,"Windups remain planted without momentum at "+str(hz))
		check(a.accepted_count>=7 and a.combo.phase!=&"step","Held combo repeats ordered native links without arbitrary step at "+str(hz))
		check(absf(wrapf(a._gait_resume_phase-float(measured.phase),-.5,.5))<.0003,"Native restart and shared leg phase follow open travel at "+str(hz))
		a.attack(false);a.requested_direction=Vector2.UP
		for i in hz*2:await tick()
		check(a.active_clip=="Run" and absf(a.current_speed-7.)<.001,"Recovery immediately yields naturally to full-speed gait at "+str(hz)+" actual="+str({"clip":a.active_clip,"speed":a.current_speed,"position":a.position,"combo":a.combo.phase,"clock":a.simulation_clock}))
		check(absf(wrapf(a.visual.rotation.y-PI,-PI,PI))<.001,"Combat turning and free locomotion share native yaw response at "+str(hz))
		trials.append({"hz":hz,"expected_m":measured.expected,"actual_m":measured.path,"locked_m":measured.locked_path,"open_seconds":measured.open_time})
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second=hz;a.reset_actor();await tick();await tick()
		var wall:=StaticBody3D.new();var wc:=CollisionShape3D.new();var wb:=BoxShape3D.new();wb.size=Vector3(10,5,.4);wc.shape=wb;wall.position=Vector3(0,2,-.8);wall.add_child(wc);root.add_child(wall)
		a.requested_direction=Vector2.UP;a.requested_run=true;a.attack(true)
		for i in hz*2:await tick()
		check(a.position.z>-.31 and a.accepted_count>=4,"Collision blocks travel without blocking event-driven chain progression at "+str(hz))
		check(a.current_speed<.001 and a._animation_motion_speed<.001,"Blocked travel cannot advance an artificial running stride at "+str(hz))
		a.release_inputs();await tick();check(not a.combo.held and a.combo.buffer_until<0.,"Focus release clears commands during collision at "+str(hz))
		a.requested_jump=true;await tick();a.requested_jump=false
		check(a.velocity.y>0. and not a.combo.active(),"Jump cancels ground combo while preserving accepted trajectory at "+str(hz))
		wall.free()
	print("SABRE_NATIVE_COMBAT_MOVEMENT ",JSON.stringify({"checks":checks,"failures":failures,"trials":trials}));a.free();floor.free();quit(0 if failures.is_empty() else 1)
