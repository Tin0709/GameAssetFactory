extends SceneTree
const OUT := "res://.validation/locomotion_r5/rendered_best"
var lab
var report := {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.physics_ticks_per_second=120
	lab=load("res://scenes/dev/LocomotionTurningLab.tscn").instantiate();root.add_child(lab);current_scene=lab;lab.set_physics_process(false)
	lab.debug.hide()
	DirAccess.make_dir_recursive_absolute(OUT)
	for sprint in [false,true]:
		for scenario in ["DefaultCircle","TightCircle","BendsRecovery","S-curve","Reversal","RadiusSweep"]:
			var p=lab.actor
			var label: String=("Sprint" if sprint else "Walk")+"_"+scenario
			p.position=Vector3(0,0.02,0);p.velocity=Vector3.ZERO;p.phase=0;p.sprint_weight=1.0 if sprint else 0.0;p.turn_amount=0;p.candidate_turn_amount=0;p.visual.rotation.y=PI
			var heading:=PI
			var speed:float=p.sprint_speed if sprint else p.walk_speed
			var duration:int=9 if scenario=="RadiusSweep" else (8 if scenario in ["BendsRecovery","S-curve"] else 6)
			var frames:=[]
			for frame in duration*24:
				var t:=frame/24.0
				var rate:=0.0
				match scenario:
					"DefaultCircle": rate=speed/6.0
					"TightCircle": rate=-speed/2.5
					"BendsRecovery": rate=0.55 if t<2 else (0.0 if t<4 else (-0.55 if t<6 else 0.0))
					"S-curve": rate=sin(t*TAU/6)*0.8
					"Reversal": rate=(1.0 if t<3 else -1.0)*speed/2.5
					"RadiusSweep": rate=speed/(4.0 if t<3 else (2.5 if t<6 else 1.5))
				for tick in 5:
					await physics_frame
					heading=wrapf(heading+rate/120,-PI,PI);p.step(1.0/120,Vector3(sin(heading),0,cos(heading)),sprint)
				lab.camera.position=p.position+lab.camera_offset
				var atlas:=Image.create(3840,720,false,Image.FORMAT_RGB8)
				var row:Dictionary={"t":t,"phase":p.phase,"speed":p.current_speed,"yaw":p.visual.rotation.y,"command_rate":rate,"B":p.turn_amount,"C":p.candidate_turn_amount,"bank":{}}
				for mode in 3:
					p.set_review_mode(mode)
					var bones:Dictionary={}
					for bone in ["Hips","Spine","Chest","Head"]:
						var up:Vector3=p.skeleton.get_bone_global_pose(p.skeleton.find_bone(bone)).basis.y.normalized()
						bones[bone]=rad_to_deg(atan2(up.x,up.y))
					row.bank[str(mode)]=bones
					await process_frame;await RenderingServer.frame_post_draw
					var pic:=root.get_texture().get_image();pic.convert(Image.FORMAT_RGB8)
					atlas.blit_rect(pic,Rect2i(0,0,1280,720),Vector2i(mode*1280,0))
				atlas.save_jpg(OUT+"/%s_%03d.jpg"%[label,frame],0.90)
				frames.append(row)
			report[label]=frames
			print("R5_CAPTURED ",label," ",frames.size()," synchronized ABC frames")
	FileAccess.open(OUT+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("R5_CAPTURE_COMPLETE 24fps; 120Hz movement; A straight V2 / B original V2 / C remapped V3; same-snapshot A/B/C")
	lab.queue_free();await process_frame;quit()
