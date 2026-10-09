extends SceneTree
## Same-camera GPU review of the short-grass material only; no desktop input.
const OUT := "res://.validation/world_map/grass_blend_v3/"
var view: SubViewport
var level: Node3D

func _initialize() -> void:
	root.visible=false
	create_timer(90).timeout.connect(func():quit(2))
	call_deferred("run")

func capture(label: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var image:=view.get_texture().get_image()
	assert(image.save_png(OUT+label+".png")==OK)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	view=SubViewport.new()
	view.size=Vector2i(1280,720)
	view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	level=load("res://scenes/WorldMap.tscn").instantiate()
	view.add_child(level)
	for i in 30: await physics_frame
	level.set_process(false)
	level.player.set_physics_process(false)
	level.player.visual.set_process(false)
	level.look.freeze_motion(0.0)
	level.look.publish_clouds(0.0)
	level.get_node("HUD").hide()
	var prefix:="before" if "--before" in OS.get_cmdline_user_args() else "after"
	if "--before-tall" in OS.get_cmdline_user_args():prefix="before_tall"
	if prefix.begins_with("before"):
		for material: ShaderMaterial in level.look.wind_materials:
			var kind=material.get_shader_parameter("plant_kind")
			if material.shader==level.look.PRESET.plants_shader && (kind==2 || (kind==0 && prefix=="before")):
				material.set_shader_parameter("ground_blending",false)
	await capture(prefix+"_gameplay")
	for spec: Array in [["flowers",Vector2(-4,-8)],["grove",Vector2(-26,6)]]:
		var point: Vector2=spec[1]
		var height: float=level.surface_height(point.x,point.y)
		if not is_finite(height): continue
		level.player.position=Vector3(point.x,height+.02,point.y)
		level.set_review_view("gameplay")
		level.geometry.update_cutaway(level.player.position,level.get_node("Camera3D").position)
		await capture(prefix+"_"+spec[0])
	if "--clip" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(OUT+"frames")
		level.player.position=level.spawn_position
		level.player.velocity=Vector3.ZERO
		level.set_review_view("gameplay")
		level.set_process(true)
		level.player.set_physics_process(true)
		level.player.visual.set_process(true)
		level.look.active=true
		Input.action_press("move_left")
		for frame in 120:
			if frame==60:Input.action_release("move_left")
			await process_frame
			await RenderingServer.frame_post_draw
			assert(view.get_texture().get_image().save_png(OUT+"frames/frame_%03d.png"%frame)==OK)
		print("GRASS_BLEND_CLIP 120 native Mobile frames at fixed 30 FPS; walking then recovery")
	print("GRASS_BLEND_REVIEW ",prefix," renderer=",RenderingServer.get_current_rendering_method()," device=",RenderingServer.get_video_adapter_name())
	level.queue_free()
	await process_frame
	quit()
