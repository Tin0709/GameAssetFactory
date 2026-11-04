extends RefCounted
## Original transfer of two already-lit reference endpoints, not native AO.
## Existing geometry/reach stay the caller's approximation.
static func source_weight(distance:float,reach:float)->float:
	assert(reach>0.,"Covered-field reach must be positive")
	return smoothstep(0.,reach,distance)
