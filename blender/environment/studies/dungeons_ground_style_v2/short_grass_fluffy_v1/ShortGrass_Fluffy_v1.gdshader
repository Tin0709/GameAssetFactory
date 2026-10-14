shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Original atlas contains all four palettes. Mesh UVs select the variation.
uniform sampler2D grass_atlas : source_color, filter_nearest_mipmap, repeat_disable;

void fragment() {
    vec4 pixel = texture(grass_atlas, UV);
    ALBEDO = pixel.rgb;
    ALPHA = pixel.a;
    ALPHA_SCISSOR_THRESHOLD = 0.5;
    ROUGHNESS = 1.0;
    // Match the reference's upward shading on BOTH sides of every thin card.
    // Standard glTF double-sided lighting flips backface normals; this avoids
    // alternating dark cards without emission or a new light in the scene.
    NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    // UV2.x is reserved for future anchored sway. No wind is applied here.
}
