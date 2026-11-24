shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#define SABRE_PACKED_SURFACE
#include "res://materials/mechanic_lab_blade_wall.gdshaderinc"
