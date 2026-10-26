extends SceneTree
## Native before/after visibility of the sibling facial-root correction.
## Diagnostic baseline disables only that correction in memory. Original
## source material, texture and mesh remain intact in both cases.
var lab:Node3D
var a:CharacterBody3D
var mode:Node
var folder:=""
var regions:Dictionary={}
func _initialize()->void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(-16000,-16000));call_deferred("run")
func _process(delta:float)->bool:
	if lab==null:return false
	mode.present(delta)
	var center:Vector3=mode.display_position()+Vector3(0,1.72,0)
	lab.camera.position=center+Vector3(.15,.25,4.);lab.camera.look_at(center);lab.camera.size=1.15
	return false
func ticks(n:int)->void:
	for i in n:await physics_frame
	await process_frame
func run()->void:
	Engine.physics_ticks_per_second=60;lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.grass_field_blocks=30;root.add_child(lab);current_scene=lab;a=lab.player;mode=lab.sabre_mode
	lab.set_process(false);mode.canvas.hide();lab.md2_lighting.ui.hide()
	for child:MeshInstance3D in a.model.find_children("*","MeshInstance3D",true,false):
		if "Sabre" in String(child.name) and child!=a.face and "Body" not in String(child.name):child.hide()
	folder=a.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/movement_measurements/face_visibility");DirAccess.make_dir_recursive_absolute(folder)
	var rig:Skeleton3D=a.skeleton;var mesh:MeshInstance3D=a.face;var arrays:=mesh.mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:int=weights.size()/vertices.size()
	for i in vertices.size():
		var bind:int=bones[i*stride];var name:StringName=mesh.skin.get_bind_name(bind);var bone:=rig.find_bone(name) if name!=&"" else mesh.skin.get_bind_bone(bind)
		var key:String=rig.get_bone_name(bone)
		if not regions.has(key):regions[key]=[]
		regions[key].append({"point":vertices[i],"bone":bone,"bind":mesh.skin.get_bind_pose(bind)})
	var original:BaseMaterial3D=mesh.mesh.surface_get_material(0);var outcomes:Array[Dictionary]=[]
	var facial_roots:Array=a.body_stability.face_roots.duplicate();var failures:Array[String]=[]
	for profile:int in 4:
		var corrected:bool=profile>=2;var running:bool=profile%2==0;var label:=("after" if corrected else "before")+("_Run" if running else "_Walk")
		mode.reset();a.body_stability.face_roots.assign(facial_roots if corrected else []);mesh.material_override=null
		a.scripted_input=true;a.requested_direction=Vector2.DOWN;a.requested_run=running;await ticks(35)
		for frame in 32:
			await ticks(2);await RenderingServer.frame_post_draw
			var img:=root.get_texture().get_image();var counts:Dictionary={}
			for key:String in ["J_L_EyeIris","J_R_EyeIris","J_Mouth"]:
				var points:Array[Vector2]=[]
				for item:Dictionary in regions[key]:points.append(lab.camera.unproject_position(mode.render_presenter.display_world[item.bone]*Transform3D(item.bind)*Vector3(item.point)))
				var rect:=Rect2(points[0],Vector2.ZERO)
				for point in points:rect=rect.expand(point)
				var pixels:=Rect2i(rect.grow(-2.)).intersection(Rect2i(Vector2i.ZERO,img.get_size()));var white:=0;var green:=0
				for y in range(pixels.position.y,pixels.end.y):
					for x in range(pixels.position.x,pixels.end.x):
						var c:=img.get_pixel(x,y)
						if absf(c.r-c.g)<.06 and absf(c.g-c.b)<.06 and c.r>.25:white+=1
						if c.g>c.r*1.35 and c.g>c.b*1.10:green+=1
				counts[key]={"white":white,"green":green,"rect":str(pixels)}
			outcomes.append({"profile":label,"corrected":corrected,"frame":frame,"source_time":a.animation_player.current_animation_position,"counts":counts})
			if corrected and (int(counts.J_L_EyeIris.white)<=0 or int(counts.J_R_EyeIris.white)<=0):failures.append(label+" frame"+str(frame)+" lost an eye")
			if frame in [0,10,20,31]:img.save_png(folder.path_join(label+"_%02d.png"%frame))
	var report:={"failures":failures,"outcomes":outcomes,"source_assets_modified":false,"original_material_no_depth_offset":not original.grow and mesh.material_override==null,"source_head_parent":"J_Neck","source_face_roots_are_head_siblings":true}
	FileAccess.open(folder.path_join("native-face-visibility.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("FACE_DIAGNOSIS ",JSON.stringify({"failures":failures,"samples":outcomes.size(),"path":folder}));lab.free();lab=null;await process_frame;quit(0 if failures.is_empty() else 1)
