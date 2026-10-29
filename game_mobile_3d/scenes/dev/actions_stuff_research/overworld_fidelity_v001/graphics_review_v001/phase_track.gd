extends RefCounted
## Original eased cyclic adapter. Phase proportions are private preset evidence;
## interpolation and full-loop duration are NOT recovered native algorithms.
const Resolver=preload("override_resolver.gd")
const NAMES:=[&"sunrise",&"day",&"sunset",&"night"]
const STARTS:=[0.,.15,.5,.65,1.]
static func sample(profile:Resource,position:float)->Dictionary:
	var p:=fposmod(position,1.);var index:=0
	for i in 4:
		if p>=STARTS[i]:index=i
	var t:=smoothstep(0.,1.,(p-STARTS[index])/(STARTS[index+1]-STARTS[index]))
	var a:Dictionary=profile.phase_fields(NAMES[index]);var b:Dictionary=profile.phase_fields(NAMES[(index+1)%4])
	# Keep Euler yaw continuous through the shortest arc.
	b.sun_yaw_deg=a.sun_yaw_deg+rad_to_deg(wrapf(deg_to_rad(b.sun_yaw_deg-a.sun_yaw_deg),-PI,PI))
	return Resolver.resolve(a,[{"priority":0,"weight":t,"fields":b}])
