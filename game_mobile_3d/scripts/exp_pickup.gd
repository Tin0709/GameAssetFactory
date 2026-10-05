extends Node3D

@export var value: int = 1
@export var collection_radius: float = 0.70
var player: Node3D
var combat: Node
var collected: bool = false
var elapsed: float = 0.0
@onready var visual: MeshInstance3D = $Visual

func _process(delta: float) -> void:
	elapsed += delta
	visual.rotation.y += delta * 2.0
	visual.position.y = sin(elapsed * 4.0) * 0.035

func _physics_process(_delta: float) -> void:
	if collected or not is_instance_valid(player) or not is_instance_valid(combat): return
	if not combat.active or player.is_dead: return
	var offset := player.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() <= collection_radius * collection_radius:
		collected = true
		combat.award_exp(value)
		queue_free()
