extends SceneTree
## Scripted real gameplay QA. Inputs go through the unchanged controller;
## snapshot-only freezes allow an identical-world Legacy/Reference comparison.
const OUT:="res://.validation/locomotion_r6p/rendered"
var level
var p
var v
var enemy
var report:={}
func _initialize() -> void:call_deferred("run")
func release() -> void:
	for action in ["move_left","move_right","move_forward","move_backward","sprint"]:Input.action_release(action)
func command(direction:Vector3,sprint:bool) -> void:
	release()
	# Input.get_vector applies its normal dead zone, so use full-unit intent.
	Input.action_press("move_right",maxf(direction.x,0));Input.action_press("move_left",maxf(-direction.x,0))
	Input.action_press("move_backward",maxf(direction.z,0));Input.action_press("move_forward",maxf(-direction.z,0))
	if sprint:Input.action_press("sprint")
func fresh(armed:bool,start:Vector3,initial_threat:bool=true) -> void:
	release()
	if is_instance_valid(level):level.queue_free();await process_frame
	level=load("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	p=level.player;v=p.visual;p.position=start
	level.get_node("HUD/AnimationDebug").hide()
	p.get_node("Pistol").cooldown=1000000
	if armed:
		enemy=load("res://scenes/characters/CuboidZombie.tscn").instantiate()
		enemy.max_hp=1000000;level.get_node("Actors").add_child(enemy);enemy.current_hp=1000000
		enemy.position=Vector3(0,0.02,0) if initial_threat else Vector3(30,0.02,30);enemy.set_physics_process(false);level.combat.register_zombie(enemy)
	for i in 150:await physics_frame
func run() -> void:
	Engine.physics_ticks_per_second=120
	DirAccess.make_dir_recursive_absolute(OUT)
	var labels:Array=["Idle","Walk_Straight","Sprint_Straight","Walk_CW","Walk_CCW","Sprint_CW","Sprint_CCW","Walk_S","Sprint_S","Walk_Reversal","Sprint_Reversal","Walk_Recovery","Sprint_Recovery","Walk_Sprint","READY_Circle","READY_CCW","READY_S","Draw_Holster_Sprint"]
	if FileAccess.file_exists(OUT+"/metrics.json"):report=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/metrics.json"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--paths="):labels=Array(arg.trim_prefix("--paths=").split(","))
	for label:String in labels:
		var armed:bool=label.begins_with("READY") or label.begins_with("Draw")
		var sprint:bool=label.begins_with("Sprint")
		var straight:bool=label.contains("Straight")
		await fresh(armed,Vector3(-5,0.02,0) if straight else Vector3(2.5,0.02,0),not label.begins_with("Draw"))
		var count:int=48 if straight or label=="Idle" else (192 if armed else (42 if label.contains("Recovery") else 96))
		var rows:=[]
		var heading:=0.0
		for frame in count:
			var t:=frame/24.0
			for tick in 5:
				var elapsed:=t+tick/120.0
				var direction:=Vector3.ZERO
				var fast:=sprint
				var pos:=Vector3(p.position.x,0,p.position.z)
				if straight:direction=Vector3.RIGHT
				elif label=="Idle":pass
				elif label.contains("_S") and label!="Walk_Sprint":
					# Closed figure-eight inside the real arena. No position resets.
					var omega:float=0.8 if sprint else 0.6
					var angle:=elapsed*omega
					var target:=Vector3(3.5*cos(angle),0,2*sin(2*angle))
					var tangent:=Vector3(-3.5*sin(angle),0,4*cos(2*angle)).normalized()
					direction=(tangent+(target-pos)*0.8).normalized()
				else:
					var sign_value:float=-1 if label.ends_with("CCW") else 1
					if label.contains("Reversal") and elapsed>=2:sign_value=-1
					var radial:=pos.normalized()
					direction=(Vector3(-radial.z,0,radial.x)*sign_value+radial*(2.5-pos.length())*0.8).normalized()
					if label.contains("Recovery") and elapsed>=0.75:
						if heading==0:heading=atan2(direction.x,direction.z)
						direction=Vector3(sin(heading),0,cos(heading))
				if label=="Walk_Sprint":fast=elapsed>=1 and elapsed<3
				if label.begins_with("Draw"):
					# Genuine awareness/layer transitions while following a curve.
					enemy.position=Vector3(30,0.02,30) if elapsed<0.5 or elapsed>=6.0 else Vector3.ZERO
					fast=elapsed>=2.5 and elapsed<4.2
					p.get_node("Pistol").cooldown=0 if elapsed>=5.5 and elapsed<6.0 else 1000000
				command(direction,fast)
				await physics_frame
			# physics_frame fires before controller callbacks. Let the fifth real
			# physics/visual update finish before freezing the snapshot; otherwise
			# playback would omit one movement tick per captured frame.
			await RenderingServer.frame_post_draw
			# Freeze simulation only during both render snapshots. No gait clock
			# advances between the two modes and no controller state is replaced.
			level.process_mode=Node.PROCESS_MODE_DISABLED
			var atlas:=Image.create(2560,720,false,Image.FORMAT_RGB8)
			var row:={"time":t,"position":[p.position.x,p.position.y,p.position.z],"speed":p.current_speed,"phase":v.reference_phase,"turn":v.reference_turn_amount,"sprint":v.reference_sprint_weight,"state":p.get_node("WeaponBehavior").State.keys()[p.get_node("WeaponBehavior").state],"banks":{}}
			for mode in 2:
				v.set_locomotion_mode(mode);v.skeleton.force_update_all_bone_transforms()
				var bones:={}
				for name in ["Hips","Spine","Chest","Head"]:
					var up:Vector3=v.skeleton.get_bone_global_pose(v.skeleton.find_bone(name)).basis.y.normalized()
					bones[name]=rad_to_deg(atan2(up.x,up.y))
				row.banks[str(mode)]=bones
				await process_frame;await RenderingServer.frame_post_draw
				var pic:=root.get_texture().get_image();pic.convert(Image.FORMAT_RGB8)
				atlas.blit_rect(pic,Rect2i(0,0,1280,720),Vector2i(mode*1280,0))
			atlas.save_jpg(OUT+"/%s_%03d.jpg"%[label,frame],0.9)
			rows.append(row);level.process_mode=Node.PROCESS_MODE_INHERIT
		report[label]=rows
		print("R6P_CAPTURED ",label," ",count," paired normal-camera frames")
	release();FileAccess.open(OUT+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("R6P_CAPTURE_COMPLETE — scripted real controller; snapshot-frozen A/B; 24fps")
	quit()
