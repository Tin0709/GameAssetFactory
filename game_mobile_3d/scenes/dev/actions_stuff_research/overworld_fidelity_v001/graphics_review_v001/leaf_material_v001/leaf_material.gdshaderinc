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

vec3 gaf_leaf_wind_offset(sampler2D pattern, vec3 relative, float clock, float weight) {
 vec2 slope = relative.xz / relative.y;
 float broad = textureLod(pattern, slope * 0.05 + clock * vec2(-0.05, 0.1), 0.0).r;
 vec2 detail = textureLod(pattern, slope + clock * vec2(0.1, 0.5), 0.0).gb;
 float horizontal = (3.0 * broad + 0.25 * detail.x - 1.0) * 0.30;
 return weight * vec3(horizontal, detail.y * 0.15, horizontal);
}
