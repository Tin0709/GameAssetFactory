extends "res://scenes/dev/actions_stuff_research/zombie_combat/combat_group.gd"
## Same encounter, with one replaceable simultaneous batch for the dev benchmark.
const StressZombie=preload("res://scenes/dev/actions_stuff_research/performance_lab_v001/physics_zombie.gd")
var spawn_count:=20

func _zombie_script()->Script:return StressZombie

func _spawn_positions()->Array[Vector3]:
	var points:Array[Vector3]=[]
	if spawn_count==0:return points
	var center:=Vector3(clampf(player.global_position.x,-4.,4.),0.,clampf(player.global_position.z,-4.,4.))
	var radius:=maxf(6.5,float(spawn_count)*.20)
	var slots:Array[Vector3]=[]
	# Fixed 64-slot ring: >=0.63m spacing, within the 30m floor, and never on
	# the player. Resampling the valid slots spreads every requested count evenly.
	for i in 64:
		var angle:=TAU*float(i)/64.+.31
		var point:=center+Vector3(sin(angle),0.,cos(angle))*radius
		var offset:=point-player.global_position;offset.y=0.
		if offset.length_squared()>=4.:slots.append(point)
	assert(slots.size()>=spawn_count)
	for i in spawn_count:points.append(slots[i*slots.size()/spawn_count])
	return points

func reset_encounter()->void:
	super.reset_encounter()
	# The benchmark exercises the existing chase even when spawned beyond its
	# ordinary detection radius; AI speed, melee and source animation are intact.
	for zombie in zombies:zombie.chasing=true

func spawn_batch(count:int)->void:
	spawn_count=clampi(count,0,50)
	reset_encounter()
	print("PERFORMANCE_ZOMBIE_BATCH ",spawn_count)

func kill_all()->void:
	# Apply every lethal hit in this call, with no queue, corpse culling or budget
	# substitution. Every actor keeps its existing native death for the stress test.
	for zombie:CharacterBody3D in zombies.duplicate():
		if not is_instance_valid(zombie) or zombie.is_dead:continue
		var direction:=zombie.global_position-player.global_position;direction.y=0.
		zombie.take_damage(zombie.current_hp,direction.normalized())

