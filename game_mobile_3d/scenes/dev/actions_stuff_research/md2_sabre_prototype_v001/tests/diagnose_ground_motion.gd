extends SceneTree
## Derived measurements from OUR running adapter; never a native MD2 calibration.
func _initialize()->void:call_deferred("run")
func tick()->void:await physics_frame;await process_frame
func ticks(n:int)->void:
	for i in n:await tick()
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.grass_field_blocks=30;root.add_child(lab);await ticks(8)
	var a=lab.player;var rig:Skeleton3D=a.skeleton;var names:Array[String]=[]
	for i in rig.get_bone_count():names.append(rig.get_bone_name(i))
	print("BONES ",names)
	var probes:Array[Dictionary]=[]
	for input:String in ["move_forward","move_right","move_backward","move_left"]:
		lab.sabre_mode.reset();await ticks(4);Input.action_press(input);await ticks(35)
		var samples:Array[Dictionary]=[]
		for t in 90:
			var point:Vector3=a.global_position+Vector3.UP
			var screen:Vector2=lab.camera.unproject_position(point+a.velocity)-lab.camera.unproject_position(point)
			var entry:={"screen_velocity":[screen.x,screen.y],"visual_facing_error_deg":rad_to_deg(acos(clampf(a.visual.global_basis.z.normalized().dot(Vector3(a.velocity.x,0,a.velocity.z).normalized()),-1,1))),"bones":{}}
			for name:String in ["J_Root","J_Hip","J_Spine","J_Chest","J_Head"]:
				var b:=rig.find_bone(name)
				if b<0:continue
				var skin:Transform3D=rig.get_bone_global_pose(b)*rig.get_bone_global_rest(b).affine_inverse()
				var up:=skin.basis.y.normalized();var forward:=skin.basis.z.normalized()
				entry.bones[name]={"yaw":rad_to_deg(atan2(forward.x,forward.z)),"side_lean":rad_to_deg(atan2(up.x,up.y)),"forward_lean":rad_to_deg(atan2(-up.z,up.y)),"position":[skin.origin.x,skin.origin.y,skin.origin.z]}
			samples.append(entry);await tick()
		Input.action_release(input);probes.append({"input":input,"samples":samples})
	# Repeated full-body attacks on moving input must not invent root travel.
	lab.sabre_mode.reset();await ticks(4);Input.action_press("move_forward");await ticks(30)
	var start:Vector3=a.global_position;a.attack(true);await ticks(120);var distance:=Vector2(a.position.x-start.x,a.position.z-start.z).length();a.attack(false);Input.action_release("move_forward")
	var out:={"bones":names,"walking_probes":probes,"held_attack_input_travel_2seconds":distance,"source_clips":a.source_clip_count,"native_runtime_verified":false}
	var research:String=a.private_model_path().get_base_dir().get_base_dir().get_base_dir();var dir:=research.path_join("reports/prototype_sabre/movement_measurements/ground_combat");DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(dir.path_join("diagnosis.json"),FileAccess.WRITE).store_string(JSON.stringify(out,"\t"));print("GROUND_DIAGNOSIS ",JSON.stringify({"two_second_attack_travel":distance,"file":dir.path_join("diagnosis.json")}));lab.free();quit()
