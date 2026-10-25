extends RefCounted
## Original gameplay clock. No imported reference motion or global time scaling.
var state:StringName=&"ready"
var attack_index:=0
var serial:=0
var clock:=0.
var time:=0.
var previous_time:=0.
var buffered_until:=-1.
var buffer_seconds:=.22
var guard_held:=false
var guard_pressed_at:=-100.
var parry_window:=.18
var parry_ready_at:=0.
var parry_armed:=false
var roll_ready_at:=0.
var hurt_duration:=.4
var durations:=PackedFloat32Array([.60,.50,.90])
var active_start:=PackedFloat32Array([.265,.165,.265])
var active_end:=PackedFloat32Array([.36,.28,.39])
var chain_open:=PackedFloat32Array([.47,.36,.76])
func enter(next:StringName)->void:
	state=next;time=0.;previous_time=0.;serial+=1
func start_attack(index:int)->void:
	attack_index=index;buffered_until=-1.;enter(&"attack")
func request_attack()->bool:
	if state==&"ready" or state==&"guard":
		guard_held=false;start_attack(0);return true
	if state==&"attack":buffered_until=clock+buffer_seconds;return true
	return false
func request_guard(held:bool)->void:
	if held and not guard_held:
		guard_pressed_at=clock;parry_armed=clock>=parry_ready_at
		if parry_armed:parry_ready_at=clock+.65
	guard_held=held
	if held and state==&"ready":enter(&"guard")
	elif not held and state==&"guard":enter(&"ready")
func request_roll()->bool:
	if clock<roll_ready_at or state==&"roll" or state==&"hurt":return false
	if state==&"attack" and time<chain_open[attack_index]:return false
	buffered_until=-1.;roll_ready_at=clock+.95;enter(&"roll");return true
func can_parry()->bool:
	return state==&"guard" and parry_armed and clock-guard_pressed_at<=parry_window
func parried()->void:
	parry_armed=false;enter(&"parry")
func invulnerable()->bool:return state==&"roll" and time>=.075 and time<=.43
func has_buffer()->bool:return buffered_until>=clock
func overlaps_active()->bool:
	return state==&"attack" and time>=active_start[attack_index] and previous_time<=active_end[attack_index] and time>previous_time
func hurt(seconds:float=.4)->void:
	buffered_until=-1.;hurt_duration=seconds;enter(&"hurt")
func cancel()->void:
	buffered_until=-1.;guard_held=false;parry_armed=false;enter(&"ready")
func reset()->void:
	clock=0.;roll_ready_at=0.;parry_ready_at=0.;cancel()
func tick(delta:float,rate:float,paused:bool=false)->void:
	clock+=delta;previous_time=time
	if paused:return
	time+=delta*(rate if state==&"attack" else 1.)
	if state==&"attack" and time+.000001>=durations[attack_index]:
		if attack_index<2 and has_buffer():start_attack(attack_index+1)
		else:enter(&"guard" if guard_held else &"ready")
	elif state==&"roll" and time>=.72:enter(&"guard" if guard_held else &"ready")
	elif state==&"parry" and time>=.32:enter(&"guard" if guard_held else &"ready")
	elif state==&"hurt" and time>=hurt_duration:enter(&"guard" if guard_held else &"ready")
