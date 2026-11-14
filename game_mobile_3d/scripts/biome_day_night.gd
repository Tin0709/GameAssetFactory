extends Resource
## Optional absolute colors over one day. An empty track keeps the shared palette.
## Gradient offsets are hours divided by 24. Match 0 and 1 for a seamless midnight.

@export var sun_color: Gradient
@export var ambient_color: Gradient
@export var sky_color: Gradient
@export var fog_color: Gradient
## Absolute degrees. Author yaw on a continuous interval, e.g. 170 to 190.
@export var sun_pitch_degrees: Curve
@export var sun_yaw_degrees: Curve
@export var exposure: Curve

static func sample_color(track: Gradient, time: float, fallback: Color) -> Color:
	return track.sample(time) if track != null and track.get_point_count() > 0 else fallback

static func sample_curve(track: Curve, time: float, fallback: float) -> float:
	return track.sample(time) if track != null and track.point_count > 0 else fallback
