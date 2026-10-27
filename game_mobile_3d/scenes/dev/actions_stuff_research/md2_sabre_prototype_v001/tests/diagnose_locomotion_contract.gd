extends SceneTree
## Private matched-time pose export and controlled movement traces. No source writes.
var folder:=""
var actor:CharacterBody3D
func _initialize()->void:call_deferred("run")
func matrix(t:Transform3D)->Array:
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0.,0.,0.,1.]]
func pose()->Array:
	actor.skeleton.force_update_all_bone_transforms()
	var result:Array=[]
	for bone in actor.skeleton.get_bone_count():result.append(matrix(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(bone)))
	return result
func run()->void:
	actor=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(actor);actor.set_physics_process(false)
	assert(actor.using_original_source)
	folder=actor.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/movement_measurements/contract_audit")
	if "--source-gait" in OS.get_cmdline_user_args():folder=actor.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/runtime_locomotion/source-gait-contract")
	if "--combat-runtime" in OS.get_cmdline_user_args():folder=actor.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/runtime_locomotion/combat/pose")
	if "--baseline" in OS.get_cmdline_user_args():
		actor.source_transition.clear();actor.source_transition=null;folder=folder.path_join("baseline")
	DirAccess.make_dir_recursive_absolute(folder)
	var names:Array=[];var parents:Array=[];var rests:Array=[];var track_contract:Dictionary={}
	for bone in actor.skeleton.get_bone_count():
		names.append(actor.skeleton.get_bone_name(bone));parents.append(actor.skeleton.get_bone_parent(bone));rests.append(matrix(actor.skeleton.get_bone_rest(bone)))
	var raw:Array=[]
	for key:String in actor.clips:
		var animation:Animation=actor.animation_player.get_animation(actor.clips[key].action);var tracks:Array=[]
		for index in animation.get_track_count():tracks.append({"path":str(animation.track_get_path(index)),"type":animation.track_get_type(index),"keys":animation.track_get_key_count(index)})
		track_contract[key]=tracks
		actor.reset_actor();actor.review_loop=false;actor.review(key)
		actor.animation_player.play(actor.clips[key].action,0.);actor.animation_player.advance(0.)
		var length:float=actor.animation_player.get_animation(actor.clips[key].action).length
		for fraction:float in [0.,.013,.083,.173,.25,.371,.5,.613,.75,.857,.937,1.]:
			var time:float=length*fraction
			actor.animation_player.seek(time,true);actor._refresh_markers()
			raw.append({"clip":key,"source_name":actor.clips[key].source_name,"time":time,"matrices":pose()})
	FileAccess.open(folder.path_join("godot-raw-poses.json"),FileAccess.WRITE).store_string(JSON.stringify({"bones":names,"parents":parents,"rests":rests,"tracks":track_contract,"samples":raw}))
	if "--raw-only" in OS.get_cmdline_user_args():print("LOCOMOTION_RAW_SAMPLES ",raw.size());actor.free();quit();return
	var floor:=StaticBody3D.new();var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.4,100);collision.shape=box;collision.position.y=-.2;floor.add_child(collision);root.add_child(floor)
	var trials:Array=[]
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second=hz
		# CharacterBody3D uses SceneTree's physics delta internally. Let the tree
		# observe the new rate before controlled manual callbacks.
		await physics_frame;await process_frame
		for trial:String in ["start_stop","reverse","walk_run","tap","wall"]:
			actor.reset_actor();actor.scripted_input=true
			var wall:StaticBody3D
			if trial=="wall":
				wall=StaticBody3D.new();var c:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=Vector3(10,4,.4);c.shape=s;wall.add_child(c);wall.position=Vector3(0,2,1.);root.add_child(wall)
			await physics_frame;await process_frame
			actor.set_physics_process(true)
			for i in 3:await physics_frame;await process_frame
			var samples:Array=[]
			for i in hz*2:
				var time:float=float(i)/hz
				actor.requested_run=true
				actor.requested_direction=Vector2(0,1) if time<1. else Vector2.ZERO
				if trial=="reverse":actor.requested_direction=Vector2(0,1 if time<1. else -1)
				elif trial=="walk_run":actor.requested_direction=Vector2(0,1);actor.requested_run=time>=.6 and time<1.4
				elif trial=="tap":actor.requested_direction=Vector2(0,1) if time<.05 else Vector2.ZERO
				await physics_frame;await process_frame
				var soles:Array=actor.direction_adapter.observe_soles(actor.global_position.y,actor.is_on_floor())
				var feet:Array=[]
				for foot:Dictionary in soles:feet.append({"xyz":[foot.center.x,foot.center.y,foot.center.z],"height":foot.height,"candidate":foot.candidate})
				samples.append({"t":(i+1.)/hz,"input":[actor.requested_direction.x,actor.requested_direction.y],"position":[actor.position.x,actor.position.y,actor.position.z],"velocity":[actor.get_real_velocity().x,actor.get_real_velocity().y,actor.get_real_velocity().z],"clip":actor.active_clip,"clip_time":actor.animation_player.current_animation_position,"rate":actor._playback_speed,"heading":actor.visual.rotation.y,"leg_yaw":actor.direction_adapter.current_yaw,"feet":feet})
			trials.append({"hz":hz,"trial":trial,"samples":samples})
			actor.set_physics_process(false)
			if wall!=null:wall.free()
	FileAccess.open(folder.path_join("godot-movement-traces.json"),FileAccess.WRITE).store_string(JSON.stringify({"trials":trials}))
	print("LOCOMOTION_CONTRACT_AUDIT ",JSON.stringify({"raw_samples":raw.size(),"trials":trials.size(),"folder":folder}))
	actor.free();floor.free();quit()
