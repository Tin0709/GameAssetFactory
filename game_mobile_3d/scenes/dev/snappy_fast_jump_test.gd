extends "res://scenes/dev/snappy_locomotion_test.gd"
var camera_ground_y:=0.0
var _demo_previous_time:=0.0
func _ready() -> void:
	review_player_scene_path="res://scenes/dev/SnappyLocomotionFastJumpPlayer.tscn"
	super._ready()
	get_window().title="Snappy Locomotion - Fast + Jump Gameplay Test"
	var panel:=status.get_parent()
	panel.get_child(0).text="SNAPPY FAST + JUMP · A/B"
	panel.custom_minimum_size.x=420
	status.custom_minimum_size.x=420;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	panel.get_child(2).custom_minimum_size.x=420;panel.get_child(2).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	panel.get_child(2).text="WASD / arrows: move   Shift: run   Space: jump   Tab: Snappy / Expressive\nSame Expressive test speed + camera · 1–3: details   4: original camera   R: reset   F9: demo   F8:30/60 FPS"
	var jump_button:=Button.new();jump_button.text="Jump / Space";panel.get_child(3).add_child(jump_button);jump_button.pressed.connect(actor.request_jump)
	var old_buttons: Node=panel.get_child(3);var grid:=GridContainer.new();grid.columns=4;panel.add_child(grid);panel.move_child(grid,3)
	for button in old_buttons.get_children():button.reparent(grid)
	old_buttons.queue_free()
func _button(label: String) -> void:
	if label=="Reset":actor.reset_jump()
	if label=="Demo":_demo_previous_time=0
	super._button(label)
func _update_camera() -> void:
	if camera_mode!=0:
		camera.size=5.3;super._update_camera();return
	# Exact current Expressive test view, including its25m offset and11.25
	# orthographic size. Keep the camera on the floor through ordinary jumps.
	if actor.is_on_floor() and actor.jump_state!="AIR":camera_ground_y=lerpf(camera_ground_y,actor.global_position.y,1-exp(-get_process_delta_time()/.16))
	camera.size=11.25;camera.far=72
	camera.position=Vector3(actor.position.x,camera_ground_y,actor.position.z)+Vector3(12,15,16)
	camera.rotation_degrees=Vector3(-36.315886,36.869898,0)
func _physics_process(delta: float) -> void:
	var previous:=demo_time
	super._physics_process(delta)
	if not demo_running:return
	camera_mode=0
	for event_time in [4.0,7.6]:
		if previous<event_time and demo_time>=event_time:actor.request_jump()
func _process(delta: float) -> void:
	super._process(delta)
	if not telemetry.is_empty():telemetry[-1]["jump_state"]=actor.jump_state;telemetry[-1]["jump_age"]=actor.jump_age
	status.text+="\nJump: %s · existing2m jump · original Expressive camera"%actor.jump_state
