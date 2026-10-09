extends SceneTree
## Reproduce ground being sent to the cliff fade pass beside a taller terrace.
const OUT:="res://.validation/world_map/seams/"
func _initialize() -> void:call_deferred("run")
func capture(label: String) -> Image:
	await process_frame;await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.save_png(OUT+label+".png")
	return image
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var level: Node3D=load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(level);current_scene=level
	for i in 30:await physics_frame
	level.set_process(false);level.player.set_physics_process(false);level.player.visual.set_process(false)
	level.look.freeze_motion();level.look.publish_clouds(0.0)
	level.get_node("HUD").hide()
	var camera: Camera3D=level.get_node("Camera3D")
	var candidates: Array=[]
	for z in range(-40,41,5):
		for x in range(-40,41,5):
			var height: float=level.surface_height(x+.5,z+.5)
			if not is_finite(height):continue
			var player:=Vector3(x+.5,height+.02,z+.5)
			var point:=player+Vector3(2.0,-.02,2.0)
			if not is_equal_approx(level.surface_height(point.x,point.z),height):continue
			level.geometry.update_cutaway(player,player+level.CAMERA_OFFSET)
			for item: Dictionary in level.geometry._cutaway_chunks:
				if not item.active:continue
				var bounds: AABB=item.visual.global_transform*item.visual.mesh.get_aabb()
				if point.x>=bounds.position.x and point.x<bounds.end.x and point.z>=bounds.position.z and point.z<bounds.end.z:
					candidates.append({"player":player,"floor_point":point,"chunk":item.visual.name})
					break
	var failures: Array=[]
	var results: Array=[]
	var wall_changed_samples:=0
	if candidates.size()<6:failures.append("Expected six real floor / cliff regression locations")
	for i in mini(candidates.size(),6):
		level.player.position=candidates[i].player
		level.set_review_view("gameplay")
		level.geometry.update_cutaway(level.player.position,camera.position)
		var faded: Image=await capture("%02d_fade_on"%i)
		level.geometry.update_cutaway(Vector3.ZERO,Vector3.ZERO)
		var opaque: Image=await capture("%02d_fade_off"%i)
		if i==0:
			# This authored location has a tall foreground wall. A disabled fade
			# must not pass merely because the floor now matches the opaque image.
			for sy in range(0,faded.get_height(),8):
				for sx in range(0,faded.get_width(),8):
					var a: Color=faded.get_pixel(sx,sy);var b: Color=opaque.get_pixel(sx,sy)
					if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>3.0/255.0:wall_changed_samples+=1
		var pixel: Vector2i=Vector2i(camera.unproject_position(candidates[i].floor_point))
		var maximum:=0.0
		for y in range(pixel.y-1,pixel.y+2):
			for x in range(pixel.x-1,pixel.x+2):
				var a: Color=faded.get_pixel(x,y);var b: Color=opaque.get_pixel(x,y)
				maximum=maxf(maximum,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))*255.0)
		results.append({"candidate":i,"ground_pixel":pixel,"maximum_rgb_delta":maximum})
		if maximum>2.0:failures.append("Cliff fade changes walkable floor at candidate "+str(i))
	if wall_changed_samples<20:failures.append("Foreground wall must still fade to reveal the player")
	FileAccess.open(OUT+"candidates.json",FileAccess.WRITE).store_string(JSON.stringify(candidates,"\t"))
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":results,"wall_changed_grid_samples":wall_changed_samples,"failures":failures},"\t"))
	print("SEAM_CANDIDATES "+str(candidates.size()))
	print("FLOOR_FADE_FAILURES "+str(failures))
	level.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
