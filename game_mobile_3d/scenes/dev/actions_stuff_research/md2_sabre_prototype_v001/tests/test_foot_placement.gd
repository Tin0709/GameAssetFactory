extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func floor_box(pos:Vector3,size:Vector3):
 var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape);root.add_child(body);body.position=pos;return body
func run():
 check(FileAccess.file_exists("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/foot_placement.gd"),"Rigid foot-ground helper is available")
 if not failures.is_empty():finish();return
 var floor=floor_box(Vector3(0,-.1,0),Vector3(20,.2,20))
 var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a);a.set_physics_process(false)
 await physics_frame;await process_frame
 var helper=a.foot_placement;check(helper!=null,"Private source mode owns the contact overlay")
 if helper==null:a.free();floor.free();finish();return
 var rig:Skeleton3D=a.skeleton
 a.animation_player.play(a.clips.Idle.action,0.);a.animation_player.seek(.2,true);rig.force_update_all_bone_transforms()
 var raw:Array=[]
 for i in rig.get_bone_count():raw.append(rig.get_bone_pose(i))
 var root_position:Vector3=a.position;var clock:float=a.simulation_clock
 for hz in [30,60,120]:
  helper.clear();helper.reset_metrics()
  for n in hz:
   helper.restore();a.animation_player.seek(.2,true);rig.force_update_all_bone_transforms();helper.apply(1./hz,true,false,true,0)
  var m:Dictionary=helper.snapshot()
  check(m.penetration_max_m<.002,"Flat soles clear floor at %dHz"%hz)
  check(m.slip_rms_m_s<.015,"Static anchors stable at %dHz"%hz)
  check(absf(helper.pelvis)<.086,"Pelvis correction bounded at %dHz"%hz)
  for bone in rig.get_bone_count():check(rig.get_bone_pose(bone).basis.is_equal_approx(raw[bone].basis),"No rotation/scale distortion %d/%d"%[hz,bone])
  helper.restore()
  check(a.visual.position.is_zero_approx(),"Whole-body offset restores")
  for bone in rig.get_bone_count():check(rig.get_bone_pose(bone).is_equal_approx(raw[bone]),"All local poses restore %d/%d"%[hz,bone])
 var step=floor_box(Vector3(2.02,-.06,0),Vector3(4,.2,4));await physics_frame;await process_frame
 for n in 120:
  helper.restore();a.animation_player.seek(.2,true);rig.force_update_all_bone_transforms();helper.apply(1./120.,true,false,true,0)
 check(helper.snapshot().penetration_m<.003,"Uneven 40mm support clears both rigid soles")
 check(a.position==root_position and a.simulation_clock==clock,"Contact solver never moves capsule or clock")
 helper.restore();helper.apply(1./60.,false,false,true,0)
 check(helper.pelvis==0. and not helper.states[0].planted and not helper.states[1].planted,"Airborne releases anchors immediately")
 for bone in rig.get_bone_count():check(rig.get_bone_pose(bone).is_equal_approx(raw[bone]),"Airborne preserves exact source %d"%bone)
 helper.apply(1./60.,true,true,true,0);check(helper.pelvis==0.,"Raw review bypasses correction")
 helper.set_enabled(false);helper.apply(1./60.,true,false,true,0)
 check(a.visual.position.is_zero_approx(),"Off comparison preserves raw visual")
 for bone in rig.get_bone_count():check(rig.get_bone_pose(bone).is_equal_approx(raw[bone]),"Off preserves exact source %d"%bone)
 helper.set_enabled(true);helper.apply(1./60.,true,false,true,0);helper.restore();a.position.x=.3;helper.apply(1./60.,true,false,true,0)
 check(not helper.states[0].planted and not helper.states[1].planted,"Excess travel releases unreachable anchors")
 helper.clear();a.position=Vector3.ZERO;helper.apply(1./60.,true,false,true,0)
 var pinned:Vector3=helper._samples(0).center
 helper.restore();a.position.x+=.02;helper.apply(1./120.,true,false,true,0)
 var displaced:Vector3=helper._samples(0).center-pinned
 check(Vector2(displaced.x,displaced.z).length()<.001,"A planted sole holds its world anchor within the rigid correction budget")
 # The footprint can straddle a terrain edge after horizontal anchoring.
 helper.clear();a.position=Vector3(.08,0,0);a.animation_player.seek(.2,true);rig.force_update_all_bone_transforms()
 for n in 120:
  helper.restore();helper.apply(1./120.,true,false,true,0)
 helper.restore();a.position.x=.04;helper.apply(1./120.,true,false,true,0)
 check(helper.snapshot().penetration_m<.003,"Ground clearance is solved at the anchored footprint across a terrain edge")

 helper.clear();a.position=Vector3.ZERO;helper.apply(1./60.,true,false,true,0);helper.restore();a.visual.rotation.y=PI/2.;helper.apply(1./60.,true,false,true,0)
 check(not helper.states[0].planted and not helper.states[1].planted,"Turning releases incompatible anchors")
 helper.restore();a.visual.rotation.y=0.;helper.clear();helper.apply(1./60.,true,false,false,1)
 check(not helper.states[0].planted and not helper.states[1].planted,"Locked strike keeps horizontal authored foot motion")
 helper.clear();a.position=Vector3(.08,0,0);a.animation_player.seek(.2,true);rig.force_update_all_bone_transforms()
 step.free()
 var toe:Vector3=helper._samples(1).points[0]
 for point:Vector3 in helper._samples(1).points:
  if point.x>toe.x:toe=point
 var island=floor_box(Vector3(toe.x,.02,toe.z),Vector3(.012,.2,.012));await physics_frame;await process_frame
 for n in 120:
  helper.restore();helper.apply(1./120.,true,false,true,0)
 helper.restore();a.position.x=.04
 for n in 30:
  helper.restore();helper.apply(1./120.,true,false,true,0)
 check(helper.snapshot().penetration_m<.003,"Pelvis support follows an anchored higher surface with remaining combined reach")
 a.free();floor.free();island.free();finish()
func finish():
 print("SABRE_FOOT_PLACEMENT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
