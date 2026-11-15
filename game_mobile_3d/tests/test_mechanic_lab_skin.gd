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
	var md2_lantern := actor.get("lantern") as Node3D
	check(md2_lantern != null and md2_lantern.visible, "The MD2 skin retains its original lantern presentation")
	lab._on_player_hit(6)
	var position_before := actor.global_position
	var health_before: int = lab.player_health
	var serial_before: int = actor.combo.serial
	picker.select(1)
	picker.item_selected.emit(1)
	var kai := actor.get_node_or_null("KaiAppearance") as Node3D
	check(kai != null and kai.is_visible_in_tree() and not md2.visible, "Selecting Kai swaps the live player meshes")
	check(md2_lantern == null or not md2_lantern.is_visible_in_tree(), "Kai shows only his attached lantern")
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
	var lantern := kai_rig.find_bone("J_Kai_Lantern_Sway")
	var tail := kai_rig.find_bone("J_Headband_Tail_A")
	var tail_b := kai_rig.find_bone("J_Headband_Tail_B")
	check(head >= 0 and lantern >= 0 and tail >= 0 and tail_b >= 0, "Kai keeps the rig and all three sway bones")
	check(kai_rig.find_bone("J_Kai_Rope_Sway") < 0, "The old rope is removed from the Lab skin")
	var lamp := kai.find_child("Kai Run | MD2 metal lantern", true, false) as MeshInstance3D
	var clasp := kai.find_child("Kai Run | MD2 lantern clasp", true, false) as MeshInstance3D
	var pouch := kai.find_child("Kai Right Hip Pouch", true, false) as MeshInstance3D
	check(lamp != null and clasp != null and pouch != null, "The new lantern, clasp and fixed right-hip pouch are loaded")
	if lamp != null:
		var material := lamp.get_active_material(0) as BaseMaterial3D
		check(material != null and material.emission_enabled and material.emission_texture != null
			and material.albedo_texture != null, "The lantern uses textured yellow emission and its dark frame")
	if pouch != null:
		check(pouch.get_aabb().end.x < -0.23 and uses_bone(pouch, kai_rig, &"J_Shoulders")
			and not uses_bone(pouch, kai_rig, &"J_Kai_Lantern_Sway"), "The large pouch sits on Kai's right and is fixed to the belt")
	if lantern < 0 or tail < 0 or tail_b < 0:
		quit(1)
		return
	actor.scripted_input = true
	actor.requested_run = true
	actor.requested_direction = Vector2(1, 0)
	var lantern_samples: Array[Quaternion] = []
	var tail_samples: Array[Quaternion] = []
	var tail_b_samples: Array[Quaternion] = []
	for i in 55:
		await physics_frame
		await process_frame
		if i > 20:
			lantern_samples.append(kai_rig.get_bone_pose_rotation(lantern))
			tail_samples.append(kai_rig.get_bone_pose_rotation(tail))
			tail_b_samples.append(kai_rig.get_bone_pose_rotation(tail_b))
	check(lamp != null and uses_bone(lamp, kai_rig, &"J_Kai_Lantern_Sway"), "The lantern is skinned to the handle pivot")
	check(actor.current_speed > 2.0 and deltas(lantern_samples) > 0.10
		and deltas(tail_samples) > 0.10 and deltas(tail_b_samples) > 0.10, "Running drives all three accessories through a real gait")
	check(kai_mesh.material_overlay == null, "The flash expires on Kai")
	picker.select(0)
	picker.item_selected.emit(0)
	check(not kai.visible and md2.is_visible_in_tree() and weapon.is_visible_in_tree(),
		"Switching back while moving restores MD2 and preserves the weapon")
	check(md2_lantern != null and md2_lantern.visible, "Returning to MD2 restores its original lantern presentation")
	picker.select(1)
	picker.item_selected.emit(1)
	check(actor.get_node_or_null("KaiAppearance") == kai and kai.is_visible_in_tree(), "Repeated swaps reuse one Kai rig")
	actor.requested_direction = Vector2.ZERO
	actor.requested_run = false
	for i in 18:
		await physics_frame
	var weapons := lab.get_node("HUD/Weapon") as OptionButton
	weapons.select(lab.Weapon.CROSS_POLLINATOR)
	weapons.item_selected.emit(lab.Weapon.CROSS_POLLINATOR)
	check(actor.crossbow_equipped, "Kai retains the live Lab weapon selector")
	actor.attack(true)
	for i in 3:
		await physics_frame
	check(actor.combo.active(), "An equipped crossbow can fire on Kai")
	var shot_serial: int = actor.combo.serial
	picker.select(0)
	picker.item_selected.emit(0)
	check(actor.combo.active() and actor.combo.serial == shot_serial and actor.crossbow_equipped,
		"Changing skin mid-attack leaves the same shot active")
	picker.select(1)
	picker.item_selected.emit(1)
	actor.attack(false)
	for i in 15:
		await physics_frame
	lab._on_player_hit(999)
	check(picker.disabled and kai.visible, "Defeat retains the chosen appearance")
	lab.reset_player()
	check(not picker.disabled and picker.selected == 1 and kai.visible, "Respawn keeps Kai and enables the skin selector")
	lab.free()
	print("MECHANIC_LAB_SKIN failures=", failures)
	quit(int(not failures.is_empty()))

func deltas(values: Array[Quaternion]) -> float:
	var largest := 0.0
	for value: Quaternion in values:
		largest = maxf(largest, values[0].angle_to(value))
	return largest


func uses_bone(mesh: MeshInstance3D, rig: Skeleton3D, bone: StringName) -> bool:
	var bone_index := rig.find_bone(bone)
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for i in ids.size():
			if weights[i] > 0.001 and (mesh.skin.get_bind_name(ids[i]) == bone
					or (bone_index >= 0 and mesh.skin.get_bind_bone(ids[i]) == bone_index)):
				return true
	return false
