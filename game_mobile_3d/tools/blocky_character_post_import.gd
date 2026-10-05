@tool
extends EditorScenePostImport
## Only the dedicated authored asset uses this hook.
func _post_import(scene: Node) -> Object:
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(player != null)
	for name in ["Idle", "Run"]:
		assert(player.has_animation(name), "Missing authored clip: " + name)
		player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	return scene
