extends SceneTree
## Production forest/player, with clearly labelled temporary measurement blocks.
var level: Node3D
var player: CharacterBody3D
var out := "res://.validation/smooth_step_up"
var frames: Array=[]
var checks: Array=[]
var failures: Array=[]
var label: Label
var tick_index:=0
var section:=""
func _initialize() -> void: call_deferred("run")
func release_inputs() -> void:
	for key in ["move_left","move_right","move_forward","move_backward","sprint"]:Input.action_release(key)
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok: failures.append(message);push_error(message)
func tick(count: int) -> void:
	for i in count:
		await physics_frame
		tick_index+=1
		frames.append({"tick":tick_index,"section":section,"position":[player.position.x,player.position.y,player.position.z],"floor":player.is_on_floor(),"step":player.smooth_step_active,"gait":player.visual.current_state})
func make_block(height: float) -> StaticBody3D:
	var block:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new();box.size=Vector3(3,height,4)
	shape.shape=box;block.add_child(shape)
	var mesh:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=box.size;mesh.mesh=cube
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.42,.46,.38);material.roughness=1
	mesh.material_override=material;block.add_child(mesh)
	level.add_child(block);block.position=Vector3(0,1+height/2,-4)
	return block
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	level=preload("res://scenes/ForestQualitySlice.tscn").instantiate()
	root.add_child(level);current_scene=level;level.set_enemies_enabled(false)
	player=level.player;player.get_node("Pistol").enabled=false
	check(player.visual.get_script().resource_path=="res://scripts/player_combat_strafe_r15.gd","Original R15 animation writer active")
	check(not player.visual.animation_player.has_animation_library("jump_v2"),"Deferred jump library is not loaded")
	level.review_label.hide()
	var canvas:=CanvasLayer.new();root.add_child(canvas);label=Label.new();canvas.add_child(label)
	label.position=Vector2(22,18);label.add_theme_font_size_override("font_size",20)
	var camera: Camera3D=level.get_node("Camera3D");camera.size=8.8
	await tick(20)
	for height in [.5,1.0]:
		var block:=make_block(height)
		player.position=Vector3(0,1.02,0);player.velocity=Vector3.ZERO
		player.equip_test_weapon(1)
		var armed: bool=height==1.0
		player.visual.weapon_equipped=armed
		player.get_node("WeaponBehavior").enabled=false
		player.visual.socket.visible=armed
		section="%.1f m / %s"%[height,"rifle" if armed else "unarmed"]
		label.text="SMOOTH STEP UP · "+section+"\nOriginal walk/run animations · temporary test block\nGodot Mobile · 30 FPS offline capture · no performance claim"
		await tick(30)
		Input.action_press("move_forward")
		await tick(55)
		release_inputs();await tick(30)
		check(player.is_on_floor() and absf(player.position.y-(1+height))<.04,"Reached %.1fm top without jump"%height)
		var maximum_y:=0.0
		for row in frames:
			if row.section==section:maximum_y=maxf(maximum_y,row.position[1])
		check(maximum_y<=1+height+.04,"No apex above %.1fm top"%height)
		Input.action_press("move_backward")
		await tick(62)
		release_inputs();await tick(35)
		block.queue_free();await tick(2)
	section="Actual forest terrace / 0.5 m"
	label.text="SMOOTH STEP UP · "+section+"\nOriginal R15 walk · existing map terrain\nGodot Mobile · 30 FPS offline capture · no performance claim"
	player.position=Vector3(10,1.02,-2);player.velocity=Vector3.ZERO
	await tick(24)
	Input.action_press("move_forward");await tick(50)
	release_inputs();await tick(30)
	check(player.is_on_floor() and absf(player.position.y-1.5)<.04,"Walked up actual forest terrace")
	FileAccess.open(out+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"frames":frames,"checks":checks,"failures":failures,"note":"Actual production controller and original R15 visual in ForestQualitySlice. Temporary .5m/1m fixtures; offline movie, no phone/performance claim. Jump animation is disabled by user request."},"\t"))
	print("SMOOTH_STEP_MOVIE frames=",frames.size())
	level.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
