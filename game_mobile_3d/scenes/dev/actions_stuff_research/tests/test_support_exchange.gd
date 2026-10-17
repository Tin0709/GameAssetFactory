extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();scene.rifle_ready=false;root.add_child(scene)
	var v=scene.player.visual;scene.player.set_physics_process(false);v.set_process(false)
	# The source snapshot now owns phase/activation; setting old viewer fields
	# by hand would create an unreachable state. Exercise a real gait exchange.
	var actor=scene.player;var passed:=true;var checked:=0;var dt:=1./60.
	for i in 240:
		actor.velocity=Vector3(0,0,actor.walk_speed);actor.position+=actor.velocity*dt
		v.drive_locomotion(actor.velocity,true,dt);v._evaluate(dt)
		if not v._support(0) and v.released[0] and v._source_clearance[0]>.06:
			for tick in 4:
				var phase: float=v.direction_snapshot.phase
				actor.velocity=Vector3(0,0,actor.run_speed);actor.position+=actor.velocity*dt
				v.drive_locomotion(actor.velocity,true,dt);v._evaluate(dt)
				passed=passed and v.direction_snapshot.phase>=phase
				if v._source_clearance[0]>.04:
					passed=passed and not v._support(0);checked+=1
			break
	passed=passed and checked>0
	if not passed:push_error("Accelerating Walk to Run must not turn a free leg back into stance mid-exchange")
	print("SUPPORT_EXCHANGE ",passed)
	scene.queue_free();quit(0 if passed else 1)
