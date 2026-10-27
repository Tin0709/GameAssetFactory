extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a);a.set_physics_process(false)
	check(a.get("using_original_source")==true,"Original source bundle is preferred over private retarget and authored fallback")
	if not failures.is_empty():a.free();quit(1);return
	check(a.skeleton.get_bone_count()==32 and a.skeleton.find_bone("J_R_Weapon")>=0,"Original32-joint hierarchy retained")
	check(a.clips.size()==22+a.supplemental_combat_clips and a.source_clip_count==13 and a.source_alias_count==9,"Twenty-two semantic states expose thirteen originals and nine declared aliases")
	check(absf(a.clips.ReadyEnter.duration-2.666667)<.000001 and a.clips.ReadyEnter.source_alias_adapter,"Adjacent source manifest owns original transition-alias duration")
	check(FileAccess.get_sha256(a.private_model_path())==a.private_metadata.glb_sha256,"Runtime source bundle matches validated original-data manifest")
	var sabre:MeshInstance3D
	for node:Node in a.model.find_children("*","MeshInstance3D",true,false):
		if "Sabre" in String(node.name) and node!=a.face and "Body" not in String(node.name):sabre=node
	check(sabre!=null and sabre.name=="SabrePrototypeSabre","Original Sabre mesh participates in the runtime scene")
	check(a.marker_base!=null and a.marker_tip!=null,"Original weapon attachment supplies actual trajectory markers")
	var tip:Vector3=a.marker_tip.global_position
	a.review("Attack1");a.animation_player.play(a.clips.Attack1.action,0.);a.animation_player.advance(0.);a._animate(.12)
	check(a.marker_tip.global_position.distance_to(tip)>.1,"Original source weapon channels move actual blade marker")
	a.global_position=Vector3(2,0,-3);a.visual.rotation.y=.42
	a.review("Attack3");a.animation_player.play(a.clips.Attack3.action,0.);a.animation_player.advance(0.);a.animation_player.seek(.35,true);a._refresh_markers()
	var attachment:BoneAttachment3D=a._weapon_attachment
	var source_pose:Transform3D=a.skeleton.get_bone_global_pose(attachment.bone_idx)
	check(attachment.transform.is_equal_approx(source_pose),"Attachment retains complete source Attack3 basis/origin including scale")
	var expected:Transform3D=a.skeleton.global_transform*source_pose*a.marker_tip.transform
	check(a.marker_tip.global_transform.is_equal_approx(expected),"Marker is exact full source bone transform times actual imported marker offset under rotated/translated actor")
	check(sabre.get_parent()==attachment,"Original Sabre and trajectory markers share the same source attachment")
	var lengths:=Vector3(source_pose.basis.x.length(),source_pose.basis.y.length(),source_pose.basis.z.length())
	check(maxf(lengths.x,maxf(lengths.y,lengths.z))-minf(lengths.x,minf(lengths.y,lengths.z))>.01,"Original nonuniform weapon scale has not been stripped")
	a.resume_gameplay();a.expression_mode=0;a.expression_clock=3.44;a._animate(.01)
	check(a.focus_value==0. and a.blink_value==0.,"Source Auto defers to original facial bone channels without added periodic morph blink")
	a.combat_requested=true;a._previous_combat=false;a.scripted_input=true;a._physics_process(1./60.)
	check(a._transition.is_empty(),"Source profile bypasses invented long Idle-as-ready transition")
	a.free();print("SABRE_SOURCE_PROFILE ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
