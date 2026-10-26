extends SceneTree
## Read/visualize the existing skin and compare temporary face-material depth
## offsets. Never writes a mesh, source texture or game material to disk.
var lab:Node3D
var a:CharacterBody3D
var mode:Node
var folder:=""
var regions:Dictionary={}
func _initialize()->void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(-16000,-16000));call_deferred("run")
func _process(delta:float)->void:
	if lab==null:return
	mode.present(delta)
	var center:Vector3=mode.display_position()+Vector3(0,1.72,0)
	lab.camera.position=center+Vector3(.15,.25,4.);lab.camera.look_at(center);lab.camera.size=1.15
func ticks(n:int)->void:
	for i in n:await physics_frame
	await process_frame
func run()->void:
	Engine.physics_ticks_per_second=60;lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.grass_field_blocks=30;root.add_child(lab);current_scene=lab;a=lab.player;mode=lab.sabre_mode
	lab.set_process(false);mode.canvas.hide();lab.md2_lighting.canvas.hide()
	folder=a.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/movement_measurements/face_visibility");DirAccess.make_dir_recursive_absolute(folder)
	var rig:Skeleton3D=a.skeleton;var mesh:MeshInstance3D=a.face;var arrays:=mesh.mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:int=weights.size()/vertices.size()
	for i in vertices.size():
		var bind:int=bones[i*stride];var name:StringName=mesh.skin.get_bind_name(bind);var bone:=rig.find_bone(name) if name!=&"" else mesh.skin.get_bind_bone(bind)
		var key:String=rig.get_bone_name(bone)
		if not regions.has(key):regions[key]=[]
		regions[key].append({"point":vertices[i],"bone":bone,"bind":mesh.skin.get_bind_pose(bind)})
	var original:BaseMaterial3D=mesh.mesh.surface_get_material(0);var outcomes:Array[Dictionary]=[]
	for offset:float in [0.,.006]:
		var material:BaseMaterial3D=original.duplicate();material.grow_enabled=offset>0.;material.grow_amount=offset;mesh.material_override=material
		mode.reset();a.scripted_input=true;a.requested_direction=Vector2.DOWN;a.requested_run=true;await ticks(35)
		for frame in 16:
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
			outcomes.append({"offset":offset,"frame":frame,"source_time":a.animation_player.current_animation_position,"counts":counts})
			if frame in [0,5,10,15]:img.save_png(folder.path_join(("raw" if offset==0. else "offset6mm")+"_%02d.png"%frame))
	var report:={"outcomes":outcomes,"source_assets_modified":false,"temporary_render_offset_only":true}
	FileAccess.open(folder.path_join("diagnosis.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("FACE_DIAGNOSIS ",JSON.stringify({"samples":outcomes.size(),"path":folder}));lab.free();lab=null;await process_frame;quit()
