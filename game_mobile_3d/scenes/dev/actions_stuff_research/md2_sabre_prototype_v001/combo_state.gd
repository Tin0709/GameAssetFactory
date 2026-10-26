extends RefCounted
## Authored input adapter. Clip durations come from the new GLB manifest;
## the 220ms buffer and VFX gates are prototype choices, not native notifies.
var clips:Dictionary={}
var phase:StringName=&"ready"
var index:=0
var time:=0.
var clock:=0.
var held:=false
var buffer_until:=-1.
var buffer_seconds:=.22
var attack_play_rates:Array=[1.,1.,1.] # Source profile sets verified table rates.
var air_attack_play_rate:=1. # Optional physics-cadence adapter; not native data.
var serial:=0
var _impact_sent:=false
var _events:Array[Dictionary]=[]

func setup(entries:Dictionary)->void:clips=entries
func clip()->String:
	if phase==&"attack":return "Attack%d"%(index+1)
	if phase==&"recovery":return "Recovery%d"%(index+1)
	if phase==&"air_attack":return "AirAttack"
	return "CombatReady"
func active()->bool:return phase!=&"ready"
func playback_rate()->float:
	if phase==&"air_attack":return maxf(.001,air_attack_play_rate)
	return maxf(.001,float(attack_play_rates[index])) if phase==&"attack" else 1.
func remaining()->float:
	return maxf(0.,float(clips[clip()].duration)-time) if active() else INF
func attack(value:bool,airborne:bool=false)->void:
	var edge:=value and not held
	held=value
	if edge:request_attack(airborne)
func request_attack(airborne:bool=false)->void:
	if not active():_start_attack(0,airborne)
	else:buffer_until=clock+buffer_seconds
func _start_attack(which:int,airborne:bool=false)->void:
	phase=&"air_attack" if airborne else &"attack";index=which;time=0.;serial+=1
	buffer_until=-1.;_impact_sent=false
	_events.append({"kind":"accepted","index":index,"serial":serial,"clip":clip(),"at":clock})
func _finish()->void:
	var queued:=held or buffer_until>=clock-.0000001
	if phase==&"air_attack":phase=&"ready";time=0.;buffer_until=-1.;return
	if phase==&"attack":
		if index<2 and queued:_start_attack(index+1)
		else:phase=&"recovery";time=0.
	elif phase==&"recovery":
		if queued:_start_attack(index+1 if index<2 else 0)
		else:phase=&"ready";time=0.;buffer_until=-1.
func advance(delta:float)->void:
	var left:=maxf(delta,0.)
	while left>.00000001:
		if not active():clock+=left;return
		var rate:=playback_rate()
		var segment:=minf(left,remaining()/rate)
		var previous:=time
		time+=segment*rate;clock+=segment;left-=segment
		if phase in [&"attack",&"air_attack"] and not _impact_sent:
			var gate:float=clips[clip()].vfx_window[0]
			if previous<=gate and time>=gate:
				_impact_sent=true;_events.append({"kind":"impact","index":index,"serial":serial,"clip":clip(),"at":clock-(time-gate)/rate})
		if remaining()<=.00000001:_finish()
func drain_events()->Array[Dictionary]:
	var result:=_events;_events=[];return result
func release_inputs()->void:held=false;buffer_until=-1.
func cancel()->void:
	phase=&"ready";index=0;time=0.;held=false;buffer_until=-1.;_impact_sent=false;_events.clear()
