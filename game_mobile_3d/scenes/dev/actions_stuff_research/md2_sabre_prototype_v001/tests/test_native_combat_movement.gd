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
		var expected:=0.;var path:=0.;var locked_path:=0.;var open_time:=0.;var previous:Vector3=a.position;var gait_before:float=a._gait_resume_phase
		a.attack(true)
		for i in hz*4:
			var open:=0.
			for segment:Dictionary in a.combo.movement_plan(1./hz):
				if segment.move:open+=segment.duration
			expected+=open*7.;open_time+=open
			a.requested_direction=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][int(i/(hz/2))%4]
			await tick();var distance:=Vector2(a.position.x-previous.x,a.position.z-previous.z).length();path+=distance;previous=a.position
			if open==0.:locked_path+=distance
		check(absf(path-expected)<.003,"Collision-resolved distance follows7m/s permission integral at "+str(hz))
		check(locked_path<.0001,"Windups remain planted without momentum at "+str(hz))
		check(a.accepted_count>=7 and a.combo.phase!=&"step","Held combo repeats ordered native links without arbitrary step at "+str(hz))
		var period:float=a.source_gait.state(7.).period;var expected_phase:=fposmod(gait_before+open_time/period,1.)
		check(absf(wrapf(a._gait_resume_phase-expected_phase,-.5,.5))<.0001,"Legs preserve shared phase and advance only during real open travel at "+str(hz))
		a.attack(false);a.requested_direction=Vector2.UP
		for i in hz*2:await tick()
		check(a.active_clip=="Run" and absf(a.current_speed-7.)<.001,"Recovery immediately yields naturally to full-speed gait at "+str(hz))
		check(absf(wrapf(a.visual.rotation.y-PI,-PI,PI))<.001,"Combat turning and free locomotion share native yaw response at "+str(hz))
		trials.append({"hz":hz,"expected_m":expected,"actual_m":path,"locked_m":locked_path,"open_seconds":open_time})
	print("SABRE_NATIVE_COMBAT_MOVEMENT ",JSON.stringify({"checks":checks,"failures":failures,"trials":trials}));a.free();floor.free();quit(0 if failures.is_empty() else 1)
