shader_type sky;
// Original first-order sky/ground field. The spherical mean is center.
uniform vec3 center;
uniform vec3 vertical;
uniform vec3 horizontal;

void sky() {
	COLOR = center + vertical * EYEDIR.y
		+ horizontal * dot(EYEDIR.xz, vec2(0.616, -0.788));
}
