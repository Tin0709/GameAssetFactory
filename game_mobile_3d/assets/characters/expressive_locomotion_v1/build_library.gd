extends SceneTree
func _initialize() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/expressive_locomotion_v1/approved_samples.json"))
	var library:=AnimationLibrary.new()
	for name: String in data:
		var record: Dictionary=data[name]
		var clip:=Animation.new();clip.resource_name=name;clip.length=record.duration;clip.loop_mode=Animation.LOOP_LINEAR
		for bone: String in record.samples[0]:
			var pt:=clip.add_track(Animation.TYPE_POSITION_3D);var qt:=clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(pt,NodePath("Skeleton3D:"+bone));clip.track_set_path(qt,NodePath("Skeleton3D:"+bone))
			for i in record.samples.size():
				var p: Array=record.samples[i][bone][0];var q: Array=record.samples[i][bone][1]
				clip.position_track_insert_key(pt,i/float(record.hz),Vector3(p[0],p[1],p[2]))
				clip.rotation_track_insert_key(qt,i/float(record.hz),Quaternion(q[0],q[1],q[2],q[3]))
		library.add_animation(name,clip)
	var error:=ResourceSaver.save(library,"res://assets/characters/expressive_locomotion_v1/approved_library.res",ResourceSaver.FLAG_COMPRESS)
	print("LIBRARY_BUILD ",error," clips ",library.get_animation_list());quit(error)
