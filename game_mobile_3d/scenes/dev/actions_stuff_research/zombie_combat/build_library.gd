extends SceneTree
func _initialize() -> void:call_deferred("build")
func build() -> void:
	var stage:=OS.get_cmdline_user_args()[0]
	var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(stage+"/profile.json"))
	var library:=AnimationLibrary.new()
	for kind: String in profile.clips:
		var info: Dictionary=profile.clips[kind]
		var file:=FileAccess.open(stage+"/"+info.raw_file,FileAccess.READ)
		var data:=file.get_buffer(file.get_length()).to_float32_array()
		assert(data.size()==int(info.samples)*int(info.row_floats))
		var clip:=Animation.new();clip.resource_name=info.action;clip.length=float(info.duration)
		clip.loop_mode=Animation.LOOP_LINEAR if info.loop else Animation.LOOP_NONE
		for bone in profile.bones.size():
			var tracks: Array[int]=[]
			for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
				var track:=clip.add_track(type);clip.track_set_path(track,NodePath(":"+str(profile.bones[bone])));tracks.append(track)
			for i in int(info.samples):
				var row:=i*int(info.row_floats);var t:=float(info.duration) if i==int(info.samples)-1 else float(data[row]);var p: int=row+1+bone*10
				clip.position_track_insert_key(tracks[0],t,Vector3(data[p],data[p+1],data[p+2]))
				clip.rotation_track_insert_key(tracks[1],t,Quaternion(data[p+3],data[p+4],data[p+5],data[p+6]).normalized())
				clip.scale_track_insert_key(tracks[2],t,Vector3(data[p+7],data[p+8],data[p+9]))
		library.add_animation(kind,clip);info.erase("raw_file")
	var dest:="res://scenes/dev/actions_stuff_research/zombie_combat/"
	assert(ResourceSaver.save(library,dest+"source_library.res",ResourceSaver.FLAG_COMPRESS)==OK)
	FileAccess.open(dest+"profile.json",FileAccess.WRITE).store_string(JSON.stringify(profile,"\t"))
	print("MOBS_RESEARCH_LIBRARY ",library.get_animation_list());quit()
