extends SceneTree
## Independent native fixtures and existing sampler API parity, plus complete roll.
const Sampler=preload("res://scenes/dev/actions_stuff_research/source_clip_sampler.gd")
const DIR="res://scenes/dev/actions_stuff_research/sword_combat_v001/"
var failures:=0
var checks:=0
func need(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("validate")
func rows(a: Array) -> Transform3D:
 return Transform3D(Basis(Vector3(a[0][0],a[1][0],a[2][0]),Vector3(a[0][1],a[1][1],a[2][1]),Vector3(a[0][2],a[1][2],a[2][2])),Vector3(a[0][3],a[1][3],a[2][3]))
func local_pose(sampler: RefCounted,bone: int,t: float) -> Transform3D:
 return Transform3D(Basis(sampler.rotation(bone,t)).scaled(sampler.scale(bone,t)),sampler.position(bone,t))
func matrix_error(a: Transform3D,b: Transform3D) -> float:
 var e: float=(a.origin-b.origin).length()
 for i in 3:e=maxf(e,(a.basis[i]-b.basis[i]).length())
 return e
func validate() -> void:
 var args:=OS.get_cmdline_user_args()
 var stage:=args[0]
 var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"profile.json"))
 var fixtures: Array=JSON.parse_string(FileAccess.get_file_as_string(stage+"/fixtures.json"))
 var library: AnimationLibrary=load(DIR+"original_library.res")
 var skeleton:=Skeleton3D.new();root.add_child(skeleton)
 var parents: Array[int]=[-1,0,1,2,3,4,3,6,3,8,3,1,1]
 for i in profile.bones.size():
  skeleton.add_bone(profile.bones[i])
  skeleton.set_bone_parent(i,parents[i])
 var samplers: Dictionary={}
 need(library.get_animation_list().size()==8,"Eight original clips")
 for kind: String in profile.clips:
  var animation:=library.get_animation(kind)
  need(animation!=null,kind+" exists")
  need(is_equal_approx(animation.length,profile.clips[kind].duration),kind+" exact duration")
  need(animation.get_track_count()==39,kind+" full13xPRS")
  need((animation.loop_mode==Animation.LOOP_LINEAR)==bool(profile.clips[kind].loop),kind+" loop mode")
  samplers[kind]=Sampler.new(animation,skeleton)
 var max_pose_error:=0.0
 var max_blade_error:=0.0
 var max_fixed_grip_error:=0.0
 var carrier:=rows(profile.carrier_in_right_arm)
 var mount:=rows(profile.weapon_mount)
 var tip:=Vector3(profile.sword_tip_local[0],profile.sword_tip_local[1],profile.sword_tip_local[2])
 for fixture: Dictionary in fixtures:
  var sampler: RefCounted=samplers[fixture.clip]
  var globals: Array[Transform3D]=[]
  for i in profile.bones.size():
   var expected: Array=fixture.poses[profile.bones[i]]
   var transform:=local_pose(sampler,i,fixture.time)
   var wanted:=Transform3D(Basis(Quaternion(expected[3],expected[4],expected[5],expected[6])).scaled(Vector3(expected[7],expected[8],expected[9])),Vector3(expected[0],expected[1],expected[2]))
   max_pose_error=maxf(max_pose_error,matrix_error(transform,wanted))
   globals.append(globals[parents[i]]*transform if parents[i]>=0 else transform)
  var actual:=globals[10]*mount*tip
  var target: Array=fixture.blade_tip_world
  max_blade_error=maxf(max_blade_error,actual.distance_to(Vector3(target[0],target[1],target[2])))
  max_fixed_grip_error=maxf(max_fixed_grip_error,matrix_error(globals[8]*carrier,globals[10]))
 need(max_pose_error<.00003,"Native localPRS parity")
 need(max_blade_error<.00003,"Native sword marker parity")
 need(max_fixed_grip_error<.00003,"Fixed right arm carrier parity")
 for pair: Array in [["Ready","Attack1"],["Attack1","Attack2"],["Attack2","Attack3"],["Attack3","Ready"]]:
  var first: RefCounted=samplers[pair[0]]
  var second: RefCounted=samplers[pair[1]]
  for i in profile.bones.size():need(matrix_error(local_pose(first,i,profile.clips[pair[0]].duration),local_pose(second,i,0.0))<.00003,"Connected original combo seam "+str(pair)+str(i))
 var roll_turns: Dictionary={}
 for hz: int in [30,60]:
  for kind: String in profile.clips:
   var sampler: RefCounted=samplers[kind]
   var duration: float=profile.clips[kind].duration
   var previous: Quaternion=sampler.rotation(0,0.0)
   var rotation_distance:=0.0
   for step in int(ceil(duration*hz))+1:
    var t:=minf(float(step)/hz,duration)
    for i in profile.bones.size():need(sampler.scale(i,t).distance_to(Vector3.ONE)<.000003,"Unit scale "+kind)
    var q: Quaternion=sampler.rotation(0,t)
    rotation_distance+=previous.angle_to(q);previous=q
   if kind=="Roll":
    roll_turns[str(hz)]=rotation_distance
    need(absf(rotation_distance-TAU)<.003,"Complete forward Roll at "+str(hz))
 need(FileAccess.get_sha256(profile.sword_asset)==profile.weapon_glb_sha256,"Exact new Sword GLB bytes")
 var report: Dictionary={"passed":failures==0,"checks":checks,"failures":failures,"native_fixtures":fixtures.size(),"maximum_local_prs_matrix_error":max_pose_error,"maximum_sword_tip_world_error_m":max_blade_error,"maximum_carrier_fixed_grip_error":max_fixed_grip_error,"roll_rotation_distance_rad":roll_turns,"fps_checks":[30,60],"sampler":"existing source_clip_sampler.gd -> animation_pose_sampler.gd"}
 FileAccess.open(DIR+"runtime_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("SWORD_LIBRARY_VALIDATION ",JSON.stringify(report))
 skeleton.queue_free();quit(0 if failures==0 else 1)
