extends SceneTree
## Actual Godot pixels; the wide overview is diagnostic, not the gameplay camera.
const OUT := "res://.validation/flat_map_100x100/"
func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+filename+".png")
	print("GAMEPLAY_MAP_CAPTURE "+filename)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var path := "res://scenes/ForestMeadowV3.tscn" if baseline else "res://scenes/GameplayMap.tscn"
	var level: Node3D = load(path).instantiate()
	root.add_child(level)
	current_scene = level
	if baseline: level.set_enemies_enabled(false)
	for i in 30: await physics_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	if baseline:
		level.review_label.hide()
		ResourceSaver.save(level.get_node("WorldEnvironment").environment, OUT+"lighting_snapshot.tres")
		var sun: DirectionalLight3D = level.get_node("Sun")
		var properties := {}
		for property in ["rotation_degrees","light_energy","light_color","shadow_enabled","shadow_opacity","shadow_bias","shadow_normal_bias","shadow_blur","directional_shadow_mode","directional_shadow_max_distance"]:
			properties[property] = var_to_str(sun.get(property))
		FileAccess.open(OUT+"sun_snapshot.json",FileAccess.WRITE).store_string(JSON.stringify(properties,"\t"))
		await capture("forest_baseline")
	else:
		level.get_node("HUD").hide()
		await capture("gameplay")
		var camera: Camera3D = level.get_node("Camera3D")
		level.get_node("Border").update_cutaway(Vector3.ZERO,camera.position,false)
		camera.size = 122.0
		camera.far = 250.0
		camera.position = Vector3(72,91,96)
		await capture("whole_map")
		var env: Environment = level.get_node("WorldEnvironment").environment
		var fog := env.fog_enabled
		env.fog_enabled = false
		# Diagnostic overview reveals the complete ring; gameplay haze stays intact.
		await capture("whole_map_clear")
		env.fog_enabled = fog
		camera.size = 14.5
		var player: Node3D = level.get_node("Actors/Player")
		player.position = Vector3(41,1,41)
		camera.position = Vector3(12,15,16)+player.position
		level.get_node("Border").update_cutaway(player.position,camera.position)
		await capture("map_corner")
		var sides := {"west":Vector3(-46,1,0),"east":Vector3(46,1,0),"north":Vector3(0,1,-46),"south":Vector3(0,1,46)}
		for side in sides:
			player.position = sides[side]*Vector3(.9,1,.9)
			camera.position = player.position+Vector3(12,15,16)
			level.get_node("Border").update_cutaway(player.position,camera.position)
			await capture("border_"+side)
			camera.size = 32
			await capture("border_"+side+"_wide")
			camera.size = 14.5
	quit()
