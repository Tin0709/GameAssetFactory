extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL ", message)

func contact(lab, delta: Vector3, serial: int, clip: String = "NativeFinisher", index: int = 2) -> float:
	var body := lab.player.get_node("BodyCollision") as CollisionShape3D
	lab._on_sabre_contact(body.global_position + delta, Vector3.RIGHT, clip, index, serial, false)
	lab._process(1.0 / 60.0)
	return lab.camera.h_offset / lab.camera.size

func run() -> void:
	var lab = load("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.set_process(false)
	await physics_frame
	check(is_zero_approx(contact(lab, Vector3(2.4, 1.9, 0), 100)), "Raised contact outside the three-dimensional outer radius does not shake")
	check(lab._impact_light.visible, "An out-of-range shake does not suppress local contact light")
	lab.reset_player()
	var half := contact(lab, Vector3(1.8, 1.35, 0), 101)
	check(is_equal_approx(half, 0.004), "Offset along two axes measures a 2.25 m distance with half strength")
	lab.reset_player()
	check(is_equal_approx(contact(lab, Vector3(0.9, 1.2, 0), 102), 0.008), "Three-dimensional inner radius applies the full kick")
	lab.reset_player()
	lab.camera.size = 6.0
	check(is_equal_approx(contact(lab, Vector3(1.8, -1.35, 0), 103, "Attack3"), half), "Sword finisher is symmetric about the pawn and independent of zoom")
	lab.reset_player()
	check(is_zero_approx(contact(lab, Vector3(1, 0, 0), 104, "Attack2", 1)), "Sword ordinary strike has zero shake")
	lab.free()
	print("PAWN_SHAKE_RANGE failures=", failures)
	quit(0 if failures.is_empty() else 1)
