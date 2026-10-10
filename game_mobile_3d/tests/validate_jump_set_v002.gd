extends SceneTree
var failures: Array[String] = []
var checks: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok: failures.append(message); push_error(message)
func tick(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	var level: Node=load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(level); current_scene=level; await tick(10)
	var player=level.player
	for name in ["Jump_Stationary_v002","Jump_Walk_v002","Jump_Run_v002"]:
		check(player.visual.samples.has(name),"V002 authored clip loaded: "+name)
	# Each state selects a different authored Action once, at supported takeoff.
	player.get_node("WeaponBehavior").enabled=false
	for kind in ["stationary","walk","run"]:
		level.reset_player();await tick(5)
		if kind!="stationary":Input.action_press("move_right")
		if kind=="run":Input.action_press("sprint")
		await tick(8)
		var ground_y:float=player.position.y
		check(player.request_jump(),kind+" starts on support")
		check(String(player.jump_kind)==kind,kind+" selected from current input")
		check(player.visual.jump_pose.clip==player.visual.samples[player.jump_profile.action].clip,kind+" uses its own authored Action")
		var peak:float=player.position.y
		for i in 15:
			await tick(1);peak=maxf(peak,player.position.y)
		# Changing travel intent in the air cannot switch the active Action.
		Input.action_release("sprint");Input.action_release("move_right")
		check(String(player.jump_kind)==kind,kind+" remains locked through flight")
		for i in 50:
			await tick(1);peak=maxf(peak,player.position.y)
		check(absf(peak-ground_y-(.64 if kind=="run" else .58))<.03,kind+" ballistic height matches source within 3cm")
		check(player.is_on_floor() and not player.jump_active,kind+" completes contact and recovery")
	level.reset_player();await tick(5)
	Input.action_press("jump");await tick(130)
	check(not player.jump_active,"Holding Space while stationary remains a single jump")
	Input.action_release("jump");await tick(2)
	Input.action_press("move_right");Input.action_press("sprint");await tick(12)
	Input.action_press("jump")
	var starts:=0;var was_active:=false;var air:=false;var supported_starts:=true
	var starts_at:Array[int]=[];var contact_frames:=0;var contact_recovery:=true;var previous_time:=0.0
	for i in 180:
		await tick(1)
		if player.jump_active and (not was_active or player.jump_time<previous_time-.01):
			starts+=1;starts_at.append(Engine.get_physics_frames()-roundi(player.jump_time*Engine.physics_ticks_per_second));supported_starts=supported_starts and player.is_on_floor()
			if starts>1:contact_recovery=contact_recovery and contact_frames>0 and Engine.get_physics_frames()-contact_frames>=10
			contact_frames=0
		if player._landed and contact_frames==0:contact_frames=Engine.get_physics_frames()
		if not player.is_on_floor():air=true
		was_active=player.jump_active;previous_time=player.jump_time
	check(starts>=3 and air,"Holding Space while running repeats grounded jumps")
	check(supported_starts,"Every repeated jump starts supported after recovery")
	check(contact_recovery,"Repeat preserves at least 10 physics ticks of contact/recovery")
	var regular:=true
	for i in range(2,starts_at.size()):regular=regular and abs((starts_at[i]-starts_at[i-1])-(starts_at[1]-starts_at[0]))<=1
	check(regular,"Flat-ground repeat cadence varies by no more than one physics tick")
	Input.action_release("jump")
	await tick(90);check(not player.jump_active,"Releasing Space while still running stops repeat")
	Input.action_release("move_right");Input.action_release("sprint")
	level.reset_player();await tick(5)
	Input.action_press("move_right");Input.action_press("sprint");Input.action_press("jump");await tick(15)
	Input.action_release("sprint");await tick(100)
	check(not player.jump_active,"Releasing sprint prevents repeat even with Space and movement held")
	Input.action_release("jump");Input.action_release("move_right")
	var tag:="runtime"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):tag=arg.trim_prefix("--report=")
	FileAccess.open("res://.validation/jump_set_v002/checks_"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"start_physics_frames":starts_at,"physics_hz":Engine.physics_ticks_per_second},"\t"))
	print("JUMP_SET_CHECKS ",checks.size()," failures=",failures)
	level.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
