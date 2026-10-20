extends SceneTree
## Test actual source hand boxes against the player's animated visible body,
## rather than just the larger collision capsule or a configured attack range.
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 if not ok and not failures.has(message):failures.append(message);push_error(message)
func ticks(count:int)->void:
 for i in count:await physics_frame
 await process_frame
func box(skeleton:Skeleton3D,bone_name:String,center:Vector3,size:Vector3)->Dictionary:
 var bone:=skeleton.find_bone(bone_name)
 var world:=skeleton.global_transform*skeleton.get_bone_global_pose(bone)*skeleton.get_bone_global_rest(bone).affine_inverse()*Transform3D(Basis.IDENTITY,center)
 return {"center":world.origin,"axes":[world.basis.x.normalized(),world.basis.y.normalized(),world.basis.z.normalized()],"half":size*.5*world.basis.get_scale()}
func intersects(a:Dictionary,b:Dictionary)->bool:
 var axes:Array=a.axes.duplicate();axes.append_array(b.axes)
 for x:Vector3 in a.axes:
  for y:Vector3 in b.axes:axes.append(x.cross(y))
 var offset:Vector3=b.center-a.center
 for axis:Vector3 in axes:
  if axis.length_squared()<.000001:continue
  axis=axis.normalized();var ra:=0.;var rb:=0.
  for i in 3:ra+=absf(axis.dot(a.axes[i]))*float(a.half[i]);rb+=absf(axis.dot(b.axes[i]))*float(b.half[i])
  if absf(offset.dot(axis))>ra+rb+.005:return false
 return true
func touching(z:CharacterBody3D,player:CharacterBody3D)->bool:
 # Contact with a visible arm is a real hit too, especially from the side.
 # Approved player arms are straight, so each complete arm is one rigid box.
 var parts: Array=[box(player.visual.skeleton,"Chest",Vector3(0,1.0125,0),Vector3(.45,.675,.225)),box(player.visual.skeleton,"Head",Vector3(0,1.575,0),Vector3(.45,.45,.45))]
 for side in [-1.,1.]:parts.append(box(player.visual.skeleton,"Arm.L" if side>0 else "Arm.R",Vector3(.3375*side,1.0125,0),Vector3(.225,.675,.225)))
 for side in [-1.,1.]:
  var hand:=box(z.visual.skeleton,"Arm.L" if side>0 else "Arm.R",Vector3(.3375*side,.775,0),Vector3(.225,.20,.225))
  for part:Dictionary in parts:
   if intersects(hand,part):return true
 return false
func freeze(z:CharacterBody3D,at:Vector3)->void:
 z.target=null;z.move_speed=0.;z.velocity=Vector3.ZERO;z.position=at
func run()->void:
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();scene.auto_aim_enabled=false;root.add_child(scene)
 scene.player.scripted_input=true
 var group=scene.zombie_combat;var reports:=[];var closest:=10.
 for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
  scene.reset_player()
  for i in 4:freeze(group.zombies[i],Vector3(25+i*3,0,25))
  var z=group.zombies[0];z.position=direction*3.;z.move_speed=2.05;z.target=scene.player;z.visual.rotation.y=atan2(-direction.x,-direction.z)
  var contacts:Dictionary={};var distances:Array[float]=[];var previous_count:=0
  for i in 210:
   await ticks(1)
   var distance:float=Vector2(z.position.x-scene.player.position.x,z.position.z-scene.player.position.z).length();closest=minf(closest,distance)
   if z.visual.attack_count>previous_count:distances.append(distance);previous_count=z.visual.attack_count
   if z.visual.attack_time>=.12 and z.visual.attack_time<=.27 and touching(z,scene.player):contacts[z.visual.attack_count]=true
  check(previous_count>=2,"Zombie reaches the player and repeatedly attacks from each direction")
  check(contacts.size()>=2,"Source hands physically meet the visible player body on repeated strikes from "+str(direction))
  check(closest>=.57,"Living capsules prevent the zombie walking into the player's body")
  reports.append({"direction":str(direction),"attack_start_distances_m":distances,"attack_count":previous_count,"contacting_strikes":contacts.size()})
 # Real group: only zombies able to reach melee range should swing. Those
 # blocked behind another zombie should keep approaching, not hit empty air.
 scene.reset_player();var group_contacts:Dictionary={};var group_strikers:Dictionary={}
 for i in 300:
  await ticks(1)
  for z in group.zombies:
   if z.visual.attack_count>0:group_strikers[z.name]=true
   if z.visual.attack_time>=.12 and z.visual.attack_time<=.27 and touching(z,scene.player):group_contacts[z.name]=true
 check(group_contacts.size()>=2,"Several zombies make actual hand contact in the four-zombie encounter")
 check(not scene.player.is_dead,"Research attack still preserves existing player health behavior")
 check(absf(scene.player.walk_speed-2.70)<.001 and absf(scene.player.run_speed-7.55)<.01,"Player movement speeds stay approved")
 var report:={"passed":failures.is_empty(),"failures":failures,"render_fps":30 if OS.get_cmdline_user_args().has("30") else 60,"physics_hz":Engine.physics_ticks_per_second,"directions":reports,"closest_capsule_centers_m":closest,"group_strikers":group_strikers.keys(),"group_contacting_zombies":group_contacts.keys()}
 print("ZOMBIE_MELEE_CONTACT ",JSON.stringify(report))
 var path:=OS.get_environment("ZOMBIE_MELEE_RESULTS")
 if not path.is_empty():FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 scene.free();quit(0 if failures.is_empty() else 1)
