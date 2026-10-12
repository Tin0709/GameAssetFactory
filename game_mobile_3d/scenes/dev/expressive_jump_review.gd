extends "res://scenes/dev/expressive_locomotion_test.gd"
## The same review workspace, now with reversible Jump V2 integration.
var jump_measurements: Dictionary={}
var jump_samples: Array=[]
var jump_cases: Array=[]
var _jump_sequence:=-1
var _last_jump_q: Array[Quaternion]=[]
var _jump_max_step:=0.0
var _jump_worst: Dictionary={}
var _jump_floor_error:=0.0
var _floor_worst: Dictionary={}
var _jump_hip_min:=100.0
var _jump_hip_max:=-100.0
var _jump_section_angles: Dictionary={}
var _last_jump_phase:=.28
var _last_jump_state:="GROUND"
var _last_jump_moving:=false
var _maximum_flight_phase_error:=0.0

func _ready() -> void:
	super._ready()
	if not jump_enabled:return
	if "--expressive-landing-original" in OS.get_cmdline_user_args():actor.visual.heavier_landing=false
	var platform:=StaticBody3D.new();platform.name="EarlyLandingPlatform";platform.position=Vector3(3,.35,4);add_child(platform)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(3,.7,3);collision.shape=shape;platform.add_child(collision)
	var model:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=shape.size;model.mesh=mesh
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.35,.42,.48);model.material_override=material;platform.add_child(model)
	var canvas:=CanvasLayer.new();add_child(canvas)
	var row:=HBoxContainer.new();row.position=Vector2(520,620);canvas.add_child(row)
	for label in ["JUMP","Drop 6m"]:
		var button:=Button.new();button.text=label;button.custom_minimum_size=Vector2(105,55);row.add_child(button)
		if label=="JUMP":button.pressed.connect(actor.request_jump)
		else:button.pressed.connect(func():actor.review_drop(6))
	for i in actor.visual.skeleton.get_bone_count():_last_jump_q.append(actor.visual.skeleton.get_bone_pose_rotation(i))

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if jump_enabled and event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_L:actor.review_drop(6)
	if jump_enabled and event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_B:
		actor.visual.heavier_landing=not actor.visual.heavier_landing;actor.visual.pose_dirty=true

func _update_camera(_delta: float) -> void:
	if not jump_enabled:super._update_camera(_delta);return
	# Keep the floor stable for ordinary jumps; follow only large fall heights.
	var floor_height: float=actor.floor_y
	var target:=Vector3(actor.global_position.x,floor_height+.95+maxf(0,actor.global_position.y-floor_height-1.6),actor.global_position.z)
	camera.position=target+camera_offset;camera.look_at(target)

func _process(delta: float) -> void:
	super._process(delta)
	if not jump_enabled:return
	var v=actor.visual
	status.text+="\nJump %s · pose F%.1f · vertical %.2f m/s\nLanding: %s · B compares"%[actor.jump_state,v.jump_frame,actor.velocity.y,"Heavier" if v.heavier_landing else "Original"]
	if _jump_sequence==v.pose_sequence:return
	_jump_sequence=v.pose_sequence
	if actor.jump_state in ["AIR","LAND"] and _last_jump_state in ["AIR","LAND"] and v.move_requested and _last_jump_moving:
		_maximum_flight_phase_error=maxf(_maximum_flight_phase_error,absf(fposmod(v.gait_phase-_last_jump_phase,1)-v.gait_frequency*v.pose_delta))
	_last_jump_phase=v.gait_phase;_last_jump_state=actor.jump_state;_last_jump_moving=v.move_requested
	for i in v.skeleton.get_bone_count():
		var q: Quaternion=v.skeleton.get_bone_pose_rotation(i)
		var angle:=rad_to_deg(_last_jump_q[i].angle_to(q))
		if v.skeleton.get_bone_name(i) not in ["Root","WeaponSocket","WeaponCarrier"]:_jump_section_angles[section]=maxf(_jump_section_angles.get(section,0.0),angle)
		if v.skeleton.get_bone_name(i) not in ["Root","WeaponSocket","WeaponCarrier"] and angle>_jump_max_step:
			_jump_max_step=angle;_jump_worst={"bone":v.skeleton.get_bone_name(i),"angle":angle,"state":actor.jump_state,"age":actor.jump_age,"section":section,"time":actor.simulation_time,"delta":v.pose_delta}
		_last_jump_q[i]=q
	if actor.is_on_floor() and actor.jump_state in ["GROUND","LAND","PREP"]:
		for p in v.last_sole:
			if -p.y>_jump_floor_error:
				_jump_floor_error=-p.y;_floor_worst={"sole":p,"state":actor.jump_state,"age":actor.jump_age,"floor":actor.floor_y,"position":actor.position,"section":section,"time":actor.simulation_time}
	var hip_y: float=(v.skeleton.global_transform*v.skeleton.get_bone_global_pose(v.hips)).origin.y-actor.position.y
	_jump_hip_min=minf(_jump_hip_min,hip_y);_jump_hip_max=maxf(_jump_hip_max,hip_y)
	jump_samples.append({"time":actor.simulation_time,"state":actor.jump_state,"age":actor.jump_age,"frame":v.jump_frame,"y":actor.position.y,"z":actor.position.z,"vy":actor.velocity.y,"speed":actor.current_speed,"phase":v.gait_phase,"support":[v.foot_support[0],v.foot_support[1]],"floor":actor.floor_y,"hip_y":hip_y,"settling":v.settling,"sole_y":[v.last_sole[0].y,v.last_sole[1].y],"contact_clamps":v.correction_clamps})

func _wait_state(value: String, maximum: int=180) -> bool:
	var limit:=Engine.get_physics_frames()+maximum
	while actor.jump_state!=value and Engine.get_physics_frames()<limit:await tick(1)
	return actor.jump_state==value

func _jump_case(test: SceneTree, name: String, move: Vector2, run: bool, height: float=1.2) -> Dictionary:
	actor.requested_direction=Vector2.ZERO;actor.requested_run=false
	await tick(65,"Rest before "+name)
	actor.jump_height=height;actor.requested_direction=move;actor.requested_run=run
	await tick(35,"Approach "+name)
	var start_time: float=actor.simulation_time;var start_pos: Vector3=actor.position
	actor.request_jump()
	await tick(2,name+" anticipation")
	test.check(actor.jump_state=="PREP","Compact grounded preparation: "+name)
	if not move.is_zero_approx():test.check(actor.position.distance_to(start_pos)>.01,"Horizontal control stays live during preparation: "+name)
	test.check(await _wait_state("AIR",30),"Actual impulse starts flight: "+name)
	var launch_time: float=actor.simulation_time
	test.check(launch_time-start_time<=.26,"Launch responds within 260ms including sampling: "+name)
	var peak: float=actor.position.y;var phase_before: float=actor.visual.gait_phase
	var limit:=Engine.get_physics_frames()+120
	while actor.jump_state=="AIR" and Engine.get_physics_frames()<limit:
		peak=maxf(peak,actor.position.y);await tick(1,name+" flight")
	test.check(actor.jump_state=="LAND" and actor.is_on_floor(),"Collision, not fixed clip duration, starts landing: "+name)
	var contact_time: float=actor.simulation_time
	var flight: float=actor.simulation_time-launch_time
	test.check(flight<1.1 and flight>.15,"Flight duration follows the ballistic test: "+name)
	test.check(absf(peak-start_pos.y-height)<.025,"Capsule elevation matches physics height without a duplicate animation arc: "+name)
	if not move.is_zero_approx():test.check(absf(wrapf(actor.visual.gait_phase-phase_before,-.5,.5))>.01,"Moving gait clock advances through flight: "+name)
	await tick(9,name+" impact")
	var impact_hip_min:=100.0
	for sample in jump_samples:
		if sample.time>=contact_time and sample.state=="LAND":impact_hip_min=minf(impact_hip_min,sample.hip_y)
	test.check(actor.visual.jump_frame>=51 and actor.visual.jump_frame<=55,"Impact reaches heavy compression after contact: "+name)
	await tick(48,name+" recovery")
	test.check(actor.jump_state=="GROUND","Recovery returns to the live locomotion system: "+name)
	if not move.is_zero_approx():test.check(actor.current_speed>1.0 and not actor.visual.settling,"Moving landing keeps input and gait active: "+name)
	var record:={"case":name,"flight_seconds":flight,"launch_delay":launch_time-start_time,"peak_y":peak,"height_setting":height,"impact_hip_min":impact_hip_min}
	jump_cases.append(record);return record

func run_jump_validation(test: SceneTree) -> void:
	actor.scripted_input=true
	await tick(8,"Initial ground")
	test.check(actor.review_pace==1.5,"Walk/Run retain requested1.5x pace")
	test.check(actor.visual.jump_clip.clip.loop_mode==Animation.LOOP_NONE,"Pending jump source is non-looping; no93-frame repeated arc")
	var normal:=await _jump_case(test,"Stationary",Vector2.ZERO,false)
	await _jump_case(test,"Walking",Vector2(0,1),false)
	await _jump_case(test,"Running",Vector2(0,1),true)
	var short_jump:=await _jump_case(test,"Short ballistic jump",Vector2.ZERO,false,.22)
	test.check(short_jump.flight_seconds<normal.flight_seconds*.7,"Earlier physical touchdown shortens flight without completing the source clip")
	actor.jump_height=1.2;actor.requested_direction=Vector2(0,1);actor.requested_run=true
	await tick(30,"Repeated running jumps")
	var previous_jumps: int=actor.jump_count
	for i in 3:
		actor.request_jump();test.check(await _wait_state("AIR",35),"Repeated jump launches %d"%i)
		test.check(await _wait_state("LAND",90),"Repeated jump contacts %d"%i)
		await tick(8,"Repeat interrupts landing recovery")
	test.check(actor.jump_count==previous_jumps+3,"Repeated jumps consume one impulse each without double jump")
	await tick(60,"Repeated jump recovery")
	actor.request_jump();await _wait_state("AIR",35)
	while actor.jump_state=="AIR" and actor.time_to_contact>.07:await tick(1,"Buffered input before touchdown")
	var buffered_count: int=actor.jump_count;actor.request_jump()
	test.check(await _wait_state("LAND",20),"Buffered jump still receives physical impact first")
	test.check(await _wait_state("PREP",20),"Pre-contact jump buffer survives minimum landing absorption")
	test.check(await _wait_state("AIR",35) and actor.jump_count==buffered_count+1,"Buffered repeat starts exactly one next impulse")
	await _wait_state("LAND",90);await tick(60,"Buffered repeat recovery")
	for phase in [.1,.6]:
		await _wait_state("GROUND",35)
		actor.visual.gait_phase=phase;actor.visual.foot_support[0]=false;actor.visual.foot_support[1]=false;actor.visual.pose_dirty=true
		await tick(1,"Receiving phase %.1f"%phase)
		actor.request_jump()
		test.check(await _wait_state("AIR",35),"Jump launches from either receiving-foot phase %.1f"%phase)
		test.check(await _wait_state("LAND",90),"Either receiving-foot phase reaches physical contact %.1f"%phase)
		await tick(40,"Moving lead-foot recovery %.1f"%phase)
		test.check(actor.current_speed>3 and not actor.visual.settling,"Either lead-foot landing rejoins live Run %.1f"%phase)
	actor.requested_direction=Vector2.ZERO;actor.requested_run=false;await tick(60)
	actor.position=Vector3(3,0,1);actor.velocity=Vector3.ZERO;actor.reset_jump()
	await tick(15,"Platform approach")
	actor.requested_direction=Vector2(0,1);actor.requested_run=true;await tick(8)
	actor.request_jump();test.check(await _wait_state("AIR",35),"Platform jump launches")
	test.check(await _wait_state("LAND",100),"Raised platform causes actual early collision landing")
	test.check(actor.floor_y>.65,"Landing support height follows the raised platform")
	test.check(await _wait_state("AIR",50),"Running off the platform during recovery immediately restores AIR")
	test.check(await _wait_state("LAND",70),"Second physical contact after the ledge triggers a new impact")
	test.check(actor.floor_y<.01,"Contact plane returns to the actual lower floor")
	actor.requested_direction=Vector2.ZERO;await tick(70,"Platform impact recovery")
	actor.gravity=6;actor.requested_run=true;actor.requested_direction=Vector2.ZERO;actor.review_drop(36)
	test.check(actor.visual.jump_frame==43,"Unprepared falls enter lowered-arm approach directly instead of replaying takeoff or recovery")
	await tick(195,"Extended fall beyond source duration")
	test.check(actor.jump_state=="AIR" and not actor.is_on_floor(),"Long fall stays airborne beyond93-frame source duration")
	var prior: Vector3=actor.position;actor.requested_direction=Vector2(1,0)
	await tick(5,"Airborne input response")
	test.check(actor.position.x-prior.x>.02,"Airborne input responds within five physics ticks")
	test.check(await _wait_state("LAND",100),"Long fall waits for actual floor contact")
	actor.gravity=18;await tick(60,"Long fall running recovery")
	actor.requested_direction=Vector2.ZERO;await tick(60)
	actor.set_review_weapon(true);await tick(20,"Rifle layer before jump")
	actor.request_jump();test.check(await _wait_state("AIR",35),"Existing weapon carry allows jump")
	await tick(15,"Rifle layer in flight")
	test.check(actor.visual.socket.visible and actor.visual.weapon_equipped,"Weapon socket and carry remain available in flight")
	test.check(actor.visual.r13_mask.find(actor.visual.leg_left)<0 and actor.visual.r13_mask.find(actor.visual.hips)<0,"Weapon upper mask still excludes jump support bones")
	await _wait_state("LAND",90);await tick(65,"Weapon landing recovery")
	actor.set_review_weapon(false);await tick(20)
	test.check(_max_scale_error<.00001,"Rigid cuboid scale preserved in every jump phase")
	test.check(_jump_floor_error<.008,"Grounded jump soles remain within8mm floor tolerance")
	test.check(_jump_max_step<60,"No extreme single-frame jump joint reset above60degrees")
	test.check(_maximum_flight_phase_error<.03,"Flight and landing advance the shared gait phase without resets")
	test.check(_sections["Stationary impact"].max_sole_speed_mps<.01,"Stationary impact maintains planted contact centers")
	jump_measurements={"cases":jump_cases,"events":actor.jump_events,"samples":jump_samples,"maximum_joint_step_degrees":_jump_max_step,"worst_joint":_jump_worst,"section_angle_maxima":_jump_section_angles,"maximum_flight_phase_error":_maximum_flight_phase_error,"contact_sections":_sections,"maximum_ground_penetration_m":_jump_floor_error,"worst_floor":_floor_worst,"maximum_scale_error":_max_scale_error,"maximum_contact_residual_m":actor.visual.contact_drift,"correction_clamps":actor.visual.correction_clamps,"source_status":"pending","production_replaced":false}

func run_demo() -> void:
	if not jump_enabled:super.run_demo();return
	demo_running=true;actor.scripted_input=true;reset_actor()
	await tick(65,"Idle 1× · Jump V2 Pending")
	actor.request_jump();await tick(95,"Standing · soft takeoff / open flight / impact")
	actor.requested_direction=Vector2(0,1);await tick(50,"Walk1.5× → jump")
	actor.request_jump();await tick(95,"Walking jump · continuous control")
	actor.requested_run=true;await tick(40,"Run1.5× → jump")
	actor.request_jump();await tick(90,"Running jump · impact back into gait")
	actor.request_jump();await tick(90,"Repeated running jump")
	actor.requested_direction=Vector2.ZERO;actor.requested_run=false;await tick(65,"Recovery to normal-speed Idle")
	camera_offset=Vector3(6,1.5,0);actor.requested_direction=Vector2(0,1);actor.requested_run=true;await tick(35,"Side · approach")
	actor.request_jump();await tick(95,"Side · physics-driven expressive jump")
	actor.requested_direction=Vector2.ZERO;await tick(60)
	camera_offset=Vector3(0,1.5,6);actor.request_jump();await tick(100,"Front · strong airborne silhouette")
	actor.review_drop(6);await tick(120,"6m fall · actual contact / heavy recovery")
	actor.scripted_input=false;demo_running=false;section="Manual review"
	if "--expressive-demo" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://.validation/expressive_jump_v1")
		FileAccess.open("res://.validation/expressive_jump_v1/movie_telemetry.json",FileAccess.WRITE).store_string(JSON.stringify(jump_samples))
		get_tree().quit()
