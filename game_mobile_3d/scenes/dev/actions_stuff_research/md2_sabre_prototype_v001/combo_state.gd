extends RefCounted
## Optional private source-event policy, with authored fallback. The220ms
## input buffer remains an adapter; native timing is validated against clips.
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
var movement_breaks_enabled:=false
var movement_requested:=false
var step_serial:=0
var step_next_index:=0
var step_buffered:=false
var serial:=0
var _impact_sent:=false
var _events:Array[Dictionary]=[]
var native_enabled:=false
var native_windows:Array=[]
var native_input_policy:="legacy_buffer"
var native_event_hz:=0.
var native_air_interrupt:=false

func configure_native(config:Variant)->bool:
	native_enabled=false;native_windows=[];native_input_policy="legacy_buffer";native_event_hz=0.;native_air_interrupt=false
	if not config is Dictionary or config.get("schema")!="md2-private-sabre-combat/1" or not config.get("windows") is Array or config.windows.size()!=3:return false
	for i in 3:
		var w:Variant=config.windows[i]
		if not w is Dictionary:return false
		for key in ["rate","resume","chain","attack_duration","recovery_duration","melee"]:
			var value:Variant=w.get(key)
			if not (value is float or value is int) or not is_finite(float(value)) or float(value)<=0.:return false
		if w.resume>=w.chain or w.chain>w.attack_duration or w.melee>w.attack_duration:return false
		for key:String in ["attack_key","recovery_key"]:
			if w.has(key) and (not w[key] is String or String(w[key]).is_empty()):return false
		var attack_key:String=w.get("attack_key","Attack%d"%(i+1));var recovery_key:String=w.get("recovery_key","Recovery%d"%(i+1))
		if not clips.has(attack_key) or not clips.has(recovery_key):return false
		if clips[attack_key].get("source_name")!=w.get("attack_source") or clips[recovery_key].get("source_name")!=w.get("recovery_source"):return false
	var input:Variant=config.get("input")
	if input!=null:
		if not input is Dictionary or input.get("ground_policy")!="live_hold":return false
		if input.has("airborne_press_interrupts_ground") and not input.airborne_press_interrupts_ground is bool:return false
		var hz:Variant=input.get("event_evaluation_hz")
		if not (hz is float or hz is int) or not is_finite(float(hz)) or float(hz)<=0. or float(hz)>1000.:return false
		native_input_policy="live_hold"
		native_event_hz=float(hz)
		native_air_interrupt=bool(input.get("airborne_press_interrupts_ground",false))
	native_windows=config.windows.duplicate(true);native_enabled=true;return true

func movement_allowed()->bool:
	return not active() or (native_enabled and (phase==&"recovery" or (phase==&"attack" and time>=float(native_windows[index].resume)-.00000001)))

func chain_source_gate()->float:
	var source:float=native_windows[index].chain
	if native_event_hz<=0.:return source
	# Notify delivery is discrete; retain the original pose/source clock.
	var rate:float=native_windows[index].rate
	return ceilf(source/rate*native_event_hz-.0000001)/native_event_hz*rate

func boundary_seconds()->float:
	if not active():return INF
	var boundary:=remaining()
	if native_enabled and phase==&"attack":
		var w:Dictionary=native_windows[index]
		if time<float(w.resume)-.00000001:boundary=minf(boundary,float(w.resume)-time)
		var chain:=chain_source_gate()
		if _queued() and time<chain-.00000001:boundary=minf(boundary,chain-time)
	return boundary/playback_rate()

func _queued()->bool:return held or (native_input_policy!="live_hold" and buffer_until>=clock-.0000001)

func _resolve_native()->void:
	if native_enabled and phase in [&"attack",&"recovery"] and _queued():
		if phase==&"recovery" or time>=chain_source_gate()-.00000001:_start_attack((index+1)%3)

func movement_plan(delta:float)->Array[Dictionary]:
	# Forecast with the SAME state machine. No real clock/input/event mutation.
	var copy=get_script().new();copy.clips=clips;copy.native_windows=native_windows;copy.native_enabled=native_enabled;copy.native_input_policy=native_input_policy;copy.native_event_hz=native_event_hz;copy.native_air_interrupt=native_air_interrupt
	for key in ["phase","index","time","clock","held","buffer_until","buffer_seconds","attack_play_rates","air_attack_play_rate","movement_breaks_enabled","movement_requested","step_serial","step_next_index","step_buffered","serial","_impact_sent"]:copy.set(key,get(key))
	var result:Array[Dictionary]=[];var left:=maxf(0.,delta)
	while left>0.:
		copy._resolve_native()
		var dt:=minf(left,maxf(.00000001,copy.boundary_seconds()))
		result.append({"duration":dt,"move":copy.movement_allowed(),"phase":copy.phase,"index":copy.index,"time":copy.time,"serial":copy.serial})
		copy.advance(dt);left-=dt
	return result

func setup(entries:Dictionary)->void:clips=entries
func clip()->String:
	if native_enabled and phase in [&"attack",&"recovery"]:return native_windows[index].get("attack_key" if phase==&"attack" else "recovery_key",("Attack%d" if phase==&"attack" else "Recovery%d")%(index+1))
	if phase==&"attack":return "Attack%d"%(index+1)
	if phase==&"recovery":return "Recovery%d"%(index+1)
	if phase==&"air_attack":return "AirAttack"
	return "CombatReady"
func active()->bool:return phase not in [&"ready",&"step"]
func playback_rate()->float:
	if phase==&"air_attack":return maxf(.001,air_attack_play_rate)
	if native_enabled and phase in [&"attack",&"recovery"]:return float(native_windows[index].rate)
	return maxf(.001,float(attack_play_rates[index])) if phase==&"attack" else 1.
func remaining()->float:
	if native_enabled and phase in [&"attack",&"recovery"]:return maxf(0.,float(native_windows[index]["attack_duration" if phase==&"attack" else "recovery_duration"])-time)
	return maxf(0.,float(clips[clip()].duration)-time) if active() else INF
func attack(value:bool,airborne:bool=false)->void:
	var edge:=value and not held
	held=value
	if edge:request_attack(airborne)
func request_attack(airborne:bool=false)->void:
	# An evidenced fresh aerial press is a different action, not a pending
	# ground combo link. Do not reject it behind the ground RecoveryStart gate.
	if native_enabled and native_air_interrupt and airborne and phase in [&"attack",&"recovery"]:
		_start_attack(0,true);return
	if native_enabled and native_input_policy=="live_hold" and phase in [&"attack",&"recovery"]:
		# Captured grounded presses are not stored across an active ability.
		# Held input is sampled at RecoveryStart; a fresh later edge is immediate.
		if phase==&"recovery" or time>=chain_source_gate()-.00000001:_start_attack((index+1)%3)
		return
	if phase==&"step" and airborne:_start_attack(0,true)
	elif phase==&"step":step_buffered=true
	elif not active():_start_attack(0,airborne)
	else:buffer_until=clock+buffer_seconds
func _start_attack(which:int,airborne:bool=false)->void:
	phase=&"air_attack" if airborne else &"attack";index=which;time=0.;serial+=1
	buffer_until=-1.;step_buffered=false;_impact_sent=false
	_events.append({"kind":"accepted","index":index,"serial":serial,"clip":clip(),"at":clock})
func _finish()->void:
	var queued:=_queued() if native_enabled else held or buffer_until>=clock-.0000001
	if phase==&"air_attack":phase=&"ready";time=0.;buffer_until=-1.;return
	if native_enabled:
		if queued:_start_attack((index+1)%3)
		elif phase==&"attack":phase=&"recovery";time=0.
		else:phase=&"ready";time=0.;buffer_until=-1.
		return
	if phase==&"attack":
		if movement_breaks_enabled and movement_requested and queued:
			phase=&"step";time=0.;step_serial+=1;step_next_index=(index+1)%3
			step_buffered=buffer_until>=clock-.0000001;buffer_until=-1.
		elif index<2 and queued:_start_attack(index+1)
		else:phase=&"recovery";time=0.
	elif phase==&"recovery":
		if queued:_start_attack(index+1 if index<2 else 0)
		else:phase=&"ready";time=0.;buffer_until=-1.
func finish_step()->void:
	if phase!=&"step":return
	if held or step_buffered:_start_attack(step_next_index)
	else:phase=&"ready";time=0.;buffer_until=-1.
func advance(delta:float)->void:
	_resolve_native()
	if active() and remaining()<=.00000001:_finish();_resolve_native()
	var left:=maxf(delta,0.)
	while left>0.:
		if not active():clock+=left;return
		var rate:=playback_rate()
		var segment:=minf(left,boundary_seconds())
		if segment<=0.:_finish();_resolve_native();continue
		var previous:=time
		time+=segment*rate;clock+=segment;left-=segment
		if phase in [&"attack",&"air_attack"] and not _impact_sent:
			var gate:float=clips[clip()].vfx_window[0]
			if native_enabled and phase==&"attack":gate=float(native_windows[index].melee)
			if previous<=gate and time>=gate:
				_impact_sent=true;_events.append({"kind":"impact","index":index,"serial":serial,"clip":clip(),"at":clock-(time-gate)/rate})
		if remaining()<=.00000001:_finish()
		_resolve_native()
func drain_events()->Array[Dictionary]:
	var result:=_events;_events=[];return result
func release_inputs()->void:
	held=false;buffer_until=-1.
	if phase==&"step":cancel()
func cancel()->void:
	phase=&"ready";index=0;time=0.;held=false;buffer_until=-1.;step_buffered=false;_impact_sent=false;_events.clear()
