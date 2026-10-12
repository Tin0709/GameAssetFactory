extends SceneTree
var checks: Array = []
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok: failures.append(message);push_error(message)
func run() -> void:
	var path := "res://scenes/dev/ExpressiveLocomotionTest.tscn"
	check(ResourceLoader.exists(path),"Isolated playable expressive locomotion scene exists")
	if not ResourceLoader.exists(path): quit(1);return
	var scene = load(path).instantiate()
	root.add_child(scene);current_scene=scene
	await physics_frame
	await process_frame
	var actor = scene.actor
	var expected_pace:=1.5
	if "--expressive-pace-1" in OS.get_cmdline_user_args():expected_pace=1.0
	if "--expressive-pace-2" in OS.get_cmdline_user_args():expected_pace=2.0
	check(actor.get("review_pace")==expected_pace,"Review defaults to moderate 1.5x pace with 1x and 2x comparisons")
	check(actor.visual.expressive_clips.size()==3,"Exactly three approved expressive clips loaded")
	check(not actor.has_method("request_jump"),"No jump controller integrated")
	check(actor.walk_speed==.9 and actor.run_speed==2.31,"Controller speeds match approved gait distances")
	var texture: Texture2D=load("res://assets/characters/expressive_locomotion_v1/approved_atlas_64.png")
	var source:=Image.new();source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/characters/expressive_locomotion_v1/approved_atlas_64.png"))
	check(texture.get_image().get_data()==source.get_data(),"Imported 64px atlas preserves approved pixels losslessly")
	var attention_before: float=actor.visual.attention_time
	var tick_before:=Engine.get_physics_frames()
	await scene.tick(12,"Idle pace verification")
	var seconds:=float(Engine.get_physics_frames()-tick_before)/Engine.physics_ticks_per_second
	check(absf(fposmod(actor.visual.attention_time-attention_before,8.0)/seconds-1.0)<.05,"Idle gestures and breathing remain at normal speed independently of movement pace")
	await scene.run_validation(self)
	var out := "res://.validation/expressive_locomotion_v1"
	DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/runtime_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":scene.measurements,"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	print("EXPRESSIVE_LOCOMOTION_CHECKS ",checks.size()," failures ",failures.size())
	quit(0 if failures.is_empty() else 1)
