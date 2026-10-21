extends SceneTree
## Behavior contracts for the same lab's new field, not another test scene.
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _initialize():call_deferred("run")
func run():
	var path:="res://scenes/dev/actions_stuff_research/grass_md2_v001/grass_field.gd"
	check(ResourceLoader.exists(path),"Existing lab provides the requested30x30grass field")
	if failures.is_empty():
		var actor:=CharacterBody3D.new();root.add_child(actor)
		var field=load(path).new();root.add_child(field);field.setup(actor)
		field.set_process(false);field.set_physics_process(false)
		check(field.cells.size()==900,"Every one of900block cells is planted")
		check(field.instance_count>=900 and field.instance_count<=2000,"Dense coverage is bounded")
		check(field.short_count>300 and field.tall_count>300,"Random population contains both heights throughout the field")
		check(field.batch_count<=32,"Grass is regionally instanced, not900individual scripts")
		check(field.meshes.size()==8,"The existing four short/four tall variants are reused")
		for mesh in field.meshes:
			var arrays:Array=mesh.surface_get_arrays(0)
			var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
			var roots:=0
			for c in colors:
				if c.r<.00001:roots+=1
			check(roots>0,"Every variant carries immutable zero-weight roots")
		var state_script=load("res://scenes/dev/actions_stuff_research/grass_md2_v001/interaction_field.gd")
		# A brush must leave a real elastic reversal, not only ease toward zero.
		var liquid=state_script.new();liquid.advance(0.,Vector3.ZERO,Vector3.ZERO)
		for f in 10:liquid.advance(1./60.,Vector3.ZERO,Vector3.ZERO)
		var probe:=Vector2(.35,.35);var initial:Vector2=liquid.sample_at(probe)
		check(initial.length()>.20,"A light contact produces a prompt visible bend")
		for f in range(1,41):liquid.advance(1./60.,Vector3(float(f)*.125,0,0),Vector3(7.5,0,0))
		var reverse:=0.;var tail_peak:=0.
		for f in 100:
			liquid.advance(1./60.,Vector3(5,0,0),Vector3.ZERO)
			var value:Vector2=liquid.sample_at(probe)
			reverse=minf(reverse,value.dot(probe.normalized()));tail_peak=maxf(tail_peak,value.length())
		check(reverse<-.025,"Departed grass sways through rest like soft jelly")
		check(liquid.sample_at(probe).length()<.015,"Elastic oscillation loses energy rather than accumulating")
		var samples:={}
		for fps in [30,60]:
			var state=state_script.new();state.advance(0.,Vector3(-3,0,0),Vector3.ZERO)
			for f in range(1,2*fps+1):
				var t:float=float(f)/float(fps)
				state.advance(1./fps,Vector3(-3.+3.*minf(t,1.),0,0),Vector3(3 if t<=1. else 0,0,0))
			var contact:Vector2=state.sample_at(Vector2(.35,.35))
			check(contact.length()>.15,"Standing proximity retains a readable contact bend")
			check(contact.dot(Vector2(.35,.35))>0.,"Grass bends away from the stopped player")
			samples[fps]=contact
			for f in range(1,3*fps+1):
				state.advance(1./fps,Vector3(minf(9.,float(f)/fps*5.),0,0),Vector3(5,0,0))
			check(state.sample_at(Vector2(.35,.35)).length()<.002,"Departed grass recovers without persistent drift")
			check(state.active.size()<160,"Shared state work stays local and bounded")
			state.reset();check(state.sample_at(Vector2(.35,.35))==Vector2.ZERO,"R/teleport reset removes the old trail")
		check(samples[30].distance_to(samples[60])<.003,"30/60FPScontact converges consistently")
		field.free();actor.free()
	var report:={"checks":checks,"failures":failures}
	print("MD2_GRASS_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
