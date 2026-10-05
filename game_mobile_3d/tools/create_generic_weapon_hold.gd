extends SceneTree
const Sampler=preload("res://scripts/animation_pose_sampler.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model=preload("res://assets/characters/player_animation_v2.glb").instantiate()
	root.add_child(model)
	var sk: Skeleton3D=model.find_child("Skeleton3D",true,false)
	var ap: AnimationPlayer=model.find_child("AnimationPlayer",true,false)
	var source=Sampler.new(ap.get_animation("LongGun_Raise"),sk)
	var hold:=Animation.new()
	hold.resource_name="WeaponHold";hold.length=1.0;hold.loop_mode=Animation.LOOP_LINEAR
	for name in ["Arm.L","Arm.R","WeaponSocket"]:
		var bone:=sk.find_bone(name)
		var p: Vector3=source.position(bone,source.clip.length*0.75)
		var q: Quaternion=source.rotation(bone,source.clip.length*0.75)
		# One shared carry pose. Preserve arm lengths and the existing socket's
		# local frame. A small front-shoulder stance clears the rigid torso.
		if name.begins_with("Arm."):p+=Vector3(0,0,0.10)
		for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
			var track:=hold.add_track(type)
			hold.track_set_path(track,NodePath("Player_Cuboid_Rig/Skeleton3D:"+name))
			for time in [0.0,1.0]:hold.track_insert_key(track,time,p if type==Animation.TYPE_POSITION_3D else q)
		print(name," POSITION=",p," ROTATION=",q)
	var error:=ResourceSaver.save(hold,"res://assets/characters/WeaponHold.tres")
	assert(error==OK)
	quit()
