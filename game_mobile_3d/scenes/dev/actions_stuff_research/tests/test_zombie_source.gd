extends SceneTree
const Sampler=preload("res://scenes/dev/actions_stuff_research/source_clip_sampler.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok and not failures.has(message):failures.append(message);push_error(message)
func run() -> void:
	var stage:=OS.get_cmdline_user_args()[0]
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
	var v=scene.zombie_combat.zombies[0].visual
	var fixtures: Array=JSON.parse_string(FileAccess.get_file_as_string(stage+"/fixtures.json"))
	var position_error:=0.0;var rotation_error:=0.0;var scale_error:=0.0
	for f in fixtures:
		var clip: Animation=v.source_library.get_animation(f.kind)
		var sampler=Sampler.new(clip,v.skeleton)
		for name: String in f.poses:
			var bone: int=v.skeleton.find_bone(name);var p: Array=f.poses[name]
			position_error=maxf(position_error,sampler.position(bone,f.time).distance_to(Vector3(p[0],p[1],p[2])))
			var expected:=Quaternion(p[3],p[4],p[5],p[6]).normalized()
			rotation_error=maxf(rotation_error,1.0-absf(expected.dot(sampler.rotation(bone,f.time))))
			scale_error=maxf(scale_error,sampler.scale(bone,f.time).distance_to(Vector3(p[7],p[8],p[9])))
	check(position_error<.000002 and rotation_error<.000002 and scale_error<.000002,"All evaluated Blender PRS fixtures retained on original10bone rig")
	check(v.source_library.get_animation("Idle").resource_name=="Zombie_Idle_ActionsStuff_Source_Test_v001","Exact requested Idle")
	check(v.source_library.get_animation("Walk").resource_name=="Zombie_Walk_ActionsStuff_Source_Test_v001","Exact requested Walk")
	check(v.source_library.get_animation("Attack").resource_name=="Zombie_Attack_Player_A&S_Reference_v001","Exact requested Attack")
	for kind in ["Idle","Walk"]:
		var clip: Animation=v.source_library.get_animation(kind)
		check(clip.loop_mode==Animation.LOOP_LINEAR,"Source locomotion loops")
		var sampler=Sampler.new(clip,v.skeleton)
		for bone in v.skeleton.get_bone_count():
			check(sampler.position(bone,0.0).distance_to(sampler.position(bone,clip.length))<.00001,"Locomotion seam translation")
			check(absf(sampler.rotation(bone,0.0).dot(sampler.rotation(bone,clip.length)))>.99999,"Locomotion seam rotation")
	check(v.source_library.get_animation("Attack").loop_mode==Animation.LOOP_NONE,"Attack remains a one-shot")
	var report:={"passed":failures.is_empty(),"failures":failures,"fixtures":fixtures.size(),"position_error_m":position_error,"rotation_quaternion_dot_error":rotation_error,"scale_error":scale_error}
	FileAccess.open(stage+"/parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("ZOMBIE_SOURCE_PARITY ",JSON.stringify(report));scene.free();quit(0 if failures.is_empty() else 1)
