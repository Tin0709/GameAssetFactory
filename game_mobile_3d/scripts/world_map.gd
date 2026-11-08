extends Node3D
## Authored schematic layout; visual optimization never changes the source cells.
const DATA := "res://assets/maps/world_map/runtime.json"
const CAMERA_OFFSET := Vector3(12,15,16)
# Extend the orthographic depth range past the view origin for foreground cliffs.
const GAMEPLAY_CAMERA_NEAR := -8.0
const GROVE_REVIEW := preload("res://scripts/world_map_grove.gd")
const JUMP_REVIEW_PLAYER = preload("res://scenes/characters/CuboidPlayerJumpGifV004.tscn")
var runtime: Dictionary
var geometry
var columns: Dictionary = {}
var solid_intervals: Dictionary = {}
var spawn_position := Vector3.ZERO
var map_ready := false
var view_mode := "gameplay"
var build_msec := 0
var border_bodies: Array[StaticBody3D] = []
var look
var grove: Node3D
var presentation: Node
var ambient: Node
var actor_fill: Node
var terrain_sky: Node
var terrain_light: Node
var vegetation_visible:=true
var showcase: Node
var _camera_ground_y := NAN
var _extended_camera_depth := true
@onready var _original_camera_near: float = $Camera3D.near
@onready var player: CharacterBody3D = $Actors/Player

func _enter_tree() -> void:
	presentation=load("res://scripts/world_map_presentation.gd").new()
	presentation.name="RenderPresentation"
	add_child(presentation);presentation.begin(self)
	# Swap before child _ready callbacks. A nested inherited scene replacement
	# leaves the previous Player orphaned in Godot 4.7; free it explicitly.
	var actors: Node=$Actors
	var previous: Node3D=actors.get_node("Player")
	var index:=previous.get_index()
	showcase=load("res://scripts/world_map_showcase.gd").new()
	showcase.name="UnifiedShowcase";add_child(showcase)
	var replacement: Node3D=showcase.make_player()
	if showcase.private_primary:
		for service:String in ["Combat","SpawnDirector"]:
			var old:=get_node_or_null(service)
			if old!=null:remove_child(old);old.free()
	replacement.name=previous.name;replacement.transform=previous.transform
	actors.remove_child(previous);previous.free()
	actors.add_child(replacement);actors.move_child(replacement,index)

func _ready() -> void:
	process_physics_priority=2
	var started:=Time.get_ticks_msec()
	$WorldEnvironment.environment=$WorldEnvironment.environment.duplicate()
	$Ground.collision_layer=0
	$Ground/CollisionShape3D.disabled=true
	if has_node("Combat"):$Combat.combat_enabled=false
	if has_node("SpawnDirector"):
		$SpawnDirector.enabled=false
		$SpawnDirector.set_physics_process(false)
	if player.has_node("Pistol"):player.get_node("Pistol").enabled=false
	$HUD/Status.hide()
	get_viewport().msaa_3d=Viewport.MSAA_2X
	if not FileAccess.file_exists(DATA):
		abort_map("Missing World Map package");return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not parsed is Dictionary or parsed.get("schema_version")!=1:
		abort_map("Unsupported World Map package");return
	runtime=parsed
	geometry=load("res://scripts/world_map_geometry.gd").new()
	geometry.name="AuthoredWorld"
	add_child(geometry)
	geometry.build(runtime)
	if not geometry.build_errors.is_empty():
		abort_map("World Map asset/geometry error: "+str(geometry.build_errors));return
	index_columns()
	build_border()
	spawn_position=find_spawn()
	if not spawn_position.is_finite():
		abort_map("No clear spawn in World Map");return
	map_ready=true
	presentation.setup()
	reset_player()
	set_review_view("gameplay")
	if build_grove():
		grove.build_understory(self)
		set_grove_visible(true, player.global_position)
	look=load("res://scripts/world_map_look.gd").new()
	look.name="ReferenceLook"
	add_child(look);look.setup(self)
	if look.atmosphere_review_available(): look.toggle_day_composition()
	if look.day_palette_available(): look.toggle_day_finish()
	ambient=load("res://scripts/world_map_ambient.gd").new()
	ambient.name="DirectionalAmbient"
	add_child(ambient);ambient.setup(self)
	actor_fill=load("res://scripts/world_map_actor_fill.gd").new()
	actor_fill.name="ActorSkyVisibility"
	add_child(actor_fill);actor_fill.setup(self)
	if look.ground_bounce_available(): look.set_ground_bounce(true)
	terrain_sky=load("res://scripts/world_map_terrain_sky.gd").new()
	terrain_sky.name="TerrainSkyVisibility"
	add_child(terrain_sky);terrain_sky.setup(self)
	$HUD/Help.text="WORLD MAP · JUMP + LAND V004\nWASD di chuyển · Shift chạy · SPACE nhảy · Giữ SPACE khi chạy: nhảy liên tiếp · R về điểm bắt đầu\n1/2/3 súng · 0 tay không · V toàn map · H sương · B so màu · F4 nắng qua mây · F3 bóng mây chỉ chặn nắng · F2 bóng tiếp xúc dưới tán"
	if RenderingServer.get_rendering_device()!=null:$HUD/Help.text+="\nF1 bóng nắng mềm"
	if look.ground_bounce_available():$HUD/Help.text+=" · Shift+F1 nắng hắt từ nền"
	if terrain_sky.available():$HUD/Help.text+=" · F12 độ che ánh trời ở vách đá"
	if look.local_exposure_available():$HUD/Help.text+=" · F7 sáng tối cục bộ · Shift+H chiều sâu không khí"
	if look.foliage_light_available():$HUD/Help.text+=" · Y xuyên sáng lá"
	if look.atmosphere_review_available():$HUD/Help.text+=" · U cảnh ban ngày"
	if look.day_palette_available():$HUD/Help.text+=" · P bảng màu · Shift+P màu cân bằng"
	if look.day_palette_available():$HUD/Help.text+=" · F8 so tổng thể"
	if look.leaf_sampling_available():$HUD/Help.text+="\nF9 so mép lá · Shift+F9 MSAA 2× / 4×"
	$HUD/Help.text+="\nG cỏ, hoa và sồi mới · Shift+G đến cụm sồi · Shift+V so mặt cắt camera · N so gió · Shift+N so vệt cỏ · Shift+Y cụm lá\nShift+F2 đất quanh gốc sồi · Alt+N gió tán sồi · F10 nội suy hiển thị"
	if ambient.available(): $HUD/Help.text+=" · F11 ánh sáng trời / đất · Shift+F11 ánh sáng nhân vật dưới cây"
	DisplayServer.window_set_title("World Map · WASD / Shift · V overview")
	build_msec=Time.get_ticks_msec()-started
	showcase.setup(self)
	terrain_light=load("res://scripts/world_map_terrain_transport.gd").new()
	terrain_light.name="TerrainColoredTransport";add_child(terrain_light);terrain_light.setup(self)
	print("WORLD_MAP_READY cells=%d terrain_triangles=%d build_ms=%d spawn=%s" % [geometry.cells.size(),geometry.terrain_triangles,build_msec,spawn_position])

func abort_map(message: String) -> void:
	push_error(message)
	$HUD/Help.text=message
	player.set_physics_process(false)
	set_process(false)
	set_physics_process(false)

func source_to_world(cell: Vector3i) -> Vector3:
	var offset: Array=runtime.offset
	return Vector3(cell)+Vector3(offset[0]+.5,offset[1],offset[2]+.5)

func index_columns() -> void:
	for cell: Vector3i in geometry.cells:
		var entry: Dictionary=runtime.palette[geometry.cells[cell]]
		if entry.category!="terrain":continue
		var column:=Vector2i(cell.x,cell.z)
		var low:=float(cell.y)+float(entry.base_y_offset)
		var high:=low+float(entry.height)
		if not solid_intervals.has(column):solid_intervals[column]=[]
		solid_intervals[column].append(Vector2(low,high))
		if entry.category=="terrain":columns[column]=maxf(float(columns.get(column,-INF)),high)

func surface_height(x: float,z: float) -> float:
	var column:=Vector2i(floori(x-float(runtime.offset[0])),floori(z-float(runtime.offset[2])))
	return float(columns.get(column,NAN))+float(runtime.offset[1])

func clear_standing_space(column: Vector2i,height: float) -> bool:
	for interval: Vector2 in solid_intervals.get(column,[]):
		if interval.x<height+1.9 and interval.y>height+.01:return false
	return true

func find_spawn() -> Vector3:
	var best:=Vector3(NAN,NAN,NAN)
	var best_score:=INF
	for column: Vector2i in columns:
		var height: float=columns[column]
		var point:=source_to_world(Vector3i(column.x,0,column.y))
		point.y=height+float(runtime.offset[1])+.02
		if absf(point.x)>47 or absf(point.z)>47:continue
		if not clear_standing_space(column,height):continue
		var exits:=0
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var neighbour: Vector2i=column+direction
			var neighbour_height: float=columns.get(neighbour,INF)
			if absf(neighbour_height-height)<=.5 and clear_standing_space(neighbour,neighbour_height):exits+=1
		if exits<3:continue
		var score:=point.x*point.x+point.z*point.z
		if score<best_score:best=point;best_score=score
	return best

func build_border() -> void:
	var a: Array=runtime.border.min
	var b: Array=runtime.border.max
	var low:=Vector3(a[0],a[1],a[2])
	var high:=Vector3(b[0],b[1],b[2])
	var center: Vector3=(low+high)*.5
	var height:=high.y-low.y
	var thickness:=.5
	var specs: Array[Dictionary]=[
		{"name":"West","center":Vector3(low.x-thickness*.5,center.y,center.z),"size":Vector3(thickness,height,high.z-low.z+thickness*2)},
		{"name":"East","center":Vector3(high.x+thickness*.5,center.y,center.z),"size":Vector3(thickness,height,high.z-low.z+thickness*2)},
		{"name":"North","center":Vector3(center.x,center.y,low.z-thickness*.5),"size":Vector3(high.x-low.x,height,thickness)},
		{"name":"South","center":Vector3(center.x,center.y,high.z+thickness*.5),"size":Vector3(high.x-low.x,height,thickness)}]
	var border:=Node3D.new()
	border.name="InvisibleBorder"
	add_child(border)
	for spec in specs:
		var body:=StaticBody3D.new()
		body.name=spec.name
		body.position=spec.center
		body.collision_layer=1;body.collision_mask=2
		var collider:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=spec.size;collider.shape=shape
		body.add_child(collider)
		border.add_child(body)
		border_bodies.append(body)

func reset_player() -> void:
	if not map_ready:return
	if player.is_dead:
		get_tree().call_deferred("reload_current_scene");return
	player.position=spawn_position
	_camera_ground_y=spawn_position.y
	player.velocity=Vector3.ZERO
	if player.has_method("cancel_jump"):player.cancel_jump()
	player.reset_physics_interpolation()

func _physics_process(_delta: float) -> void:
	if map_ready and player.position.y<float(runtime.border.min[1])-1.0:reset_player()

func _process(delta: float) -> void:
	if not map_ready:return
	if not is_finite(_camera_ground_y):_camera_ground_y=player.global_position.y
	# Hold the last supported elevation through the jump. Horizontal tracking
	# remains exact; a different landing elevation settles without a camera pop.
	var jumping:bool=player.get("jump_active")==true
	var landed:bool=player.get("_landed")==true
	if (player.is_on_floor() or player.smooth_step_active) and (not jumping or landed):
		_camera_ground_y=lerpf(_camera_ground_y,player.global_position.y,1.0-exp(-delta/.16))
	if view_mode=="gameplay":
		var camera: Camera3D = $Camera3D
		var focus: Vector3 = presentation.player_position()
		_update_camera_near(camera)
		camera.position=Vector3(focus.x,_camera_ground_y,focus.z)+CAMERA_OFFSET
		geometry.update_cutaway(focus,camera.global_position)
		if grove != null and grove.visible:grove.update_focus(camera,focus,true)
	if presentation.enabled and look != null and look.active:
		look.publish_render_wind(presentation.wind_time(look.motion.clock))

func set_review_view(mode: String) -> void:
	if showcase!=null:showcase.begin_environment_edit()
	view_mode=mode
	var camera: Camera3D=$Camera3D
	if mode=="gameplay":
		camera.size=14.5;camera.far=72.0
		camera.rotation_degrees=Vector3(-36.315886,36.869898,0)
		camera.position=Vector3(player.global_position.x,_camera_ground_y,player.global_position.z)+CAMERA_OFFSET
	else:
		camera.far=300.0;camera.size=150.0
		camera.position=Vector3(-8.5,140,-1)
		camera.rotation_degrees=Vector3(-90,0,0)
		# Zero-length cutaway corridor restores native materials for overview.
		geometry.update_cutaway(Vector3.ZERO,Vector3.ZERO)
	_update_camera_near(camera)
	if look != null:look.refresh_atmosphere()
	if grove != null and grove.visible:grove.update_focus(camera,player.global_position,mode=="gameplay")
	if showcase!=null:showcase.end_environment_edit()

func _update_camera_near(camera: Camera3D) -> void:
	var extend := _extended_camera_depth and view_mode == "gameplay" and camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	var near_plane := GAMEPLAY_CAMERA_NEAR if extend else _original_camera_near
	if camera.near != near_plane: camera.near = near_plane

func build_grove() -> bool:
	var candidate := GROVE_REVIEW.new()
	candidate.name = "GroveReview"
	if not candidate.build(self):
		candidate.free()
		push_warning("WorldMap grove assets or support unavailable.")
		return false
	grove = candidate
	add_child(grove)
	return true

func set_grove_visible(enabled: bool, at: Vector3) -> bool:
	var collider:=player.get_node_or_null("CollisionShape3D")
	if collider==null:collider=player.get_node_or_null("BodyCollision")
	var player_shape := collider.shape as CapsuleShape3D
	if not grove.set_enabled(enabled, at, player_shape): return false
	vegetation_visible=enabled
	for batch: MultiMeshInstance3D in geometry.vegetation_batches+geometry.accent_batches: batch.visible = enabled
	if enabled:
		grove.update_focus($Camera3D, player.global_position, view_mode == "gameplay")
		if look != null: look.refresh_grove_lighting()
	if look != null:
		look.refresh_vegetation_ground_detail()
		look.refresh_canopy_contact()
		look.refresh_oak_root_beds()
	return true

func review_grove(visit: bool) -> void:
	if grove == null: return
	var point: Vector2 = GROVE_REVIEW.REVIEW_POSITION
	var destination := Vector3(point.x, surface_height(point.x, point.y) + 0.02, point.y)
	if not set_grove_visible(visit or not grove.visible, destination if visit else player.global_position): return
	if visit:
		player.position = destination
		player.velocity = Vector3.ZERO
		player.cancel_jump()
		player.reset_physics_interpolation()
		_camera_ground_y = destination.y
		set_review_view("gameplay")

func update_status() -> void:
	$HUD/Defeated.visible=player.is_dead

func set_reference_look(enabled: bool) -> void:
	look.set_stage(2 if enabled else 0)

func _unhandled_input(event: InputEvent) -> void:
	if not map_ready:return
	if event.is_action_pressed("reset_test"):reset_player()
	if event is InputEventKey and event.pressed and not event.echo:
		if showcase.handle_key(event):
			get_viewport().set_input_as_handled();return
		showcase.begin_environment_edit()
		if event.physical_keycode == KEY_F11:
			if event.shift_pressed:
				actor_fill.set_enabled(not actor_fill.enabled)
			else:
				ambient.set_enabled(not ambient.enabled)
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_F10:
			presentation.set_enabled(not presentation.enabled)
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_G:
			review_grove(event.shift_pressed)
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_N and look.stage != 0:
			if event.alt_pressed:
				look.set_oak_crown_wind(not look.oak_crown_wind)
			elif event.shift_pressed:
				look.set_segment_passage_height(not look.segment_passage_height)
			else:
				look.set_travelling_breeze(not look.travelling_breeze)
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_H:
			if event.shift_pressed and look.atmosphere_review_available():
				if look.stage == 2 and view_mode == "gameplay":
					look.set_atmosphere_review(not look.atmosphere_review_active())
			else:
				$WorldEnvironment.environment.fog_enabled = not $WorldEnvironment.environment.fog_enabled
				if look.atmosphere_review_active():look.refresh_atmosphere()
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_V:
			if event.shift_pressed:
				_extended_camera_depth = not _extended_camera_depth
				_update_camera_near($Camera3D)
			else:
				set_review_view("overview" if view_mode == "gameplay" else "gameplay")
			get_viewport().set_input_as_handled()
		if event.physical_keycode==KEY_B:set_reference_look(look.stage==0)
		if event.physical_keycode == KEY_F8 and look.stage == 2:
			look.toggle_day_finish()
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_F9:
			if event.shift_pressed:
				var viewport := get_viewport()
				viewport.msaa_3d = Viewport.MSAA_2X if viewport.msaa_3d == Viewport.MSAA_4X else Viewport.MSAA_4X
			elif look.stage == 2:
				look.toggle_leaf_sampling()
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_U and look.stage == 2 and look.atmosphere_review_available():
			look.toggle_day_composition()
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_P and look.stage == 2 and look.day_palette_available():
			look.set_day_palette(not look.day_palette_active(event.shift_pressed), event.shift_pressed)
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_Y and look.stage == 2:
			if event.shift_pressed:
				look.toggle_crown_detail()
				get_viewport().set_input_as_handled()
			elif look.foliage_light_available():
				look.set_foliage_light(not look.foliage_light_active())
				get_viewport().set_input_as_handled()
		if event.physical_keycode==KEY_F7 and look.stage==2 and look.local_exposure_available():
			look.set_local_exposure(not look.local_exposure_active())
			get_viewport().set_input_as_handled()
		if event.physical_keycode==KEY_F1 and look.stage==2:
			if event.shift_pressed:
				look.set_ground_bounce(not look.ground_bounce_active())
			else:
				look.set_directional_shadow_review(not look.directional_shadow_review_active())
			get_viewport().set_input_as_handled()
		if event.physical_keycode==KEY_F12:
			terrain_sky.set_enabled(not terrain_sky.enabled)
			get_viewport().set_input_as_handled()
		if event.physical_keycode==KEY_F2 and look.stage==2:
			if event.shift_pressed:
				look.toggle_oak_root_beds()
			else:
				look.set_canopy_contact(not look.canopy_contact_active())
			get_viewport().set_input_as_handled()
		if event.physical_keycode==KEY_F3 and look.stage==2:
			look.set_direct_clouds(not look.direct_clouds_active())
			get_viewport().set_input_as_handled()
		if event.physical_keycode==KEY_F4 and look.stage==2:
			look.set_daylight_pockets(not look.daylight_pockets_active())
			get_viewport().set_input_as_handled()
		showcase.end_environment_edit()
