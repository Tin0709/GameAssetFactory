extends SceneTree
var checks: Array=[]
var failures: Array=[]
var cases: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var scene=load("res://scenes/dev/ExpressiveLocomotionTest.tscn").instantiate();root.add_child(scene);current_scene=scene
	var actor=scene.actor;var v=actor.visual;actor.scripted_input=true
	for pace in [1.5,2.25]:
		actor.requested_direction=Vector2.ZERO;scene.reset_actor();await scene.tick(60)
		actor.review_pace=pace;actor.requested_run=true;actor.requested_direction=Vector2(0,1);await scene.tick(60)
		var feet: Array=v.last_sole.duplicate();var support: Array=v.foot_support.duplicate()
		var events: Array=[];var worst:=0.0;var release_age: Array[float]=[1.0,1.0];var maximum_joint_offset:=0.0
		var previous_velocity: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO];var peak_velocity_jump:=0.0;var peak_acceleration:=0.0
		var worst_release: Dictionary={}
		for sample in 180:
			await scene.tick(1)
			for side in 2:
				var bone: int=[v.leg_left,v.leg_right][side]
				var parent: int=v.skeleton.get_bone_parent(bone)
				var basis: Basis=v.skeleton.global_basis*v.skeleton.get_bone_global_pose(parent).basis
				maximum_joint_offset=maxf(maximum_joint_offset,(basis*(v.skeleton.get_bone_pose_position(bone)-v._p[bone])).length())
				var speed: float=v.last_sole[side].distance_to(feet[side])/v.pose_delta
				var velocity: Vector3=(v.last_sole[side]-feet[side])/v.pose_delta
				if support[side] and not v.foot_support[side]:
					worst=maxf(worst,speed);events.append({"side":side,"phase":v.gait_phase,"release_speed":speed,"delta":v.pose_delta})
					release_age[side]=0
				if release_age[side]<.08:
					peak_velocity_jump=maxf(peak_velocity_jump,(velocity-previous_velocity[side]).length())
					if (velocity-previous_velocity[side]).length()/v.pose_delta>peak_acceleration:
						worst_release={"phase":v.gait_phase,"side":side,"support":v.foot_support[side],"velocity":velocity,"previous_velocity":previous_velocity[side],"age":v.run_release_age[side],"duration":v.run_release_duration[side],"offset":v.run_release_offset[side],"offset_velocity":v.run_release_velocity[side]}
					peak_acceleration=maxf(peak_acceleration,(velocity-previous_velocity[side]).length()/v.pose_delta)
				release_age[side]+=v.pose_delta;previous_velocity[side]=velocity
				feet[side]=v.last_sole[side];support[side]=v.foot_support[side]
		cases.append({"pace":pace,"worst_release_speed":worst,"peak_release_velocity_jump":peak_velocity_jump,"peak_release_acceleration":peak_acceleration,"maximum_combined_joint_offset":maximum_joint_offset,"events":events,"worst_release":worst_release})
		check(not events.is_empty(),"Straight Run reaches support-to-swing events")
		check(worst<4.5,"Run lifts from support smoothly rather than dropping contact translation instantly")
		# The new speed candidate changes physical acceleration by speed squared.
		# Compare geometric release smoothness at the prior nominal travel rate;
		# preserve raw acceleration above rather than hiding the faster motion.
		check(peak_acceleration/(v.run_speed_scale*v.run_speed_scale)<300,"Speed-normalized foot velocity ramps through release without a delayed discontinuity")
		check(maximum_joint_offset<.1401,"Carried swing and floor corrections share the same140mm joint budget")
	for interruption in ["Walk","Pace","Orbit","Release"]:
		actor.requested_direction=Vector2.ZERO;scene.reset_actor();await scene.tick(60)
		actor.review_pace=2.25;v.run_release_enabled=true;v.run_orbit_enabled=true
		actor.requested_run=true;actor.requested_direction=Vector2(0,1);await scene.tick(60)
		var wait:=0
		while not (v.run_release_active[0] or v.run_release_active[1]) and wait<90:await scene.tick(1);wait+=1
		check(wait<90,"Interruption probe catches a carried foot in swing: "+interruption)
		var previous_q: Array=[v.skeleton.get_bone_pose_rotation(v.leg_left),v.skeleton.get_bone_pose_rotation(v.leg_right)]
		var initial_phase: float=v.gait_phase;var travel:=0.0;var maximum:=0.0;var angle:=0.0
		match interruption:
			"Walk":actor.requested_run=false
			"Pace":scene._button("Compare pace")
			"Orbit","Release":
				var event:=InputEventKey.new();event.pressed=true;event.physical_keycode=KEY_N if interruption=="Orbit" else KEY_O
				scene._unhandled_key_input(event)
		for sample in 24:
			await scene.tick(1)
			travel+=wrapf(v.gait_phase-initial_phase,-.5,.5);initial_phase=v.gait_phase
			for side in 2:
				var bone: int=[v.leg_left,v.leg_right][side];var parent: int=v.skeleton.get_bone_parent(bone)
				var basis: Basis=v.skeleton.global_basis*v.skeleton.get_bone_global_pose(parent).basis
				maximum=maxf(maximum,(basis*(v.skeleton.get_bone_pose_position(bone)-v._p[bone])).length())
				var q: Quaternion=v.skeleton.get_bone_pose_rotation(bone)
				angle=maxf(angle,rad_to_deg(previous_q[side].angle_to(q)));previous_q[side]=q
		cases.append({"interruption":interruption,"maximum_combined_joint_offset":maximum,"maximum_leg_step_degrees":angle,"phase_travel":travel})
		check(maximum<.1401,"Interrupted release remains within the shared contact budget: "+interruption)
		check(angle<60 and travel>0,"Interrupted release preserves pose continuity and live gait: "+interruption)
	var out:="res://.validation/expressive_turn_spin_v1";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/run_release.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"))
	print("RUN_RELEASE_CHECKS ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)
