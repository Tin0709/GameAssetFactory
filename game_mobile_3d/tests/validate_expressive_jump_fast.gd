extends "res://tests/validate_expressive_jump.gd"
## Reuse all stress scenarios at the explicitly requested2.25x test pace.
## Keep the existing clearance/angular guards: report failures rather than weaken them.
func check(ok: bool, message: String) -> void:
	if message=="Walk/Run retain requested1.5x pace":
		ok=current_scene.actor.review_pace==2.25
		message="Walk/Run retain requested2.25x pace"
	super.check(ok,message)
