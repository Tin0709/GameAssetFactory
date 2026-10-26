extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func error(a:Transform3D,b:Transform3D)->float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func _initialize()->void:call_deferred("run")
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.md2_sabre_prototype_enabled=true;lab.grass_field_blocks=30;root.add_child(lab)
	await physics_frame;await process_frame
	var mode=lab.sabre_mode;var a=lab.player;var viewport:=root.get_viewport()
	print("SABRE_PRESENTATION_SETTINGS ",JSON.stringify({"scale":viewport.scaling_3d_scale,"mode":viewport.scaling_3d_mode,"taa":viewport.use_taa,"screen_aa":viewport.screen_space_aa,"msaa":viewport.msaa_3d,"project_physics_interpolation":ProjectSettings.get_setting("physics/common/physics_interpolation",false)}))
	check(mode.get("render_presenter")!=null,"Source mode needs render-rate presentation for skin/Sabre/camera")
	check(absf(viewport.scaling_3d_scale-1.)<.00001,"Source clarity uses native resolution without changing Medium shadow tier")
	if mode.get("render_presenter")==null:lab.free();quit(1);return
	lab.set_process(false);a.set_physics_process(false);mode.set_physics_process(false)
	var p=mode.render_presenter;var rig:Skeleton3D=a.skeleton
	mode.set_native_pixels(false);check(absf(viewport.scaling_3d_scale-.85)<.00001,"Clarity-off restores selected Medium render scale")
	lab.md2_lighting.set_quality(0);mode.set_native_pixels(true);check(viewport.scaling_3d_scale==1. and lab.md2_lighting.quality==0,"Native pixels preserve selected Low lighting tier")
	mode.set_native_pixels(false);check(absf(viewport.scaling_3d_scale-.75)<.00001,"Clarity-off follows latest selected quality tier")
	lab.md2_lighting.set_original(true);mode.set_native_pixels(false);check(viewport.scaling_3d_scale==lab.md2_lighting.original_view.scale,"Original lighting A/B retains original render scale")
	lab.md2_lighting.set_original(false);lab.md2_lighting.set_quality(1);mode.set_native_pixels(true)
	var worst_endpoint:=0.;var worst_rigid:=0.;var samples:=0
	for hz in [30,60]:
		a.reset_actor();p.reset_history()
		for i in 12:
			a.global_position+=Vector3(.07,0,-.04);a.visual.rotation.y+=.08
			a.review_clip="";a.current_speed=7.;a._move_requested=true;a._run_requested=true;a._grounded=true;a._animate(1./hz);p.capture()
			var source_clock:float=a.simulation_clock;var physical:Transform3D=a.global_transform;var marker:Transform3D=a.marker_tip.global_transform;var frozen:Array[Transform3D]=[]
			for bone in rig.get_bone_count():frozen.append(rig.get_bone_pose(bone))
			for alpha:float in [0.,.25,.5,.75,1.]:
				p.prepare(alpha)
				check(a.global_transform==physical and a.simulation_clock==source_clock and a.marker_tip.global_transform==marker,"Presentation leaves physical authority unchanged")
				var untouched:=true
				for bone in rig.get_bone_count():untouched=untouched and rig.get_bone_pose(bone)==frozen[bone]
				check(untouched,"Render sampling cannot rewrite original skeleton pose")
				check(p.display_actor.distance_to(Vector3(p.previous.actor).lerp(p.current.actor,alpha))<.00001,"Camera follows same interpolated actor root")
				if alpha==0. or alpha==1.:
					var endpoint:Dictionary=p.previous if alpha==0. else p.current
					for bone in rig.get_bone_count():worst_endpoint=maxf(worst_endpoint,error(p.display_world[bone],endpoint.world[bone]))
					for index in p.meshes.size():worst_rigid=maxf(worst_rigid,error(p.display_meshes[index],endpoint.meshes[index]))
				check(p.display_marker(a.marker_tip).origin.distance_to(p.display_world[a._weapon_attachment.bone_idx]*a.marker_tip.transform.origin)<.00002,"Rendered blade marker uses the same weapon bone")
				samples+=1
	# Exact nonuniform original finisher basis must survive at both endpoints.
	a.review("Attack3");a.animation_player.seek(.35,true);a._refresh_markers();p.capture();p.prepare(1.)
	check(error(p.display_world[a._weapon_attachment.bone_idx],rig.global_transform*rig.get_bone_global_pose(a._weapon_attachment.bone_idx))<.00002,"Finisher's full original weapon basis is retained")
	a.reset_actor();p.prepare(.5);check(p.display_actor.distance_to(a.global_position)<.00001,"Reset rebases history, avoiding a teleport streak")
	check(worst_endpoint<.00002 and worst_rigid<.00003,"Exact render endpoint matrices for skin and original rigid Sabre")
	print("SABRE_PRESENTATION ",JSON.stringify({"checks":checks,"failures":failures,"fractional_samples":samples,"endpoint_error":worst_endpoint,"rigid_error":worst_rigid}));lab.free();quit(0 if failures.is_empty() else 1)
