extends RefCounted
## Shared Environment and directional-light setters. The caller owns the scene and phase inputs.

static func apply_lighting(sun: DirectionalLight3D, env: Environment, phase: Dictionary, noon: Dictionary,
		sun_rotation: Vector3, key_color: Color, key_energy: float, ambient_color: Color, ambient_energy: float) -> void:
	sun.rotation_degrees = sun_rotation + Vector3(phase.pitch - noon.pitch, phase.yaw - noon.yaw, 0.)
	sun.light_color = key_color * Color(phase.key) / Color(noon.key)
	sun.light_energy = key_energy * float(phase.energy) / float(noon.energy)
	env.ambient_light_color = ambient_color * Color(phase.ambient) / Color(noon.ambient)
	env.ambient_light_energy = ambient_energy * float(phase.ambient_energy) / float(noon.ambient_energy)

static func apply_depth_fog(env: Environment, tint: Color, density: float, begin: float, end: float) -> void:
	env.fog_light_color = tint
	env.fog_depth_begin = begin
	env.fog_depth_end = end
	env.fog_density = density

static func apply_grade(env: Environment, contrast: float, saturation: float) -> void:
	env.adjustment_contrast = contrast
	env.adjustment_saturation = saturation

static func apply_bloom(env: Environment, glow: bool, intensity: float, bloom: float, threshold: float) -> void:
	env.glow_enabled = glow
	env.glow_intensity = intensity
	env.glow_bloom = bloom
	env.glow_hdr_threshold = threshold
