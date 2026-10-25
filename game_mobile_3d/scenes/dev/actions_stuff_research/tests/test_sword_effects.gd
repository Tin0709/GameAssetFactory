extends SceneTree
## Behavioral saturation/cleanup contract: crowd events never grow the scene pool.
var failures: Array[String] = []
const EFFECTS_PATH = "res://scenes/dev/actions_stuff_research/sword_combat_v001/effects.gd"
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(FileAccess.file_exists(EFFECTS_PATH), "Standalone Sword effects implementation must exist")
	if not failures.is_empty():
		quit(1)
		return
	var script = load(EFFECTS_PATH)
	check(script != null and script.can_instantiate(), "Sword effects script must parse")
	if not failures.is_empty():
		quit(1)
		return
	var reports: Array = []
	for quality in [0, 1, 2]:
		var effects = script.new()
		effects.quality = quality
		root.add_child(effects)
		effects.setup()
		effects.set_process(false)
		var nodes: int = effects.get_child_count()
		var capacity: int = effects.fixed_capacity()
		check(capacity > 0 and capacity <= 320, "Particle capacity is finite/mobile bounded")
		effects.setup()
		check(effects.get_child_count() == nodes, "Setup is idempotent")
		check(effects.active_count() == 0, "Fresh pool starts empty")
		effects.swing(1)
		check(effects.active_count() == 0, "Whiff swing never emits a contact impact")
		for hit in 100:
			effects.impact(Vector3(float(hit) * .02, 1.0, 0.0), Vector3.FORWARD, hit % 3 == 0, hit % 7 == 0)
			effects.defense(Vector3(0, 1, 0), hit % 2 == 0)
			effects.dust(Vector3.ZERO, 1.0)
		check(effects.active_count() > 0 and effects.active_count() <= capacity, "100-hit burst respects fixed capacity")
		check(effects.get_child_count() == nodes, "Crowd impacts/defense/dust never allocate nodes")
		var burst: int = effects.active_count()
		for frame in 60:
			effects._process(1.0 / 60.0)
			for hit in 12:
				effects.impact(Vector3(0, 1, 0), Vector3.RIGHT, true, true)
			check(effects.active_count() <= capacity, "Repeated saturation never exceeds fixed capacity")
		effects.reset()
		check(effects.active_count() == 0, "Reset immediately releases every particle")
		check(effects.get_child_count() == nodes and effects.fixed_capacity() == capacity, "Reset retains fixed scene/pool allocation")
		for frame in 12:
			effects.set_trail(Vector3(0, 1, 0), Vector3(float(frame) * .08, 2, 0), true, true)
			effects._process(1.0 / 60.0)
		effects.set_trail(Vector3.ZERO, Vector3.ZERO, false)
		for frame in 120:
			effects._process(1.0 / 60.0)
		check(effects.active_count() == 0, "All effects naturally expire after reset/reuse")
		effects.impact(Vector3.UP, Vector3.ZERO)
		check(effects.active_count() > 0, "Pool reuses slots after reset and accepts zero hit direction")
		effects.intensity = 0.0
		effects.reset()
		effects.impact(Vector3.UP, Vector3.FORWARD, true, true)
		effects.defense(Vector3.UP, true)
		effects.dust(Vector3.ZERO)
		check(effects.active_count() == 0, "Zero intensity disables emissions")
		reports.append({"quality": quality, "capacity": capacity, "crowd_burst": burst, "child_nodes": nodes})
		effects.free()
	print("SWORD_EFFECTS ", JSON.stringify({"failures": failures, "reports": reports}))
	quit(0 if failures.is_empty() else 1)
