extends Node
## Standalone review only: a durable, non-attacking awareness test target.
var level: Node3D
var enemy: Node3D
var threat_enabled := true
func _ready() -> void:
	process_physics_priority = -2
func _physics_process(_delta: float) -> void:
	enemy.global_position = level.player.global_position + Vector3(0,0,3 if threat_enabled else 40)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		threat_enabled = not threat_enabled
