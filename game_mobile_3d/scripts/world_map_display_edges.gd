extends RefCounted
## Independently authored edge-oriented display resampling, no temporal history.
## Local contrast / edge search / coverage follows the public FXAA principles.
## Use a short edge search to keep the pixel-art silhouette stable during a pan.
const HEADER := """#version 450
layout(set=0,binding=0) uniform sampler2D scene_color;
layout(location=0) out vec4 result;
vec4 read_scene(vec2 at) {
 vec2 half_pixel = .5 / vec2(textureSize(scene_color, 0));
 return textureLod(scene_color, clamp(at, half_pixel, 1. - half_pixel), 0.);
}
"""
const EDGE_SEARCH := """
float endpoint_hit(float delta, float required) {
 return smoothstep(.82 * required, 1.22 * required, abs(delta));
}
float matches_edge(float endpoint, float center) {
 return (endpoint < 0.) != (center < 0.) ? 1. : 0.;
}
// Return distance in pixels and confidence that the endpoint crosses the edge.
// At a marginal hit, blend the neighboring offsets instead of skipping a tap.
vec2 trace_endpoint(vec2 center, vec2 step, float average, float required, float center_delta) {
 float first = brightness(center + step) - average;
 float first_hit = endpoint_hit(first, required);
 vec2 closest = vec2(1., matches_edge(first, center_delta));
 if (first_hit >= 1.) return closest;
 float second = brightness(center + 2.5 * step) - average;
 float second_hit = endpoint_hit(second, required);
 vec2 middle = vec2(2.5, matches_edge(second, center_delta));
 if (second_hit >= 1.) return mix(middle, closest, first_hit);
 float last = brightness(center + 4.5 * step) - average;
 vec2 farthest = vec2(4.5, endpoint_hit(last, required) * matches_edge(last, center_delta));
 return mix(mix(farthest, middle, second_hit), closest, first_hit);
}

vec3 filter_edge(vec2 uv, vec2 pixel, vec3 original, float edge_floor) {
 vec3 north = read_scene(uv - vec2(0, pixel.y)).rgb;
 vec3 south = read_scene(uv + vec2(0, pixel.y)).rgb;
 vec3 west = read_scene(uv - vec2(pixel.x, 0)).rgb;
 vec3 east = read_scene(uv + vec2(pixel.x, 0)).rgb;
 float m = edge_luma(original);
 float n = edge_luma(north), s = edge_luma(south);
 float w = edge_luma(west), e = edge_luma(east);
 float low = min(m, min(min(n, s), min(w, e)));
 float high = max(m, max(max(n, s), max(w, e)));
 float range = high - low;
 float cutoff = max(edge_floor, high * .166);
 if (range <= cutoff) return original;
 float nw = brightness(uv - pixel), ne = brightness(uv + vec2(pixel.x, -pixel.y));
 float sw = brightness(uv + vec2(-pixel.x, pixel.y)), se = brightness(uv + pixel);
 float horizontal_strength = abs(nw + sw - 2. * w) + 2. * abs(n + s - 2. * m) + abs(ne + se - 2. * e);
 float vertical_strength = abs(nw + ne - 2. * n) + 2. * abs(w + e - 2. * m) + abs(sw + se - 2. * s);
 bool horizontal = horizontal_strength >= vertical_strength;
 float near_value = horizontal ? n : w, far_value = horizontal ? s : e;
 float near_gradient = abs(near_value - m), far_gradient = abs(far_value - m);
 float strongest_gradient = max(near_gradient, far_gradient);
 bool negative = near_gradient >= far_gradient;
 float pair_average = .5 * (m + (negative ? near_value : far_value));
 float required = max(.25 * strongest_gradient, 1e-6);
 vec2 normal = (horizontal ? vec2(0, pixel.y) : vec2(pixel.x, 0)) * (negative ? -1. : 1.);
 vec2 tangent = horizontal ? vec2(pixel.x, 0) : vec2(0, pixel.y);
 vec2 center = uv + .5 * normal;
 vec2 left = trace_endpoint(center, -tangent, pair_average, required, m - pair_average);
 vec2 right = trace_endpoint(center, tangent, pair_average, required, m - pair_average);
 float end_weight = smoothstep(-.65, .65, right.x - left.x);
 float endpoint_confidence = mix(right.y, left.y, end_weight);
 float edge = (.5 - min(left.x, right.x) / (left.x + right.x)) * endpoint_confidence;
 float mean = ((n + s + w + e) * 2. + nw + ne + sw + se) / 12.;
 float coverage = smoothstep(0., 1., abs(mean - m) / range);
 coverage = coverage * coverage * .28;
 // Use symmetric coverage when either direction is plausible.
 float axis_gap = abs(horizontal_strength - vertical_strength) / max(horizontal_strength + vertical_strength, 1e-6);
 float side_gap = abs(near_gradient - far_gradient) / max(strongest_gradient, 1e-6);
 float contrast_weight = smoothstep(cutoff, 1.24 * cutoff, range);
 float direction_weight = smoothstep(0., .13, axis_gap) * smoothstep(0., .16, side_gap);
 vec3 symmetric = mix(original, (north + south + west + east) * .25, .38);
 vec3 directional = read_scene(uv + max(.70 * edge, coverage) * normal).rgb;
 return mix(original, mix(symmetric, directional, direction_weight), contrast_weight);
}
"""

const FRAGMENT := HEADER + """
layout(set=0,binding=1,std430) readonly buffer Baseline { vec4 base[]; };
const vec3 luma_weights = vec3(.299, .587, .114);
float edge_luma(vec3 color) { return dot(color, luma_weights); }
float brightness(vec2 uv) { return edge_luma(read_scene(uv).rgb); }
vec3 linear_display(vec3 c) {
 return mix(c/12.92, pow((c+.055)/1.055, vec3(2.4)), greaterThan(c, vec3(.04045)));
}
""" + EDGE_SEARCH + """
void main() {
 vec2 pixel = 1. / vec2(textureSize(scene_color, 0));
 vec2 uv = gl_FragCoord.xy * pixel;
 vec3 original = read_scene(uv).rgb;
 vec3 filtered = filter_edge(uv, pixel, original, .0833);
 result = vec4(linear_display(mix(original, filtered, base[1].z * base[5].z)), 1.);
}
"""

const SCENE_HDR := HEADER + """
layout(push_constant,std430) uniform Settings { vec4 settings; vec4 air; vec4 finish; };
const vec3 linear_luma = vec3(.2126, .7152, .0722);
float guide(vec3 color) {
 // Shape only the edge guide. Radiance used by the renderer stays in scene space.
 float y = max(dot(linear_luma, color), 0.) * finish.z * (air.z > .5 ? 1. : 2.);
 return sqrt(y / (y + .55));
}
float edge_luma(vec3 color) { return guide(color); }
float brightness(vec2 uv) { return edge_luma(read_scene(uv).rgb); }
""" + EDGE_SEARCH + """
void main() {
 vec2 pixel = 1. / vec2(textureSize(scene_color, 0));
 vec2 uv = gl_FragCoord.xy * pixel;
 vec4 original = read_scene(uv);
 vec3 filtered = filter_edge(uv, pixel, original.rgb, .066);
 result = vec4(mix(original.rgb, filtered, finish.w), original.a);
}
"""
