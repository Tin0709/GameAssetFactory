extends SceneTree
const BASE="res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/"
var errors:Array[String]=[]
var checks:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	check(ResourceLoader.exists(BASE+"profile.gd") and ResourceLoader.exists(BASE+"override_resolver.gd"),"Missing reusable graphics profile/resolver implementation")
	if not errors.is_empty():finish();return
	var Profile=load(BASE+"profile.gd");var Solver=load(BASE+"override_resolver.gd")
	var p=Profile.new();p.profile_id="original-test";p.fields={"energy":1.,"fill":Vector3(.2,.3,.4)};p.phases={"day":{"energy":2.}}
	check(p.validate().is_empty(),"Valid original profile")
	check(p.phase_fields("day").energy==2. and p.phase_fields("day").fill==p.fields.fill,"Phase inherits fields")
	var copy:Dictionary=p.phase_fields("day");copy.energy=9.
	check(p.fields.energy==1.,"Profile snapshot cannot mutate source")
	p.fields["energy"]=NAN;check(not p.validate().is_empty(),"Nonfinite profile rejected");p.fields.energy=1.
	p.fields["exposure_bounds"]=Vector2(3,2);check(not p.validate().is_empty(),"Inverted exposure rejected");p.fields.erase("exposure_bounds")
	var overrides:Array[Dictionary]=[{"id":"a","priority":2,"weight":.5,"fields":{"energy":3.}},{"id":"b","priority":2,"weight":.5,"fields":{"energy":5.}},{"id":"low","priority":1,"weight":1.,"fields":{"energy":100.,"fill":Vector3.ONE}}]
	var r:Dictionary=Solver.resolve(p.fields,overrides)
	check(is_equal_approx(r.energy,4.),"Tied override weights normalize without brightness addition")
	check(r.fill==Vector3.ONE,"Masked fields inherit lower priority")
	overrides.reverse();check(Solver.resolve(p.fields,overrides)==r,"Override resolution order independent")
	check(Solver.resolve(p.fields,[{"priority":9,"weight":0.,"fields":{"energy":99.}}]).energy==1.,"Zero override no-op")
	var color_test:Dictionary=Solver.resolve({"sun_color_srgb":Vector3.ZERO},[{"weight":.5,"fields":{"sun_color_srgb":Vector3.ONE}}])
	check(absf(color_test.sun_color_srgb.x-.73535698)<.00001,"sRGB display colors blend through linear light")
	var reference:=0.
	for hz in [30,60,120]:
		var state:={"energy":0.};var velocity:={}
		for i in hz:
			var step:Dictionary=Solver.advance(state,{"energy":1.},velocity,1./hz,.5);state=step.state;velocity=step.velocity
		if hz==30:reference=state.energy
		check(absf(float(state.energy)-reference)<.00001,"Analytic graphics transition independent of render rate"+str(hz))
		var before:float=state.energy
		var zero:Dictionary=Solver.advance(state,{"energy":0.},velocity,0.,.5)
		check(zero.state.energy==before,"Retarget preserves displayed value")
	finish()
func finish()->void:
	print("GRAPHICS_PROFILE_CHECKS ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
