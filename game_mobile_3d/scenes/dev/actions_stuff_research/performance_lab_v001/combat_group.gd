extends "res://scenes/dev/actions_stuff_research/zombie_combat/combat_group.gd"
## Same native encounter. UI additions preserve every existing actor and corpse.
const StressZombie=preload("res://scenes/dev/actions_stuff_research/performance_lab_v001/physics_zombie.gd")
const SPAWN_SPACING:=.75
var spawn_count:=20
var last_added:=0

func _zombie_script()->Script:return StressZombie

func _cell(point:Vector3)->Vector2i:
 return Vector2i(floori(point.x/SPAWN_SPACING),floori(point.z/SPAWN_SPACING))

func _occupy(occupied:Dictionary,point:Vector3)->void:
 var key:=_cell(point)
 if not occupied.has(key):occupied[key]=[]
 occupied[key].append(Vector2(point.x,point.z))

func _blocked(occupied:Dictionary,point:Vector3)->bool:
 var key:=_cell(point);var at:=Vector2(point.x,point.z)
 for x in range(-1,2):
  for z in range(-1,2):
   var neighbor:=key+Vector2i(x,z)
   if not occupied.has(neighbor):continue
   for other:Vector2 in occupied[neighbor]:
    if at.distance_squared_to(other)<SPAWN_SPACING*SPAWN_SPACING:return true
 return false

func _spawn_positions()->Array[Vector3]:
 var points:Array[Vector3]=[]
 if spawn_count==0:return points
 var side:float=float(get_parent().get("grass_field_blocks"))
 var limit:=maxf(2.,side*.5-1.)
 var center:=Vector3(player.global_position.x,0.,player.global_position.z)
 var occupied:Dictionary={}
 # One sparse occupancy grid per button press, never per frame. Check living
 # capsules; native corpses already pass through actors under the approved policy.
 for zombie in zombies:
  if is_instance_valid(zombie) and not zombie.is_dead:_occupy(occupied,zombie.global_position)
 var radius:=minf(maxf(6.5,float(spawn_count)*.20),maxf(2.5,side*.25))
 var phase:=.31+float(_spawn_serial)*.37
 while radius<=side*1.42 and points.size()<spawn_count:
  var candidates:=ceili(TAU*radius/.45)
  for i in candidates:
   # Golden-angle order distributes each added batch around the player rather
   # than filling one short arc first. Occupancy enforces actual clearance.
   var angle:=phase+float(i)*2.399963229728653
   var point:=center+Vector3(sin(angle),0.,cos(angle))*radius
   if absf(point.x)>limit or absf(point.z)>limit:continue
   if point.distance_squared_to(center)<4. or _blocked(occupied,point):continue
   points.append(point);_occupy(occupied,point)
   if points.size()==spawn_count:break
  radius+=1.
 return points

func reset_encounter()->void:
 super.reset_encounter()
 for zombie in zombies:zombie.chasing=true
 last_added=zombies.size()

func spawn_batch(count:int)->void:
 # Explicit replacement retained for R/reset fixtures. The Spawn button uses
 # add_batch; it never calls this destructive-to-runtime reset path.
 spawn_count=clampi(count,0,50)
 reset_encounter()

func add_batch(count:int)->int:
 spawn_count=clampi(count,0,50)
 var first:=zombies.size()
 _spawn_zombies(_spawn_positions())
 for i in range(first,zombies.size()):zombies[i].chasing=true
 last_added=zombies.size()-first
 print("PERFORMANCE_ZOMBIES_ADDED ",JSON.stringify({"requested":spawn_count,"added":last_added,"alive":living_count()}))
 return last_added

func kill_all()->void:
 # Every actor receives its native lethal hit now; no admission/corpse cap.
 for zombie:CharacterBody3D in zombies.duplicate():
  if not is_instance_valid(zombie) or zombie.is_dead:continue
  var direction:=zombie.global_position-player.global_position;direction.y=0.
  zombie.take_damage(zombie.current_hp,direction.normalized())
