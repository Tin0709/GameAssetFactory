extends SceneTree
## Guards reversible art review against changing production assets or gameplay.
var failures: Array[String] = []
func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func tick(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	if not ResourceLoader.exists("res://scenes/QualitySlice.tscn"):
		print("QUALITY_SLICE FAIL: review scene missing")
		quit(1)
		return
	var original_env = load("res://environment/Gameplay.tres")
	var env_energy: float = original_env.ambient_light_energy
	var level = load("res://scenes/QualitySlice.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await tick(4)
	var p = level.player
	var camera = level.get_node("Camera3D")
	var before_position: Vector3 = p.position
	var camera_size: float = camera.size
	level.set_review_stage(0)
	var baseline_energy: float = level.get_node("Sun").light_energy
	var baseline_blur: float = level.get_node("Sun").shadow_blur
	var f3 := InputEventKey.new()
	f3.physical_keycode = KEY_F3
	f3.pressed = true
	level._unhandled_input(f3)
	level.set_review_stage(0)
	check(is_equal_approx(level.get_node("Sun").shadow_blur,baseline_blur),"F3 cannot contaminate labeled baseline")
	for i in 3:
		level.set_review_stage(3)
		check(not level.get_node("WorldEnvironment").environment.fog_enabled,"Fog remains deferred")
		for grass in level.vegetation:
			check(grass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Vegetation never gains shadow casting")
		level.set_review_stage(0)
		check(not level.review_props.visible,"Baseline hides all study props")
		check(is_equal_approx(level.get_node("Sun").light_energy,baseline_energy),"A/B restores sun")
		for pair in level.flower_batches:
			check(pair[0].multimesh.visible_instance_count == pair[1],"A/B restores flower population")
	check(p.position.is_equal_approx(before_position) and camera.size == camera_size,"A/B preserves camera and player")
	check(original_env.ambient_light_energy == env_energy,"Shared production environment untouched")
	level.set_review_stage(3)
	Input.action_press("move_forward")
	await tick(30)
	Input.action_release("move_forward")
	check(p.position.distance_to(before_position) > 1.0,"Production controller still moves")
	check(p.is_on_floor(),"Existing floor collision retained")
	level.reset_player()
	level.set_enemies_enabled(true)
	var enemy = level.add_review_zombie(Vector3(2,1.02,-2))
	var hp: int = enemy.current_hp
	await tick(150)
	check(not is_instance_valid(enemy) or enemy.current_hp < hp,"Real gun/projectile damages real zombie")
	print("QUALITY_SLICE " + JSON.stringify({"failures":failures,"renderer":RenderingServer.get_current_rendering_method()}))
	level.set_enemies_enabled(false)
	level.queue_free()
	for i in 3: await process_frame
	quit(0 if failures.is_empty() else 1)
