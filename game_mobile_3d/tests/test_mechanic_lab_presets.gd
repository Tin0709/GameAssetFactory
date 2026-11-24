extends SceneTree

const Lab := preload("res://scenes/dev/MechanicLab.tscn")
const VALUES := [
	"RagdollTuning/Launch/Slider", "RagdollTuning/Gravity/Slider",
	"RagdollLifetime/Slider", "CameraShake/Slider", "Hitstop/Slider",
	"RagdollPhysicsPanel/Rows/Mass/Slider", "RagdollPhysicsPanel/Rows/Damping/Slider",
	"RagdollPhysicsPanel/Rows/JointSpan/Slider",
]

var failures: Array[String] = []
var folder := "user://mechanic_lab_preset_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func make_lab() -> Node3D:
	var lab := Lab.instantiate()
	lab.set("tuning_preset_directory", folder)
	root.add_child(lab)
	return lab

func select_action(lab: Node3D, index: int) -> void:
	var menu := (lab.get_node("HUD/TuningPresets") as MenuButton).get_popup()
	var event := InputEventKey.new()
	event.keycode = KEY_F8
	event.pressed = true
	menu.set_item_accelerator(index, KEY_F8)
	check(menu.activate_item_by_event(event), "Preset menu action %d can be activated" % index)
	menu.set_item_accelerator(index, KEY_NONE)

func set_values(lab: Node3D, values: Array, crowd: int, base_health: bool, animation_style: int, render_scale: int) -> void:
	for i in VALUES.size():
		(lab.get_node("HUD/" + VALUES[i]) as HSlider).value = values[i]
	var picker := lab.get_node("HUD/CrowdSpawnCount") as OptionButton
	picker.select(picker.get_item_index(crowd))
	var animation := lab.get_node("HUD/ZombieGait") as OptionButton
	animation.select(animation_style)
	animation.item_selected.emit(animation_style)
	var render := lab.get_node("HUD/RenderScale") as OptionButton
	if render.item_count > 0:
		var index := render.get_item_index(render_scale)
		render.select(index)
		render.item_selected.emit(index)
	lab.get_node("HUD/BaseZombieToggle").button_pressed = base_health

func values_match(lab: Node3D, values: Array, crowd: int, base_health: bool) -> bool:
	var group = lab.get_node("Zombies")
	for i in VALUES.size():
		if not is_equal_approx((lab.get_node("HUD/" + VALUES[i]) as HSlider).value, float(values[i])):
			return false
	return (is_equal_approx(group.ragdoll_launch_multiplier, values[0] / 100.0)
		and is_equal_approx(group.ragdoll_gravity_multiplier, values[1] / 100.0)
		and is_equal_approx(group.corpse_lifetime, values[2])
		and is_equal_approx(lab.get("_shake_intensity"), values[3] / 100.0)
		and is_equal_approx(lab.get("player").hitstop_seconds, values[4] / 1000.0)
		and is_equal_approx(group.ragdoll_mass_multiplier, values[5] / 100.0)
		and is_equal_approx(group.ragdoll_damping_multiplier, values[6] / 100.0)
		and is_equal_approx(group.ragdoll_joint_span_multiplier, values[7] / 100.0)
		and lab.get_node("HUD/SpawnCrowd").text == "Spawn %d zombie" % crowd
		and lab.get_node("HUD/BaseZombieToggle").button_pressed == base_health)

func select_frame_rate(lab: Node3D, fps: int) -> void:
	var picker := lab.get_node("HUD/FrameRate") as OptionButton
	var index := picker.get_item_index(fps)
	var popup := picker.get_popup()
	popup.set_item_accelerator(index, KEY_F7)
	var event := InputEventKey.new()
	event.keycode = KEY_F7
	event.pressed = true
	check(popup.activate_item_by_event(event), "The FPS mode can be selected through the menu")
	popup.set_item_accelerator(index, KEY_NONE)

func run() -> void:
	var starting_cap := Engine.max_fps
	var physics_hz := Engine.physics_ticks_per_second
	Engine.max_fps = 75
	var lab := make_lab()
	var impact_opacity := lab.get_node_or_null("HUD/ImpactFxPanel/Rows/Opacity/Slider") as HSlider
	var impact_duration := lab.get_node_or_null("HUD/ImpactFxPanel/Rows/Duration/Slider") as HSlider
	if impact_opacity == null or impact_duration == null:
		printerr("FAIL The Lab has no impact streak opacity and duration controls")
		lab.free()
		Engine.max_fps = starting_cap
		quit(1)
		return
	var impact_button := lab.get_node("HUD/ImpactFxButton") as Button
	var audio_button := lab.get_node("HUD/AudioMixButton") as Button
	impact_button.button_pressed = true
	check(lab.get_node("HUD/ImpactFxPanel").visible, "The new button opens the impact controls")
	audio_button.button_pressed = true
	check(not lab.get_node("HUD/ImpactFxPanel").visible and lab.get_node("HUD/AudioMixPanel").visible,
		"Opening the audio controls closes the overlapping impact panel")
	audio_button.button_pressed = false
	var frame_rate := lab.get_node_or_null("HUD/FrameRate") as OptionButton
	if frame_rate == null:
		printerr("FAIL The Lab has no FPS mode selector")
		Engine.max_fps = starting_cap
		quit(1)
		return
	check(frame_rate.get_selected_id() == 0 and Engine.max_fps == 75,
		"Entering the Lab inherits the app's render cap")
	var menu := lab.get_node_or_null("HUD/TuningPresets") as MenuButton
	if menu == null:
		printerr("The Lab has no preset menu")
		quit(1)
		return
	var a := [450.0, 275.0, 2.4, 30.0, 45.0, 200.0, 25.0, 150.0]
	var b := [85.0, 1000.0, 4.5, 0.0, 20.0, 50.0, 200.0, 75.0]
	var default_animation: int = lab.get_node("HUD/ZombieGait").selected
	var a_animation := 0
	var b_animation := default_animation
	set_values(lab, a, 150, true, a_animation, 75)
	select_frame_rate(lab, 30)
	check(Engine.max_fps == 30 and Engine.physics_ticks_per_second == physics_hz,
		"30 FPS caps rendering without changing the physics tick rate")
	var mix_weapon := lab.get_node("HUD/AudioMixPanel/Rows/Weapon/Slider") as HSlider
	mix_weapon.value = 35.0
	var quality := lab.get_node("HUD/ImpactFxPanel/Rows/ContactSparkQuality") as OptionButton
	impact_opacity.value = 35.0
	impact_duration.value = 150.0
	quality.select(1)
	quality.item_selected.emit(1)
	select_action(lab, 0)
	set_values(lab, b, 25, false, b_animation, 85)
	select_frame_rate(lab, 60)
	check(Engine.max_fps == 60 and Engine.physics_ticks_per_second == physics_hz,
		"60 FPS caps rendering without changing the physics tick rate")
	mix_weapon.value = 100.0
	impact_opacity.value = 85.0
	impact_duration.value = 65.0
	quality.select(0)
	quality.item_selected.emit(0)
	select_action(lab, 2)
	lab.free()
	check(Engine.max_fps == 75, "Leaving the Lab restores the app cap")
	lab = make_lab()
	var baseline := [100.0, 100.0, 1.2, 100.0, 0.0, 100.0, 100.0, 100.0]
	check(values_match(lab, baseline, 100, false), "The Lab starts with its normal settings")
	select_action(lab, 1)
	check(Engine.max_fps == 30, "Loading A restores 30 FPS")
	check(values_match(lab, a, 150, true), "Slot A restores sliders, crowd count and live values after reopening")
	check(lab.get_node("HUD/AudioMixPanel/Rows/Weapon/Slider").value == 35.0, "Loading A restores the weapon mix")
	check(lab.get_node("HUD/ImpactFxPanel/Rows/ContactSparkQuality").selected == 1, "Loading A restores reduced contact sparks")
	check_impact_values(lab, 35.0, 150.0)
	check(lab.get_node("HUD/ZombieGait").selected == a_animation,
		"Loading A restores the selected zombie animation")
	if lab.get_node("HUD/RenderScale").item_count > 0:
		check(is_equal_approx(root.scaling_3d_scale, 0.75), "Loading A applies its 3D render scale")
	select_action(lab, 3)
	check(Engine.max_fps == 60, "Loading B restores 60 FPS")
	check(values_match(lab, b, 25, false), "Slot B restores a distinct configuration")
	check(lab.get_node("HUD/AudioMixPanel/Rows/Weapon/Slider").value == 100.0, "Loading B restores full weapon level")
	check(lab.get_node("HUD/ImpactFxPanel/Rows/ContactSparkQuality").selected == 0, "Loading B restores the full spark budget")
	check_impact_values(lab, 85.0, 65.0)
	check(lab.get_node("HUD/ZombieGait").selected == b_animation,
		"Loading B restores its zombie animation")
	if lab.get_node("HUD/RenderScale").item_count > 0:
		check(is_equal_approx(root.scaling_3d_scale, 0.85), "Loading B applies its 3D render scale")
	select_action(lab, 4)
	check(Engine.max_fps == 75, "Restoring defaults inherits the app's cap")
	check(values_match(lab, baseline, 100, false), "Restoring defaults updates the HUD and runtime together")
	select_action(lab, 1)
	check(values_match(lab, a, 150, true), "Restoring defaults preserves a saved slot")
	set_values(lab, b, 25, false, b_animation, 85)
	select_action(lab, 0)
	select_action(lab, 4)
	select_action(lab, 1)
	check(values_match(lab, b, 25, false), "Saving over slot A replaces the old settings")
	var invalid := ConfigFile.new()
	invalid.set_value("preset", "settings", "invalid")
	invalid.save(folder.path_join("b.cfg"))
	select_action(lab, 3)
	check(values_match(lab, b, 25, false), "Invalid stored settings leave the live configuration intact")
	check(not lab.get_node("HUD/CombatAudioToggle").button_pressed, "Preset actions keep the session silent")
	var old_preset := ConfigFile.new()
	old_preset.set_value("preset", "settings", {"launch": 100.0})
	old_preset.save(folder.path_join("b.cfg"))
	select_frame_rate(lab, 60)
	select_action(lab, 3)
	check(Engine.max_fps == 75, "Loading a preset saved before the FPS control inherits the app cap")
	check(values_match(lab, baseline, 100, false), "Older presets use reference physics values for the added controls")
	check_impact_values(lab, 100.0, 100.0)
	select_frame_rate(lab, 30)
	Engine.max_fps = 45
	lab.free()
	check(Engine.max_fps == 45, "Leaving a Lab preserves a newer external cap change")
	Engine.max_fps = starting_cap
	for file in ["a.cfg", "b.cfg"]:
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	print("MECHANIC_LAB_PRESETS ", JSON.stringify({"failures": failures}))
	quit(int(not failures.is_empty()))

func check_impact_values(lab: Node3D, opacity: float, duration: float) -> void:
	var rows := lab.get_node("HUD/ImpactFxPanel/Rows")
	var sparks := lab.get_node("ContactSparks/Streaks") as MultiMeshInstance3D
	var material := sparks.multimesh.mesh.material as ShaderMaterial
	check(rows.get_node("Opacity/Slider").value == opacity and rows.get_node("Duration/Slider").value == duration
		and is_equal_approx(material.get_shader_parameter("opacity_scale"), opacity * 0.01)
		and is_equal_approx(sparks.get_parent().duration_scale, duration * 0.01),
		"Preset restores %d%% opacity and %d%% lifetime in the HUD and renderer" % [opacity, duration])
