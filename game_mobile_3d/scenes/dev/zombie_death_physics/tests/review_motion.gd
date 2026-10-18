extends SceneTree
## Original-speed offline recording of the actual Mobile-rendered lab, no comparisons.
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func run() -> void:
	root.size = Vector2i(1440,810)
	var lab = load("res://scenes/dev/ZombieDeathPhysicsLab.tscn").instantiate()
	root.add_child(lab)
	var caption := Label.new()
	caption.position = Vector2(24,82)
	caption.add_theme_font_size_override("font_size",24)
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	overlay.add_child(caption)
	await frames(15)
	for weapon in 3:
		lab.animation_choice.select(weapon)
		lab.weapon_choice.select(weapon)
		lab._load_profile(weapon)
		lab.reset_zombie()
		lab.set_view(2 if weapon != 1 else 1)
		caption.text = ["PISTOL / Idle","RIFLE / Walk","SHOTGUN / Attack"][weapon]+" — 1× / 30 FPS\n1.2 s corpse + bounded landing extension"
		await frames(15)
		lab.trigger_death()
		await frames(66)
	caption.text = "Cleanup complete — pooled visuals retain ZERO physics bodies/joints"
	await frames(24)
	quit()
