// Original world-space normal response. The caller supplies the material weight.
vec3 gaf_foliage_world_normal(vec3 world_normal,float up_weight) {
 return normalize(world_normal*(1.-up_weight)+vec3(0.,up_weight,0.));
}
