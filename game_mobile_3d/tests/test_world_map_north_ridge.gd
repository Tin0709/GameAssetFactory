extends SceneTree

var issues: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		issues.append(message)

func run() -> void:
	var world = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var candidate := world.get_node_or_null("NorthernRidgeline") as Node3D
	var button := world.find_child("NorthernRidgelineToggle",true,false) as CheckButton
	var review = world.showcase
	if "absent" in OS.get_cmdline_user_args():
		check(candidate == null and button == null,"No private horizon when sources or Mobile are unavailable")
	else:
		check(candidate != null and button != null and button.button_pressed,"F5 enables the new ridge")
		if candidate != null and button != null:
			check(candidate.visible and not review.distant_terrain.vista.visible,"The background selects one ridge at a time")
			check(candidate.get_child_count() == 2,"Terrain and trees are batched")
			check(candidate.find_children("*","CollisionObject3D",true,false).is_empty(),"The ridge is visual-only")
			var woods := candidate.get_node_or_null("DistantSpruce") as MultiMeshInstance3D
			check(woods != null and woods.multimesh.instance_count == 18,"Verified Spruce placements visible as one batch")
			button.button_pressed = false
			check(not candidate.visible and review.distant_terrain.vista.visible,"A/B selects the previous ridge")
			button.button_pressed = true
			world.set_review_view("overview")
			check(not candidate.visible and not review.distant_terrain.vista.visible,"Overview keeps the imported layout")
			world.set_review_view("gameplay")
			check(candidate.visible and not review.distant_terrain.vista.visible,"World restores gameplay visualization")
			review.set_lighting_scale(&"cliff_vista",0.)
			check(not candidate.visible and not review.distant_terrain.vista.visible,"Existing preset control hides both shapes")
			review.set_lighting_scale(&"cliff_vista",1.)
			check(candidate.visible and not review.distant_terrain.vista.visible,"Existing preset control restores the selected shape")
	world.free()
	await process_frame
	print("NORTHERN_RIDGELINE failures=",JSON.stringify(issues))
	quit(0 if issues.is_empty() else 1)
