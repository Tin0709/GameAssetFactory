extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label);push_error(label)
func _initialize() -> void: call_deferred("run")
func difference(a: Transform3D,b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func run() -> void:
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
	scene.set_process(false);scene.player.set_physics_process(false);scene.player.visual.set_process(false)
	check(scene.get("presentation")!=null,"Existing research scene needs render-rate final-pose presentation")
	if not failures.is_empty(): scene.free();quit(1);return
	var a=scene.player;var v=a.visual;var p=scene.presentation
	var samples:=0;var endpoints:=0.;var min_floor:=INF;var intermediate_motion:=0;var planted_drift:=0.
	for fps in [30,60]:
		scene.reset_player();var dt: float=1./fps
		for i in fps*4:
			var t: float=i*dt
			var heading:=Vector3(sin(t*4.),0.,-cos(t*4.)) if t>1.8 else Vector3(0,0,-1)
			var vel:=heading*5.031
			var jump_t:=t-1.
			var airborne:=jump_t>0. and jump_t<.74
			var height:=maxf(0.,6.66*jump_t-9.*jump_t*jump_t) if airborne else 0.
			a.position+=vel*dt;a.position.y=height
			v.drive_jump_motion(vel,true,{"grounded":not airborne,"body_position":a.position,"vertical_speed":6.66-18.*jump_t if airborne else 0.,"takeoff":absf(jump_t)<dt*.5,"sprinting":true},dt)
			var frozen:=[]
			for b in v.skeleton.get_bone_count(): frozen.append(v.skeleton.get_bone_pose(b))
			var phase: float=v.gait_phase;var sequence: int=v.pose_sequence;var physical: Vector3=a.position
			var previous_world: Vector3=p.current.actor
			for alpha in [0.,.25,.5,.75,1.]:
				p.prepare(alpha)
				for b in v.skeleton.get_bone_count(): check(difference(v.skeleton.get_bone_pose(b),frozen[b])<.000001,"Rendering cannot write authoritative skeleton")
				check(v.gait_phase==phase and v.pose_sequence==sequence and a.position==physical,"Rendering cannot advance source or physics")
				if alpha==0. or alpha==1.:
					var source: Dictionary=p.previous if alpha==0. else p.current
					for b in v.skeleton.get_bone_count(): endpoints=maxf(endpoints,difference(p.display_world[b],source.world[b]))
				else:
					if p.display_actor.distance_to(p.current.actor)>.00001: intermediate_motion+=1
				for side in 2:
					var sole: Vector3=p.sole(p.display_world[[v.leg_left,v.leg_right][side]])
					min_floor=minf(min_floor,sole.y)
					if p.previous.support[side] and p.current.support[side]: planted_drift=maxf(planted_drift,sole.distance_to(Vector3(p.previous.soles[side]).lerp(p.current.soles[side],alpha)))
				samples+=1
			check(p.current.actor==previous_world,"Presentation snapshots immutable")
			check(v._pending_physics_delta==0.,"Pose evaluated once per physics tick")
		# Teleport must not render a streak from the previous position.
		a.position=Vector3(70,0,30);p.reset_history();p.prepare(.5)
		check(p.display_actor.distance_to(a.position)<.00001,"Teleport rebases both snapshots")
	check(endpoints<.00002,"Exact final-contact PRS at both render endpoints: "+str(endpoints))
	check(min_floor>-.0002,"Intermediate feet remain clear of floor: "+str(min_floor))
	check(planted_drift<.0002,"Planted world sole continuity: "+str(planted_drift))
	check(intermediate_motion>500,"Real fractional render samples between physics poses")
	print("RENDER_PRESENTATION ",JSON.stringify({"failures":failures,"samples":samples,"endpoint_error":endpoints,"minimum_floor":min_floor,"planted_drift":planted_drift,"intermediate_motion":intermediate_motion}))
	scene.free();quit(0 if failures.is_empty() else 1)
