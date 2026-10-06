extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	root.add_child(level);level.select_test_weapon(1)
	var v=level.player.visual
	v.set_process(false);v.weapon_hold_weight=1.0;v.long_gun_weight=1.0;v._evaluate(0.0)
	for name in ["Chest","Neck","Head","Arm.L","Arm.R","WeaponSocket"]:
		var i=v.skeleton.find_bone(name)
		print(name," rest=",v.skeleton.get_bone_global_rest(i)," pose=",v.skeleton.get_bone_global_pose(i))
	for w in [1,2]:
		var instance=v.socket.instances[w]
		for name in ["Grip_Point","Support_Hand_Point","Muzzle_Point"]:
			var marker=instance.find_child(name,true,false)
			var asset_point: Vector3=instance.to_local(marker.global_position)
			var model_point: Vector3=v.skeleton.get_bone_global_pose(v.socket_bone)*instance.transform*asset_point
			print(w," ",name," asset=",asset_point," sk=",model_point)
	quit()
