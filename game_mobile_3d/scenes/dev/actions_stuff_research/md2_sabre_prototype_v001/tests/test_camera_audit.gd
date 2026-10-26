extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func ticks(count:int)->void:
	for i in count:await physics_frame
	await process_frame
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.grass_field_blocks=30;root.add_child(lab)
	await ticks(5);var m=lab.sabre_mode;var a=lab.player
	check(m.has_method("camera_measurements"),"Camera has inspectable projection/direction/framing provenance")
	if not m.has_method("camera_measurements"):lab.free();quit(1);return
	var baseline:Dictionary=m.camera_measurements()
	check(baseline.projection=="orthographic" and baseline.native_md2_solo_verified==false,"Current adapter is not labelled recovered native camera")
	check(absf(baseline.azimuth_deg-rad_to_deg(.66))<.0001 and absf(baseline.elevation_deg-rad_to_deg(.4))<.0001,"Serialized existing camera direction remains explicit")
	check(absf(baseline.orthographic_span-14.5)<.00001,"Existing serialized framing retained without video-derived replacement")
	var actual:Vector3=(lab.camera.global_position-lab.camera_anchor).normalized()
	check(absf(asin(actual.y)-.4)<.00001 and absf(atan2(actual.x,actual.z)-.66)<.00001,"Actual camera basis agrees with displayed orientation")
	var e:=InputEventKey.new();e.physical_keycode=KEY_F8;e.pressed=true
	lab.azimuth=1.2;lab.elevation=.7;lab.camera_size=5.;lab.grass_overview=true;await ticks(2)
	var overview:Dictionary=m.camera_measurements();var outward:Vector3=lab.camera.global_basis.z
	check(absf(deg_to_rad(float(overview.azimuth_deg))-atan2(outward.x,outward.z))<.00001 and absf(deg_to_rad(float(overview.elevation_deg))-asin(outward.y))<.00001,"Overview measurements describe actual camera rather than inactive orbit settings")
	m.unhandled_input(e);await ticks(2)
	check(absf(lab.azimuth-.66)<.00001 and absf(lab.elevation-.4)<.00001 and absf(lab.camera_size-14.5)<.00001 and not lab.grass_overview,"F8 restores launch framing after orbit/zoom/overview")
	var trials:Array[Dictionary]=[]
	for hz in [30,60]:
		Engine.physics_ticks_per_second=hz;m.reset();await ticks(6);a.scripted_input=true
		var before:float=lab.camera_anchor.y;var min_y:=before;var max_y:=before;a.requested_jump=true;await ticks(1);a.requested_jump=false
		for i in hz:
			await ticks(1);min_y=minf(min_y,lab.camera_anchor.y);max_y=maxf(max_y,lab.camera_anchor.y)
		check(max_y-min_y<.003,"Normal jump does not add vertical camera bob at%dHz"%hz)
		trials.append({"physics_hz":hz,"ordinary_jump_anchor_y_span":max_y-min_y})
	var report:={"checks":checks,"failures":failures,"camera":m.camera_measurements(),"trials":trials}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation/md2_sabre_movement"));FileAccess.open("res://.validation/md2_sabre_movement/camera-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_CAMERA_AUDIT ",JSON.stringify(report));lab.free();quit(0 if failures.is_empty() else 1)
