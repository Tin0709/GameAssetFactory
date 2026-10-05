extends Node3D

@export var value: int = 1
@export var collection_radius: float = 0.70
var player: Node3D
var combat: Node
var collected: bool = false
@export var collect_duration: float = 0.12
var elapsed: float = 0.0
var collect_elapsed: float = 0.0
var collect_origin: Vector3
@onready var visual: MeshInstance3D = $Visual

func _process(delta: float) -> void:
	elapsed += delta
	visual.rotation.y += delta * 2.0
	visual.position.y = sin(elapsed * 4.0) * 0.035

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(combat): return
	if not combat.active or player.is_dead: return
	if collected:
		collect_elapsed += _delta
		var progress := minf(1.0, collect_elapsed / collect_duration)
		global_position = collect_origin.lerp(player.global_position + Vector3(0, 0.65, 0), progress)
		visual.scale = Vector3.ONE * lerpf(1.0, 0.25, progress)
		if progress >= 1.0:
			combat.award_exp(value)
			queue_free()
		return
	var offset := player.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() <= collection_radius * collection_radius:
		collected = true
		collect_origin = global_position
