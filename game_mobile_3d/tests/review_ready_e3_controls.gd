extends Node
## Review-only fixture. Gameplay stays on its real controller. Diagnostics
## pause that controller and pose Run in place; they never redefine locomotion.
var level: Node3D
var enemy: Node3D
var threat_enabled := true
var diagnostic := 0 # 0 gameplay, 1 Run in place, 2 Idle composition
var close_view := false
var original_camera := Transform3D.IDENTITY
var original_size := 14.5
func _ready() -> void:
	process_physics_priority = -2
	original_camera = level.get_node("Camera3D").transform
	original_size = level.get_node("Camera3D").size
func _physics_process(_delta: float) -> void:
	enemy.global_position = level.player.global_position + Vector3(0,0,3 if threat_enabled else 40)
func _process(delta: float) -> void:
	var p: CharacterBody3D = level.player
	if diagnostic > 0:
		var input := Input.get_vector("move_left","move_right","move_forward","move_backward")
		var direction := Vector3(input.x,0,input.y).normalized() if not input.is_zero_approx() else Vector3.RIGHT
		var speed := 6.25 if diagnostic == 1 else 0.0
		p.visual.update_motion(direction*speed,null,delta)
		p.visual._process(delta)
	var context: String = "GAMEPLAY: normal movement = Walk fallback" if diagnostic == 0 else ("RUN IN PLACE DIAGNOSTIC (controller paused)" if diagnostic == 1 else "IDLE COMPOSITION DIAGNOSTIC (controller paused)")
	level.get_node("HUD/Help/Text").text = "E3 LIVING READY A/B REVIEW\nV: Legacy Hold / Living Ready | " + p.visual.ready_context_text() + "\nWASD: move | Shift: sprint/stow | T: threat | 1/2/3: weapon\nG: gameplay / Run diagnostic / Idle diagnostic | C: close view\n" + context
func set_diagnostic(mode: int) -> void:
	var p: CharacterBody3D = level.player
	if mode > 0 and not p.get_node("WeaponBehavior").is_ready(): return
	diagnostic = mode
	p.process_mode = Node.PROCESS_MODE_DISABLED if diagnostic > 0 else Node.PROCESS_MODE_INHERIT
	if diagnostic == 0:
		p.velocity = Vector3.ZERO; p.current_speed = 0.0
		p.visual.update_motion(Vector3.ZERO,null,0.0)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_G: set_diagnostic((diagnostic+1)%3)
	elif event.physical_keycode == KEY_C:
		close_view = not close_view
		var camera: Camera3D = level.get_node("Camera3D")
		if close_view:
			camera.position = level.player.position+Vector3(3,2.8,5)
			camera.look_at(level.player.position+Vector3(0,1,0)); camera.size = 3.0
		else: camera.transform = original_camera; camera.size = original_size
	elif event.physical_keycode == KEY_T: threat_enabled = not threat_enabled
	elif diagnostic > 0 and event.physical_keycode == KEY_V:
		level.player.visual.ready_animation_mode = 1-level.player.visual.ready_animation_mode
	elif diagnostic > 0 and event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
		level.player.equip_test_weapon(event.physical_keycode-KEY_1)
	else: return
	get_viewport().set_input_as_handled()
