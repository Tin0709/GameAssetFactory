## Static foliage material setup; no gameplay, wind or map changes.
@tool
extends Node3D

@export var foliage_material: Material = preload("ShortGrass_Fluffy_v1_Material.tres")

func _ready() -> void:
	apply_to(self, foliage_material)

static func apply_to(root: Node, shared_material: Material) -> void:
	if root is MeshInstance3D:
		root.material_override = shared_material
		# Avoid stacked alpha-card shadows. Ground contact is anchored in geometry.
		root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children():
		apply_to(child, shared_material)
