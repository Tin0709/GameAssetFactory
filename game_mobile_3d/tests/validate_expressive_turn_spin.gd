extends SceneTree
var checks: Array=[]
var failures: Array=[]
var cases: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var scene=load("res://scenes/dev/ExpressiveLocomotionTest.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	var actor=scene.actor;var v=actor.visual;actor.scripted_input=true
	for pace in [1.5,2.25]:
		for sprint in [false,true]:
			actor.requested_direction=Vector2.ZERO;scene.reset_actor();actor.position.x=-12;await scene.tick(45)
			actor.review_pace=pace;actor.requested_run=sprint;actor.requested_direction=Vector2(0,1);await scene.tick(40)
			var worst:=0.0;var trace: Array=[]
			for degrees in [180,0,-90,90,180,-90,0,180,0,90,-90,0]:
				actor.requested_direction=Vector2(sin(deg_to_rad(degrees)),cos(deg_to_rad(degrees)))
				for tick in 15:
					await scene.tick(1)
					for side in 2:
						var bone: int=[v.leg_left,v.leg_right][side]
						var parent: int=v.skeleton.get_bone_parent(bone)
						var expected: Basis=v.skeleton.global_basis*v.skeleton.get_bone_global_pose(parent).basis*Basis(v._q[bone])
						var actual:=Basis(v._leg_world_rotation(bone))
						var heading:=absf(rad_to_deg(wrapf(atan2(actual.z.x,actual.z.z)-atan2(expected.z.x,expected.z.z),-PI,PI)))
						worst=maxf(worst,heading)
						trace.append({"heading_error":heading,"side":side,"support":v.foot_support[side],"phase":v.gait_phase,"yaw":rad_to_deg(v.rotation.y),"turn":degrees,"aim":rad_to_deg(v.support_aim[side].angle_to(Quaternion.IDENTITY))})
			cases.append({"pace":pace,"run":sprint,"maximum_heading_error":worst,"trace":trace})
			check(worst<65,"Turning legs keep a clean forward heading rather than winding behind the body")
	var out:="res://.validation/expressive_turn_spin_v1";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/spin.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"))
	print("TURN_SPIN_CHECKS ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)
