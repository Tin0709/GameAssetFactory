extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:
	var path:="res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/movement_meter.gd"
	check(ResourceLoader.exists(path),"Actual-displacement movement meter exists")
	if not failures.is_empty():quit(1);return
	var meter=load(path).new()
	for hz in [30,60]:
		meter.reset(Vector3.ZERO)
		for i in hz:meter.sample(1./hz,Vector3(7.*(i+1)/hz,0,0),7.,true,7./5.6/.433333/hz)
		var r:Dictionary=meter.snapshot()
		check(absf(r.distance-7.)<.00001 and absf(r.net_distance-7.)<.00001,"Actual measured travel is7 at "+str(hz))
		check(absf(r.speed-7.)<.0001 and absf(r.elapsed-1.)<.00001,"Speed uses actual displacement/time at "+str(hz))
		check(absf(r.gait_cycles-7./5.6/.433333)<.00001,"Actual advanced gait cycles accumulated at "+str(hz))
	meter.reset(Vector3.ZERO)
	for i in 20:meter.sample(.1,Vector3.ZERO,7.,true,0.)
	var blocked:Dictionary=meter.snapshot()
	check(blocked.distance==0. and blocked.speed==0. and blocked.response_95<0.,"Blocked command is never counted as travel or achieved response")
	meter.reset(Vector3.ZERO)
	for p:Vector3 in [Vector3(1,0,0),Vector3(1,0,1),Vector3(0,0,1),Vector3.ZERO]:meter.sample(.25,p,4.,true,.1)
	check(absf(meter.snapshot().distance-4.)<.00001 and meter.snapshot().net_distance==0.,"Path distance is distinct from net displacement")
	meter.reset(Vector3.ZERO);meter.sample(.1,Vector3(.35,0,0),7.,true,.1);meter.sample(.1,Vector3(1.05,0,0),7.,true,.2)
	check(absf(meter.snapshot().response_95-.2)<.00001,"Response95 measures actual threshold crossing")
	meter.sample(.1,Vector3(1.4,0,0),0.,false,.1);meter.sample(.1,Vector3(1.4,0,0),0.,false,0.)
	check(absf(meter.snapshot().stop_distance-.35)<.00001 and absf(meter.snapshot().stop_seconds-.2)<.00001,"Release-to-stop distance and time include actual braking")
	meter.reset(Vector3(10,0,0),true);meter.sample(.1,Vector3(10.7,0,0),7.,true,.2)
	check(meter.snapshot().response_95<0.,"Reset during cruise does not invent an acceleration response")
	meter.reset(Vector3.ZERO);meter.sample(.1,Vector3(0,1,0),0.,false,0.)
	check(meter.snapshot().distance==0. and absf(meter.snapshot().vertical_speed-10.)<.00001,"Jump elevation is not horizontal travel")
	meter.reset(Vector3.ZERO)
	var soles:Array=[{"center":Vector3(-.2,0,0),"height":0.,"candidate":true},{"center":Vector3(.2,.2,0),"height":.2,"candidate":false}]
	meter.sample(.1,Vector3.ZERO,0.,false,0.,soles);meter.sample(.1,Vector3.ZERO,0.,false,0.,soles)
	check(meter.snapshot().sole_speed[0]==0. and meter.snapshot().sole_speed[1]<0.,"Candidate sole drift distinguishes stationary support from an airborne foot")
	soles[0].center+=Vector3(.05,0,0);meter.sample(.1,Vector3.ZERO,0.,false,0.,soles)
	check(absf(meter.snapshot().sole_speed[0]-.5)<.00001,"World-space sole movement is measured, not declared foot locking")
	print("SABRE_MOVEMENT_METER ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
