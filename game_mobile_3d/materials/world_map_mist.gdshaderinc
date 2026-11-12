// One integrated medium for opaque, alpha-tested and cutaway surfaces.
global uniform bool gaf_mist_enabled;
global uniform float gaf_mist_far;
global uniform float gaf_mist_near_entry;
global uniform sampler3D gaf_mist_volume : repeat_disable, filter_linear;
global uniform vec3 gaf_mist_camera_position;
global uniform vec3 gaf_mist_camera_direction;
global uniform vec2 gaf_mist_projection_scale;
global uniform vec4 gaf_local_mist_center;
global uniform vec3 gaf_local_mist_radii;
global uniform vec3 gaf_local_mist_origin;
global uniform vec3 gaf_local_mist_dx;
global uniform vec3 gaf_local_mist_dy;

float gaf_local_mist_entry(vec2 uv,vec3 direction,float base_entry){
	vec3 origin=gaf_local_mist_origin+gaf_local_mist_dx*uv.x+gaf_local_mist_dy*uv.y;
	vec3 start=(origin-gaf_local_mist_center.xyz)/gaf_local_mist_radii;
	vec3 ray=direction/gaf_local_mist_radii;
	float curvature=dot(ray,ray);
	float midpoint=-dot(start,ray)/curvature;
	vec3 nearest=start+ray*midpoint;
	float ceiling=1.0-dot(nearest,nearest);
	if(ceiling<=0.0)return base_entry;
	float radius=sqrt(ceiling/curvature);
	return midpoint+radius>0.0?min(base_entry,max(0.0,midpoint-radius)):base_entry;
}

vec4 gaf_surface_mist(vec2 uv,float view_depth,vec3 camera_position,vec3 direction,vec2 projection_scale){
	if(!gaf_mist_enabled || view_depth<=0.0)return vec4(0.0);
	if(distance(camera_position,gaf_mist_camera_position)>.005 || dot(direction,gaf_mist_camera_direction)<.99999 || length(abs(projection_scale)-abs(gaf_mist_projection_scale))>.0001)return vec4(0.0);
	float slice=sqrt(clamp(view_depth/gaf_mist_far,0.0,1.0))*31.0;
	float entry=gaf_mist_near_entry;
	if (entry > 0.0) {
		float previous_slice = floor(sqrt(entry/gaf_mist_far)*31.0);
		float next_depth = gaf_mist_far * pow((previous_slice+1.0)/31.0, 2.0);
		if (view_depth < next_depth && gaf_local_mist_center.w > 0.0) {
			entry=gaf_local_mist_entry(uv,direction,entry);
			previous_slice=floor(sqrt(entry/gaf_mist_far)*31.0);
			next_depth=gaf_mist_far*pow((previous_slice+1.0)/31.0,2.0);
		}
		if (view_depth <= entry) return vec4(0.0);
		// The first active interval starts at the layer entry, between grid slices.
		if (view_depth < next_depth) {
			slice = previous_slice + (view_depth-entry)/max(next_depth-entry, 0.00001);
		}
	}
	vec4 medium=textureLod(gaf_mist_volume,vec3(uv,(slice+0.5)/32.0),0.0);
	float opacity=clamp(1.0-medium.a,0.0,1.0);
	return vec4(medium.rgb/max(opacity,0.000001),opacity);
}
