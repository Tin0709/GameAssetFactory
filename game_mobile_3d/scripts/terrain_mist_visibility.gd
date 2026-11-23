extends Resource
## Stores sqrt of upper-hemisphere visibility at texel centers. Light only.

@export var texture: Texture3D
@export var origin := Vector3.ZERO
@export var spacing := Vector3.ONE
@export var layout_sha256 := ""

func binding_for_layout(path: String) -> Dictionary:
	if texture == null or layout_sha256.length() != 64 or not origin.is_finite() or not spacing.is_finite():
		return {}
	var dimensions := Vector3(texture.get_width(), texture.get_height(), texture.get_depth())
	if dimensions[dimensions.min_axis_index()] < 2. or spacing[spacing.min_axis_index()] < .01:
		return {}
	if FileAccess.get_sha256(path) != layout_sha256:
		return {}
	return {"texture": texture, "origin": origin, "step": spacing, "dimensions": dimensions,
		"valid": false, "ambient_floor": 1.}
