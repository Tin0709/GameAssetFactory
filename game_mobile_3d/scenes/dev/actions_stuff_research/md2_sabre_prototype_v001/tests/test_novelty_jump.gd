extends SceneTree
var failures:Array[String]=[]
var checks:=0
var rows:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.md2_sabre_prototype_enabled=true;lab.grass_field_blocks=80;root.add_child(lab);await tick()
	var a=lab.player;a.scripted_input=true
	check(a.get("novelty_jump")!=null,"Recovered third jump variation is available in existing actor")
	if not failures.is_empty():finish(lab);return
	check(a.clips.has("JumpFlip"),"Original clip is independently selectable without replacing approved jump")
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second=hz;a.reset_actor();await ticks(3)
		for index in 4:
			var start:float=a.simulation_clock;a.requested_jump=true;await tick();a.requested_jump=false
			var expected_flip:=index==2;var serial:int=a.novelty_jump.serial;var minimum_up:=1.;var peak:=0.;var selected:bool=a.active_clip=="JumpFlip";var pose_error:=0.
			check(selected==expected_flip,"Two ordinary jumps then original flip, sequence "+str(index)+" at "+str(hz))
			for i in hz:
				# Bone localY is not anatomical up in this recovered rig. Measure
				# the skin deformation of WORLD up relative to its actual rest basis.
				# Source hip is a fixed pivot; the torso somersault is authored on Spine.
				var hip:int=a.skeleton.find_bone("J_Shoulders")
				var deformation:Basis=a.skeleton.get_bone_global_pose(hip).basis*a.skeleton.get_bone_global_rest(hip).basis.inverse()
				var body_up:Vector3=a.skeleton.global_basis*deformation*(a.skeleton.global_basis.inverse()*Vector3.UP)
				minimum_up=minf(minimum_up,body_up.normalized().dot(Vector3.UP))
				if expected_flip and a.active_clip=="JumpFlip" and a.source_transition.incoming_weight>=.9999:
					var original:Array=a.hybrid_motion._native_worlds(a,"JumpFlip",a.animation_player.current_animation_position)
					for name in ["J_Spine","J_Shoulders","J_Head","J_L_Leg","J_R_Leg","J_R_Weapon"]:
						var bone:int=a.skeleton.find_bone(name);var shown:Transform3D=a.skeleton.get_bone_global_pose(bone)
						pose_error=maxf(pose_error,maxf(shown.origin.distance_to(original[bone].origin),shown.basis.get_rotation_quaternion().angle_to(original[bone].basis.get_rotation_quaternion())))
				peak=maxf(peak,a.global_position.y)
				if a._grounded:break
				await tick()
			check(a._grounded and a.simulation_clock-start<.55,"Flip never adds flight height/delay "+str(hz)+" "+str(index))
			check(absf(peak-1.728)<.015,"All variants retain same ballistic rise "+str(hz)+" "+str(index))
			if expected_flip:
				check(minimum_up<-.5,"Full-body source really rotates upside-down, not just a renamed ordinary jump "+str(hz))
				check(pose_error<.002,"Torso/head/limbs/weapon match original source sampling after entry handoff "+str(hz))
			check(a.novelty_jump.serial==serial,"No duplicate launch on landing or held jump "+str(hz))
			rows.append({"hz":hz,"index":index,"flip":selected,"minimum_torso_up":minimum_up,"peak":peak,"air_s":a.simulation_clock-start,"source_pose_error":pose_error})
			await tick()
		await ticks(ceili(.25*hz));a.requested_jump=true;await tick();a.requested_jump=false
		check(a.novelty_jump.variant==0 and a.active_clip!="JumpFlip","Ground pause resets chain "+str(hz))
		await ticks(2);var serial:int=a.novelty_jump.serial;a.requested_jump=true;await tick();a.requested_jump=false
		check(a.novelty_jump.serial==serial,"Repeated air press cannot become a double jump "+str(hz))
		await ticks(hz)
		# Restore chain by two more immediate legal launches, then interrupt flip.
		a.reset_actor();await ticks(3)
		for index in 3:
			a.requested_jump=true;await tick();a.requested_jump=false
			if index<2:
				for i in hz:
					if a._grounded:break
					await tick()
				await tick()
		await ticks(ceili(.10*hz));a.attack(true);await tick();a.attack(false)
		check(a.active_clip=="AirAttack" and not a.novelty_jump.flip,"Sabre air attack takes pose ownership from flip "+str(hz))
		await ticks(hz*2)
		check(a.is_on_floor() and a.skeleton.get_bone_global_pose(a.skeleton.find_bone("J_Head")).is_finite(),"Interrupted flip returns to intact grounded pose "+str(hz))
	finish(lab)
func finish(lab)->void:
	var report:={"checks":checks,"failures":failures,"cases":rows};print("NOVELTY_JUMP ",JSON.stringify(report))
	FileAccess.open("C:/Users/ADMIN/Desktop/MD2 Research/reports/prototype_sabre/jump_flip_20261028/validation.private.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));lab.free();quit(0 if failures.is_empty() else 1)
func tick()->void:await physics_frame;await process_frame
func ticks(n:int)->void:for i in n:await tick()
