extends Node3D
## Research scene inside the existing game. F6 here; F5 remains WorldMap.
const PLAYER=preload("res://scenes/dev/ExpressiveLocomotionPlayer.tscn")
const SOURCE_VISUAL=preload("res://scenes/dev/actions_stuff_research/idle_locomotion_visual.gd")
const SOURCE_ACTOR=preload("res://scenes/dev/actions_stuff_research/source_jump_actor.gd")
const RenderPresenter=preload("res://scenes/dev/actions_stuff_research/render_pose_presenter.gd")
const RIFLE_VISUAL=preload("res://scenes/dev/actions_stuff_research/rifle_ready_v001/rifle_visual.gd")
const RiflePresenter=preload("res://scenes/dev/actions_stuff_research/rifle_ready_v001/rifle_presenter.gd")
const RifleFire=preload("res://scenes/dev/actions_stuff_research/rifle_ready_v001/continuous_fire.gd")
const ZombieCombat=preload("res://scenes/dev/actions_stuff_research/zombie_combat/combat_group.gd")
const RifleAutoAim=preload("res://scenes/dev/actions_stuff_research/rifle_ready_v001/auto_aim.gd")
const SoldierLoadout=preload("res://scenes/dev/actions_stuff_research/soldier_loadout_v001/loadout.gd")
const SoldierAppearance=preload("res://scenes/dev/actions_stuff_research/soldier_loadout_v001/appearance.gd")
const GrassField=preload("res://scenes/dev/actions_stuff_research/grass_md2_v001/grass_field.gd")
const MD2Lighting=preload("res://scenes/dev/actions_stuff_research/lighting_md2_v001/lighting.gd")
const PerformanceCombat=preload("res://scenes/dev/actions_stuff_research/performance_lab_v001/combat_group.gd")
const PerformanceControls=preload("res://scenes/dev/actions_stuff_research/performance_lab_v001/controls.gd")
@export var performance_test_enabled:=false
var performance_controls:CanvasLayer
@export var md2_lighting_enabled:=false
var md2_lighting:Node
@export var grass_field_enabled:=false
@export var grass_vegetation_enabled:=true
var grass_field:Node3D
var grass_overview:=false
var soldier_appearance:Node
@export var soldier_loadout:=true
@export var rifle_ready:=true
@export var zombie_combat_enabled:=true
@export var auto_aim_enabled:=true
@export_range(.1,3.,.05) var movement_speed_multiplier:=1.5
@export_range(.1,3.,.05) var locomotion_animation_multiplier:=1.0
var presentation: Node
var rifle_fire: Node3D
var zombie_combat: Node3D
var rifle_auto_aim: Node
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var azimuth:=.66
var elevation:=.40
@export_range(3.6,24.,.1) var camera_size:=7.2
const CAMERA_DISTANCE:=10.0
var orbiting:=false
var _fire_key_held:=false
var _right_aim_held:=false
var _turn_left_held:=false
var _turn_right_held:=false
# Comfort rule: track travel independently from airborne capsule height.
# Normal 1.26m jumps fit inside this vertical zone without moving the camera.
var camera_anchor:=Vector3.ZERO
var _camera_initialized:=false
var _camera_vertical_velocity:=0.0
const CAMERA_HORIZONTAL_RESPONSE:=12.0
const CAMERA_VERTICAL_RESPONSE:=8.0
const CAMERA_AIR_UP_ZONE:=1.4
const CAMERA_AIR_DOWN_ZONE:=1.1
func _ready() -> void:
	_build_environment()
	player=PLAYER.instantiate();player.name="ResearchPlayer"
	player.set_script(SOURCE_ACTOR)
	player.get_node("Visual").set_script(RIFLE_VISUAL if rifle_ready else SOURCE_VISUAL)
	player.get_node("Visual").authored_locomotion=true;player.get_node("Visual").generic_weapon_carry=true;player.get_node("Visual").long_gun_carry_v2=true;player.get_node("Visual").weapon_equipped=false
	# Planar travel and rifle gait playback have independent, reversible tuning.
	player.review_pace=1.;player.walk_speed=1.8*movement_speed_multiplier;player.run_speed=5.031*movement_speed_multiplier;player.acceleration=40.*movement_speed_multiplier;player.deceleration=35.*movement_speed_multiplier
	player.get_node("Visual").travel_speed_scale=movement_speed_multiplier
	player.get_node("Visual").locomotion_playback_rate=locomotion_animation_multiplier if rifle_ready else 1.
	add_child(player)
	if rifle_ready:
		if soldier_loadout:
			SoldierLoadout.install_skin(player.visual)
			player.visual.activate_rifle_ready(SoldierLoadout.RIFLE)
		else:player.visual.activate_rifle_ready()
	camera=Camera3D.new();camera.name="GameplayCamera";camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=camera_size;camera.far=150.;add_child(camera);camera.make_current()
	var layer:=CanvasLayer.new();add_child(layer)
	var panel:=PanelContainer.new();panel.position=Vector2(20,20);panel.scale=Vector2(.25,.25);layer.add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.045,.055,.88);style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=12;style.content_margin_bottom=12;style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel",style)
	hud=Label.new();hud.add_theme_font_size_override("font_size",18);panel.add_child(hud)
	presentation=RiflePresenter.new() if rifle_ready else RenderPresenter.new();presentation.name="RenderPosePresentation";add_child(presentation)
	presentation.setup(player,player.visual);player.visual.presentation=presentation
	if rifle_ready:
		rifle_fire=RifleFire.new();rifle_fire.name="InfiniteRifleFire";add_child(rifle_fire);rifle_fire.setup(player)
		if performance_test_enabled:
			# Current combat-feel experiment only; shared weapon profiles stay exact.
			rifle_fire.level_trajectory=true
			rifle_fire.projectile_speed_multiplier=1.5
			rifle_fire.projectile_range_multiplier=3.
			var boundary:=get_node_or_null("FieldBoundary") as StaticBody3D
			if boundary!=null:
				var excluded:Array[RID]=rifle_fire.query.exclude
				excluded.append(boundary.get_rid());rifle_fire.query.exclude=excluded
		if zombie_combat_enabled:
			zombie_combat=PerformanceCombat.new() if performance_test_enabled else ZombieCombat.new();zombie_combat.name="ResearchZombieCombat";add_child(zombie_combat);zombie_combat.setup(player,rifle_fire.audio)
			if auto_aim_enabled:
				rifle_auto_aim=RifleAutoAim.new();rifle_auto_aim.name="NearestZombieAutoAim";add_child(rifle_auto_aim);rifle_auto_aim.setup(player,zombie_combat)
	if soldier_loadout and rifle_ready:
		soldier_appearance=SoldierAppearance.new();soldier_appearance.name="SoldierAppearance";add_child(soldier_appearance);soldier_appearance.setup(self)
	if grass_field_enabled:
		grass_field=GrassField.new();grass_field.name="MD2GrassField30x30";add_child(grass_field);grass_field.setup(player)
		if not grass_vegetation_enabled:
			# Keep terrain, meshes, shader and contact histories for later restoration.
			for child in grass_field.get_children():
				if child.name.begins_with("GrassRegion_"):child.hide()
			grass_field.enabled=false
			grass_field.set_process(false);grass_field.set_physics_process(false)
	if md2_lighting_enabled:
		md2_lighting=MD2Lighting.new();md2_lighting.name="GAF_MD2_Lighting_v001";add_child(md2_lighting);md2_lighting.setup(self,grass_field,not performance_test_enabled)
	if performance_test_enabled and zombie_combat!=null:
		performance_controls=PerformanceControls.new();performance_controls.name="PerformanceTestControls";add_child(performance_controls);performance_controls.setup(self)
	_update_camera()
func _build_environment() -> void:
	var environment:=WorldEnvironment.new();var settings:=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(.17,.22,.26)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color(.78,.86,1.);settings.ambient_light_energy=.65
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=settings;add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-35,0);sun.light_color=Color(1.,.94,.85);sun.light_energy=1.3;sun.shadow_enabled=true;sun.directional_shadow_max_distance=35.;add_child(sun)
	var floor_body:=StaticBody3D.new();floor_body.name="FlatGround";add_child(floor_body)
	# Same surface atY0; use the Lab's thicker contact slab and recovery bias
	# for its fast native corpse impulses. Player floor height/physics stay exact.
	var shape:=BoxShape3D.new();shape.size=Vector3(30 if grass_field_enabled else 200,.4,30 if grass_field_enabled else 200);shape.custom_solver_bias=.6
	var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=-.2;floor_body.add_child(collision)
	if grass_field_enabled:
		# Bounded playable field; same Y0 and floor solver. Four static edge shapes.
		# Separate invisible walls so dev bullets may fly beyond the arena edge.
		var boundary:=StaticBody3D.new();boundary.name="FieldBoundary";add_child(boundary)
		for edge in [Vector3(-15.2,.7,0),Vector3(15.2,.7,0),Vector3(0,.7,-15.2),Vector3(0,.7,15.2)]:
			var wall:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.4,2.,30.8) if edge.x!=0 else Vector3(30.8,2.,.4)
			wall.shape=box;wall.position=edge;boundary.add_child(wall)
		return
	var ground:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(200,200);ground.mesh=mesh
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.31,.38,.39);material.roughness=1.;ground.material_override=material;floor_body.add_child(ground)
	# Quiet metre markers reveal travel and sliding without competing with the pose.
	var lines:=ImmediateMesh.new();lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-50,51):
		lines.surface_add_vertex(Vector3(i,.002,-50));lines.surface_add_vertex(Vector3(i,.002,50))
		lines.surface_add_vertex(Vector3(-50,.002,i));lines.surface_add_vertex(Vector3(50,.002,i))
	lines.surface_end();var grid:=MeshInstance3D.new();grid.mesh=lines
	var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.albedo_color=Color(.36,.43,.44);grid.material_override=ink;add_child(grid)
func _process(delta: float) -> void:
	if player==null:return
	presentation.prepare(Engine.get_physics_interpolation_fraction())
	if rifle_fire!=null:rifle_fire.present(presentation)
	_update_camera(delta,presentation.display_actor)
	var visual=player.visual
	# Camera orbit is observational; Q/C and auto-aim own stationary look intent.
	var state:="RUN" if visual.gait_run_weight>.98 else ("WALK ↔ RUN" if visual.gait_run_weight>.02 else "WALK")
	if not visual.move_requested:state="SETTLING" if visual.settling else "IDLE"
	if visual.idle_active and not visual.move_requested:state="RIFLE READY · IDLE" if rifle_ready else "IDLE · LOOK AROUND"
	if visual.jump_active:
		state="LANDING" if visual.jump_grounded else ("TAKEOFF / RISE" if player.velocity.y>0 else "AIRBORNE / FALL")
	if rifle_ready and visual.rifle_aim_weight>.001:state+=" · AIM" if visual.rifle_aim_weight>.999 else " · READY ↔ AIM"
	if rifle_fire!=null and rifle_fire.trigger_held:state+=" · FIRING" if visual.rifle_aim_weight>=.999 else " · RAISING TO FIRE"
	var variables: Dictionary=visual.direction_snapshot.get("vars",{})
	hud.text=("RIFLE READY / AIM / FIRE · INFINITE AMMO ∞" if rifle_ready else "ACTIONS & STUFF · LOCOMOTION RESEARCH")+"\n%s   |   %.2f m/s   |   %.2f cycles/s\nPhase %.2f · F %.2f / Side %.2f\nWASD Walk · Shift Run · Space Jump · R Reset\nHold E Aim + Fire · Right Mouse Aim / Orbit\nWheel Zoom"%[state,player.current_speed,visual.gait_frequency,visual.gait_phase,variables.get("v.cknrcn",0.),variables.get("v.mrmeib",0.)]
	if zombie_combat!=null:
		var capacity:int=zombie_combat.spawn_count if performance_test_enabled else ZombieCombat.MAX_RAGDOLLS
		hud.text+="\nZombies %d · Corpses %d / %d · Cleared %d · R Restart"%[zombie_combat.living_count(),zombie_combat.active_ragdolls(),capacity,zombie_combat.kills]
	if rifle_auto_aim!=null:hud.text+="\nAuto-aim: "+(rifle_auto_aim.target.name if is_instance_valid(rifle_auto_aim.target) else "nearest zombie while aiming")
	if rifle_ready:hud.text+="\nQ / C Turn in place · head leads, feet correct >60°"
	if grass_field!=null:hud.text+="\n30 × 30 BLOCKS · "+("STRONG WIND + PLAYER WAKE" if grass_vegetation_enabled else "GRASS PAUSED")+" · V Overview"
func _update_camera(delta: float=1./60.,display_position: Variant=null) -> void:
	if grass_field!=null and grass_overview:
		camera.global_position=Vector3(24,30,24);camera.look_at(Vector3(0,.5,0));camera.size=43.;return
	var target: Vector3=(player.global_position if display_position==null else display_position)+Vector3(0,.95,0)
	# Actual ground contact owns floor elevation; do not follow the last airborne
	# display sample upward on the landing frame.
	if player.visual.jump_grounded: target.y=player.global_position.y+.95
	if not _camera_initialized:
		camera_anchor=target;_camera_initialized=true;_camera_vertical_velocity=0.
	var horizontal:=1.-exp(-CAMERA_HORIZONTAL_RESPONSE*delta)
	camera_anchor.x=lerpf(camera_anchor.x,target.x,horizontal)
	camera_anchor.z=lerpf(camera_anchor.z,target.z,horizontal)
	var height:=target.y
	if not player.visual.jump_grounded:
		# Keep the current anchor until the character leaves the visibility zone.
		# Long falls/high elevation changes then follow with the same damping.
		height=clampf(camera_anchor.y,target.y-CAMERA_AIR_UP_ZONE,target.y+CAMERA_AIR_DOWN_ZONE)
		if not is_equal_approx(height,camera_anchor.y):
			# Velocity anticipation only outside the zone keeps long falls readable.
			# Ordinary jump ascent/descent never drives this branch.
			height+=player.velocity.y*.25
	# Exact critically damped spring: position and velocity stay continuous at
	# takeoff, landing and platform changes; no camera bob or added physics.
	var offset:=camera_anchor.y-height
	var spring:=_camera_vertical_velocity+CAMERA_VERTICAL_RESPONSE*offset
	var decay:=exp(-CAMERA_VERTICAL_RESPONSE*delta)
	camera_anchor.y=height+(offset+spring*delta)*decay
	_camera_vertical_velocity=(_camera_vertical_velocity-CAMERA_VERTICAL_RESPONSE*spring*delta)*decay
	# Orthographic framing needs distance as well: a wider view must still start
	# above the ground rather than clip its foreground at the camera near plane.
	var view_distance:=CAMERA_DISTANCE*maxf(1.,camera_size/7.2)
	camera.global_position=camera_anchor+Vector3(sin(azimuth)*cos(elevation),sin(elevation),cos(azimuth)*cos(elevation))*view_distance
	camera.look_at(camera_anchor,Vector3.UP);camera.size=camera_size
func _input(event: InputEvent) -> void:
	# A GUI may consume the key-up after the press began over the world.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and not event.pressed:
		orbiting=false;_right_aim_held=false;_sync_rifle_controls()
	if event is InputEventKey and (event.physical_keycode==KEY_E or event.keycode==KEY_E) and not event.pressed:
		_fire_key_held=false;_sync_rifle_controls()
	if event is InputEventKey and not event.pressed:_turn_key(event)
func _turn_key(event: InputEventKey) -> void:
	var code:=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if code==KEY_Q:_turn_left_held=event.pressed
	elif code==KEY_C:_turn_right_held=event.pressed
	else:return
	if rifle_ready and is_instance_valid(player):player.visual.turn_axis=float(_turn_left_held)-float(_turn_right_held)
func _sync_rifle_controls() -> void:
	if is_instance_valid(player) and rifle_ready:player.visual.set_rifle_aim(_fire_key_held or _right_aim_held)
	if is_instance_valid(player) and rifle_ready:player.visual.combat_turn_requested=_fire_key_held
	if rifle_fire!=null:rifle_fire.set_trigger(_fire_key_held)
	if rifle_auto_aim!=null and not (_fire_key_held or _right_aim_held):rifle_auto_aim.reset_target()
func _unhandled_input(event: InputEvent) -> void:
	if grass_field!=null and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_V:
		grass_overview=not grass_overview;_camera_initialized=false
	if event.is_action_pressed("reset_test"):reset_player()
	if event is InputEventKey and (event.physical_keycode==KEY_E or event.keycode==KEY_E) and not event.echo:
		_fire_key_held=event.pressed;_sync_rifle_controls()
	if event is InputEventKey and not event.echo:_turn_key(event)
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:
			orbiting=event.pressed
			_right_aim_held=event.pressed;_sync_rifle_controls()
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:camera_size=maxf(3.6,camera_size-.3)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera_size=minf(24.,camera_size+.3)
	if event is InputEventMouseMotion and orbiting:
		azimuth-=event.relative.x*.006;elevation=clampf(elevation+event.relative.y*.004,.15,.75)
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		orbiting=false;_fire_key_held=false;_right_aim_held=false;_sync_rifle_controls()
		_turn_left_held=false;_turn_right_held=false
		if rifle_ready and is_instance_valid(player):player.visual.turn_axis=0.
func reset_player() -> void:
	if rifle_auto_aim!=null:rifle_auto_aim.reset_target()
	if rifle_fire!=null:rifle_fire.reset_fire()
	_fire_key_held=false;_right_aim_held=false;_sync_rifle_controls()
	_turn_left_held=false;_turn_right_held=false
	player.global_position=Vector3.ZERO;player.velocity=Vector3.ZERO;player.current_speed=0.;player.reset_jump_motion();player.visual.reset_contacts()
	# Adjustable batches derive their positions from the player's reset location.
	if zombie_combat!=null:zombie_combat.reset_encounter()
	if presentation!=null: presentation.reset_history()
	if soldier_appearance!=null:soldier_appearance.reset()
	if grass_field!=null:grass_field.reset()
	_camera_initialized=false;_update_camera()
