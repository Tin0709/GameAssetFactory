extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func tick()->void:await physics_frame;await process_frame
func ticks(n:int)->void:
	for i in n:await tick()
func run()->void:
	var floor:=StaticBody3D.new();var c:=CollisionShape3D.new();var b:=BoxShape3D.new();b.size=Vector3(100,.4,100);c.shape=b;c.position.y=-.2;floor.add_child(c);root.add_child(floor)
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();a.scripted_input=true;root.add_child(a)
	a.combo.movement_breaks_enabled=false # Isolate full-body planting; default interleave is tested separately.
	var trials:Array[Dictionary]=[]
	for hz in [30,60]:
		Engine.physics_ticks_per_second=hz;a.reset_actor();await ticks(4);a.requested_direction=Vector2(0,-1);a.requested_run=true;await ticks(hz/2)
		check(absf(a.current_speed-7.)<.01,"Ground-combat probe starts at full Run")
		var start:Vector3=a.position;var previous:=start;var path:=0.;var peak:=0.;a.attack(true)
		for i in hz*2:
			a.requested_direction=[Vector2(0,-1),Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][int(i/(hz/2))%4]
			await tick();path+=Vector2(a.position.x-previous.x,a.position.z-previous.z).length();previous=a.position;peak=maxf(peak,a.current_speed)
		check(path<.005 and peak<.005,"Held ground combo cannot skate from movement input or pre-attack momentum at%dHz"%hz)
		check(a.movement_measurements().attack_travel_adapter==0.,"Source measurements report anchored input travel rather than superseded22percent adapter")
		check(a.accepted_count>=3 and a.impact_count>=3,"Anchoring preserves complete combo/events at%dHz"%hz)
		a.attack(false);a.requested_direction=Vector2(0,-1);await ticks(hz)
		check(a.active_clip=="Run" and absf(a.current_speed-7.)<.01,"Release resumes normal movement after the active strike at%dHz"%hz)
		a.reset_actor();await ticks(4);a.requested_direction=Vector2(0,-1);a.requested_run=true;await ticks(hz/2)
		var tapped_start:Vector3=a.position
		for i in hz*2:a.attack(i%int(hz/6)==0);await tick()
		check(Vector2(a.position.x-tapped_start.x,a.position.z-tapped_start.z).length()<.005 and a.accepted_count>=3,"Repeated six-taps-per-second combat keeps buffered feet planted at%dHz"%hz)
		a.attack(false)
		# Recovery can yield to movement without truncating a still-active strike.
		a.reset_actor();await ticks(4);a.requested_direction=Vector2(0,-1);a.requested_run=true;a.combo.phase=&"recovery";a.combo.index=0;a.combo.time=.01
		await tick();check(not a.combo.active() and a.active_clip=="Run","Unqueued recovery yields to intentional movement at%dHz"%hz)
		# The accepted jump trajectory and air steering are separate from ground planting.
		a.reset_actor();await ticks(4);a.requested_direction=Vector2(0,-1);a.requested_run=true;await ticks(hz/2);a.attack(true);a.requested_jump=true;await tick()
		print("GROUND_JUMP_LAUNCH ",JSON.stringify({"hz":hz,"speed":a.current_speed,"velocity":str(a.velocity),"combo":str(a.combo.phase),"grounded":a._grounded,"jump":a._jump_stage,"clock":a.simulation_clock}))
		check(absf(Vector2(a.velocity.x,a.velocity.z).length()-7.)<.0001 and a.current_speed>=6.99,"Simultaneous attack and jump retains full commanded running speed without anchor reduction at%dHz"%hz)
		a.requested_jump=false;await ticks(6)
		check(a.velocity.y>0. and a.current_speed>1. and not a.combo.active(),"Jump cancels ground anchor and retains air movement at%dHz"%hz)
		trials.append({"hz":hz,"two_second_held_attack_path":path,"maximum_ground_attack_speed":peak})
	var out:={"checks":checks,"failures":failures,"trials":trials,"native_root_motion_recovered":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation/md2_sabre_movement"));FileAccess.open("res://.validation/md2_sabre_movement/ground-combat.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("SABRE_GROUND_COMBAT ",JSON.stringify(out));a.free();floor.free();quit(0 if failures.is_empty() else 1)
