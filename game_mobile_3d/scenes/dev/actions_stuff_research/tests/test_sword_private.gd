extends SceneTree
## Optional private-reference regression. Contains no source tracks; the external
## user-owned research library must be available on this development machine.
var failures:Array[String]=[]
func _initialize()->void:
	Engine.physics_ticks_per_second=30 if OS.get_cmdline_user_args().has("30") else 60
	call_deferred("run")
func check(value:bool,label:String)->void:
	if not value and not failures.has(label):failures.append(label);push_error(label)
func ticks(n:int)->void:
	for i in n:await physics_frame
	await process_frame
func run()->void:
	var hz:=Engine.physics_ticks_per_second
	var s=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate()
	s.grass_field_enabled=false;s.md2_lighting_enabled=false;root.add_child(s)
	s.player.scripted_input=true
	for i in s.zombie_combat.zombies.size():
		var z=s.zombie_combat.zombies[i];z.set_physics_process(false);z.target=null;z.velocity=Vector3.ZERO;z.position=Vector3(40+i*2,0,40)
	await ticks(8)
	var c=s.sword_combat;var v=s.player.visual
	check(v.using_private_fiery,"Requested actual Fiery source library loaded outside res://")
	if not v.using_private_fiery:s.free();quit(1);return
	for key in ["Attack1","Attack2","Attack3","Roll","Ready","Guard"]:
		check(v.sword_clips[key].clip.resource_path.begins_with("/Users/") and v._dynamic_clips.has(key),"External source clip and item channel: "+key)
	c.set_equipped(true)
	var z=s.zombie_combat.zombies[0]
	var accepted:Array[int]=[]
	for attack_index in 3:
		c.reset_combat();s.player.position=Vector3.ZERO;s.player.velocity=Vector3.ZERO;v.rotation.y=0.
		z.position=Vector3(0,0,1.05);z.current_hp=1000;z.poise=36.;z.knockback=Vector3.ZERO;z.stagger_remaining=0.;z.melee_freeze=0.
		c.state.start_attack(attack_index)
		await ticks(ceili(hz*1.6));accepted.append(c.hits)
		check(c.hits==1 and z.current_hp==1000-c.config.damage[attack_index],"Actual source Attack%d physically hits forward target exactly once"%(attack_index+1))
		check(c.state.state==&"ready","Source attack recovers without a stuck state")
	# Source item animation must survive the sole pose writer and presenter.
	c.reset_combat();c.state.start_attack(1)
	var attachment_start:Transform3D=v.sword_current_attachment
	var changed:=false;var max_grip:=0.
	for frame in ceili(hz*.5):
		await ticks(1)
		changed=changed or not v.sword_current_attachment.basis.is_equal_approx(attachment_start.basis)
		var arm:Transform3D=v.skeleton.global_transform*v.skeleton.get_bone_global_pose(v.arm_right)
		max_grip=maxf(max_grip,(arm*v.sword_current_attachment).origin.distance_to(v.sword_world().origin))
	check(changed and max_grip<.0001,"Actual changing rightItem channel retains a stable palm grip")
	c.reset_combat();z.position=Vector3(40,0,40);s.player.requested_direction=Vector2.RIGHT
	c.roll();var phase:float=v.direction_snapshot.phase
	await ticks(ceili(hz*.35));check(c.state.state==&"roll" and absf(float(v.direction_snapshot.phase)-phase)<.00001,"Actual source Roll owns body and preserves gait cursor")
	await ticks(ceili(hz*.6));check(c.state.state==&"ready","Source Roll releases at its actual duration")
	c.guard(true);await ticks(5);c.set_equipped(false)
	await ticks(hz);check(absf(wrapf(v.rotation.y-PI*.5,-PI,PI))<.1,"Rifle faces movement after private Guard switch-back")
	s.player.requested_direction=Vector2.ZERO
	print("SWORD_PRIVATE ",JSON.stringify({"physics_hz":hz,"failures":failures,"attack_hits":accepted,"grip_error_m":max_grip,"source_clips":v.private_fiery_profile.clips.keys()}))
	s.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
