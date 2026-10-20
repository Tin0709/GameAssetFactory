extends Node3D
## Research adapter: reuse existing combat assets/profile/audio/damage contract,
## with fixed pools instead of their one-shot queue_free lifecycle. No reload.
const Profiles=preload("res://scripts/weapon_fire_profiles.gd")
const PROJECTILE=preload("res://scenes/combat/PistolProjectile.tscn")
const FLASH=preload("res://scenes/combat/MuzzleFlash.tscn")
const IMPACT=preload("res://scenes/combat/ImpactBurst.tscn")
const Audio=preload("res://scripts/combat_audio.gd")
const INTERVAL:=1./6. # Complete approved recoil/recovery once per shot:360RPM.
const BULLETS:=16
const IMPACTS:=8
var player: CharacterBody3D
var visual: Node
var trigger_held:=false
var shots_fired:=0
var hit_count:=0
var pool_misses:=0
var cooldown:=0.
var bullets: Array[Node3D]=[]
var impacts: Array[Node3D]=[]
var ages:=PackedFloat32Array()
var directions:=PackedVector3Array()
var impact_ages:=PackedFloat32Array()
var flash: Node3D
var flash_age:=1.
var flash_size:=1.
var audio: Node
var query:=PhysicsRayQueryParameters3D.new()
var muzzle_local:=Vector3.ZERO
func setup(body: CharacterBody3D) -> void:
 player=body;visual=player.visual;process_physics_priority=1
 for i in BULLETS:bullets.append(_pooled(PROJECTILE))
 for i in IMPACTS:impacts.append(_pooled(IMPACT))
 ages.resize(BULLETS);ages.fill(-1.);directions.resize(BULLETS)
 impact_ages.resize(IMPACTS);impact_ages.fill(-1.)
 flash=_pooled(FLASH);audio=Audio.new();audio.name="ExistingCombatAudio";add_child(audio)
 query.collision_mask=5;query.exclude=[player.get_rid()]
 muzzle_local=visual.rifle_model.to_local(visual.socket.muzzles[1].global_position)
func _pooled(scene: PackedScene) -> Node3D:
 var node: Node3D=scene.instantiate()
 # Retain the exact existing meshes/materials; the manager owns lifetime.
 node.set_script(null);node.visible=false;add_child(node);return node
func set_trigger(held: bool) -> void:
 trigger_held=held
func _physics_process(delta: float) -> void:tick(delta)
func tick(delta: float) -> void:
 var profile: Dictionary=Profiles.PROFILES[1]
 _move_projectiles(delta,profile)
 for i in IMPACTS:
  if impact_ages[i]<0.:continue
  impact_ages[i]+=delta
  if impact_ages[i]>=.14:impact_ages[i]=-1.;impacts[i].hide()
  else:impacts[i].scale=Vector3.ONE*lerpf(1.,.02,impact_ages[i]/.14)
 flash_age+=delta
 if flash_age>=float(profile.flash_duration):flash.hide()
 else:flash.scale=Vector3.ONE*flash_size*(1.-.45*flash_age/float(profile.flash_duration))
 cooldown=maxf(0.,cooldown-delta)
 if trigger_held and cooldown<=.000001:
  _fire(profile);cooldown=INTERVAL # Never catch up with a burst after a stall.
func _fire(profile: Dictionary) -> void:
 var slot:=ages.find(-1.)
 if slot<0:pool_misses+=1;return
 var origin: Vector3=visual.socket.muzzle_position()
 var carrier: Transform3D=visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(visual.carrier_bone)
 var direction:=carrier.basis.y.normalized()
 ages[slot]=0.;directions[slot]=direction
 var bullet:=bullets[slot];bullet.global_position=origin;bullet.look_at(origin+direction,Vector3.UP);bullet.reset_physics_interpolation();bullet.show()
 shots_fired+=1;visual.play_rifle_recoil()
 flash_age=0.;flash_size=float(profile.flash_scale)*(.94+.06*(shots_fired%3));flash.scale=Vector3.ONE*flash_size
 flash.get_node("Visual").rotation.z=(shots_fired%4)*PI/8.;flash.global_position=origin;flash.look_at(origin+direction,Vector3.UP);flash.reset_physics_interpolation();flash.show()
 audio.play_event(&"pistol_shot")
func _move_projectiles(delta: float,profile: Dictionary) -> void:
 var speed:=float(profile.speed);var limit:=float(profile.range)/speed
 for i in BULLETS:
  if ages[i]<0.:continue
  var step:=minf(delta,maxf(0.,limit-ages[i]));ages[i]+=delta
  var bullet:=bullets[i];var destination:=bullet.global_position+directions[i]*speed*step
  query.from=bullet.global_position;query.to=destination
  var hit:=get_world_3d().direct_space_state.intersect_ray(query)
  if not hit.is_empty():
   var collider: Object=hit.collider
   if collider.has_method("take_damage") and collider.is_in_group("zombies"):collider.take_damage(int(profile.damage),directions[i])
   hit_count+=1;_impact(hit.position);audio.play_event(&"bullet_impact");ages[i]=-1.;bullet.hide()
  elif ages[i]>=limit:ages[i]=-1.;bullet.hide()
  else:bullet.global_position=destination
func _impact(point: Vector3) -> void:
 var slot:=impact_ages.find(-1.)
 if slot<0:return # Cosmetic capacity never blocks damage or firing.
 impact_ages[slot]=0.;impacts[slot].scale=Vector3.ONE;impacts[slot].global_position=point;impacts[slot].reset_physics_interpolation();impacts[slot].show()
func present(presentation: Node) -> void:
 if not flash.visible or presentation.display_world.is_empty():return
 var carrier: Transform3D=presentation.display_world[visual.carrier_bone]
 flash.global_position=carrier*visual.socket.hand_transforms[1]*muzzle_local
 flash.look_at(flash.global_position+carrier.basis.y.normalized(),Vector3.UP)
func active_projectiles() -> int:
 var count:=0
 for age in ages:
  if age>=0.:count+=1
 return count
func reset_fire() -> void:
 trigger_held=false;cooldown=0.;visual.cancel_rifle_recoil();ages.fill(-1.);impact_ages.fill(-1.);flash_age=1.;flash.hide()
 for node in bullets:node.hide()
 for node in impacts:node.hide()
