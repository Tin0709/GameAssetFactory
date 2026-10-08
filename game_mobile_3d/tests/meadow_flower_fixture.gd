extends "res://scripts/forest_meadow_v3.gd"
## Dummy rendering does not retain MultiMesh transform buffers. Capture the
## production scatter boundary in tests; rendered tests also inspect real buffers.
var captured_flowers: Array[Transform3D] = []

func scatter_batch(mesh: Mesh, transforms: Array[Transform3D], material: Material, name_prefix: String, grass := false) -> void:
	if name_prefix=="MeadowWhiteFlowers": captured_flowers.assign(transforms)
	super.scatter_batch(mesh,transforms,material,name_prefix,grass)
