extends RefCounted
## CPU oracle for the shader's authored bend, not recovered native WPO bytecode.
var direction:=Vector2(.894427,-.447214)
var intensity:=.5
var frequency:=.375
func offset(u:float,height:float,root:Vector2,phase:float,response:float,time:float,contact:Vector2)->Vector3:
	var spatial:=root.dot(direction)
	var p:=phase+spatial*.6283185
	var bend:=direction*(.28*sin(time*frequency*TAU+p)+.055*sin(time*TAU*.625+spatial*.34))
	bend+=Vector2(-direction.y,direction.x)*.025*sin(time*TAU*.25+p)
	bend=bend*intensity*response+contact
	var theta:=minf(bend.length(),.75)
	if theta<.0001:return Vector3(bend.x,bend.length()*-u/3.,bend.y)*(.5*height*u*u)
	var planar:=bend.normalized()*height*(1.-cos(theta*u))/theta
	return Vector3(planar.x,height*sin(theta*u)/theta-height*u,planar.y)
