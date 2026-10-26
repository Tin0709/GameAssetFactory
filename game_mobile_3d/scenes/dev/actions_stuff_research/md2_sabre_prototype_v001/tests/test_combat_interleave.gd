extends SceneTree
var checks:=0
var failures:Array[String]=[]
var a:CharacterBody3D
var record:=false
var previous:=Vector3.ZERO
var trace:Array[Dictionary]=[]
var starts:Array[int]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func tick()->void:await physics_frame;await process_frame
func ticks(n:int)->void:
	for i in n:await tick()
func observe()->void:
	if not record:return
	var travel:=Vector2(a.position.x-previous.x,a.position.z-previous.z).length();previous=a.position
	trace.append({"phase":str(a.combo.phase),"clip":a.active_clip,"travel":travel,"speed":a.current_speed,"index":a.combo.index})
func wait_step(hz:int)->bool:
	for i in hz*2:
		if a.combo.phase==&"step":return true
		await tick()
	return false
func run()->void:
	var floor:=StaticBody3D.new();var c:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.4,100);c.shape=box;c.position.y=-.2;floor.add_child(c);root.add_child(floor)
	a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();a.scripted_input=true;root.add_child(a);a.physics_pose_ready.connect(observe)
	a.attack_accepted.connect(func(index:int,_clip:String,_serial:int):starts.append(index))
	check(a.combo.get("movement_breaks_enabled")==true,"Default source mode supports strike/move/strike rather than locking the entire held combo")
	var trials:Array[Dictionary]=[]
	for hz in [30,60]:
		Engine.physics_ticks_per_second=hz;a.reset_actor();await ticks(4);a.requested_direction=Vector2(0,-1);a.requested_run=true;await ticks(hz/2)
		trace.clear();starts.clear();previous=a.position;record=true;a.attack(true);await ticks(hz*4);record=false
		var attack_travel:=0.;var step_travel:=0.;var step_frames:=0;var valid_gait:=true
		for frame:Dictionary in trace:
			if frame.phase=="step":
				step_travel+=frame.travel;step_frames+=1
				if frame.travel>.001:valid_gait=valid_gait and frame.clip in a.GAITS
			else:attack_travel+=frame.travel
		check(step_frames>0 and step_travel>.5,"Holding movement and combat creates real movement between strikes at%dHz"%hz)
		check(attack_travel<.005 and valid_gait,"Travel belongs to locomotion windows; full-body attacks stay planted at%dHz"%hz)
		check(starts.size()>=6 and starts.slice(0,6)==[0,1,2,0,1,2],"Movement windows retain complete1/2/3 combo order at%dHz"%hz)
		trials.append({"hz":hz,"step_frames":step_frames,"step_travel":step_travel,"attack_travel":attack_travel,"accepted":starts.duplicate()})
		# Release attack during the window: continue moving, no surprise next swing.
		a.reset_actor();await ticks(4);a.requested_direction=Vector2(0,-1);a.requested_run=true;starts.clear();a.attack(true)
		var found:bool=await wait_step(hz);check(found,"A completed moving strike opens a movement window")
		a.attack(false);await ticks(hz)
		check(starts==[0] and not a.combo.active() and a.current_speed>6.99,"Releasing held combat in a step cancels automatic continuation at%dHz"%hz)
		# Releasing the direction instead resumes the next strike in place.
		a.reset_actor();await ticks(4);a.requested_direction=Vector2(0,-1);a.requested_run=true;a.attack(true);await wait_step(hz);a.requested_direction=Vector2.ZERO;await tick()
		check(a.combo.phase==&"attack" and a.combo.index==1 and a.current_speed<.001,"Stopping movement exits the step into the next planted strike at%dHz"%hz)
		# Jump/focus cannot leak a reserved ground strike into the airborne scene.
		a.reset_actor();await ticks(4);a.requested_direction=Vector2(0,-1);a.requested_run=true;a.attack(true);await wait_step(hz);a.requested_jump=true;await tick();a.requested_jump=false
		check(a.velocity.y>0. and not a.combo.active(),"Jump interrupts movement continuation without altering approved trajectory")
		a.reset_actor();await ticks(4);a.requested_direction=Vector2(0,-1);a.requested_run=true;starts.clear();a.attack(true);await wait_step(hz);a.release_inputs();await ticks(hz)
		check(starts==[0] and not a.combo.active(),"Focus release clears the reserved next strike")
		# A collision may stop travel, but must not leave the held combo stuck forever.
		a.reset_actor();await ticks(4);var wall:=StaticBody3D.new();var wc:=CollisionShape3D.new();var wb:=BoxShape3D.new();wb.size=Vector3(10,5,.4);wc.shape=wb;wall.position=Vector3(0,2,-.8);wall.add_child(wc);root.add_child(wall)
		a.requested_direction=Vector2(0,-1);a.requested_run=true;starts.clear();a.attack(true);await ticks(hz*3)
		check(starts.size()>=3 and starts.slice(0,3)==[0,1,2],"Blocked movement has a bounded escape and continues held attacks at%dHz"%hz)
		wall.free()
	var out:={"checks":checks,"failures":failures,"trials":trials,"native_md2_interleave_interval_recovered":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation/md2_sabre_movement"));FileAccess.open("res://.validation/md2_sabre_movement/combat-interleave.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("SABRE_COMBAT_INTERLEAVE ",JSON.stringify(out));a.free();floor.free();quit(0 if failures.is_empty() else 1)
