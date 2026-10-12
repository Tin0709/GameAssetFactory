extends "res://scenes/dev/expressive_jump_review.gd"

var gameplay_camera:=true
var camera_ground_y:=0.0

func _ready() -> void:
	review_player_scene="res://scenes/dev/ExpressiveDirectionalPlayer.tscn"
	jump_review_note="Jump V2 test baseline approved"
	review_title="DIRECTIONAL MOVEMENT · TEST"
	super._ready()
	if jump_enabled and not "--expressive-pace-1" in OS.get_cmdline_user_args() and not "--expressive-pace-2" in OS.get_cmdline_user_args():
		actor.review_pace=2.25;actor.visual.review_pace=2.25
	if jump_enabled and "--expressive-pace-1_5" in OS.get_cmdline_user_args():actor.review_pace=1.5;actor.visual.review_pace=1.5
	if jump_enabled and "--expressive-pace-2_25" in OS.get_cmdline_user_args():actor.review_pace=2.25;actor.visual.review_pace=2.25
	if jump_enabled and "--expressive-direction-original" in OS.get_cmdline_user_args():actor.visual.directional_enabled=false
	if jump_enabled and "--expressive-fall-original" in OS.get_cmdline_user_args():actor.visual.fall_wave_enabled=false
	if jump_enabled and "--expressive-stride-original" in OS.get_cmdline_user_args():actor.visual.run_stride_scale=1.0
	if jump_enabled and "--expressive-polish-before" in OS.get_cmdline_user_args():actor.visual.polish_enabled=false
	if jump_enabled and "--expressive-turn-pivot-original" in OS.get_cmdline_user_args():actor.visual.turn_twist_guard_enabled=false
	if jump_enabled and "--expressive-run-release-original" in OS.get_cmdline_user_args():actor.visual.run_release_enabled=false
	if jump_enabled and "--expressive-run-orbit-original" in OS.get_cmdline_user_args():actor.visual.run_orbit_enabled=false
	if jump_enabled and "--expressive-jump-original" in OS.get_cmdline_user_args():
		actor.jump_flight_speed=1.0;actor.jump_height=1.2
	if jump_enabled and "--expressive-jump-quicker-v1" in OS.get_cmdline_user_args():
		actor.jump_flight_speed=1.18;actor.jump_height=1.2
	if jump_enabled and "--expressive-jump-snappier-v2" in OS.get_cmdline_user_args():
		actor.jump_flight_speed=1.4;actor.jump_height=1.35
	if jump_enabled and "--expressive-jump-2m-previous" in OS.get_cmdline_user_args():
		actor.jump_flight_speed=1.7;actor.jump_height=2.0
	if jump_enabled and "--expressive-polish-demo" in OS.get_cmdline_user_args():call_deferred("run_polish_demo")
	if jump_enabled and "--expressive-quicker-demo" in OS.get_cmdline_user_args():call_deferred("run_quicker_demo")

func _button(label: String) -> void:
	if label in ["Front","3/4","Side"]:gameplay_camera=false
	if jump_enabled and label=="Compare pace":
		actor.review_pace=1.0 if actor.review_pace>=2.25 else (1.5 if actor.review_pace<1.5 else 2.25)
		actor.visual.pose_dirty=true;actor.visual.run_release_active=[false,false]
		return
	super._button(label)

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if jump_enabled and event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_V:
		actor.visual.directional_enabled=not actor.visual.directional_enabled;actor.visual.pose_dirty=true
	if jump_enabled and event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_F:
		actor.visual.fall_wave_enabled=not actor.visual.fall_wave_enabled;actor.visual.pose_dirty=true
	if jump_enabled and event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_G:
		actor.visual.run_stride_scale=1.0 if actor.visual.run_stride_scale>1.0 else 1.2;actor.visual.pose_dirty=true
	if jump_enabled and event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_K:
		actor.visual.polish_enabled=not actor.visual.polish_enabled;actor.visual.pose_dirty=true
	if jump_enabled and event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_J:
		actor.jump_flight_speed=1.7 if actor.jump_flight_speed>1.8 else (1.4 if actor.jump_flight_speed>1.5 else (1.18 if actor.jump_flight_speed>1.3 else (1.0 if actor.jump_flight_speed>1.0 else 1.9)))
		actor.jump_height=2.0 if actor.jump_flight_speed>1.5 else (1.35 if actor.jump_flight_speed>1.3 else 1.2)
	if event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_C:
		gameplay_camera=not gameplay_camera
	if event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_P:
		actor.visual.turn_twist_guard_enabled=not actor.visual.turn_twist_guard_enabled
	if event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_O:
		actor.visual.run_release_enabled=not actor.visual.run_release_enabled
		actor.visual.pose_dirty=true;actor.visual.run_release_active=[false,false]
	if event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_N:
		actor.visual.run_orbit_enabled=not actor.visual.run_orbit_enabled
		actor.visual.pose_dirty=true;actor.visual.run_release_active=[false,false]

func _update_camera(delta: float) -> void:
	if not gameplay_camera:
		camera.size=5.3;super._update_camera(delta);return
	if actor.is_on_floor() and actor.jump_state!="AIR":
		camera_ground_y=lerpf(camera_ground_y,actor.global_position.y,1.0-exp(-delta/.16))
	camera.size=12.5;camera.far=72.0
	camera.position=Vector3(actor.global_position.x,camera_ground_y,actor.global_position.z)+Vector3(12,15,16)
	camera.rotation_degrees=Vector3(-36.315886,36.869898,0)

func _process(delta: float) -> void:
	super._process(delta)
	if jump_enabled:status.text+="\nTurns: %s · V compares\nFalling limbs: %s · F compares\nRun stride: %s · G compares"%["Refined" if actor.visual.directional_enabled else "Original","Raised wave" if actor.visual.fall_wave_enabled else "Original","Longer" if actor.visual.run_stride_scale>1.0 else "Original"]
	if jump_enabled:status.text+="\nPolish: %s · K before/after · T pace"%["After" if actor.visual.polish_enabled else "Before"]
	if jump_enabled:status.text+="\nJump: %s · J compares next launch"%["2m extra snappy" if actor.jump_flight_speed>1.8 else ("2m previous" if actor.jump_flight_speed>1.5 else ("1.35m snappy" if actor.jump_flight_speed>1.3 else ("Quicker V1" if actor.jump_flight_speed>1.0 else "Original")))]
	if jump_enabled:status.text+="\nCamera: %s · C gameplay/detail"%["Gameplay" if gameplay_camera else "Detail"]
	if jump_enabled:status.text+="\nLeg pivot: %s · P compares"%["Clean" if actor.visual.turn_twist_guard_enabled else "Previous"]
	if jump_enabled:status.text+="\nRun liftoff: %s · O compares"%["Smooth" if actor.visual.run_release_enabled else "Previous"]
	if jump_enabled:status.text+="\nRun foot arc: %s · N compares"%["Rounded" if actor.visual.run_orbit_enabled else "Previous"]

func run_quicker_demo() -> void:
	demo_running=true;actor.scripted_input=true
	for mode in ["Stationary","Walk","Run"]:
		actor.requested_direction=Vector2.ZERO;actor.requested_run=false;reset_actor();actor.position.x=-12
		camera_offset=Vector3(6,1.5,0) if mode=="Walk" else Vector3(4,3.1,5)
		await tick(35,"%s · preserved ready posture"%mode)
		actor.requested_direction=Vector2.ZERO if mode=="Stationary" else Vector2(0,1);actor.requested_run=mode=="Run"
		await tick(35,"%s · approach at current locomotion pace"%mode)
		actor.request_jump();await tick(140,"%s · quicker physics flight / original impact timing"%mode)
		actor.requested_direction=Vector2.ZERO;await tick(35,"Stable recovery")
	demo_running=false;actor.scripted_input=false
	if "--expressive-quicker-demo" in OS.get_cmdline_user_args():get_tree().quit()

func run_polish_demo() -> void:
	demo_running=true;actor.scripted_input=true;reset_actor();actor.position.x=-12
	for pace in [2.25,1.5]:
		actor.requested_direction=Vector2.ZERO;actor.requested_run=false
		reset_actor();actor.position.x=-12
		actor.review_pace=pace
		camera_offset=Vector3(4,3.1,5)
		await tick(30,"Idle1x · candidate%.2fx / accepted1.5x comparison"%pace)
		for sprint in [false,true]:
			actor.requested_direction=Vector2(0,1);actor.requested_run=sprint
			await tick(45,"%s%.2fx · approach"%["Run" if sprint else "Walk",pace])
			for heading in [90,270]:
				var angle:=deg_to_rad(heading);actor.requested_direction=Vector2(sin(angle),cos(angle))
				await tick(50,"%s%.2fx · sharp%d degree turn"%["Run" if sprint else "Walk",pace,90 if heading==90 else 180])
			actor.requested_direction=Vector2.ZERO;await tick(35,"Responsive stop / support recovery")
		camera_offset=Vector3(6,1.5,0);actor.requested_run=true;actor.requested_direction=Vector2(0,1)
		await tick(60,"Side · longer stride / quieter Run body")
		actor.request_jump();await tick(20,"Jump · live physics")
		actor.requested_direction=Vector2(-1,0);await tick(90,"Turning jump / heavy contact back into Run")
		actor.requested_direction=Vector2.ZERO;await tick(40,"Settle before weapon review")
		actor.set_review_weapon(true);await tick(25,"Rifle equip · independent upper-body clock")
		for view in [["Front",Vector3(0,1.5,6)],["Three-quarter",Vector3(4,3.1,5)],["Side",Vector3(6,1.5,0)]]:
			camera_offset=view[1];actor.review_drop(6)
			await tick(30,"%s · rifle carry during fall"%view[0])
			actor.set_review_weapon(false);await tick(90,"%s · release to wider flutter / natural landing"%view[0])
			actor.set_review_weapon(true);await tick(25,"Weapon recovery · no gait-paced arm reset")
		actor.set_review_weapon(false);await tick(30,"Return to relaxed Idle1x")
		camera_offset=Vector3(4,3.1,5);actor.review_drop(6)
		await tick(120,"Unarmed · full above-head waves / wider flutter / natural contact")
	actor.scripted_input=false;demo_running=false;section="Manual review"
	if "--expressive-polish-demo" in OS.get_cmdline_user_args():get_tree().quit()

func run_demo() -> void:
	if not jump_enabled:super.run_demo();return
	demo_running=true;actor.scripted_input=true;reset_actor()
	actor.position.x=-8
	await tick(35,"Approved Idle1x · directional test Pending")
	for sprint in [false,true]:
		actor.requested_direction=Vector2(0,1);actor.requested_run=sprint
		await tick(55,"Run approach" if sprint else "Walk approach")
		for pair in [[45,45],[135,90],[315,180]]:
			var radians:=deg_to_rad(float(pair[0]));actor.requested_direction=Vector2(sin(radians),cos(radians))
			await tick(55,"%s · %d degree direction change"%["Run" if sprint else "Walk",pair[1]])
		actor.requested_direction=Vector2.ZERO;await tick(45,"Stop · individual support recovery")
	camera_offset=Vector3(6,1.5,0)
	actor.requested_direction=Vector2(0,1);actor.requested_run=true;await tick(40,"Side · Run to turning jump")
	actor.request_jump();await tick(20,"Jump · physics-driven launch")
	actor.requested_direction=Vector2(1,0);await tick(95,"90 degree airborne turn · heavy landing into Run")
	actor.requested_direction=Vector2.ZERO;await tick(45,"Planted recovery")
	camera_offset=Vector3(0,1.5,6)
	actor.requested_direction=Vector2(0,1);await tick(40,"Front · running reversal")
	actor.requested_direction=Vector2(0,-1);await tick(65,"180 degree Run reversal · responsive control")
	actor.request_jump();await tick(20,"Reversal jump · launch")
	actor.requested_direction=Vector2(0,1);await tick(95,"180 degree airborne reversal · live landing gait")
	actor.requested_direction=Vector2.ZERO;await tick(55,"Recover to normal Idle")
	camera_offset=Vector3(6,1.5,0);actor.requested_direction=Vector2(0,1);actor.requested_run=true
	await tick(90,"Side · longer reaching Run stride · close leg tracks")
	camera_offset=Vector3(4,3.1,5);await tick(90,"Three-quarter · expressive Run at requested pace")
	actor.requested_direction=Vector2.ZERO;await tick(30,"Controlled stop before falling review")
	for view in [["Front",Vector3(0,1.5,6)],["Three-quarter",Vector3(4,3.1,5)],["Side",Vector3(6,1.5,0)]]:
		camera_offset=view[1];actor.requested_run=false;actor.review_drop(6)
		await tick(120,"%s · falling hands above head · staggered waves"%view[0])
	actor.scripted_input=false;demo_running=false;section="Manual review"
	if "--expressive-demo" in OS.get_cmdline_user_args():get_tree().quit()
