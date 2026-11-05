#include "cloud_projector.gdshaderinc"

uniform sampler2D actor_albedo : source_color, filter_nearest, repeat_disable;
uniform sampler2D actor_surface : filter_nearest, repeat_disable;
uniform sampler2D actor_emission : source_color, filter_nearest, repeat_disable;
uniform vec4 actor_tint : source_color = vec4(1.0);
uniform vec3 actor_emission_tint : source_color = vec3(1.0);
uniform float actor_roughness = 1.0;
uniform float actor_metallic = 1.0;
uniform float actor_specular = 0.5;
uniform float actor_cutoff = 0.5;
uniform float actor_emission_gain = 1.0;
varying float actor_sun_visibility;

void fragment() {
	vec4 color = texture(actor_albedo, UV) * actor_tint;
	vec3 surface = texture(actor_surface, UV).rgb;
	ALBEDO = color.rgb;
	ROUGHNESS = surface.g * actor_roughness;
	METALLIC = surface.b * actor_metallic;
	SPECULAR = actor_specular;
	EMISSION = texture(actor_emission, UV).rgb * actor_emission_tint * actor_emission_gain;
#ifdef GAF_ACTOR_CUTOUT
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = actor_cutoff;
#endif
	actor_sun_visibility = gaf_cloud_strength > 0.0
		? gaf_cloud_at((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz)
		: 1.0;
}

float gaf_actor_fresnel(float cosine) {
	float complement = 1.0 - cosine;
	float square = complement * complement;
	return square * square * complement;
}

// Burley diffuse and isotropic GGX for the supported actor materials.
// Godot combines these direct lobes with its own ambient, fog and emission.
void light() {
	float normal_light = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float normal_view = clamp(dot(NORMAL, VIEW), 0.0001, 1.0);
	vec3 halfway = normalize(LIGHT + VIEW);
	float light_half = clamp(dot(LIGHT, halfway), 0.0, 1.0);
	vec3 incident = LIGHT_COLOR * (ATTENUATION * normal_light / PI);
	if (LIGHT_IS_DIRECTIONAL) { incident *= actor_sun_visibility; }

	float grazing_diffuse = 2.0 * ROUGHNESS * light_half * light_half - 0.5;
	if (METALLIC < 1.0) {
		float diffuse_view = 1.0 + grazing_diffuse * gaf_actor_fresnel(normal_view);
		float diffuse_light = 1.0 + grazing_diffuse * gaf_actor_fresnel(normal_light);
		DIFFUSE_LIGHT += incident * (diffuse_view * diffuse_light);
	}
	if (ROUGHNESS > 0.0) {
		float alpha = ROUGHNESS * ROUGHNESS;
		float normal_half = clamp(dot(NORMAL, halfway), 0.0, 1.0);
		float alpha_half = normal_half * alpha;
		float ggx = alpha / max(1.0 - normal_half * normal_half + alpha_half * alpha_half, 0.000001);
		float distribution_pi = min(ggx * ggx, PI);
		float visibility = min(0.5 / max(mix(2.0 * normal_light * normal_view, normal_light + normal_view, alpha), 0.000001), 1.0);
		vec3 f0 = mix(vec3(0.16 * actor_specular * actor_specular), ALBEDO, METALLIC);
		float grazing_specular = clamp(16.5 * (f0.r + f0.g + f0.b), METALLIC, 1.0);
		vec3 fresnel = mix(f0, vec3(grazing_specular), gaf_actor_fresnel(light_half));
		SPECULAR_LIGHT += incident * fresnel * (distribution_pi * visibility * SPECULAR_AMOUNT);
	}
}
