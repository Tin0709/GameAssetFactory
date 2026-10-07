extends SceneTree
const OUT := "res://.validation/locomotion_r5"
var lab
var records := {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	lab=load("res://scenes/dev/LocomotionTurningLab.tscn").instantiate();root.add_child(lab);current_scene=lab;lab.set_physics_process(false)
	var p=lab.actor
	var candidate := "--candidate" in OS.get_cmdline_user_args()
	p.set_review_mode(2 if candidate else 1)
	for sprint in [false,true]:
		for scenario in ["MildLeft","MildRight","DefaultCircle","TightCircle","S-curve","Reversal"]:
			var label: String=("Sprint" if sprint else "Walk")+"_"+scenario
			p.position=Vector3(0,0.02,0);p.velocity=Vector3.ZERO;p.phase=0;p.sprint_weight=1.0 if sprint else 0.0;p.turn_amount=0;p.candidate_turn_amount=0;p.visual.rotation.y=PI;p.turning_enabled=true
			var heading:=PI
			var rows:=[]
			for i in 480:
				await physics_frame
				var t:=i/60.0
				var rate:=0.0
				if t>=1 and t<6:
					match scenario:
						"MildLeft": rate=0.55 # Existing sequence bend.
						"MildRight": rate=-0.55
						"DefaultCircle": rate=(p.sprint_speed if sprint else p.walk_speed)/6.0
						"TightCircle": rate=(p.sprint_speed if sprint else p.walk_speed)/2.5 # Existing R4 capture radius.
						"S-curve": rate=sin((t-1)*TAU/6)*0.8
						"Reversal": rate=(1.0 if t<3.5 else -1.0)*(p.sprint_speed if sprint else p.walk_speed)/2.5
				heading=wrapf(heading+rate/60,-PI,PI)
				var before:Vector3=p.position;var yaw:float=p.visual.rotation.y
				p.step(1.0/60,Vector3(sin(heading),0,cos(heading)),sprint)
				var delta:Vector3=p.position-before;delta.y=0
				rows.append({"t":t,"commanded_heading_rate":rate,"raw_yaw_rate":p.angular_velocity,"normalized_before_smoothing":p.candidate_normalized_turn if candidate else p.raw_normalized_turn,"shaped_target":p.candidate_shaped_turn if candidate else p.raw_normalized_turn,"smoothed_turn":p.candidate_turn_amount if candidate else p.turn_amount,"final_blend":p.final_turn_value,"gait":"Sprint" if sprint else "Walk","speed":p.current_speed,"measured_speed":delta.length()*60,"measured_character_yaw_rate":wrapf(p.visual.rotation.y-yaw,-PI,PI)*60,"phase":p.phase})
			records[label]=rows
	DirAccess.make_dir_recursive_absolute(OUT)
	FileAccess.open(OUT+("/candidate_samples.json" if candidate else "/original_recheck_samples.json"),FileAccess.WRITE).store_string(JSON.stringify(records))
	print("R5_MEASURED ","C" if candidate else "B",records.size()," cases / ",records.size()*480," physics samples")
	lab.queue_free();await process_frame;quit()
