extends SceneTree
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
	var floor:=StaticBody3D.new();var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(100,.4,100);col.shape=shape;col.position.y=-.2;floor.add_child(col);root.add_child(floor)
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();a.scripted_input=true;root.add_child(a)
	check(a.using_original_source,"Combat test loads original private source profile")
	var accepted_times:Array[float]=[]
	check(a.has_signal("attack_accepted_timed"),"Actor preserves accepted sub-tick timestamp for synchronized audio")
	if a.has_signal("attack_accepted_timed"):a.attack_accepted_timed.connect(func(_index:int,_clip:String,_serial:int,at:float):accepted_times.append(at))
	var timings:Array[Dictionary]=[]
	for hz in [30,60]:
		Engine.physics_ticks_per_second=hz;a.reset_actor();await ticks(4);a.set_physics_process(false)
		accepted_times.clear();a.attack(true)
		for i in ceili(.76*hz):a._physics_process(1./hz)
		check(accepted_times.size()>=3 and absf(accepted_times[1]-accepted_times[0]-float(a.clips.Attack1.duration)/1.2)<.00001,"Accepted source chain retains fractional wall-time boundary at%dHz"%hz)
		for index in 3:
			a.combo.cancel();a.combo._start_attack(index);a.combo.drain_events()
			var rate:float=[1.2,1.2,1.][index];a._animate(.1)
			check(absf(a.combo.time-.1*rate)<.00001,"Source attack%d clock follows public rate at%dHz"%[index+1,hz])
			check(absf(a.animation_player.current_animation_position-a.combo.time)<.00001,"Source pose and combo clock agree at%dHz"%hz)
			check(absf(a._playback_speed-rate)<.00001,"Displayed attack rate is inspectable")
		# A buffer lasting220ms must not shrink with source playback rate.
		a.combo.cancel();a.combo.request_attack();a.combo.advance(.1);a.combo.request_attack();a.combo.advance(.27)
		check(a.combo.phase==&"recovery" and a.combo.index==0,"Early buffer expires in wall seconds at%dHz"%hz)
		a.combo.cancel();a.combo.request_attack();a.combo.advance(.2);a.combo.request_attack();a.combo.advance(.17)
		check(a.combo.phase==&"attack" and a.combo.index==1,"Recent wall-time buffer chains faster attack at%dHz"%hz)
		a.combo.cancel();a.review("Attack1");a._animate(.1)
		check(absf(a.animation_player.current_animation_position-.1)<.00001 and a._playback_speed==1.,"Raw attack review keeps original1x source clock")
		a.review_clip="";a.reset_actor();a.set_physics_process(true);await ticks(4)
		# Actual movement and floor collision, no manually assigned grounded flag.
		a.requested_jump=true;await tick();a.requested_jump=false
		var apex:float=a.global_position.y;var guard:=0
		while a.velocity.y>0. and guard<hz*2:
			await tick();apex=maxf(apex,a.global_position.y);guard+=1
		var normal_start:float=a.simulation_clock
		while not a._grounded and guard<hz*3:await tick();guard+=1
		var normal_fall:float=a.simulation_clock-normal_start
		a.reset_actor();await ticks(4);a.requested_jump=true;await tick();a.requested_jump=false;guard=0
		while a.velocity.y>0. and guard<hz*2:await tick();guard+=1
		var start_velocity:float=a.velocity.y;var slam_start:float=a.simulation_clock;a.attack(true);a.attack(false);await tick()
		check(a.combo.clip()=="AirAttack" and absf(a.velocity.y-(start_velocity-2.*a.gravity/hz))<.0001,"Aerial attack uses recovered gravity factor2 at%dHz"%hz)
		while not a._grounded and guard<hz*3:await tick();guard+=1
		var slam_fall:float=a.simulation_clock-slam_start
		var source_at_contact:float=a.combo.time
		check(source_at_contact>=float(a.clips.AirAttack.vfx_window[0]) and source_at_contact<=float(a.clips.AirAttack.vfx_window[1]),"Real slam contact stays inside original blade-motion effect window at%dHz"%hz)
		check(absf(source_at_contact-.2542)/a.combo.playback_rate()<.04,"Derived aerial audio landmark remains near floor contact at%dHz"%hz)
		check(slam_fall<normal_fall*.85,"Slam reaches real floor decisively sooner at%dHz"%hz)
		check(absf(a.gravity-38.4)<.0001,"Ordinary jump gravity adapter is not replaced by aerial attack factor")
		timings.append({"hz":hz,"normal_apex":apex,"normal_apex_to_floor":normal_fall,"slam_apex_to_floor":slam_fall,"air_source_time_at_contact":source_at_contact,"air_rate":a.combo.playback_rate()})
		a.reset_actor();a.global_position.y=100.;await ticks(3);a.attack(true);a.attack(false);await ticks(hz)
		check(not a._grounded and not a.combo.active() and a._heavy_slam_active,"Heavy gravity persists after air clip ends above a high ledge at%dHz"%hz)
		a.review("Idle");var falling:float=a.velocity.y;await tick()
		check(absf(a.velocity.y-(falling-2.*a.gravity/hz))<.0001,"Review/cancel does not interrupt physical slam before floor at%dHz"%hz)
		await ticks(hz*2)
		check(a._grounded and not a._heavy_slam_active,"Real floor clears heavy gravity even during review at%dHz"%hz)
		a.review("AirAttack");a.set_physics_process(false);a._animate(.2)
		check(absf(a.animation_player.current_animation_position-.2)<.00001 and a._playback_speed==1.,"Raw aerial strike review is1x despite gameplay physics synchronization")
	# Rate-aware event clock must be invariant under wall-time partition.
	var C=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/combo_state.gd");var b=C.new();b.setup(a.clips)
	if b.get("attack_play_rates")!=null:
		b.attack_play_rates=[1.2,1.2,1.];b.attack(true);b.advance(1.1);var events:Array=b.drain_events()
		check(absf(float(events[1].at)-float(a.clips.Attack1.vfx_window[0])/1.2)<.000001,"First source VFX gate maps to exact wall-time rate")
	else:check(false,"Combo exposes independently configured source attack rates")
	var report:={"checks":checks,"failures":failures,"timings":timings,"native_jump_base_recovered":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation/md2_sabre_movement"));FileAccess.open("res://.validation/md2_sabre_movement/source-combat.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_SOURCE_COMBAT ",JSON.stringify(report));a.free();floor.free();quit(0 if failures.is_empty() else 1)
