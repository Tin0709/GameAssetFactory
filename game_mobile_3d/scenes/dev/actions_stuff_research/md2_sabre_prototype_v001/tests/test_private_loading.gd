extends SceneTree
var failures:Array[String]=[]
var checks:=0
func inventory(path:String,result:Dictionary)->void:
	var directory:=DirAccess.open(path)
	if directory==null:return
	for file:String in directory.get_files():result[path.path_join(file)]=true
	for folder:String in directory.get_directories():inventory(path.path_join(folder),result)
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	if "--inspect-probe" in OS.get_cmdline_user_args():
		var probe:=ReflectionProbe.new()
		for property:Dictionary in probe.get_property_list():
			if property.type!=TYPE_NIL and not String(property.name).begins_with("_"):print("PROBE_PROPERTY ",property.name,"=",probe.get(property.name))
		probe.free()
	if "--inspect-gltf" in OS.get_cmdline_user_args():
		for property:Dictionary in GLTFState.new().get_property_list():
			if "image" in String(property.name):print("GLTF_PROPERTY ",property)
		for constant:String in ClassDB.class_get_integer_constant_list("GLTFState"):
			if "IMAGE" in constant:print("GLTF_CONSTANT ",constant,"=",ClassDB.class_get_integer_constant("GLTFState",constant))
		for method:Dictionary in ClassDB.class_get_method_list("GLTFDocument"):
			if method.name=="generate_scene":print("GLTF_GENERATE ",method)
	var script=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd")
	var a=script.new()
	check(a.get("prefer_private_skin")!=null,"Actor exposes private external appearance preference")
	if not failures.is_empty():a.free();quit(1);return
	a.prefer_private_skin=false;root.add_child(a);a.set_physics_process(false)
	check(not a.using_private_skin and a.appearance_label=="Authored fallback","Authored fallback remains selectable and labelled")
	check(a.clips.size()==22 and a.marker_tip!=null,"Fallback retains full authored animation/marker API")
	var path:String=a.private_model_path();a.free()
	check(path.is_absolute_path() and not path.begins_with(ProjectSettings.globalize_path("res://")),"Private reference resolves outside the game project")
	check(script.load_private_model(path+".missing")==null,"Absent external path cleanly returns fallback")
	var available:=FileAccess.file_exists(path)
	var textures:Array[Dictionary]=[]
	var new_project_files:Array[String]=[]
	if available:
		var before:Dictionary={};inventory("res://",before)
		a=script.new();root.add_child(a);a.set_physics_process(false)
		check(a.using_private_skin and (a.using_original_source or a.appearance_label=="MD2 Valorie skin / reconstructed motion"),"External GLTFDocument source/appearance loads and is clearly labelled")
		check(a.model.scene_file_path.is_empty(),"Private runtime scene has no saved/imported project resource")
		check(a.skeleton.get_bone_count()==(32 if a.using_original_source else 11) and a.clips.size()==22,"Private source/original rig and twenty-two-state interface retained")
		check(a.face.mesh.get_blend_shape_count()==2 and a.marker_base!=null and a.marker_tip!=null,"Private variant preserves face and blade interface")
		check(a.face.get_blend_shape_value(a._focus_index)==0. and a.face.get_blend_shape_value(a._blink_index)==0.,"Private appearance starts with neutral zero morphs")
		var nearest:=0;var masked:=0;var embedded:=0;var selective_emission:=0
		for node:Node in a.model.find_children("*","MeshInstance3D",true,false):
			for surface in node.mesh.get_surface_count():
				var material:=node.mesh.surface_get_material(surface) as BaseMaterial3D
				if material==null:continue
				if material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST:nearest+=1
				if material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:masked+=1
				if material.albedo_texture!=null and material.albedo_texture.resource_path.is_empty():embedded+=1
				if material.albedo_texture!=null:
					var image:=material.albedo_texture.get_image();var alpha_pixels:=0
					for y in image.get_height():
						for x in image.get_width():
							if image.get_pixel(x,y).a<.5:alpha_pixels+=1
					var emission_masked_pixels:=0
					if material.emission_enabled and material.emission_texture!=null:
						var emission:=material.emission_texture.get_image()
						for y in mini(image.get_height(),emission.get_height()):
							for x in mini(image.get_width(),emission.get_width()):
								var base:Color=image.get_pixel(x,y);var glow:Color=emission.get_pixel(x,y)
								if base.a>.5 and maxf(base.r,maxf(base.g,base.b))>.2 and maxf(glow.r,maxf(glow.g,glow.b))<.005:emission_masked_pixels+=1
						if emission_masked_pixels>0:selective_emission+=1
					textures.append({"width":image.get_width(),"height":image.get_height(),"alpha_pixels":alpha_pixels,"transparency":material.transparency,"embedded":material.albedo_texture.resource_path.is_empty(),"emission_masked_pixels":emission_masked_pixels})
		check(nearest>0 and masked>0 and embedded>0,"Runtime private texture stays embedded, nearest filtered and alpha aware")
		var original_atlas:=false
		for item:Dictionary in textures:
			if item.width==64 and item.height==64 and item.alpha_pixels>0:original_atlas=true
		check(original_atlas,"Actual private 64px atlas retains transparent pixels")
		check(selective_emission>0,"Private emission mask leaves ordinary skin regions responsive to lighting")
		a.free()
		var after:Dictionary={};inventory("res://",after)
		for file:String in after:
			if not before.has(file):new_project_files.append(file)
		check(new_project_files.is_empty(),"Runtime private load writes no project files or extracted images")
	var report:={"checks":checks,"failures":failures,"private_available":available,"external_path":path,"private_sha256":FileAccess.get_sha256(path) if available else "","textures":textures,"new_project_files":new_project_files}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation/md2_sabre_prototype_v001"))
	FileAccess.open("res://.validation/md2_sabre_prototype_v001/private-loading.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_PRIVATE_LOADING ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
