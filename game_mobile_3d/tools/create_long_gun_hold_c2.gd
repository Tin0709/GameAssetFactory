extends SceneTree
## Offline authoring in model space; no runtime hand solver or rig edits.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var model=preload("res://assets/characters/player_cuboid_animated_v1.glb").instantiate()
	root.add_child(model)
	var sk: Skeleton3D=model.find_child("Skeleton3D",true,false)
	var hold:=Animation.new()
	hold.resource_name="LongGunHold_V2";hold.length=1.0;hold.loop_mode=Animation.LOOP_LINEAR
	for name in ["Arm.R","Arm.L","WeaponSocket","Chest"]:
		var bone:=sk.find_bone(name)
		# WeaponSocket is added by the adapter at runtime; its parent is Chest.
		var parent:=sk.find_bone("Chest") if bone<0 else sk.get_bone_parent(bone)
		var parent_rest:=sk.get_bone_global_rest(parent)
		var p: Vector3
		var q: Quaternion
		if name.begins_with("Arm."):
			var rest:=sk.get_bone_global_rest(bone)
			var right: bool=name=="Arm.R"
			var shoulder:=rest.origin+Vector3(0,-0.015 if right else -0.035,0.035 if right else 0.145)
			var direction:=Vector3(0.43,-0.48,0.765).normalized() if right else Vector3(-0.27,-0.50,0.823).normalized()
			var basis:=Basis(Quaternion(rest.basis.y,direction))*rest.basis
			p=parent_rest.affine_inverse()*shoulder
			q=(parent_rest.basis.inverse()*basis).get_rotation_quaternion()
		elif name=="WeaponSocket":
			var pitch:=deg_to_rad(7.0)
			var basis:=Basis(Vector3.LEFT,Vector3(0,-sin(pitch),cos(pitch)),Vector3(0,cos(pitch),sin(pitch)))
			var grip:=Vector3(-0.06,0.985,0.465)
			var origin:=grip-basis*Vector3(0.210,0.270,-0.120)
			p=parent_rest.affine_inverse()*origin
			q=(parent_rest.basis.inverse()*basis).get_rotation_quaternion()
		else:
			# Chest track is a delta, composed additively over locomotion.
			p=Vector3.ZERO;q=Quaternion.from_euler(Vector3(deg_to_rad(2.0),deg_to_rad(-4.0),0))
		for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
			if name=="Chest" and type==Animation.TYPE_POSITION_3D:continue
			var track:=hold.add_track(type)
			hold.track_set_path(track,NodePath("Player_Cuboid_Rig/Skeleton3D:"+name))
			for time in [0.0,1.0]:hold.track_insert_key(track,time,p if type==Animation.TYPE_POSITION_3D else q)
	assert(ResourceSaver.save(hold,"res://assets/characters/LongGunHold_V2.tres")==OK)
	quit()
