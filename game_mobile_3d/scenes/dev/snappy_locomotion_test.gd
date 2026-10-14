extends Node3D
var review_player_scene_path:="res://scenes/dev/SnappyLocomotionPlayer.tscn"
var actor: CharacterBody3D
var camera: Camera3D
var status: Label
var section:="Manual play"
var camera_mode:=0
var demo_running:=false
var demo_time:=0.0
var capture_mode:=""
var measurements: Dictionary={"max_floor_penetration_m":0.0,"max_scale_error":0.0,"steady_support_speed_m_s":0.0,"steady_correction_clamps":0,"max_correction_m":0.0,"style_toggles":0,"max_bone_angle_per_frame_deg":0.0,"sections":{}}
var _sequence:=-1
var _last_p: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var _last_contact: Array[int]=[-1,-1]
var _last_support: Array[bool]=[false,false]
var _last_clamps:=0
var _last_q: Array[Quaternion]=[]
var _last_section:=""
var telemetry: Array=[]

func _ready() -> void:
	get_window().title="Snappy Locomotion - Gameplay A/B Test"
	process_priority=100
	var world:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(.12,.17,.21)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.7,.8,1);env.ambient_light_energy=.65
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;world.environment=env;add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-35,0);sun.light_energy=1.35;sun.shadow_enabled=true;add_child(sun)
	var ground:=StaticBody3D.new();ground.name="SnappyTestGround";add_child(ground)
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(500,.2,500);collider.shape=box;collider.position.y=-.1;ground.add_child(collider)
	var mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(500,500);mesh.mesh=plane
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.32,.37,.38);mat.roughness=1;mesh.material_override=mat;ground.add_child(mesh)
	var grid:=MeshInstance3D.new();var lines:=ImmediateMesh.new();var line_mat:=StandardMaterial3D.new();line_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;line_mat.albedo_color=Color(.40,.45,.46)
	lines.surface_begin(Mesh.PRIMITIVE_LINES,line_mat)
	for i in range(-60,61):
		lines.surface_add_vertex(Vector3(i,.002,-60));lines.surface_add_vertex(Vector3(i,.002,60))
		lines.surface_add_vertex(Vector3(-60,.002,i));lines.surface_add_vertex(Vector3(60,.002,i))
	lines.surface_end();grid.mesh=lines;add_child(grid)
	actor=load(review_player_scene_path).instantiate();add_child(actor)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.5;camera.far=100;camera.current=true;add_child(camera)
	var canvas:=CanvasLayer.new();add_child(canvas)
	var panel:=VBoxContainer.new();panel.position=Vector2(22,16);canvas.add_child(panel)
	var title:=Label.new();title.text="SNAPPY LOCOMOTION · GAMEPLAY A/B";title.add_theme_font_size_override("font_size",24);panel.add_child(title)
	status=Label.new();status.add_theme_font_size_override("font_size",18);panel.add_child(status)
	var help:=Label.new();help.text="WASD / arrows: move   Shift: run   Tab: Snappy / Expressive\n1: front   2: three-quarter   3: side   4: follow   R: reset   F9: demo   F8:30/60 FPS";panel.add_child(help)
	var buttons:=HBoxContainer.new();panel.add_child(buttons)
	for label in ["Switch style","Front","3/4","Side","Follow","Demo","Reset"]:
		var button:=Button.new();button.text=label;buttons.add_child(button);button.pressed.connect(_button.bind(label))
	for i in actor.visual.skeleton.get_bone_count():_last_q.append(actor.visual.skeleton.get_bone_pose_rotation(i))
	var args:=OS.get_cmdline_user_args()
	if "--capture-snappy" in args:capture_mode="snappy"
	if "--capture-expressive" in args:capture_mode="expressive";actor.visual.set_snappy(false);actor.visual.style_weight=0
	if "--capture-toggle" in args:capture_mode="toggle"
	if capture_mode!="":demo_running=true;actor.scripted_input=true
	_update_camera()

func _button(label: String) -> void:
	match label:
		"Switch style":actor.visual.set_snappy(not actor.visual.snappy_enabled)
		"Front":camera_mode=1
		"3/4":camera_mode=2
		"Side":camera_mode=3
		"Follow":camera_mode=0
		"Demo":demo_running=not demo_running;demo_time=0;actor.scripted_input=demo_running;actor.requested_direction=Vector2.ZERO;actor.requested_run=false
		"Reset":
			demo_running=false;actor.scripted_input=false;actor.position=Vector3.ZERO;actor.velocity=Vector3.ZERO
			actor.current_speed=0;actor.visual.reset_review();section="Manual play"

func _input(event: InputEvent) -> void:
	# Tab normally navigates GUI focus. Reserve this lab's A/B shortcut before
	# the HUD consumes it, including after clicking one of its buttons.
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_TAB:
		_button("Switch style");get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():return
	match event.physical_keycode:
		KEY_1:_button("Front")
		KEY_2:_button("3/4")
		KEY_3:_button("Side")
		KEY_4:_button("Follow")
		KEY_F9:_button("Demo")
		KEY_R:_button("Reset")
		KEY_F8:Engine.max_fps=30 if Engine.max_fps!=30 else 60

func _physics_process(delta: float) -> void:
	if not demo_running:return
	demo_time+=delta
	actor.requested_direction=Vector2.DOWN;actor.requested_run=false
	if demo_time<.8:actor.requested_direction=Vector2.ZERO;section="Calm Idle"
	elif demo_time<3.2:section="Walk · full target";camera_mode=2
	elif demo_time<6.2:actor.requested_run=true;section="Run · full target";camera_mode=3
	elif demo_time<7.2:section="Run to Walk";camera_mode=2
	elif demo_time<8.1:actor.requested_direction=Vector2.ZERO;section="Stop / replant"
	elif demo_time<9.5:actor.requested_direction=Vector2.RIGHT;actor.requested_run=true;section="Right turn";camera_mode=0
	elif demo_time<11:actor.requested_direction=Vector2.LEFT;actor.requested_run=true;section="Reversal"
	elif demo_time<12.2:actor.requested_direction=Vector2.UP;section="Direction change / Walk"
	elif demo_time<13.2:actor.requested_direction=Vector2.ZERO;section="Final settle";camera_mode=2
	else:
		demo_running=false;actor.scripted_input=false
		if capture_mode!="":
			DirAccess.make_dir_recursive_absolute("res://.validation/snappy_gameplay_v001")
			FileAccess.open("res://.validation/snappy_gameplay_v001/capture_"+capture_mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"measurements":measurements,"telemetry":telemetry,"seconds":demo_time,"original_speed":true,"time_scale":Engine.time_scale},"\t"));get_tree().quit()
	if capture_mode=="toggle":actor.visual.set_snappy(demo_time<4.2 or demo_time>=6.0)

func _update_camera() -> void:
	var target:=actor.global_position+Vector3(0,.96,0)
	var offset:=Vector3(4,3.0,5)
	match camera_mode:
		1:offset=Vector3(0,1.15,6).rotated(Vector3.UP,actor.visual.rotation.y)
		2:offset=Vector3(4,2.3,5).rotated(Vector3.UP,actor.visual.rotation.y)
		3:offset=Vector3(6,1.15,0).rotated(Vector3.UP,actor.visual.rotation.y)
	camera.position=target+offset;camera.look_at(target)

func _process(_delta: float) -> void:
	_update_camera()
	var v=actor.visual
	status.text="%s · matched travel speed\n%s   Speed %.2fm/s   Run %.0f%%   Phase %.3f   %s\nWalk + Run artistically approved · isolated gameplay test"%["SNAPPY" if v.snappy_enabled else "EXPRESSIVE",section,actor.current_speed,v.gait_run_weight*100,v.gait_phase,("30 FPS review / 1x" if capture_mode!="" else "FPS %.0f"%Engine.get_frames_per_second())]
	if _sequence==v.pose_sequence:return
	_sequence=v.pose_sequence
	var dt: float=v.pose_delta
	var steady:=section.begins_with("Stable")
	if not measurements.sections.has(section):measurements.sections[section]={"samples":0,"floor_penetration_m":0.0,"support_speed_m_s":0.0,"correction_clamps":0}
	var row: Dictionary=measurements.sections[section];row.samples+=1
	# Measure after the sole writer: SceneTree.process_frame resumes tests
	# before node processing, when the physics phase can already be ahead.
	row.latest_body_target_error_m=v.skeleton.get_bone_pose_position(v.hips).distance_to(v._target_pose(v.hips).origin)
	var new_clamps: int=v.correction_clamps-_last_clamps
	row.correction_clamps+=new_clamps
	if steady and _last_section==section:measurements.steady_correction_clamps+=new_clamps
	_last_clamps=v.correction_clamps
	for side in 2:
		var p: Vector3=v.last_sole[side]
		measurements.max_floor_penetration_m=maxf(measurements.max_floor_penetration_m,-p.y);row.floor_penetration_m=maxf(row.floor_penetration_m,-p.y)
		if v.foot_support[side] and _last_support[side] and _last_contact[side]==v.contact_ids[side] and not v.settling:
			var speed:=p.distance_to(_last_p[side])/dt
			row.support_speed_m_s=maxf(row.support_speed_m_s,speed)
			if steady and _last_section==section:measurements.steady_support_speed_m_s=maxf(measurements.steady_support_speed_m_s,speed)
		_last_p[side]=p;_last_contact[side]=v.contact_ids[side];_last_support[side]=v.foot_support[side] and not v.settling
	for i in v.skeleton.get_bone_count():
		measurements.max_scale_error=maxf(measurements.max_scale_error,(v.skeleton.get_bone_pose_scale(i)-Vector3.ONE).length())
		var q: Quaternion=v.skeleton.get_bone_pose_rotation(i)
		measurements.max_bone_angle_per_frame_deg=maxf(measurements.max_bone_angle_per_frame_deg,rad_to_deg(q.angle_to(_last_q[i])));_last_q[i]=q
	measurements.max_correction_m=v.maximum_correction;measurements.style_toggles=v.style_toggles;measurements.max_gait_handoff_wait_s=v.maximum_run_blend_wait;measurements.turn_release_count=v.turn_release_count
	_last_section=section
	telemetry.append({"section":section,"position":[actor.position.x,actor.position.y,actor.position.z],"style":v.style_weight,"run":v.gait_run_weight,"phase":v.gait_phase,"speed":actor.current_speed,"frequency":v.gait_frequency,"L":v.last_sole[0].y,"R":v.last_sole[1].y,"support":v.foot_support.duplicate(),"settling":v.settling,"transition_age":v.transition_age,"feet":[[v.last_sole[0].x,v.last_sole[0].y,v.last_sole[0].z],[v.last_sole[1].x,v.last_sole[1].y,v.last_sole[1].z]],"clamps":v.correction_clamps})
