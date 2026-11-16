extends RefCounted

## A shared limit for scene exposure and the optional raw bloom source.
const SHADER := """
float gaf_limit_neighborhood_gain(float gain_ev, float luminance, float broad_minus_local,
		vec2 uv, vec2 extent, vec4 protection) {
 if (protection.z <= 0.0 || gain_ev <= 0.0 || broad_minus_local <= .45) return gain_ev;
 vec2 from_actor=(uv-protection.xy)*vec2(extent.x/extent.y,1.0)*protection.w;
 float outside=smoothstep(1.35,3.0,length(from_actor));
 float disagreement=smoothstep(.45,1.65,broad_minus_local);
 float dim=smoothstep(.003,.012,luminance)*(1.0-smoothstep(.050,.140,luminance));
 return max(0.0,gain_ev-protection.z*outside*disagreement*dim);
}
"""
