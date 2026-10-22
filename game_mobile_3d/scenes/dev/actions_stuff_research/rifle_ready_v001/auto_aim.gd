extends Node
## Scene-local equivalent of AutoPistol's nearest-living-target policy, using
## this encounter's existing four-entry registry and real line of sight.
const Profiles=preload("res://scripts/weapon_fire_profiles.gd")
const RETARGET_MARGIN:=.20 # Nearly equal melee distances should not chatter.
var player: CharacterBody3D
var encounter: Node3D
var target: Node3D
var scan_count:=0
var query:=PhysicsRayQueryParameters3D.new()
var last_ray_count:=0
var _candidate_rows:Array[Array]=[]
var _ordered:Array[Array]=[]
func _closer(a:Array,b:Array)->bool:
	# Original scan replaces on equal distance, so the later registry entry wins.
	return a[0]<b[0] or (a[0]==b[0] and a[1]>b[1])
func _visible(zombie:Node3D)->bool:
	query.to=zombie.global_position+Vector3(0,1.02,0)
	last_ray_count+=1
	var hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider==zombie
func setup(body: CharacterBody3D,group: Node3D) -> void:
	player=body;encounter=group;process_physics_priority=-1
	query.collision_mask=5;query.exclude=[player.get_rid()];query.hit_from_inside=true
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):return
	var visual=player.visual
	if not visual.rifle_ready_active or not visual.rifle_aim_requested:
		reset_target();return
	var closest: Node3D
	var best:=pow(float(Profiles.PROFILES[1].range),2)
	var origin:=player.global_position
	query.from=origin+Vector3(0,1.02,0)
	scan_count+=1
	last_ray_count=0
	_ordered.clear()
	# Reuse rows; spawn growth is the only allocation. Sorting distance keys is
	# much cheaper than casting through every occluded candidate in a crowd.
	for i in encounter.zombies.size():
		var zombie:Node3D=encounter.zombies[i]
		if not is_instance_valid(zombie) or zombie.is_dead:continue
		var offset:Vector3=zombie.global_position-origin;offset.y=0.
		var distance:=offset.length_squared()
		if distance>best:continue
		if _ordered.size()==_candidate_rows.size():_candidate_rows.append([0.0,0,null])
		var row:Array=_candidate_rows[_ordered.size()]
		row[0]=distance;row[1]=i;row[2]=zombie
		_ordered.append(row)
	_ordered.sort_custom(_closer)
	for row:Array in _ordered:
		if not _visible(row[2]):continue
		best=row[0];closest=row[2];break
	if closest!=target and is_instance_valid(target) and not target.is_dead:
		var current_offset: Vector3=target.global_position-origin;current_offset.y=0.0
		var current_distance:=current_offset.length()
		if current_distance<=float(Profiles.PROFILES[1].range) and current_distance<=sqrt(best)+RETARGET_MARGIN:
			if _visible(target):closest=target
	target=closest;visual.auto_aim_target=target
func reset_target() -> void:
	target=null
	if is_instance_valid(player):player.visual.auto_aim_target=null
