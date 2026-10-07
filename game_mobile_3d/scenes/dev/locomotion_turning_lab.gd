extends Node3D
@onready var actor = $Actor
@onready var camera: Camera3D = $Camera3D
@onready var debug: Label = $HUD/Debug
var automated := false
var auto_sprint := false
var auto_time := 0.0
var auto_heading := PI
var path_index := 0
var circle_radius := 6.0
var camera_offset := Vector3(0,13,10)
var path_label := "Manual"
var paths := ["Sequence","CW circle","CCW circle"]

func _ready() -> void:
	DisplayServer.window_set_title("R4-G — Locomotion Turning Lab")
	make_grid()
	camera.position=actor.position+camera_offset;camera.look_at(actor.position+Vector3(0,0.9,0))
	print("R4G_LAB_READY — WASD move, Shift sprint, Tab A/B, F1 HUD, Space demo, F2 path, F3 auto gait, [ ] radius, R reset")
	if "--smoke" in OS.get_cmdline_user_args(): get_tree().call_deferred("quit")

func _physics_process(dt: float) -> void:
	var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT)
	if direction != Vector3.ZERO: automated=false
	if automated:
		auto_time+=dt; direction=auto_direction(dt); sprint=auto_sprint
	actor.step(dt,direction,sprint)
	# Translation only: camera axes never rotate with the character or demo path.
	camera.position=actor.position+camera_offset
	update_debug()

func auto_direction(dt: float) -> Vector3:
	var speed: float = actor.sprint_speed if auto_sprint else actor.walk_speed
	var rate := 0.0
	if path_index>0:
		rate=(-1.0 if path_index==1 else 1.0)*speed/circle_radius
		path_label=paths[path_index]+" r=%.1fm"%circle_radius
	else:
		var t := fmod(auto_time,36.0)
		if t<3: path_label="Straight"
		elif t<6: path_label="Left bend";rate=0.55
		elif t<9: path_label="Straight recovery"
		elif t<12: path_label="Right bend";rate=-0.55
		elif t<18: path_label="S-curve";rate=sin((t-12)*TAU/6)*0.8
		elif t<25: path_label="CW circle";rate=-speed/circle_radius
		elif t<32: path_label="CCW circle";rate=speed/circle_radius
		else: path_label="Straight recovery"
	auto_heading=wrapf(auto_heading+rate*dt,-PI,PI)
	return Vector3(sin(auto_heading),0,cos(auto_heading))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_TAB: actor.turning_enabled=not actor.turning_enabled
		KEY_F1: debug.visible=not debug.visible
		KEY_SPACE: automated=not automated;auto_heading=actor.visual.rotation.y;auto_time=0
		KEY_F2: path_index=(path_index+1)%paths.size();auto_heading=actor.visual.rotation.y;auto_time=0
		KEY_F3: auto_sprint=not auto_sprint
		KEY_BRACKETLEFT: circle_radius=maxf(1.5,circle_radius-0.5)
		KEY_BRACKETRIGHT: circle_radius=minf(20,circle_radius+0.5)
		KEY_C: camera.size=6.0 if camera.size>8 else 10.0
		KEY_R:
			actor.position=Vector3(0,0.02,0);actor.velocity=Vector3.ZERO;actor.visual.rotation.y=PI
			auto_heading=PI;auto_time=0
	update_debug()

func update_debug() -> void:
	debug.text="R4-G · LOCOMOTION TURNING LAB · AWAITING HUMAN REVIEW\nWASD move · Shift sprint · Tab A/B · F1 hide HUD · C close view · R reset\nSpace auto/manual · F2 sequence/CW/CCW · F3 auto Walk/Sprint · [ ] radius\n\n%s | %s | %s\nPhase %.3f · turn %+.3f (- left / + right) · yaw %+.1f°/s\nSpeed %.2f m/s · Sprint blend %.2f · cadence 1.0\n%s\n%s"%["B — TURNING BLEND" if actor.turning_enabled else "A — PATH/FACING ONLY","Sprint" if actor.sprint_weight>0.5 else "Walk",path_label if automated else "Manual",actor.phase,actor.turn_amount,rad_to_deg(actor.angular_velocity),actor.current_speed,actor.sprint_weight,actor.active_names(),"Auto radius %.1f m"%circle_radius if automated else "Release input: freeze gait pose; no idle/start/stop clip"]

func make_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-100,101,2):
		mesh.surface_add_vertex(Vector3(i,0.003,-100));mesh.surface_add_vertex(Vector3(i,0.003,100))
		mesh.surface_add_vertex(Vector3(-100,0.003,i));mesh.surface_add_vertex(Vector3(100,0.003,i))
	mesh.surface_end()
	var lines := MeshInstance3D.new();lines.mesh=mesh
	var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(0.31,0.39,0.43)
	lines.material_override=material;add_child(lines)
