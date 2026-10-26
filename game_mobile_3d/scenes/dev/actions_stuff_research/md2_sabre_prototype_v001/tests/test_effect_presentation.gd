extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var fx=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/effects.gd").new();root.add_child(fx)
	check(fx.has_method("samples_at"),"Blade trail needs the same interpolated display time as the weapon")
	if not failures.is_empty():fx.free();quit(1);return
	fx.sample(.01,true,Vector3.ZERO,Vector3(0,1,0),1);fx.sample(.01,true,Vector3(1,0,0),Vector3(1,1,0),1)
	var saved:Array=fx.samples.duplicate(true);var clock:float=fx.clock;var bursts:int=fx.bursts
	var visible:Array=fx.samples_at(.015,Vector3(.5,0,0),Vector3(.5,1,0))
	check(visible.size()==2 and visible[-1].tip==Vector3(.5,1,0) and absf(visible[-1].time-.015)<.00001,"Ribbon's displayed endpoint matches interpolated blade")
	check(fx.samples_at(.005).is_empty(),"Future trail points cannot render before the effect starts")
	check(fx.samples_at(clock)==saved,"Current-time presentation retains original samples")
	fx.present(.015,Vector3(.5,0,0),Vector3(.5,1,0))
	check(fx.samples==saved and fx.clock==clock and fx.bursts==bursts,"Display does not resample/advance/retrigger physical VFX")
	check(fx.particles.size()==48 and fx.samples.size()<=fx.MAX_SAMPLES,"Display retains bounded existing VFX pools")
	Engine.physics_ticks_per_second=30;fx.sample(.135,false,Vector3.ZERO,Vector3.ZERO,1)
	var retained:=false
	for point:Dictionary in fx.samples_at(.135):retained=retained or absf(float(point.time)-.01)<.000001
	check(retained,"Physically old ribbon point survives while still alive at delayed display time")
	check(fx.has_method("particle_at"),"Delayed presentation needs retained particle states")
	if fx.has_method("particle_at"):
		fx.reset();fx.sample(.01,true,Vector3.ZERO,Vector3.UP,2)
		while fx.particles[0].life>.008:fx.sample(.004,false,Vector3.ZERO,Vector3.ZERO,2)
		var prior_time:float=fx.clock;var prior_position:Vector3=fx.particles[0].position;var prior_life:float=fx.particles[0].life
		fx.sample(.016,false,Vector3.ZERO,Vector3.ZERO,2)
		var past:Dictionary=fx.particle_at(0,prior_time)
		check(fx.particles[0].life==0. and absf(float(past.life)-prior_life)<.00001 and Vector3(past.position).distance_to(prior_position)<.00001,"Expired physical spark remains visible at the correct earlier display state")
		var birth:float=fx.particles[0].born;fx.sample(.001,true,Vector3.ZERO,Vector3.UP,3)
		check(fx.particles[0].born==birth,"Dead particle slot cannot be reused before delayed display has expired")
	print("SABRE_EFFECT_PRESENTATION ",JSON.stringify({"checks":checks,"failures":failures}));fx.free();quit(0 if failures.is_empty() else 1)
