extends SceneTree
## Offline capture of the actual main WorldMap and final composed skeleton.
const OUT:="res://.validation/jump_gif_v004"
var level
var player
var label:Label
var frames:Array=[]
var section:=""
var lane:Vector3
func _initialize() -> void:call_deferred("run")
func tick(count:int) -> void:
	for i in count:
		await process_frame
		var v=player.visual;var c:Camera3D=level.get_node("Camera3D")
		frames.append({"frame":frames.size(),"section":section,"position":[player.position.x,player.position.y,player.position.z],"camera":[c.position.x,c.position.y,c.position.z],"jump":player.jump_active,"kind":String(player.jump_kind),"pose_time":v.jump_time,"floor":player.is_on_floor(),"airborne":player._airborne,"landed":player._landed,"leg_weight":v._jump_bone_weight("Leg.L",1.0),"left":rad_to_deg(v.skeleton.get_bone_pose_rotation(v.leg_left).get_euler().x),"right":rad_to_deg(v.skeleton.get_bone_pose_rotation(v.leg_right).get_euler().x)})
func release() -> void:
	for action in ["move_right","move_left","move_forward","move_backward","sprint","jump"]:Input.action_release(action)
func title(text:String) -> void:
	section=text;label.text="JUMP + LAND V004 | "+text+"\nActual WorldMap / Mobile renderer / 1x playback\nOffline 30 FPS capture / review pending"
func find_lane() -> Vector3:
	# A real clear row: no replacement ground or lighting for this review.
	for column:Vector2i in level.columns:
		var start:Vector3=level.source_to_world(Vector3i(column.x,0,column.y))
		if absf(start.x)>30 or absf(start.z)>30:continue
		var height:float=level.columns[column];var clear:=true
		for x in range(26):
			var cell:=column+Vector2i(x,0)
			clear=clear and is_equal_approx(level.columns.get(cell,-INF),height) and level.clear_standing_space(cell,height)
		if clear:start.y=height+float(level.runtime.offset[1])+.02;return start
	return level.spawn_position
func reset_at_lane() -> void:
	release();player.cancel_jump();level.reset_player();player.position=lane;player.velocity=Vector3.ZERO
	level.set("_camera_ground_y",lane.y)
	await tick(20)
func review(kind:String,held:bool=false,prefix:String="") -> void:
	title(prefix+kind.capitalize()+" / "+("held Space then release" if held else "stride to jump to stride"))
	await reset_at_lane()
	if kind!="stationary":Input.action_press("move_right")
	if kind=="run":Input.action_press("sprint")
	await tick(22)
	Input.action_press("jump");await tick(2)
	if not held:Input.action_release("jump")
	await tick(78 if held else 42)
	Input.action_release("jump");await tick(28)
	release();await tick(12)
func run() -> void:
	level=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(level);current_scene=level;player=level.player
	level.get_node("HUD/Help").hide()
	player.get_node("WeaponBehavior").enabled=false;player.get_node("Pistol").enabled=false
	player.visual.set_weapon_equipped(false)
	var canvas:=CanvasLayer.new();root.add_child(canvas);label=Label.new();canvas.add_child(label)
	label.position=Vector2(18,14);label.add_theme_font_size_override("font_size",17)
	await tick(18);lane=find_lane()
	await review("stationary")
	level.get_node("Camera3D").size=8.0
	await review("walk");await review("run");await review("run",true)
	# Preserve the gameplay camera angle; size alone changes for foot inspection.
	await review_mapped_block("walk");await review_mapped_block("run")
	player.equip_test_weapon(1);await tick(12);await review("run",false,"Rifle / ")
	DirAccess.make_dir_recursive_absolute(OUT)
	FileAccess.open(OUT+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"lane":str(lane),"frames":frames,"note":"Actual WorldMap. Grounded moving stride preserved; airborne V004 blend 7/30s; gait release starts on collision over6/30s. Ground-height camera anchor, normal X/Z follow. Offline capture, not measured phone performance."},"\t"))
	print("V004_REVIEW_CAPTURE frames=",frames.size()," lane=",lane)
	level.queue_free();canvas.queue_free();await process_frame;await process_frame;quit()
func review_mapped_block(kind:String) -> void:
	var route:Dictionary=load("res://tests/jump_v003_map_route.gd").find(level);assert(not route.is_empty())
	release();player.cancel_jump();player.position=route.start;player.velocity=Vector3.ZERO
	player.smooth_step_up_enabled=false;level.set("_camera_ground_y",route.start.y)
	title(kind.capitalize()+" / original 1m terrace / step assistance OFF")
	await tick(25);Input.action_press(route.action)
	if kind=="run":Input.action_press("sprint")
	Input.action_press("jump");await tick(2);Input.action_release("jump")
	var landed:=false
	for i in 42:
		await tick(1)
		if player.is_on_floor() and absf(player.position.y-route.target.y)<.04:landed=true;release()
	assert(landed,"Original terrace jump must reach supported target")
	release();await tick(18)
