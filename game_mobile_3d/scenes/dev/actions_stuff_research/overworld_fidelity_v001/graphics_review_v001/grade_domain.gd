extends RefCounted
## Original inverse-domain adapter for a caller-supplied color-correction LUT.
## The LUT must be baked for the same linear input domain. No palette/LUT data.
## Godot decodes Environment UI brightness to linear before applying it.
static func supported(domain:float)->bool:
	return is_finite(domain) and domain>=1. and domain<=2.
static func ui_brightness(domain:float)->float:
	if not supported(domain):return -1.
	var gain:=1./domain
	return Color(gain,gain,gain).linear_to_srgb().r
static func sampling_contrast(size:int)->float:
	# mix(0.5,c,(N-1)/N) places c=0/1 at the first/last texel centers.
	# Pair with an endpoint lattice i/(N-1), not a center-baked LUT.
	return float(size-1)/size if size>=2 else -1.
