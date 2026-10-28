extends RefCounted
## Private clip routing only. Counter/reset scheduling is an original adapter;
## no recovered code or source keyframes are embedded in this module.
var enabled:=true
var requested_enabled:=true
var variant:=-1
var flip:=false
var serial:=0
var launched_at:=0.
var last_contact:=-INF
var config:Dictionary={}
func setup(actor,path:String)->bool:
	var project:=ProjectSettings.globalize_path("res://").replace("\\","/").simplify_path().to_lower().trim_suffix("/")+"/"
	var normalized:=path.replace("\\","/").simplify_path().to_lower()
	if not path.is_absolute_path() or normalized.begins_with(project) or not FileAccess.file_exists(path):return false
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>16000:return false
	file.close()
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema")!="private-novelty-jump/1" or data.get("research_only")!=true or data.get("production_eligible")!=false:return false
	if data.get("target_sha256")!=FileAccess.get_sha256(actor.private_model_path()):return false
	for key in ["source_path","source_name","source_sha256"]:
		if not data.get(key) is String or String(data[key]).is_empty():return false
	for key in ["duration","reset_ground_seconds","variants","flip_variant"]:
		if not(data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):return false
	if float(data.duration)<=0. or float(data.duration)>5. or float(data.reset_ground_seconds)<0. or float(data.reset_ground_seconds)>5.:return false
	if int(data.variants)!=float(data.variants) or int(data.variants)<2 or int(data.variants)>8 or int(data.flip_variant)!=float(data.flip_variant) or int(data.flip_variant)<0 or int(data.flip_variant)>=int(data.variants):return false
	# Source must stay within the same private Research root, outside the project.
	var research:String=actor.private_model_path().get_base_dir().get_base_dir().get_base_dir().replace("\\","/").simplify_path().to_lower().trim_suffix("/")+"/"
	var source:String=data.source_path;var source_normalized:=source.replace("\\","/").simplify_path().to_lower()
	if not source.is_absolute_path() or not source_normalized.begins_with(research) or source_normalized.begins_with(project) or not source_normalized.ends_with(".glb"):return false
	if not FileAccess.file_exists(source):return false
	var source_file:=FileAccess.open(source,FileAccess.READ)
	if source_file==null or source_file.get_length()>32000000:return false
	source_file.close()
	if FileAccess.get_sha256(source)!=data.source_sha256:return false
	var imported:Node3D=actor.load_private_model(source)
	if imported==null:return false
	var player:AnimationPlayer;var rig:Skeleton3D
	for node:Node in imported.find_children("*","",true,false):
		if node is AnimationPlayer:player=node
		elif node is Skeleton3D:rig=node
	var valid:bool=player!=null and rig!=null and rig.get_bone_count()==actor.skeleton.get_bone_count()
	if valid:
		for bone in rig.get_bone_count():
			if rig.get_bone_name(bone)!=actor.skeleton.get_bone_name(bone) or rig.get_bone_parent(bone)!=actor.skeleton.get_bone_parent(bone) or not rig.get_bone_rest(bone).is_equal_approx(actor.skeleton.get_bone_rest(bone)):valid=false;break
	var animation:Animation;var count:=0
	if valid:
		for name:String in player.get_animation_list():
			if name!="RESET":animation=player.get_animation(name);count+=1
		valid=count==1 and animation!=null and absf(animation.length-float(data.duration))<.001
	var copied:Animation
	if valid:
		copied=animation.duplicate(true)
		var target:NodePath=actor.animation_player.get_node(actor.animation_player.root_node).get_path_to(actor.skeleton)
		for track in copied.get_track_count():
			var old:=copied.track_get_path(track)
			if old.get_subname_count()!=1 or actor.skeleton.find_bone(old.get_subname(0))<0 or copied.track_get_type(track) not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:valid=false;break
			copied.track_set_path(track,NodePath(str(target)+":"+str(old.get_subname(0))))
	imported.free()
	if not valid or actor.animation_player.has_animation_library("private_jump") or actor.clips.has("JumpFlip"):return false
	var library:=AnimationLibrary.new();copied.loop_mode=Animation.LOOP_NONE;library.add_animation("JumpFlip",copied);actor.animation_player.add_animation_library("private_jump",library)
	actor.clips["JumpFlip"]={"action":"private_jump/JumpFlip","duration":float(data.duration),"loop":false,"category":"jump","source_name":data.source_name,"source_file":source,"source_alias_adapter":false}
	actor.source_clip_count+=1;config=data;return true
func reset()->void:
	variant=-1;flip=false;last_contact=-INF;serial=0;launched_at=0.
func cancel()->void:
	variant=-1;flip=false;last_contact=-INF
func set_enabled(value:bool)->void:requested_enabled=value
func launch(clock:float)->void:
	if enabled!=requested_enabled:cancel()
	enabled=requested_enabled;serial+=1;launched_at=clock
	if not enabled:cancel();return
	variant=0 if variant<0 or clock-last_contact>float(config.reset_ground_seconds)+.0000001 else (variant+1)%int(config.variants)
	flip=variant==int(config.flip_variant)
func contact(clock:float)->void:last_contact=clock;flip=false
func diagnostics()->Dictionary:
	return {"enabled":enabled,"requested":requested_enabled,"variant":variant,"flip":flip,"serial":serial,"source_name":config.get("source_name"),"reset_ground_seconds":config.get("reset_ground_seconds"),"scope":config.get("scope")}
