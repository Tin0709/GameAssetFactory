extends Resource
## Optional absolute colors over one day. An empty track keeps the shared palette.
## Gradient offsets are hours divided by 24. Match 0 and 1 for a seamless midnight.

@export var sun_color: Gradient
@export var ambient_color: Gradient
@export var sky_color: Gradient
@export var fog_color: Gradient

static func sample_color(track: Gradient, time: float, fallback: Color) -> Color:
	return track.sample(time) if track != null and track.get_point_count() > 0 else fallback
