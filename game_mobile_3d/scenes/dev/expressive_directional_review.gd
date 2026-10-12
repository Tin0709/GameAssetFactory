extends "res://scenes/dev/expressive_jump_review.gd"

func _ready() -> void:
	review_player_scene="res://scenes/dev/ExpressiveDirectionalPlayer.tscn"
	jump_review_note="Jump V2 test baseline approved"
	review_title="DIRECTIONAL MOVEMENT · TEST"
	super._ready()
	if jump_enabled and not "--expressive-pace-1" in OS.get_cmdline_user_args() and not "--expressive-pace-2" in OS.get_cmdline_user_args():
		actor.review_pace=2.25;actor.visual.review_pace=2.25
	if jump_enabled and "--expressive-pace-1_5" in OS.get_cmdline_user_args():actor.review_pace=1.5;actor.visual.review_pace=1.5
	if jump_enabled and "--expressive-direction-original" in OS.get_cmdline_user_args():actor.visual.directional_enabled=false
	if jump_enabled and "--expressive-fall-original" in OS.get_cmdline_user_args():actor.visual.fall_wave_enabled=false

func _button(label: String) -> void:
	if jump_enabled and label=="Compare pace":
		actor.review_pace=1.0 if actor.review_pace>=2.25 else (1.5 if actor.review_pace<1.5 else 2.25)
		return
	super._button(label)

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if jump_enabled and event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_V:
		actor.visual.directional_enabled=not actor.visual.directional_enabled;actor.visual.pose_dirty=true
	if jump_enabled and event.is_pressed() and not event.is_echo() and event.physical_keycode==KEY_F:
		actor.visual.fall_wave_enabled=not actor.visual.fall_wave_enabled;actor.visual.pose_dirty=true

func _process(delta: float) -> void:
	super._process(delta)
	if jump_enabled:status.text+="\nTurns: %s · V compares\nFalling arms: %s · F compares"%["Refined" if actor.visual.directional_enabled else "Original","Raised wave" if actor.visual.fall_wave_enabled else "Original"]

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
	for view in [["Front",Vector3(0,1.5,6)],["Three-quarter",Vector3(4,3.1,5)],["Side",Vector3(6,1.5,0)]]:
		camera_offset=view[1];actor.requested_run=false;actor.review_drop(6)
		await tick(120,"%s · falling hands above head · staggered waves"%view[0])
	actor.scripted_input=false;demo_running=false;section="Manual review"
	if "--expressive-demo" in OS.get_cmdline_user_args():get_tree().quit()
