extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
 var baseline=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();baseline.soldier_loadout=false;root.add_child(baseline)
 var v=scene.player.visual;var cv=baseline.player.visual
 for s in [scene,baseline]:
  s.set_process(false);s.player.set_physics_process(false);s.player.visual.set_process(false);s.rifle_fire.set_physics_process(false);s.rifle_auto_aim.set_physics_process(false)
 check(v.meshes.size()==1 and v.meshes[0].name=="SoldierSkinV001","Single merged Soldier draw surface")
 var mesh:MeshInstance3D=v.meshes[0];check(mesh.mesh.get_surface_count()==1,"Single atlas material")
 check(mesh.skin.get_bind_count()==10,"All ten original skin bindings retained")
 var bind_error:=0.
 for i in mesh.skin.get_bind_count():
  var b:int=v.skeleton.find_bone(mesh.skin.get_bind_name(i));var t:Transform3D=v.skeleton.get_bone_global_rest(b)*mesh.skin.get_bind_pose(i)
  bind_error=maxf(bind_error,t.origin.length()+t.basis.x.distance_to(Vector3.RIGHT)+t.basis.y.distance_to(Vector3.UP)+t.basis.z.distance_to(Vector3.BACK))
 check(bind_error<.00001,"Runtime inverse binds preserve canonical silhouette")
 check(v.rifle_model.scene_file_path.ends_with("Rifle_Sand_Block_V1.glb"),"Requested Sand Block rifle")
 check(v.skeleton.get_bone_count()==cv.skeleton.get_bone_count(),"Existing animated rig remains unchanged")
 var max_pose_error:=0.;var muzzle_axis_error:=0.
 for i in 8*fps:
  var t:=float(i)/fps;var moving:=t>1. and t<6.;var running:=t>3. and t<4.5
  var air:=t>4.5 and t<5.2;var velocity:=Vector3(sin(t*3.),0.,cos(t*3.))*(scene.player.run_speed if running else scene.player.walk_speed) if moving else Vector3.ZERO
  var context:={"grounded":not air,"body_position":Vector3(0,1. if air else 0.,0),"vertical_speed":0.,"takeoff":absf(t-4.5)<.5/fps,"sprinting":running}
  for visual in [v,cv]:
   visual.set_rifle_aim(t>.5 and t<7.);visual.turn_axis=1. if t>6. and t<6.4 else 0.;visual.drive_jump_motion(velocity,moving,context,1./fps)
   if i%maxi(1,int(fps/6))==0:visual.play_rifle_recoil()
  for b in v.skeleton.get_bone_count():
   var a:Transform3D=v.skeleton.get_bone_pose(b);var c:Transform3D=cv.skeleton.get_bone_pose(b)
   max_pose_error=maxf(max_pose_error,a.origin.distance_to(c.origin)+a.basis.x.distance_to(c.basis.x)+a.basis.y.distance_to(c.basis.y)+a.basis.z.distance_to(c.basis.z))
  var carrier:Transform3D=v.skeleton.global_transform*v.skeleton.get_bone_global_pose(v.carrier_bone)
  var forward:Vector3=-v.rifle_model.global_basis.z.normalized()
  muzzle_axis_error=maxf(muzzle_axis_error,forward.distance_to(carrier.basis.y.normalized()))
 check(max_pose_error<.00001,"Appearance swap leaves all animation poses exact")
 check(muzzle_axis_error<.00001,"New barrel matches existing projectile/auto-aim axis")
 check(scene.presentation.mesh==mesh and scene.presentation.bind_bones.size()==10,"Render interpolation uses new skin and all bindings")
 check(not scene.player.find_child("*Backpack*",true,false),"Backpack remains standalone")
 var report:={"fps":fps,"passed":failures.is_empty(),"failures":failures,"bind_error":bind_error,"pose_difference_from_old_loadout":max_pose_error,"barrel_axis_error":muzzle_axis_error}
 print("SOLDIER_LOADOUT ",JSON.stringify(report));scene.free();baseline.free();quit(0 if failures.is_empty() else 1)
