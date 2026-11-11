// Original parameterized leaf color/linear transmission, independent of lighting.
// Vertex weights are supplied data; no green-pixel classification or palette.
vec3 gaf_leaf_color(vec3 color, float angle, float vertex_red) {
 vec3 axis=vec3(0.5773502691896258);
 vec3 axial=axis*dot(axis,color);
 vec3 shifted=axial+(color-axial)*cos(angle)+cross(axis,color)*sin(angle);
 return clamp(mix(color,shifted,vertex_red),vec3(0.),vec3(1.));
}
vec3 gaf_leaf_transmission(vec3 color,float vertex_green,float strength) {
 return clamp(color*(vertex_green*strength),vec3(0.),vec3(1.));
}

vec3 gaf_leaf_drift_from_samples(float broad, vec2 detail, float weight) {
 float horizontal = (3.0 * broad + 0.25 * detail.x - 1.0) * 0.30;
 return weight * vec3(horizontal, detail.y * 0.15, horizontal);
}

vec3 gaf_leaf_wind_offset(sampler2D pattern, vec3 relative, float clock, float weight) {
 vec2 slope = relative.xz / relative.y;
 float broad = textureLod(pattern, slope * 0.05 + clock * vec2(-0.05, 0.1), 0.0).r;
 vec2 detail = textureLod(pattern, slope + clock * vec2(0.1, 0.5), 0.0).gb;
 return gaf_leaf_drift_from_samples(broad, detail, weight);
}

vec3 gaf_leaf_world_drift(sampler2D pattern, vec3 position, float root_height, vec2 state, float weight) {
 // A world-fixed reference height keeps the wind identical for view and shadow passes.
 vec3 relative = position - vec3(0.0, root_height + 24.0, 0.0);
 relative.y = min(relative.y, -8.0);
 // This sampler is linear. The dedicated PIX comparison above uses point filtering.
 vec2 slope = relative.xz / relative.y;
 float broad = textureLod(pattern, slope * 0.05 + state.x * vec2(-0.05, 0.1), 0.0).r;
 vec2 detail = textureLod(pattern, slope + state.x * vec2(0.1, 0.5), 0.0).gb;
 return gaf_leaf_drift_from_samples(broad, detail, state.y * weight);
}
