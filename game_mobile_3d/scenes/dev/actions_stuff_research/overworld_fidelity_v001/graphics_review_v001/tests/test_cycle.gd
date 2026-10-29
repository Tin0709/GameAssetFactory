extends SceneTree
const Track=preload("../phase_track.gd")
var errors:Array[String]=[]
func check(value:bool,label:String)->void:
	if not value:errors.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var lab=load("res://scenes/dev/MD2OverworldFidelityTest.tscn").instantiate();root.add_child(lab)
	var o:Node=lab.graphics_foundation
	o.seek_cycle(.15,true)
	var day:float=lab.md2_lighting.sun.light_energy
	for i in 1001:
		var state:Dictionary=Track.sample(o.profile,float(i)/1000.)
		for v:Variant in state.values():
			if v is float:check(is_finite(v),"Finite phase values")
			elif v is Vector3:check(v.is_finite(),"Finite phase vectors")
	check(Track.sample(o.profile,0.)==Track.sample(o.profile,1.),"Cycle wraps exactly")
	o.seek_cycle(.65,true);check(lab.md2_lighting.sun.light_energy<day*.3,"Night key light dims")
	o.set_candidate(false);check(lab.md2_lighting.environment.ambient_light_energy==o.environment_baseline.ambient_light_energy,"A/B restores ambient")
	o.set_candidate(true);o.seek_cycle(.15,true)
	check(is_equal_approx(lab.md2_lighting.sun.light_energy,day),"Day key restored")
	o.set_cycle_enabled(true);var before:float=o.cycle_position;o._process(1.)
	check(o.cycle_position>before,"Auto cycle advances")
	o.set_cycle_enabled(false);before=o.cycle_position;o._process(1.);check(o.cycle_position==before,"Cycle pause holds position")
	print("CYCLE_CHECKS ",JSON.stringify({"errors":errors,"native_cycle_duration_verified":false,"preview_seconds":o.cycle_seconds}));lab.free();quit(0 if errors.is_empty()else 1)
