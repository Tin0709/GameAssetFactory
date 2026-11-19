extends RefCounted
## Selects low receivers in the existing overhead lantern's world-space footprint.

const DepthDiffusion := preload("res://scripts/world_map_depth_diffusion.gd")
const MAX_TRIM := .32
const SAMPLE_COUNT_OFFSET := 84

const SHADER := """
layout(set=0,binding=4) uniform sampler2DMS lantern_depth;
layout(set=0,binding=5,std430) readonly buffer LanternExposure {
	vec4 corner; // relative to the player, trim in EV
	vec4 dx; // near plane in w
	vec4 dy; // far minus near in w
	vec4 ray; // lantern height relative to the player in w
	vec4 clip_uv;
	vec4 light; // radius, sample count, relative lantern X and Z
} lantern_exposure;

float lantern_receiver_weight(float raw, vec3 origin) {
	if (raw <= 0.0) return 0.0;
	vec3 point = origin + lantern_exposure.ray.xyz *
		(lantern_exposure.dx.w + (1.0 - raw) * lantern_exposure.dy.w);
	vec3 emitter = vec3(lantern_exposure.light.z, lantern_exposure.ray.w, lantern_exposure.light.w);
	float radius = lantern_exposure.light.x;
	float radial = length(point.xz - emitter.xz);
	float shell = smoothstep(2.0, 3.3, radial) * (1.0 - smoothstep(5.5, 7.6, radial));
	float low_receiver = 1.0 - smoothstep(.80, 2.20, abs(point.y));
	return shell * low_receiver * (1.0 - smoothstep(radius - 1.3, radius, length(point - emitter)));
}

float gaf_lantern_exposure(float gain_ev, vec3 rgb, float luminance, vec2 uv, ivec2 pixel) {
	if (gain_ev <= 0.0 || any(lessThan(uv, lantern_exposure.clip_uv.xy)) ||
			any(greaterThan(uv, lantern_exposure.clip_uv.zw))) return gain_ev;
	float y = max(dot(rgb, vec3(.2126,.7152,.0722)), .00001);
	float chroma = smoothstep(.06, .32, (rgb.g - rgb.b) / y);
	float middle = smoothstep(.002, .009, luminance) * (1.0 - smoothstep(.05, .16, luminance));
	if (chroma * middle <= 0.0) return gain_ev;
	vec3 origin = lantern_exposure.corner.xyz + lantern_exposure.dx.xyz * uv.x + lantern_exposure.dy.xyz * uv.y;
	float a = texelFetch(lantern_depth, pixel, 0).r;
	float b = texelFetch(lantern_depth, pixel, 1).r;
	float nearest = max(a, b);
	float farthest = min(a, b);
	if (lantern_exposure.light.y > 2.0) {
		float c = texelFetch(lantern_depth, pixel, 2).r;
		float d = texelFetch(lantern_depth, pixel, 3).r;
		nearest = max(nearest, max(c, d));
		farthest = min(farthest, min(c, d));
	}
	// At a mixed edge, protect both contributors to the resolved color.
	float weight = (nearest - farthest) * lantern_exposure.dy.w < .18 ?
		lantern_receiver_weight(.5 * (nearest + farthest), origin) :
		min(lantern_receiver_weight(nearest, origin), lantern_receiver_weight(farthest, origin));
	return max(0.0, gain_ev - lantern_exposure.corner.w * chroma * middle * weight);
}
"""

static func supported(viewport: Viewport) -> bool:
	return DepthDiffusion.supported(viewport)

static func parameters(camera: Camera3D, feet: Vector3, lamp: OmniLight3D, amount: float) -> PackedByteArray:
	if not is_finite(amount) or amount <= 0. or not is_instance_valid(lamp) or not lamp.is_visible_in_tree():
		return PackedByteArray()
	if not is_instance_valid(camera) or camera.projection != Camera3D.PROJECTION_ORTHOGONAL or not camera.is_current():
		return PackedByteArray()
	var viewport := camera.get_viewport()
	if not supported(viewport) or not feet.is_finite():
		return PackedByteArray()
	var extent := viewport.get_visible_rect().size
	if extent.x <= 0. or extent.y <= 0.:
		return PackedByteArray()
	var ray := -camera.global_basis.z
	var corner := camera.project_position(Vector2.ZERO, 1.) - ray
	var dx := camera.project_position(Vector2(extent.x, 0.), 1.) - ray - corner
	var dy := camera.project_position(Vector2(0., extent.y), 1.) - ray - corner
	var light_position := lamp.global_position
	var radius := lamp.omni_range
	var center := camera.unproject_position(light_position) / extent
	var bound := Vector2(radius / dx.length(), radius / dy.length())
	var offset := corner - feet
	var emitter := light_position - feet
	return PackedFloat32Array([
		offset.x, offset.y, offset.z, minf(amount, MAX_TRIM),
		dx.x, dx.y, dx.z, camera.near,
		dy.x, dy.y, dy.z, camera.far - camera.near,
		ray.x, ray.y, ray.z, emitter.y,
		center.x - bound.x, center.y - bound.y, center.x + bound.x, center.y + bound.y,
		radius, 0., emitter.x, emitter.z,
	]).to_byte_array()
