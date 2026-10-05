extends RefCounted
## Shared numeric geometry cache, independent of any actor or scene instance.
static var death_serial := 0
static var bound_bones := PackedInt32Array()
static var bound_corners: Array[Vector3] = []
