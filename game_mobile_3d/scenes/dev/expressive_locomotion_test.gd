extends Node3D
## Flat-ground, reversible integration lab. F6 runs only this scene.
var actor: CharacterBody3D
var camera: Camera3D
var status: Label
var section:="Manual review"
var measurements: Dictionary={}
var demo_running:=false
var camera_offset:=Vector3(4,3.1,5)
var _elapsed:=0.0
var _telemetry: Array=[]
var _previous_q: Array[Quaternion]=[]
var _max_angle_step:=0.0
var _worst_angle: Dictionary={}
var _measured_sequence:=-1
var _sections: Dictionary={}
var _max_sole_speed:=0.0
var _last_support: Array[bool]=[false,false]
var _last_contact: Array[int]=[-1,-1]
var _last_feet: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var _max_floor_penetration:=0.0
var _max_scale_error:=0.0
var _max_hip_gap:=0.0
var _armed:=false
var _phase_cases: Array=[]
var jump_enabled:=true
var review_player_scene:="res://scenes/dev/ExpressiveJumpPlayer.tscn"
var jump_review_note:="Jump V2 Pending"
var review_title:="EXPRESSIVE JUMP · GAMEPLAY TEST"
func _ready() -> void:
	process_priority=100
	var world:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(.13,.18,.22)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.7,.8,1);env.ambient_light_energy=.65
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	world.environment=env;add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-35,0);sun.light_energy=1.35;sun.shadow_enabled=true;sun.directional_shadow_max_distance=25;add_child(sun)
	var ground:=StaticBody3D.new();ground.name="ReviewGround";add_child(ground)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(500,.2,500);shape.shape=box;shape.position.y=-.1;ground.add_child(shape)
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(500,500);floor_mesh.mesh=plane
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.32,.37,.38);material.roughness=1;floor_mesh.material_override=material;ground.add_child(floor_mesh)
	var lines:=MeshInstance3D.new();var mesh:=ImmediateMesh.new();var line_material:=StandardMaterial3D.new();line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;line_material.albedo_color=Color(.38,.43,.44)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,line_material)
	for i in range(-30,31):
		mesh.surface_add_vertex(Vector3(i,.002,-30));mesh.surface_add_vertex(Vector3(i,.002,30))
		mesh.surface_add_vertex(Vector3(-30,.002,i));mesh.surface_add_vertex(Vector3(30,.002,i))
	mesh.surface_end();lines.mesh=mesh;add_child(lines)
	var player_path:=review_player_scene if jump_enabled else "res://scenes/dev/ExpressiveLocomotionPlayer.tscn"
	actor=load(player_path).instantiate();add_child(actor)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.3;camera.current=true;camera.far=80;add_child(camera)
	var canvas:=CanvasLayer.new();add_child(canvas)
	var panel:=VBoxContainer.new();panel.position=Vector2(22,16);canvas.add_child(panel)
	var title:=Label.new();title.text=review_title if jump_enabled else "EXPRESSIVE LOCOMOTION  |  GODOT TEST";title.add_theme_font_size_override("font_size",20 if jump_enabled else 24);panel.add_child(title)
	status=Label.new();status.add_theme_font_size_override("font_size",15 if jump_enabled else 19)
	if jump_enabled:status.custom_minimum_size.x=410;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status)
	var help:=Label.new();help.text="WASD / arrows: move   Shift: run   R: reset   F9: demo\n1: front   2: three-quarter   3: side   E: rifle layer   T: compare pace\n"+("Space: jump · L: drop test · "+jump_review_note if jump_enabled else "Idle: normal speed · no Jump · production unchanged")
	if jump_enabled:help.custom_minimum_size.x=410;help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(help)
	var controls:=HBoxContainer.new();panel.add_child(controls)
	var labels:=["Front","3/4","Side","Demo","Reset"] if jump_enabled else ["Front","3/4","Side","Demo","Reset","Rifle layer","Compare pace"]
	for label in labels:
		var button:=Button.new();button.text=label;controls.add_child(button)
		button.pressed.connect(_button.bind(label))
	var slider:=HSlider.new();slider.min_value=.2;slider.max_value=1;slider.step=.05;slider.value=1;slider.custom_minimum_size=Vector2(260,24)
	if jump_enabled:panel.add_child(slider)
	else:controls.add_child(slider)
	slider.value_changed.connect(func(value:float):actor.analog_strength=value)
	var touch:=HBoxContainer.new();touch.position=Vector2(22,620);canvas.add_child(touch)
	for pair in [["←","move_left"],["↑","move_forward"],["↓","move_backward"],["→","move_right"],["RUN","sprint"]]:
		var button:=Button.new();button.text=pair[0];button.custom_minimum_size=Vector2(68,55);touch.add_child(button)
		button.button_down.connect(func():Input.action_press(pair[1]))
		button.button_up.connect(func():Input.action_release(pair[1]))
	for i in actor.visual.skeleton.get_bone_count():_previous_q.append(actor.visual.skeleton.get_bone_pose_rotation(i))
	_update_camera(1)
	if "--expressive-pace-1" in OS.get_cmdline_user_args():actor.review_pace=1.0;actor.visual.review_pace=1.0
	if "--expressive-pace-2" in OS.get_cmdline_user_args():actor.review_pace=2.0;actor.visual.review_pace=2.0
	if "--expressive-demo" in OS.get_cmdline_user_args():call_deferred("run_demo")

func _button(label: String) -> void:
	match label:
		"Front":camera_offset=Vector3(0,1.5,6)
		"3/4":camera_offset=Vector3(4,3.1,5)
		"Side":camera_offset=Vector3(6,1.5,0)
		"Demo":if not demo_running:run_demo()
		"Reset":reset_actor()
		"Rifle layer":_armed=not _armed;actor.set_review_weapon(_armed)
		"Compare pace":actor.review_pace=1.0 if actor.review_pace>=2.0 else actor.review_pace+.5
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():return
	match event.physical_keycode:
		KEY_1:_button("Front")
		KEY_2:_button("3/4")
		KEY_3:_button("Side")
		KEY_F9:_button("Demo")
		KEY_R:_button("Reset")
		KEY_E:_button("Rifle layer")
		KEY_T:_button("Compare pace")
func _update_camera(_delta: float) -> void:
	var target:=actor.global_position+Vector3(0,.95,0)
	camera.position=target+camera_offset;camera.look_at(target)
func _process(delta: float) -> void:
	_elapsed+=delta;_update_camera(delta)
	var v=actor.visual
	status.text="%s · %.1f× travel / gait · Idle 1×\nSpeed %.2f m/s   Run %.0f%%   Phase %.3f   Support %s%s\n%s"%[section,actor.review_pace,actor.current_speed,v.gait_run_weight*100,v.gait_phase,"L " if v.support_left else "","R" if v.support_right else "",("Idle look-around" if not v.move_requested and not v.settling else ("Single-foot replant" if v.settling else "Distance-driven gait"))]
	if delta>.00001 and _measured_sequence!=v.pose_sequence:
		_measured_sequence=v.pose_sequence
		var elapsed: float=v.pose_delta
		if not _sections.has(section):_sections[section]={"max_sole_speed_mps":0.0,"clamps_at_start":v.correction_clamps,"max_correction_m":0.0}
		for i in v.skeleton.get_bone_count():
			var q: Quaternion=v.skeleton.get_bone_pose_rotation(i)
			var angle:=rad_to_deg(_previous_q[i].angle_to(q))
			if v.skeleton.get_bone_name(i) not in ["Root","WeaponSocket","WeaponCarrier"] and angle>_max_angle_step:_max_angle_step=angle;_worst_angle={"bone":v.skeleton.get_bone_name(i),"section":section,"time":_elapsed,"pose_delta":elapsed,"weapon":v.weapon_equipped,"layer":v.review_weapon_weight,"switch":v.switch_weight,"move":v.move_weight,"mode":v.r13_mode,"transition_age":v.transition_age,"base_angle":rad_to_deg(_previous_q[i].angle_to(v._q[i]))}
			_previous_q[i]=q
			_max_scale_error=maxf(_max_scale_error,(v.skeleton.get_bone_pose_scale(i)-Vector3.ONE).length())
		for side in 2:
			var p: Vector3=v.last_sole[side]
			_max_floor_penetration=maxf(_max_floor_penetration,-p.y)
			if v.foot_support[side] and _last_support[side] and not v.settling and _last_contact[side]==v.contact_ids[side]:
				var speed:=p.distance_to(_last_feet[side])/elapsed
				_max_sole_speed=maxf(_max_sole_speed,speed);_sections[section].max_sole_speed_mps=maxf(_sections[section].max_sole_speed_mps,speed)
			_last_feet[side]=p;_last_support[side]=v.foot_support[side] and not v.settling
			_last_contact[side]=v.contact_ids[side]

func reset_actor() -> void:
	actor.position=Vector3.ZERO;actor.velocity=Vector3.ZERO
	if actor.has_method("reset_jump"):actor.reset_jump()
	actor.visual.foot_support[0]=false;actor.visual.foot_support[1]=false;actor.visual.pose_dirty=true
	actor.visual.attention_time=0;actor.visual.contact_drift=0
	section="Manual review"

func tick(count: int, label: String="") -> void:
	if label!="":section=label
	var end_tick:=Engine.get_physics_frames()+count
	while Engine.get_physics_frames()<end_tick:
		await get_tree().process_frame
		var v=actor.visual
		_telemetry.append({"time":_elapsed,"section":section,"speed":actor.current_speed,"phase":v.gait_phase,"run":v.gait_run_weight,"moving":v.move_requested,"settling":v.settling,"position":[actor.position.x,actor.position.y,actor.position.z],"L":v.support_left,"R":v.support_right})

func run_validation(test: SceneTree) -> void:
	actor.scripted_input=true
	await tick(6,"Rest")
	for idle_time in [1.0,4.1,6.0]:
		actor.visual.attention_time=idle_time
		actor.visual.pose_dirty=true
		await tick(4,"Idle observation interruption")
		var start: Vector3=actor.position
		actor.requested_direction=Vector2(0,1)
		await tick(2)
		test.check(actor.position.distance_to(start)>.001,"Movement responds within two physics ticks at Idle %.1fs"%idle_time)
		await tick(48,"Walk start and stable support")
		await tick(50,"Walk stable support")
		actor.requested_run=true
		var phase_before: float=actor.visual.gait_phase
		await tick(1,"Walk to Run")
		test.check(fposmod(actor.visual.gait_phase-phase_before,1)<.06*actor.review_pace,"Walk to Run preserves continuous gait phase")
		await tick(70,"Run stable support and flight")
		test.check(absf(actor.current_speed-2.31*actor.review_pace)<.03,"Run reaches pace-scaled stride matching speed")
		test.check(absf(actor.visual.gait_frequency-1.5*actor.review_pace)<.01,"Run cadence matches travel at selected pace")
		actor.requested_run=false
		await tick(40,"Run to Walk deceleration")
		test.check(absf(actor.current_speed-.9*actor.review_pace)<.03,"Walk reaches pace-scaled stride matching speed")
		test.check(absf(actor.visual.gait_frequency-actor.review_pace/1.2)<.01,"Walk cadence matches travel at selected pace")
		actor.requested_direction=Vector2.ZERO
		await tick(50,"Stop / individual replant")
		test.check(not actor.visual.settling and not actor.visual.move_requested,"Stop settles back to planted Idle")
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]:
		actor.requested_direction=direction;actor.requested_run=true
		await tick(40,"Direction change including reversal")
	actor.requested_direction=Vector2.ZERO;actor.requested_run=false
	await tick(50,"Final settle")
	for desired_phase in [.1,.6,.45,.95]:
		actor.requested_direction=Vector2(0,1);actor.requested_run=true
		await tick(55,"Both-lead / flight stop preparation")
		var timeout:=0
		while absf(wrapf(actor.visual.gait_phase-desired_phase,-.5,.5))>.04 and timeout<100:
			await tick(1);timeout+=1
		_phase_cases.append({"phase":actor.visual.gait_phase,"left":actor.visual.support_left,"right":actor.visual.support_right})
		actor.requested_direction=Vector2.ZERO;actor.requested_run=false
		await tick(50,"Stop from phase %.2f"%desired_phase)
		test.check(not actor.visual.move_requested and not actor.visual.settling,"Run stop settles from phase %.2f"%desired_phase)
	for i in 4:
		actor.requested_direction=Vector2(0,-1);await tick(4,"Short tap / interruption during replant")
		actor.requested_direction=Vector2.ZERO;await tick(9)
	await tick(50)
	var phase_before: float=actor.visual.gait_phase
	actor.requested_direction=Vector2(0,-1);await tick(30,"Upper-body layer smoke test")
	var lower: Array=[]
	actor.set_review_weapon(true)
	await tick(15)
	for bone in [actor.visual.hips,actor.visual.leg_left,actor.visual.leg_right]:lower.append(actor.visual.skeleton.get_bone_pose_rotation(bone))
	test.check(actor.visual.weapon_equipped and actor.visual.socket.visible,"Existing rifle socket/upper layer remains available")
	test.check(actor.visual.r13_mask.find(actor.visual.hips)<0 and actor.visual.r13_mask.find(actor.visual.leg_left)<0,"Existing weapon mask excludes support bones")
	actor.set_review_weapon(false);actor.requested_direction=Vector2.ZERO;await tick(50)
	measurements={"max_joint_step_degrees":_max_angle_step,"worst_angle":_worst_angle,"phase_stop_cases":_phase_cases,"sections":_sections,"max_support_sole_speed_mps":_max_sole_speed,"maximum_floor_penetration_m":_max_floor_penetration,"maximum_scale_error":_max_scale_error,"maximum_contact_correction_m":actor.visual.maximum_correction,"correction_clamps":actor.visual.correction_clamps,"contact_anchor_residual_m":actor.visual.contact_drift,"transitions":actor.visual.transition_count,"frames":_telemetry}
	test.check(_max_scale_error<.00001,"All blocks remain rigid; no scale deformation")
	test.check(_sections["Walk stable support"].max_sole_speed_mps<.005,"Stable Walk contact-center drift under 5mm/s")
	test.check(_sections["Run stable support and flight"].max_sole_speed_mps<.005,"Stable Run contact-center drift under 5mm/s")
	test.check(_sections["Run to Walk deceleration"].max_sole_speed_mps<.02,"Run to Walk contact-center drift under 20mm/s")
	test.check(_max_floor_penetration<.008,"Flat-floor soles do not penetrate more than 8mm")
	test.check(_max_angle_step<35*actor.review_pace,"Joint rotation steps remain within the pace-scaled original bound")
	test.check(actor.visual.transition_count>=16,"Both starts/stops and short taps exercised")

func run_demo() -> void:
	demo_running=true;actor.scripted_input=true
	await tick(100,"Approved Idle · relaxed observation")
	actor.requested_direction=Vector2(0,1)
	await tick(140,"Idle → Walk · immediate attention interruption")
	actor.requested_run=true
	await tick(150,"Walk → Run V3 · matched receiving phase")
	actor.requested_direction=Vector2(1,1).normalized()
	await tick(65,"Run · diagonal direction change")
	actor.requested_run=false
	await tick(100,"Run → Walk · controlled deceleration")
	actor.requested_direction=Vector2.ZERO
	await tick(80,"Walk → Idle · individual foot replants")
	camera_offset=Vector3(6,1.5,0)
	actor.requested_direction=Vector2(0,1)
	await tick(90,"Side view · Walk contact")
	actor.requested_run=true;await tick(90,"Side view · Run contact and flight")
	actor.requested_direction=Vector2.ZERO;await tick(65,"Run → Idle · weighted stop")
	camera_offset=Vector3(0,1.5,6)
	actor.requested_direction=Vector2(0,1);actor.requested_run=false
	await tick(80,"Front view · expressive Walk")
	actor.requested_run=true;await tick(80,"Front view · expressive Run V3")
	actor.requested_direction=Vector2.ZERO;await tick(50,"Front view · recovery to Idle")
	actor.scripted_input=false;demo_running=false;section="Manual review"
	if "--expressive-demo" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://.validation/expressive_locomotion_v1")
		FileAccess.open("res://.validation/expressive_locomotion_v1/movie_telemetry.json",FileAccess.WRITE).store_string(JSON.stringify(_telemetry))
		get_tree().quit()
