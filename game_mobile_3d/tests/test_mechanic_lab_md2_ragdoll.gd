
extends SceneTree

const ZOMBIE = preload("res://scripts/mechanic_lab_zombie.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	var lab = load("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	var group = lab.get_node("Zombies")
	lab.get_node("HUD/BaseZombieToggle").button_pressed = true
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		check(false, "Verified MD2 zombie spawns")
		quit(1)
		return
	var zombie = group.get_child(0)
	await ticks(56)
	var strike: Dictionary = group.SABRE_STRIKES[0]
	group._apply_contact(zombie, zombie.global_position + Vector3.UP, "Attack1", 0, 1, strike, Vector3.FORWARD, false)
	await ticks(4)
	check(zombie.ragdoll.running and zombie.health == 0, "Lethal contact transfers the live pose to physics")
	var impulse: Vector3 = zombie.ragdoll.total_applied_impulse
	check(absf(rad_to_deg(atan2(impulse.y, Vector2(impulse.x, impulse.z).length())) - 30.0) < 0.01,
		"DefaultHostile's 30-degree launch is applied to the death impulse")
	check(zombie.ragdoll.handoff_error < 0.005, "No snap at physics handoff")
	await ticks(60)
	check(zombie._corpse_landed and zombie.ragdoll.max_anchor_error() < 0.10, "The corpse settles with connected joints")
	while is_instance_valid(zombie) and zombie._corpse_age < 4.96:
		await physics_frame
	check(is_instance_valid(zombie), "Corpse remains until the table's five-second lifespan")
	await ticks(6)
	check(not is_instance_valid(zombie), "Corpse is released after its breakup")
	print("MECHANIC_LAB_MD2_RAGDOLL ", JSON.stringify({"checks": checks, "failures": failures}))
	lab.free()
	quit(0 if failures.is_empty() else 1)

