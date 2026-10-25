extends "res://scenes/dev/actions_stuff_research/performance_lab_v001/physics_zombie.gd"
## Melee-only extensions; inherited Rifle damage and native death remain intact.
var poise:=36.
var poise_delay:=0.
var stagger_remaining:=0.
var melee_freeze:=0.
var poise_breaks:=0
func _ready()->void:
	super._ready()
	if is_instance_valid(target) and target.get("melee_controller")!=null:
		attack_damage=12 if target.melee_controller.equipped else 0
func apply_melee_hit(amount:int,direction:Vector3,impact:float,strength:float,freeze:float)->bool:
	if is_dead:return false
	var accepted:=take_damage(amount,direction)
	if not accepted:return false
	poise-=impact;poise_delay=1.2
	if poise<=0.:
		poise=36.;poise_breaks+=1;stagger_remaining=maxf(stagger_remaining,.55)
	if not is_dead:
		knockback=direction.normalized()*strength
		pending_attack=-1.;attack_visual_remaining=0.;attack_cooldown=maxf(attack_cooldown,.22)
		stagger_remaining=maxf(stagger_remaining,.10)
		melee_freeze=maxf(melee_freeze,freeze)
	return true
func parry_stagger()->void:
	if is_dead:return
	stagger_remaining=maxf(stagger_remaining,.7);poise=36.;poise_delay=1.2
	pending_attack=-1.;attack_visual_remaining=0.;attack_cooldown=maxf(attack_cooldown,.8)
	visual.hit_impulse((global_position-target.global_position).normalized() if is_instance_valid(target) else -global_basis.z)
func _physics_process(delta:float)->void:
	if not is_dead and melee_freeze>0.:
		melee_freeze=maxf(0.,melee_freeze-delta);return
	poise_delay=maxf(0.,poise_delay-delta)
	if poise_delay==0.:poise=minf(36.,poise+delta*8.)
	super._physics_process(delta)
func _advance_living_ai(delta:float)->void:
	if stagger_remaining>0.:
		stagger_remaining=maxf(0.,stagger_remaining-delta)
		pending_attack=-1.;attack_visual_remaining=0.;velocity=knockback
		velocity.y=-.2 if is_on_floor() else velocity.y-gravity*delta
		move_and_slide();knockback*=exp(-knockback_decay*delta)
		visual.play_state(&"Idle");return
	# The inherited damage call only carries direction. Identify its true sender
	# around that synchronous call, avoiding an ambiguous crowd proximity lookup.
	if is_instance_valid(target):target.melee_attacker=self
	super._advance_living_ai(delta)
	if is_instance_valid(target):target.melee_attacker=null
