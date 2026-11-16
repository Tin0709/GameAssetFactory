extends RefCounted

const GREEN_SHADOW_TRIM_SHADER := """
float gaf_green_shadow_lift(vec3 color, vec3 luma, float amount) {
 if (amount <= 0.0) return 1.0;
 float y = max(dot(color, luma), 0.00001);
 float hue = smoothstep(.09,.29,(color.g-color.r)/y)*smoothstep(.12,.34,(color.g-color.b)/y);
 float shade = smoothstep(.002,.007,y)*(1.0-smoothstep(.014,.049,y));
 return 1.0 - amount*hue*shade;
}
"""
