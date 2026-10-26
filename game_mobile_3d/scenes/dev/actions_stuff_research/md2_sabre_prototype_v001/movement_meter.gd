extends RefCounted
## Aggregate diagnostics only. Position differences own travel; requested speed
## never counts as displacement. Sole movement includes rolling, not proven slip.
var elapsed:=0.
var distance:=0.
var gait_cycles:=0.
var speed:=0.
var peak_speed:=0.
var vertical_speed:=0.
var acceleration:=0.
var acceleration_valid:=false
var _has_velocity_sample:=false
var target_speed:=0.
var cycle_hz:=0.
var response_95:=-1.
var stop_distance:=0.
var stop_seconds:=0.
var sole_speed:Array[float]=[-1.,-1.]
var sole_height:Array[float]=[0.,0.]
var _start:=Vector3.ZERO
var _previous:=Vector3.ZERO
var _intent:=false
var _responding:=false
var _response_time:=0.
var _stopping:=false
var _sole_previous:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var _sole_contact:Array[bool]=[false,false]
var _sole_squared:Array[float]=[0.,0.]
var _sole_samples:Array[int]=[0,0]

func reset(position:Vector3,moving:bool=false)->void:
	elapsed=0.;distance=0.;gait_cycles=0.;speed=0.;peak_speed=0.;vertical_speed=0.;acceleration=0.;target_speed=0.;cycle_hz=0.
	response_95=-1.;stop_distance=0.;stop_seconds=0.;_start=position;_previous=position
	acceleration_valid=false;_has_velocity_sample=false
	_intent=moving;_responding=false;_response_time=0.;_stopping=false
	sole_speed=[-1.,-1.];sole_height=[0.,0.];_sole_previous=[Vector3.ZERO,Vector3.ZERO];_sole_contact=[false,false];_sole_squared=[0.,0.];_sole_samples=[0,0]

func sample(delta:float,position:Vector3,requested_speed:float,moving:bool,advanced_cycles:float,soles:Array=[])->void:
	if delta<=0.:return
	var step:=position-_previous;var travelled:=Vector2(step.x,step.z).length()
	var previous_speed:=speed;speed=travelled/delta;vertical_speed=step.y/delta
	acceleration_valid=_has_velocity_sample;acceleration=(speed-previous_speed)/delta if acceleration_valid else 0.;_has_velocity_sample=true
	elapsed+=delta;distance+=travelled;peak_speed=maxf(peak_speed,speed);target_speed=requested_speed
	gait_cycles+=advanced_cycles;cycle_hz=advanced_cycles/delta
	if moving and not _intent:_responding=true;_response_time=0.;response_95=-1.;_stopping=false
	if _responding:
		_response_time+=delta
		if moving and requested_speed>.01 and speed>=requested_speed*.95:response_95=_response_time;_responding=false
		elif not moving:_responding=false
	if not moving and _intent:_stopping=true;stop_distance=0.;stop_seconds=0.
	if _stopping:
		stop_distance+=travelled;stop_seconds+=delta
		if speed<.01:_stopping=false
	for side in 2:
		sole_speed[side]=-1.
		if side>=soles.size():_sole_contact[side]=false;continue
		var item:Dictionary=soles[side];var center:Vector3=item.center;var candidate:bool=item.candidate
		sole_height[side]=float(item.height)
		if speed>.1 and advanced_cycles>0. and _has_velocity_sample:
			var relative_motion:Vector3=center-_sole_previous[side]-step
			# A low foot travelling forward relative to the body is still in swing.
			# Height alone would misreport its fast return as stance sliding.
			candidate=candidate and Vector2(relative_motion.x,relative_motion.z).dot(Vector2(step.x,step.z))<=0.
		if candidate and _sole_contact[side]:
			var motion:=center-_sole_previous[side];var ground_speed:=Vector2(motion.x,motion.z).length()/delta
			sole_speed[side]=ground_speed;_sole_squared[side]+=ground_speed*ground_speed;_sole_samples[side]+=1
		_sole_previous[side]=center;_sole_contact[side]=candidate
	_previous=position;_intent=moving

func snapshot()->Dictionary:
	var net:=_previous-_start;var rms:Array[float]=[-1.,-1.]
	for side in 2:
		if _sole_samples[side]>0:rms[side]=sqrt(_sole_squared[side]/_sole_samples[side])
	return {"elapsed":elapsed,"distance":distance,"net_distance":Vector2(net.x,net.z).length(),"speed":speed,"peak_speed":peak_speed,"vertical_speed":vertical_speed,"acceleration":acceleration if acceleration_valid else null,"acceleration_sample_valid":acceleration_valid,"target_speed":target_speed,"gait_cycles":gait_cycles,"cycle_hz":cycle_hz,"response_95":response_95,"stop_distance":stop_distance,"stop_seconds":stop_seconds,"sole_speed":sole_speed.duplicate(),"sole_height":sole_height.duplicate(),"sole_candidate_rms_speed":rms,"sole_candidate_samples":_sole_samples.duplicate(),"sole_note":"Rest-bottom centroids during low/backward foot candidates; rolling and stance inference are not resolved. Not a proof of foot slip or foot locking."}
