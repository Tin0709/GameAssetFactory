extends SceneTree
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if not ok and not failures.has(label):failures.append(label);push_error(label)
func ticks(n:int)->void:
	for i in n:await physics_frame
	await process_frame
func run()->void:
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate()
	scene.grass_field_enabled=false;scene.md2_lighting_enabled=false;scene.sword_private_reference_enabled=false
	root.add_child(scene);await ticks(6)
	var driver=scene.get("sword_combat")
	check(driver!=null,"Existing lab contains playable Sword controller")
	if driver==null:scene.free();quit(1);return
	scene.player.scripted_input=true
	var zombies:Array=scene.zombie_combat.zombies
	for i in zombies.size():
		zombies[i].target=null;zombies[i].move_speed=0.;zombies[i].chasing=false;zombies[i].position=Vector3(20+i,0,20)
	driver.set_equipped(true);await ticks(8)
	check(scene.player.visual.sword_model.visible and not scene.player.visual.rifle_model.visible,"New Blender Sword equips and Rifle hides")
	check(scene.player.visual.sword_profile.sword_asset.contains("Sword_Sand_Block_V1"),"Uses requested new sword asset")
	var original_nodes:int=driver.effects.get_child_count()
	driver.state.request_attack();await ticks(Engine.physics_ticks_per_second)
	check(driver.hits==0 and driver.freeze_remaining==0.,"Whiff deals no damage and no hit-stop")
	var z=zombies[0];z.position=scene.player.global_position+Vector3(0,0,1.05);z.current_hp=1000
	driver.state.cancel();driver._seen_serial=-1;driver.state.request_attack()
	await ticks(Engine.physics_ticks_per_second)
	check(driver.hits==1 and z.current_hp==983,"Actual swept blade accepts exactly one hit per swing")
	var count:int=driver.hits
	await ticks(10);check(driver.hits==count,"Recovery cannot deal ghost damage")
	for i in range(1,4):zombies[i].position=Vector3((i-2)*.30,0,1.2);zombies[i].current_hp=1000
	driver.state.cancel();driver.attack(true);await ticks(ceili(Engine.physics_ticks_per_second*2.9));driver.attack(false)
	check(driver.swings>=4 and driver.hits>=4,"Held input chains a full combo against multiple targets")
	check(driver.effects.get_child_count()==original_nodes,"Repeated attacks do not allocate effect nodes")
	driver.state.cancel();driver.state.request_guard(true)
	var before:int=driver.vitality;var direction:Vector3=-driver.forward()
	driver.receive_attack(12,direction,z)
	check(driver.parries==1 and driver.vitality==before and z.stagger_remaining>.6,"Timed parry denies damage and staggers exact attacker")
	driver.state.cancel();driver.state.request_guard(true);driver.state.tick(.3,1.)
	driver.receive_attack(12,direction,z)
	check(driver.blocks==1 and driver.stamina<100. and driver.vitality==before,"Late guard blocks at stamina cost")
	driver.state.cancel();driver.state.roll_ready_at=0.;driver.roll();driver.state.time=.12
	driver.receive_attack(12,direction,z);check(driver.vitality==before,"Roll active window denies damage")
	driver.state.time=.6;driver.receive_attack(12,direction,z);check(driver.vitality==before-12,"Roll recovery remains vulnerable")
	driver.state.cancel();driver.state.request_attack();driver.set_equipped(false)
	check(driver.state.state==&"ready" and not driver.state.has_buffer(),"Switch clears buffered/active sword events")
	check(scene.player.visual.rifle_model.visible and not scene.player.visual.sword_model.visible,"Rifle is restored")
	scene._fire_key_held=true;scene._sync_rifle_controls();check(scene.rifle_fire.trigger_held,"Approved E-fire available after switch")
	scene._fire_key_held=false;scene._sync_rifle_controls()
	scene.reset_player();check(driver.hits==0 and driver.stamina==100. and driver.effects.active_count()==0,"Reset clears combat and pooled effects");await ticks(3)
	var result:={"failures":failures,"physics_hz":Engine.physics_ticks_per_second,"sword_hits":count,"pool_children":original_nodes}
	print("SWORD_COMBAT_CHECKS ",JSON.stringify(result));scene.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
