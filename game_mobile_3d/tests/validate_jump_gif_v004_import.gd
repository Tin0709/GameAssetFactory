extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var old:Node=load("res://assets/characters/jump_loop_v003/player_r15_jump_loop_v003.glb").instantiate()
	var current:Node=load("res://assets/characters/jump_gif_v004/player_r15_jump_gif_v004.glb").instantiate()
	var a:AnimationPlayer=old.find_child("AnimationPlayer",true,false)
	var b:AnimationPlayer=current.find_child("AnimationPlayer",true,false)
	var checks:Array=[];var failures:Array=[]
	for name in a.get_animation_list():
		var same:=b.has_animation(name)
		if same:
			var x:Animation=a.get_animation(name);var y:Animation=b.get_animation(name)
			same=x.length==y.length and x.loop_mode==y.loop_mode and x.get_track_count()==y.get_track_count()
			if same:
				for track in x.get_track_count():
					same=same and x.track_get_path(track)==y.track_get_path(track) and x.track_get_type(track)==y.track_get_type(track) and x.track_get_interpolation_type(track)==y.track_get_interpolation_type(track) and x.track_is_enabled(track)==y.track_is_enabled(track) and x.track_get_key_count(track)==y.track_get_key_count(track)
					if not same:break
					for key in x.track_get_key_count(track):
						same=same and x.track_get_key_time(track,key)==y.track_get_key_time(track,key) and x.track_get_key_value(track,key)==y.track_get_key_value(track,key) and x.track_get_key_transition(track,key)==y.track_get_key_transition(track,key)
		checks.append({"clip":name,"passed":same})
		if not same:failures.append(name)
	var added:=b.has_animation("Jump_DungeonsII_Combined_v004") and b.get_animation("Jump_DungeonsII_Combined_v004").loop_mode==Animation.LOOP_NONE and b.get_animation_list().size()==a.get_animation_list().size()+1
	checks.append({"clip":"One added nonperiodic V004","passed":added})
	if not added:failures.append("Added clip")
	FileAccess.open("res://.validation/jump_gif_v004/import_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("V004_IMPORT checks=",checks.size()," failures=",failures)
	old.free();current.free();quit(0 if failures.is_empty() else 1)
