extends RefCounted
## Original visual-facing adapter. No change to input, velocity or camera.
## Analytic critical damping stays consistent across physics frequencies.
var angular_velocity:=0.
var target:=0.
var initialized:=false
const RESPONSE_95_SECONDS:=.16
const OMEGA:=4.744/RESPONSE_95_SECONDS
func reset(angle:float)->void:
	angular_velocity=0.;target=angle;initialized=false
func step(current:float,goal:float,delta:float,max_rate:float,has_goal:bool=true)->float:
	if not initialized:target=current;initialized=true
	if has_goal:target=current+wrapf(goal-current,-PI,PI)
	if delta<=0.:return current
	var error:=wrapf(current-target,-PI,PI);var c:=angular_velocity+OMEGA*error;var decay:=exp(-OMEGA*delta)
	var next_error:=(error+c*delta)*decay
	var velocity:=(angular_velocity-OMEGA*c*delta)*decay
	var step_angle:=wrapf(target+next_error-current,-PI,PI)
	var limited:=clampf(step_angle,-max_rate*delta,max_rate*delta)
	angular_velocity=velocity if absf(step_angle-limited)<.000001 else limited/delta
	if absf(next_error)<.00001 and absf(angular_velocity)<.0001:angular_velocity=0.;return target
	return current+limited
