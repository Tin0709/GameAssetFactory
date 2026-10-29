extends SceneTree
var errors:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func protected_environment(env:Environment)->Dictionary:
	var result:={}
	for p:Dictionary in env.get_property_list():
		var n:String=p.name
		if n.begins_with("fog_")or n.begins_with("glow_")or n.begins_with("tonemap_")or n.begins_with("adjustment_"):result[n]=str(env.get(n))
	return result
func run()->void:
	var lab=load("res://scenes/dev/MD2OverworldFidelityTest.tscn").instantiate();root.add_child(lab)
	var owner:Node=lab.get("graphics_foundation")
	check(owner!=null,"Existing Overworld needs reversible foundation owner")
	if owner==null:lab.free();finish();return
	owner.set_cycle_enabled(false);owner.seek_cycle(.15,true)
	owner.set_candidate(false);owner.set_comparison_camera(false);lab._update_camera()
	var env_before:=protected_environment(lab.md2_lighting.world.environment)
	var before_count:int=lab.meadow.instance_count;var before_bone_count:int=lab.player.skeleton.get_bone_count()
	var transforms:={}
	for n:Node in lab.meadow.get_children():
		if n is MultiMeshInstance3D:transforms[n.name]=n.multimesh.buffer.duplicate()
	var baseline_sun:Vector3=lab.md2_lighting.sun.rotation_degrees
	var shader_before:Dictionary=owner.material_identity()
	check(owner.has_method("set_local_overrides")and owner.has_method("set_phase"),"Foundation exposes validated phase/local-light interfaces")
	if owner.has_method("set_local_overrides"):
		check(not owner.set_phase(&"unrecovered_night"),"No invented biome/phase calibration")
		check(owner.set_phase(&"day"),"Known Day phase selectable")
		var original_energy:float=owner.resolved.sun_energy
		check(owner.set_local_overrides([{"priority":1,"weight":1.,"fields":{"sun_energy":original_energy+1.}}]),"Original local light override accepted")
		check(owner.resolved.sun_energy==original_energy,"Override does not pop on assignment")
		owner._process(.5)
		check(owner.resolved.sun_energy>original_energy+.9 and owner.resolved.sun_energy<original_energy+1.,"Local light transition is bounded and smooth")
		check(not owner.set_local_overrides([{"weight":1.,"fields":{"shadow_bias":9.}}]),"Deferred shadow override rejected")
		owner.set_local_overrides([]);owner._process(4.)
	owner.set_candidate(true);lab._update_camera()
	check(lab.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Candidate perspective")
	check(lab.camera.keep_aspect==Camera3D.KEEP_WIDTH and is_equal_approx(lab.camera.fov,45.),"Horizontal45 degree FOV convention")
	check(absf(rad_to_deg(asin(lab.camera.global_basis.z.y))-45.)<.01,"Downward45 degree camera")
	check(protected_environment(lab.md2_lighting.world.environment)==env_before,"Fog/postprocess unchanged")
	check(lab.meadow.instance_count==before_count and lab.player.skeleton.get_bone_count()==before_bone_count,"Assets/rig/distribution preserved")
	for n:Node in lab.meadow.get_children():
		if n is MultiMeshInstance3D:check(n.multimesh.buffer==transforms[n.name],"Instance buffer unchanged "+str(n.name))
	check(owner.material_identity()!=shader_before,"Candidate has independent materials")
	owner.set_candidate(false);owner.set_comparison_camera(true);lab._update_camera()
	check(lab.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Baseline can use matched perspective")
	check(owner.material_identity()==shader_before,"Baseline material identity restored")
	check(lab.md2_lighting.sun.rotation_degrees.is_equal_approx(baseline_sun),"Baseline direct light restored")
	owner.set_comparison_camera(false);lab._update_camera()
	check(lab.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Original camera restored")
	owner.release();owner.release()
	check(lab.md2_lighting.is_processing(),"Lighting owner processing restored")
	check(protected_environment(lab.md2_lighting.world.environment)==env_before,"Exit leaves postprocess intact")
	lab.free();await process_frame;finish()
func finish()->void:
	print("GRAPHICS_OWNER_CHECKS ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty()else 1)
