extends Node
## Scene-local equivalent of AutoPistol's nearest-living-target policy, using
## this encounter's existing four-entry registry and real line of sight.
const Profiles=preload("res://scripts/weapon_fire_profiles.gd")
var player: CharacterBody3D
var encounter: Node3D
var target: Node3D
var scan_count:=0
var query:=PhysicsRayQueryParameters3D.new()
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
	for zombie in encounter.zombies:
		if not is_instance_valid(zombie) or zombie.is_dead:continue
		var offset: Vector3=zombie.global_position-origin;offset.y=0.0
		var distance:=offset.length_squared()
		if distance>best:continue
		query.to=zombie.global_position+Vector3(0,1.02,0)
		var hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider!=zombie:continue
		best=distance;closest=zombie
	target=closest;visual.auto_aim_target=target
func reset_target() -> void:
	target=null
	if is_instance_valid(player):player.visual.auto_aim_target=null
