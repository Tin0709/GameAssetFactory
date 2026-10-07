extends SceneTree
## Natural awareness and real input/movement. Optional every-frame gameplay view.
var level: Node3D
var p: CharacterBody3D
var v: Node3D
var b: Node
var gun: Node3D
var enemy: Node3D
var near := false
var failures: Array[String] = []
var checks := 0
var cases: Array[Dictionary] = []
var rendered := false
var serial := 0
var label := ""
var minimum_draw_speed := 100.0
var shots_drawing := 0
var clock_error := 0.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func ticks(count: int, monitor: bool = false) -> void:
	for i in count:
		enemy.global_position=p.global_position+Vector3(0,0,3 if near else 40)
		var before: float=v.authored_run_time
		var shots: int=gun.shot_count
		var was_drawing: bool=b.state==b.State.DRAWING
		await physics_frame
		if monitor:
			clock_error=maxf(clock_error,absf(wrapf(v.authored_run_time-before-1.6/60,-v.run.clip.length/2,v.run.clip.length/2)))
			if b.state==b.State.DRAWING:
				minimum_draw_speed=minf(minimum_draw_speed,p.current_speed)
				# Existing 2.6 m/s combat cap with a 90-degree accelerated turn
				# reaches ~2.6/sqrt(2), independently of the animation layer.
				check(p.current_speed>1.5,"Actual movement continues through Draw/turn")
				check(not gun.can_fire(),"Actual gun remains gated during Draw")
				if was_drawing: shots_drawing+=gun.shot_count-shots
		if rendered and not label.is_empty():
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.validation/draw_d5_live/%s_%03d.png"%[label,serial]);serial+=1
func release_inputs() -> void:
	for action in ["move_right","move_forward","move_left","move_backward","sprint"]: Input.action_release(action)
func run() -> void:
	rendered="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://.validation/draw_d5_live")
	level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	p=level.player;v=p.visual;b=p.get_node("WeaponBehavior");gun=p.get_node("Pistol")
	level.get_node("HUD").visible=false
	enemy=preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp=100000;level.get_node("Actors").add_child(enemy);enemy.current_hp=100000
	enemy.set_physics_process(false);level.combat.register_zombie(enemy)
	for weapon in [1,2]:
		for phase in [0.0,0.25,0.5,0.75]:
			label=""; near=false; release_inputs(); await ticks(160)
			p.position=Vector3(-2,0.02,-2);p.equip_test_weapon(weapon);gun.cooldown=1000
			Input.action_press("move_right");await ticks(15)
			check(b.state==b.State.STOWED and p.current_speed>4,"Normal moving stowed fixture")
			v.authored_run_time=phase*v.run.clip.length
			near=true;serial=0;label="%d_%s"%[weapon,str(phase).replace(".","_")]
			await ticks(2,not rendered)
			check(b.authored_draw and b.state==b.State.DRAWING,"Existing awareness triggers real moving Draw immediately")
			await ticks(13,not rendered)
			check(v.socket.current_attachment==&"carrier","Live release follows carrier")
			Input.action_release("move_right");Input.action_press("move_forward")
			await ticks(10,not rendered)
			check(b.state==b.State.DRAWING and not gun.can_fire(),"Live catch/settle is not Ready")
			await ticks(20,not rendered)
			check(b.is_ready() and v.socket.current_attachment==&"hand","Moving/turning Draw reaches hand Ready")
			cases.append({"weapon":weapon,"phase":phase,"events":v.draw_event_log.slice(-5)})
			label=""
			# Real sprint/awareness path, no forced transition.
			Input.action_press("sprint");await ticks(55)
			check(b.state==b.State.STOWED and b.threat_present,"Threat remains stowed during sprint")
			Input.action_release("sprint");await ticks(2)
			check(b.authored_draw and b.state==b.State.DRAWING,"Sprint release triggers real Draw")
			await ticks(45);check(b.is_ready(),"Sprint release settles Ready")
			release_inputs();await ticks(15);gun.cooldown=0
			var shots: int=gun.shot_count;await ticks(10)
			check(gun.shot_count>shots,"Actual READY profile fires %d"%weapon)
			gun.cooldown=1000
	release_inputs()
	check(clock_error<1e-6 and shots_drawing==0,"Run clock and firing gate maintained")
	var report={"checks":checks,"failures":failures,"cases":cases,"clock_error":clock_error,"minimum_draw_speed":minimum_draw_speed,"shots_drawing":shots_drawing,"rendered":rendered}
	FileAccess.open(("res://tests/draw_d5_live_render_validation.json" if rendered else "res://tests/draw_d5_live_validation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("D5_LIVE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
