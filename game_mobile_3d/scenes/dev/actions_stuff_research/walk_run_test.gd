extends Node3D
## Research scene inside the existing game. F6 here; F5 remains WorldMap.
const PLAYER=preload("res://scenes/dev/ExpressiveLocomotionPlayer.tscn")
const SOURCE_VISUAL=preload("res://scenes/dev/actions_stuff_research/jump_locomotion_visual.gd")
const SOURCE_ACTOR=preload("res://scenes/dev/actions_stuff_research/source_jump_actor.gd")
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var azimuth:=.66
var elevation:=.40
var camera_size:=5.1
var orbiting:=false
func _ready() -> void:
	_build_environment()
	player=PLAYER.instantiate();player.name="ResearchPlayer"
	player.set_script(SOURCE_ACTOR)
	player.get_node("Visual").set_script(SOURCE_VISUAL)
	player.get_node("Visual").authored_locomotion=true;player.get_node("Visual").generic_weapon_carry=true;player.get_node("Visual").long_gun_carry_v2=true;player.get_node("Visual").weapon_equipped=false
	player.review_pace=1.;player.walk_speed=1.8;player.run_speed=5.031;player.acceleration=32.;player.deceleration=28.
	add_child(player)
	camera=Camera3D.new();camera.name="GameplayCamera";camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=camera_size;camera.far=150.;add_child(camera);camera.make_current()
	var layer:=CanvasLayer.new();add_child(layer)
	var panel:=PanelContainer.new();panel.position=Vector2(20,20);layer.add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.045,.055,.88);style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=12;style.content_margin_bottom=12;style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel",style)
	hud=Label.new();hud.add_theme_font_size_override("font_size",18);panel.add_child(hud)
	_update_camera()
func _build_environment() -> void:
	var environment:=WorldEnvironment.new();var settings:=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(.17,.22,.26)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color(.78,.86,1.);settings.ambient_light_energy=.65
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=settings;add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-35,0);sun.light_color=Color(1.,.94,.85);sun.light_energy=1.3;sun.shadow_enabled=true;sun.directional_shadow_max_distance=35.;add_child(sun)
	var floor_body:=StaticBody3D.new();floor_body.name="FlatGround";add_child(floor_body)
	var shape:=BoxShape3D.new();shape.size=Vector3(200,.2,200)
	var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=-.1;floor_body.add_child(collision)
	var ground:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(200,200);ground.mesh=mesh
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.31,.38,.39);material.roughness=1.;ground.material_override=material;floor_body.add_child(ground)
	# Quiet metre markers reveal travel and sliding without competing with the pose.
	var lines:=ImmediateMesh.new();lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-50,51):
		lines.surface_add_vertex(Vector3(i,.002,-50));lines.surface_add_vertex(Vector3(i,.002,50))
		lines.surface_add_vertex(Vector3(-50,.002,i));lines.surface_add_vertex(Vector3(50,.002,i))
	lines.surface_end();var grid:=MeshInstance3D.new();grid.mesh=lines
	var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.albedo_color=Color(.36,.43,.44);grid.material_override=ink;add_child(grid)
func _process(_delta: float) -> void:
	if player==null:return
	_update_camera()
	var visual=player.visual
	# Camera orbit is observational; locomotion owns the character's heading.
	var state:="RUN" if visual.gait_run_weight>.98 else ("WALK ↔ RUN" if visual.gait_run_weight>.02 else "WALK")
	if not visual.move_requested:state="SETTLING" if visual.settling else "IDLE"
	if visual.jump_active:
		state="LANDING" if visual.jump_grounded else ("TAKEOFF / RISE" if player.velocity.y>0 else "AIRBORNE / FALL")
	var variables: Dictionary=visual.direction_snapshot.get("vars",{})
	hud.text="ACTIONS & STUFF · LOCOMOTION RESEARCH\n%s   |   %.2f m/s   |   %.2f cycles/s\nPhase %.2f · F %.2f / Side %.2f\nWASD Walk · Shift Run · Space Jump · R Reset\nRight-drag Orbit · Wheel Zoom"%[state,player.current_speed,visual.gait_frequency,visual.gait_phase,variables.get("v.cknrcn",0.),variables.get("v.mrmeib",0.)]
func _update_camera() -> void:
	var target:=player.global_position+Vector3(0,.95,0)
	camera.global_position=target+Vector3(sin(azimuth)*cos(elevation),sin(elevation),cos(azimuth)*cos(elevation))*8.
	camera.look_at(target,Vector3.UP);camera.size=camera_size
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_test"):reset_player()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:orbiting=event.pressed
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:camera_size=maxf(3.6,camera_size-.3)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera_size=minf(8.,camera_size+.3)
	if event is InputEventMouseMotion and orbiting:
		azimuth-=event.relative.x*.006;elevation=clampf(elevation+event.relative.y*.004,.15,.75)
func reset_player() -> void:
	player.global_position=Vector3.ZERO;player.velocity=Vector3.ZERO;player.current_speed=0.;player.reset_jump_motion();player.visual.reset_contacts()
