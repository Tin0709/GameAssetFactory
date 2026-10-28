extends SceneTree
var failures:Array[String]=[]
var checks:=0
var cases:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.md2_sabre_prototype_enabled=true;lab.grass_field_blocks=80;root.add_child(lab)
	await tick();var a=lab.player;a.scripted_input=true
	check(absf(a.gravity-60.)<.01,"Ordinary jump acceleration matches measured native velocity slope, not old guessed38.4")
	check(absf(sqrt(2.*a.gravity*a.jump_height)-14.4)<.001,"Ordinary launch matches native1440cm/s configuration and first-frame trace")
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second=hz
		for moving in [false,true]:
			a.reset_actor();await tick();await tick();await tick()
			a.requested_run=true;a.requested_direction=Vector2.UP if moving else Vector2.ZERO
			for i in 4:await tick()
			var begin:float=a.simulation_clock;var peak:=0.;var apex:=-1.;var contact:=-1.;var finished:=-1.;var landing_begin:=-1.
			a.requested_jump=true;await tick();a.requested_jump=false
			var first_velocity:float=a.velocity.y
			for i in hz*3:
				var elapsed:float=a.simulation_clock-begin;peak=maxf(peak,a.global_position.y)
				if apex<0. and a.velocity.y<=0.:apex=elapsed
				if contact<0. and a._grounded:contact=elapsed;landing_begin=elapsed
				if contact>=0. and a._jump_stage.is_empty():finished=elapsed;break
				await tick()
			check(contact>0. and contact<.55,"No hidden slow-motion/delay in physical flight "+str(hz)+" "+str(moving))
			check(absf(apex-.24)<=1./hz+.012,"Observed-profile apex agrees with native launch/gravity "+str(hz)+" "+str(moving))
			check(absf(peak-1.728)<.015,"Measured rise follows verified launch/gravity without unexplained70cm teleport "+str(hz)+" "+str(moving))
			cases.append({"hz":hz,"moving":moving,"launch_speed_setting":sqrt(2.*a.gravity*a.jump_height),"first_tick_vertical_speed":first_velocity,"gravity":a.gravity,"apex_s":apex,"air_s":contact,"peak_m":peak,"landing_visual_s":finished-landing_begin,"complete_visual_state_s":finished,"air_horizontal_target":a.current_speed,"native_sabre_air_rate_preserved":a.combo.air_attack_play_rate})
	var report:={"checks":checks,"failures":failures,"cases":cases}
	var output:=OS.get_environment("JUMP_TIMING_OUTPUT")
	if output.is_empty():output="C:/Users/ADMIN/Desktop/MD2 Research/reports/prototype_sabre/jump_fidelity_20261028/godot_timing.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("JUMP_TIMING ",JSON.stringify(report));lab.free();quit(0 if failures.is_empty()else 1)
func tick()->void:
	await physics_frame;await process_frame
