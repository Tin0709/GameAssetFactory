extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		printerr("FAIL ", text)

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await physics_frame
	await physics_frame
	var picker := lab.get_node_or_null("HUD/PlayerSkin") as OptionButton
	check(picker != null, "MechanicLab HUD offers a skin selector")
	if picker == null:
		quit(1)
		return
	check(picker.item_count == 2 and picker.get_item_text(0).contains("MD2")
		and picker.get_item_text(1).contains("Kai"), "Both skins are available in the selector")
	check(picker.selected == 0, "Lab still opens on the existing MD2 appearance")
	var actor: CharacterBody3D = lab.player
	var rig: Skeleton3D = actor.skeleton
	var md2 := actor.model.find_child("SabrePrototypeBody", true, false) as MeshInstance3D
	var weapon := actor.model.find_child("SabrePrototypeSabre", true, false) as MeshInstance3D
	lab._on_player_hit(6)
	var position_before := actor.global_position
	var health_before: int = lab.player_health
	var serial_before: int = actor.combo.serial
	picker.select(1)
	picker.item_selected.emit(1)
	var kai := actor.get_node_or_null("KaiAppearance") as Node3D
	check(kai != null and kai.is_visible_in_tree() and not md2.visible, "Selecting Kai swaps the live player meshes")
	if kai == null:
		quit(1)
		return
	check(lab.player == actor and actor.skeleton == rig and weapon.is_visible_in_tree()
		and actor.global_position == position_before and lab.player_health == health_before
		and actor.combo.serial == serial_before, "Skin swap preserves actor, position, health, weapon and combo")
	var kai_rig := kai.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var kai_mesh := kai.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	check(kai_mesh.material_overlay != null, "A skin loaded during a hit inherits the flash")
	var head := kai_rig.find_bone("J_Head")
	var rope := kai_rig.find_bone("J_Kai_Rope_Sway")
	var tail := kai_rig.find_bone("J_Headband_Tail_A")
	var tail_b := kai_rig.find_bone("J_Headband_Tail_B")
	check(head >= 0 and rope >= 0 and tail >= 0 and tail_b >= 0, "Kai keeps the rig and all three sway bones")
	if rope < 0 or tail < 0 or tail_b < 0:
		quit(1)
		return
	actor.scripted_input = true
	actor.requested_run = true
	actor.requested_direction = Vector2(1, 0)
	var rope_samples: Array[Quaternion] = []
	var tail_samples: Array[Quaternion] = []
	var tail_b_samples: Array[Quaternion] = []
	for i in 55:
		await physics_frame
		await process_frame
		if i > 20:
			rope_samples.append(kai_rig.get_bone_pose_rotation(rope))
			tail_samples.append(kai_rig.get_bone_pose_rotation(tail))
			tail_b_samples.append(kai_rig.get_bone_pose_rotation(tail_b))
	check(actor.current_speed > 2.0 and deltas(rope_samples) > 0.10
		and deltas(tail_samples) > 0.10 and deltas(tail_b_samples) > 0.10, "Running drives all three accessories through a real gait")
	check(kai_mesh.material_overlay == null, "The flash expires on Kai")
	picker.select(0)
	picker.item_selected.emit(0)
	check(not kai.visible and md2.is_visible_in_tree() and weapon.is_visible_in_tree(),
		"Switching back while moving restores MD2 and preserves the weapon")
	picker.select(1)
	picker.item_selected.emit(1)
	check(actor.get_node_or_null("KaiAppearance") == kai and kai.is_visible_in_tree(), "Repeated swaps reuse one Kai rig")
	lab.free()
	print("MECHANIC_LAB_SKIN failures=", failures)
	quit(int(not failures.is_empty()))

func deltas(values: Array[Quaternion]) -> float:
	var largest := 0.0
	for value: Quaternion in values:
		largest = maxf(largest, values[0].angle_to(value))
	return largest

