extends SceneTree

const Lab := preload("res://scenes/dev/MechanicLab.tscn")
const VALUES := [
	"RagdollTuning/Launch/Slider", "RagdollTuning/Gravity/Slider",
	"RagdollLifetime/Slider", "CameraShake/Slider",
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

func set_values(lab: Node3D, values: Array, crowd: int, base_health: bool) -> void:
	for i in VALUES.size():
		(lab.get_node("HUD/" + VALUES[i]) as HSlider).value = values[i]
	var picker := lab.get_node("HUD/CrowdSpawnCount") as OptionButton
	picker.select(picker.get_item_index(crowd))
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
		and lab.get_node("HUD/SpawnCrowd").text == "Spawn %d zombie" % crowd
		and lab.get_node("HUD/BaseZombieToggle").button_pressed == base_health)

func run() -> void:
	var lab := make_lab()
	var menu := lab.get_node_or_null("HUD/TuningPresets") as MenuButton
	if menu == null:
		printerr("The Lab has no preset menu")
		quit(1)
		return
	var a := [450.0, 275.0, 2.4, 30.0]
	var b := [85.0, 1000.0, 4.5, 0.0]
	set_values(lab, a, 150, true)
	select_action(lab, 0)
	set_values(lab, b, 25, false)
	select_action(lab, 2)
	lab.free()
	lab = make_lab()
	var baseline := [100.0, 100.0, 1.2, 100.0]
	check(values_match(lab, baseline, 100, false), "The Lab starts with its normal settings")
	select_action(lab, 1)
	check(values_match(lab, a, 150, true), "Slot A restores sliders, crowd count and live values after reopening")
	select_action(lab, 3)
	check(values_match(lab, b, 25, false), "Slot B restores a distinct configuration")
	select_action(lab, 4)
	check(values_match(lab, baseline, 100, false), "Restoring defaults updates the HUD and runtime together")
	select_action(lab, 1)
	check(values_match(lab, a, 150, true), "Restoring defaults preserves a saved slot")
	set_values(lab, b, 25, false)
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
	lab.free()
	for file in ["a.cfg", "b.cfg"]:
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	print("MECHANIC_LAB_PRESETS ", JSON.stringify({"failures": failures}))
	quit(int(not failures.is_empty()))
