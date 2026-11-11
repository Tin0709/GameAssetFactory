// One integrated medium for opaque, alpha-tested and cutaway surfaces.
global uniform bool gaf_mist_enabled;
global uniform float gaf_mist_far;
global uniform float gaf_mist_near_entry;
global uniform sampler3D gaf_mist_volume : repeat_disable, filter_linear;
global uniform vec3 gaf_mist_camera_position;
global uniform vec3 gaf_mist_camera_direction;
global uniform vec2 gaf_mist_projection_scale;
vec4 gaf_surface_mist(vec2 uv,float view_depth,vec3 camera_position,vec3 direction,vec2 projection_scale){
	if(!gaf_mist_enabled || view_depth<=0.0)return vec4(0.0);
	if(distance(camera_position,gaf_mist_camera_position)>.005 || dot(direction,gaf_mist_camera_direction)<.99999 || length(abs(projection_scale)-abs(gaf_mist_projection_scale))>.0001)return vec4(0.0);
	float slice=sqrt(clamp(view_depth/gaf_mist_far,0.0,1.0))*31.0;
	if (gaf_mist_near_entry > 0.0) {
		if (view_depth <= gaf_mist_near_entry) return vec4(0.0);
		// The first active interval starts at the layer entry, between grid slices.
		float previous_slice = floor(sqrt(gaf_mist_near_entry/gaf_mist_far)*31.0);
		float next_depth = gaf_mist_far * pow((previous_slice+1.0)/31.0, 2.0);
		if (view_depth < next_depth) {
			slice = previous_slice + (view_depth-gaf_mist_near_entry)/max(next_depth-gaf_mist_near_entry, 0.00001);
		}
	}
	vec4 medium=textureLod(gaf_mist_volume,vec3(uv,(slice+0.5)/32.0),0.0);
	float opacity=clamp(1.0-medium.a,0.0,1.0);
	return vec4(medium.rgb/max(opacity,0.000001),opacity);
}
