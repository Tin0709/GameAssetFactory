## Optional static foliage material setup; no gameplay, wind or map changes.
extends RefCounted

static func apply_to(root: Node, shared_material: Material) -> void:
	if root is MeshInstance3D:
		root.material_override = shared_material
		# Avoid stacked alpha-card shadows. Ground contact is anchored in geometry.
		root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children():
		apply_to(child, shared_material)
