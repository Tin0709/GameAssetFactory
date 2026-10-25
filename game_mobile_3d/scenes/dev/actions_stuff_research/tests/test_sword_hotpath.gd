extends SceneTree
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	if not value and not failures.has(label):failures.append(label);push_error(label)
func run()->void:
	var s=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();s.grass_field_enabled=false;s.md2_lighting_enabled=false;s.sword_private_reference_enabled=false;root.add_child(s);s.player.scripted_input=true
	for z in s.zombie_combat.zombies:z.target=null;z.move_speed=0.
	for i in 8:await physics_frame
	var c=s.sword_combat;c.set_equipped(true)
	var original_runtime:RefCounted=s.player.visual.stationary_turn.runtime
	c.attack(true);c.attack(false)
	for i in 12:
		var yaw:float=s.player.visual.rotation.y
		await physics_frame
		check(s.player.visual.stationary_turn.runtime==original_runtime,"Sword tick must reuse compiled turn runtime")
		check(absf(wrapf(s.player.visual.rotation.y-yaw,-PI,PI))<=16./Engine.physics_ticks_per_second+.00001,"Combat heading advances only once per tick")
	c.state.cancel();c.roll()
	var phase:float=s.player.visual.direction_snapshot.phase
	for i in 12:await physics_frame
	check(absf(float(s.player.visual.direction_snapshot.phase)-phase)<.00001,"Dodge travel must preserve locomotion phase")
	c.rifle_button.pressed.emit();check(not c.equipped and c.rifle_button.button_pressed and not c.sword_button.button_pressed,"Rifle UI selects Rifle")
	c.sword_button.pressed.emit();check(c.equipped and c.sword_button.button_pressed and not c.rifle_button.button_pressed,"Sword UI selects Sword")
	c.state.cancel();c.guard(true)
	for i in 5:await physics_frame
	c.set_equipped(false);s.player.requested_direction=Vector2.RIGHT
	for i in Engine.physics_ticks_per_second:await physics_frame
	check(absf(wrapf(s.player.visual.rotation.y-PI*.5,-PI,PI))<.1,"Rifle movement facing recovers after switching out of Guard")
	s.player.requested_direction=Vector2.ZERO;c.set_equipped(true)
	c.state.start_attack(0);c.state.time=.50;check(not c.locks_jump(),"Recovery permits jump interruption")
	c.knockout=.9;c.state.cancel();check(c.locks_jump(),"Knockout cannot jump after Hurt pose ends")
	print("SWORD_HOTPATH ",JSON.stringify({"failures":failures}));s.free();quit(0 if failures.is_empty() else 1)
