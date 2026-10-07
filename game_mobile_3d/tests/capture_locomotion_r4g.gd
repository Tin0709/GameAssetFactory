extends SceneTree
var lab
var soles: Dictionary
var report := {}
const OUT := "res://.validation/locomotion_r4g/rendered"
func _initialize() -> void: call_deferred("run")
func foot(name: String) -> Dictionary:
	var world: Transform3D = lab.actor.skeleton.global_transform*lab.actor.skeleton.get_bone_global_pose(lab.actor.skeleton.find_bone(name))
	var center := Vector3.ZERO
	var low := 100.0
	for row in soles[name]:
		var p := world*Vector3(row[0],row[1],row[2]);center+=p;low=minf(low,p.y)
	center/=soles[name].size()
	return {"position":center,"low":low}
func run() -> void:
	Engine.physics_ticks_per_second=120
	lab=load("res://scenes/dev/LocomotionTurningLab.tscn").instantiate();root.add_child(lab);current_scene=lab;lab.set_physics_process(false)
	var source := ProjectSettings.globalize_path("res://").path_join("../blender/characters/player/cuboid/export/locomotion_r4g/sole_points.json")
	soles=JSON.parse_string(FileAccess.get_file_as_string(source))
	DirAccess.make_dir_recursive_absolute(OUT)
	for sprint in [false,true]:
		for scenario in ["Straight","MildCW","MildCCW","TightCW","TightCCW","Recovery"]:
			var p = lab.actor
			var label: String = ("Sprint" if sprint else "Walk")+"_"+scenario
			p.position=Vector3(0,0.02,0);p.velocity=Vector3.ZERO;p.phase=0;p.sprint_weight=1.0 if sprint else 0.0;p.turn_amount=0;p.visual.rotation.y=PI
			var heading := PI
			var rate := 0.0
			var speed: float = p.sprint_speed if sprint else p.walk_speed
			if scenario.begins_with("Mild"): rate=speed/12.0
			elif scenario.begins_with("Tight"): rate=speed/2.5
			if scenario.ends_with("CW") and not scenario.ends_with("CCW"): rate=-rate
			var metrics := {"speed_m_s":speed,"radius_m":12.0 if scenario.begins_with("Mild") else (2.5 if scenario.begins_with("Tight") else 0.0),"yaw_rate_rad_s":rate,"A":{},"B":{},"turn_samples":[],"measured_travel_speed_m_s":[]}
			if metrics.radius_m>0:lab.circle_radius=metrics.radius_m
			var previous := {"A":{},"B":{}}
			for mode in ["A","B"]:
				for leg in ["Leg.L","Leg.R"]:metrics[mode][leg]={"contact_speed_m_s":[],"height_m":[]}
			# Warm the actual facing/filter before sustained-curve measurement.
			for i in 48:
				for tick in 5:
					await physics_frame
					heading+=rate/120.0;p.step(1.0/120,Vector3(sin(heading),0,cos(heading)),sprint)
			for frame in 72:
				if scenario=="Recovery": rate=0.9 if frame<24 else (0.0 if frame<48 else -0.9)
				var before: Vector3=p.position
				for tick in 5:
					await physics_frame
					heading+=rate/120.0;p.step(1.0/120,Vector3(sin(heading),0,cos(heading)),sprint)
				var travel: Vector3=p.position-before;travel.y=0
				var measured_speed:=travel.length()*24
				assert(absf(measured_speed-speed)<0.01,"Capture must move at the stated speed")
				metrics.measured_travel_speed_m_s.append(measured_speed)
				metrics.turn_samples.append(p.turn_amount)
				lab.camera.position=p.position+lab.camera_offset
				lab.path_label=label;lab.automated=true;lab.auto_sprint=sprint
				for mode in ["A","B"]:
					p.turning_enabled=mode=="B";p.evaluate_pose();lab.update_debug()
					for leg in ["Leg.L","Leg.R"]:
						var f := foot(leg);metrics[mode][leg].height_m.append(f.low)
						if previous[mode].has(leg) and f.low<0.04 and previous[mode][leg].low<0.04:
							var delta: Vector3 = f.position-previous[mode][leg].position;delta.y=0
							metrics[mode][leg].contact_speed_m_s.append(delta.length()*24.0)
						previous[mode][leg]=f
					await process_frame; await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OUT+"/%s_%s_%03d.png"%[label,mode,frame])
			report[label]=metrics
	FileAccess.open(OUT+"/measurements.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("R4G_RENDERED_COMPLETE: actual movement, identical A/B snapshots, 24fps authored cadence")
	lab.queue_free();await process_frame;quit()
