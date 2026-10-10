extends Node3D
## Authored schematic layout; visual optimization never changes the source cells.
const DATA := "res://assets/maps/world_map/runtime.json"
const CAMERA_OFFSET := Vector3(12,15,16)
const JUMP_REVIEW_PLAYER = preload("res://scenes/characters/CuboidPlayerJumpLoopV003.tscn")
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
@onready var player: CharacterBody3D = $Actors/Player

func _enter_tree() -> void:
	# Swap before child _ready callbacks. A nested inherited scene replacement
	# leaves the previous Player orphaned in Godot 4.7; free it explicitly.
	var actors: Node=$Actors
	var previous: Node3D=actors.get_node("Player")
	var index:=previous.get_index()
	var replacement: Node3D=JUMP_REVIEW_PLAYER.instantiate()
	replacement.name=previous.name;replacement.transform=previous.transform
	actors.remove_child(previous);previous.free()
	actors.add_child(replacement);actors.move_child(replacement,index)

func _ready() -> void:
	process_physics_priority=2
	var started:=Time.get_ticks_msec()
	$WorldEnvironment.environment=$WorldEnvironment.environment.duplicate()
	$Ground.collision_layer=0
	$Ground/CollisionShape3D.disabled=true
	$Combat.combat_enabled=false
	$SpawnDirector.enabled=false
	$SpawnDirector.set_physics_process(false)
	player.get_node("Pistol").enabled=false
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
	reset_player()
	set_review_view("gameplay")
	look=load("res://scripts/world_map_look.gd").new()
	look.name="ReferenceLook"
	add_child(look);look.setup(self)
	$HUD/Help.text="WORLD MAP · JUMP V003\nWASD di chuyển · Shift chạy · SPACE nhảy · Giữ SPACE khi chạy: nhảy liên tiếp · R về điểm bắt đầu\n1/2/3 súng · 0 tay không · V toàn map · H sương · B so màu"
	DisplayServer.window_set_title("World Map · WASD / Shift · V overview")
	build_msec=Time.get_ticks_msec()-started
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
	player.velocity=Vector3.ZERO
	if player.has_method("cancel_jump"):player.cancel_jump()

func _physics_process(_delta: float) -> void:
	if map_ready and player.position.y<float(runtime.border.min[1])-1.0:reset_player()

func _process(_delta: float) -> void:
	if not map_ready:return
	if view_mode=="gameplay":
		$Camera3D.position=player.global_position+CAMERA_OFFSET
		geometry.update_cutaway(player.global_position,$Camera3D.global_position)

func set_review_view(mode: String) -> void:
	view_mode=mode
	var camera: Camera3D=$Camera3D
	if mode=="gameplay":
		camera.size=14.5;camera.far=72.0
		camera.rotation_degrees=Vector3(-36.315886,36.869898,0)
		camera.position=player.position+CAMERA_OFFSET
	else:
		camera.far=300.0;camera.size=150.0
		camera.position=Vector3(-8.5,140,-1)
		camera.rotation_degrees=Vector3(-90,0,0)
		# Zero-length cutaway corridor restores native materials for overview.
		geometry.update_cutaway(Vector3.ZERO,Vector3.ZERO)

func update_status() -> void:
	$HUD/Defeated.visible=player.is_dead

func set_reference_look(enabled: bool) -> void:
	look.set_stage(2 if enabled else 0)

func _unhandled_input(event: InputEvent) -> void:
	if not map_ready:return
	if event.is_action_pressed("reset_test"):reset_player()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_H:$WorldEnvironment.environment.fog_enabled=not $WorldEnvironment.environment.fog_enabled
		if event.physical_keycode==KEY_V:set_review_view("overview" if view_mode=="gameplay" else "gameplay")
		if event.physical_keycode==KEY_B:set_reference_look(look.stage==0)
