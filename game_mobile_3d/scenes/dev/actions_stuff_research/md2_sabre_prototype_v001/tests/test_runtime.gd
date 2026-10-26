extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var path:="res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd"
	check(FileAccess.file_exists(path),"Independent authored actor exists")
	if not failures.is_empty():quit(1);return
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate()
	lab.md2_sabre_prototype_enabled=true;lab.grass_field_blocks=30;root.add_child(lab)
	await physics_frame;await process_frame
	var a=lab.player;var mode=lab.sabre_mode
	check(mode!=null and a.animation_player!=null,"Same lab opts into independent AnimationPlayer actor")
	check(lab.zombie_combat==null and lab.rifle_fire==null and lab.sword_combat==null,"New mode has no legacy combat coupling")
	check(a.skeleton.get_bone_count()==(32 if a.using_original_source else 11),"Selected source/authored rig imported")
	check(a.clips.size()==22,"All twenty-two authored actions available")
	for key:String in a.clips:
		check(a.animation_player.has_animation(a.clips[key].action),"Imported action "+key)
		check(absf(a.animation_player.get_animation(a.clips[key].action).length-float(a.clips[key].duration))<.0001,"Imported action duration "+key)
	check(a.marker_grip!=null and a.marker_base!=null and a.marker_tip!=null,"Real exported blade markers imported")
	check(a.face.mesh.get_blend_shape_count()==2,"Both authored facial morphs imported")
	check(lab.grass_field!=null and lab.md2_lighting!=null and lab.get_node_or_null("FlatGround")!=null,"Original grass/lighting/ground reused")
	check(lab.camera_size==14.5 and lab.azimuth==.66 and lab.elevation==.40,"Original saved camera preserved")
	if a.using_private_skin:
		check(mode.reflection_probe!=null and mode.reflection_probe.reflection_mask==2 and mode.reflection_probe.cull_mask==1,"Local reflection is limited to actor layer and excludes actor from its capture")
		check(lab.md2_lighting.environment.reflected_light_source==Environment.REFLECTION_SOURCE_DISABLED,"Actor probe preserves original global lighting reflection setting")
		check(mode.reference_audio!=null and mode.reference_audio.voices.size()==4 and mode.reference_audio.available_count==15,"Original private samples use bounded four-voice prototype mix")
	check(a.active_clip=="Idle","First ground contact keeps neutral Idle rather than playing a landing")
	for hz in [30,60]:
		Engine.physics_ticks_per_second=hz
		mode.reset();await ticks(3)
		var start:Vector3=a.global_position
		Input.action_press("move_right")
		await ticks(hz)
		check(a.global_position.x>start.x+1.5 and a.current_speed>1.8,"Actual movement Input actions move capsule at "+str(hz))
		Input.action_press("sprint");await ticks(hz)
		check(a.current_speed>5.,"Actual Shift action sprints at "+str(hz))
		Input.action_release("move_right");Input.action_release("sprint")
		Input.action_press("jump");await ticks(1);Input.action_release("jump")
		var peak:float=a.global_position.y
		for i in hz:await ticks(1);peak=maxf(peak,a.global_position.y)
		check(peak>.9 and a.is_on_floor(),"Actual Space action jumps and lands at "+str(hz))
		var before:Vector3=a.marker_tip.global_position
		a.attack(true);await ticks(int(hz*.21));a.attack(false)
		check(a.marker_tip.global_position.distance_to(before)>.15,"Real tip follows authored attack pose")
		await ticks(hz*2)
		check(a.combo.phase==&"ready","Attack/recovery returns gameplay")
		a.review("Attack3");check(a.review_clip=="Attack3","Action review selects imported action")
		Input.action_press("move_left");await ticks(2);Input.action_release("move_left")
		check(a.review_clip.is_empty(),"Movement immediately resumes gameplay from review")
		a.expression_mode=2;await ticks(hz)
		check(a.focus_value>.99,"Focused expression drives imported morph")
		a.force_blink();await ticks(3)
		check(a.blink_value>.05,"Blink visibly drives imported morph")
		a.attack(true);mode.release_inputs();await ticks(hz*2)
		check(not a.combo.held and not a.combat_requested,"Focus release clears held commands")
		mode.reset();check(a.global_position.length()<.00001 and a.velocity.length()<.00001 and a.review_clip.is_empty() and a.combo.index==0 and a.accepted_count==0,"Reset clears physical/review/attack state and counters")
		await ticks(3)
		var accepted:Array[int]=[];var emitted:Array[int]=[]
		var on_start:Callable=func(index:int,_clip:String,_serial:int):accepted.append(index)
		var on_gate:Callable=func(index:int,_base:Vector3,_tip:Vector3,_serial:int):emitted.append(index)
		a.attack_accepted.connect(on_start);a.impact_ready.connect(on_gate)
		var down:=InputEventKey.new();down.physical_keycode=KEY_E;down.pressed=true;Input.parse_input_event(down)
		await ticks(ceili(hz*1.55))
		var up:=InputEventKey.new();up.physical_keycode=KEY_E;up.pressed=false;Input.parse_input_event(up)
		await ticks(hz)
		check(accepted==[0,1,2] and emitted==[0,1,2],"Actual E events produce exactly three accepted attacks and ready gates at "+str(hz))
		a.attack_accepted.disconnect(on_start);a.impact_ready.disconnect(on_gate)
		var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_RIGHT;mouse.pressed=true;mode.unhandled_input(mouse)
		Input.action_press("move_right");await ticks(8);Input.action_release("move_right")
		check(a.active_clip in ["CombatWalk","CombatStrafeLeft","CombatStrafeRight"],"RMB + movement selects authored combat locomotion")
		if a.using_original_source:
			Input.action_press("move_right");Input.action_press("sprint");await ticks(8)
			check(a.active_clip=="CombatRun" and a.clips[a.active_clip].source_name=="Player_Master_Run" and absf(float(a._playback_speed)-1.)<.0001,"RMB + Shift + lateral Input uses original Run at1x")
			Input.action_release("move_right");Input.action_release("sprint")
		mouse.pressed=false;mode.input(mouse);await ticks(3)
		check(not a.combat_requested,"RMB release over GUI clears combat facing")
	var fx=mode.effects;var node_count:int=fx.get_child_count()
	for i in 150:
		fx.sample(1./120.,true,Vector3.ZERO,Vector3(sin(i*.2),1,cos(i*.2)),i)
	check(fx.get_child_count()==node_count and fx.samples.size()<=fx.MAX_SAMPLES and fx.particles.size()==fx.PARTICLE_CAPACITY,"VFX budget remains bounded under saturation")
	mode.reset();check(fx.samples.is_empty(),"Reset clears ribbon histories")
	var report:={"checks":checks,"failures":failures,"clips":a.clips.keys(),"renderer":RenderingServer.get_current_rendering_method()}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation/md2_sabre_prototype_v001"))
	FileAccess.open("res://.validation/md2_sabre_prototype_v001/runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_RUNTIME ",JSON.stringify(report));lab.free();quit(0 if failures.is_empty() else 1)
func ticks(count:int)->void:
	for i in count:await physics_frame
	await process_frame
