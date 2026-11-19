shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

instance uniform float hit_flash : instance_index(0) = 0.0;
#define ZOMBIE_HIT_FLASH
#include "res://materials/mechanic_lab_zombie_skin.gdshaderinc"
