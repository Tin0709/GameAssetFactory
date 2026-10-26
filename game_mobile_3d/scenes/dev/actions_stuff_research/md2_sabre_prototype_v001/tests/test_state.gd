extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var path:="res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/combo_state.gd"
	check(FileAccess.file_exists(path),"New authored sabre state is implemented independently")
	if not failures.is_empty():quit(1);return
	var script=load(path)
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/assets/manifest.json"))
	for hz in [30,60]:
		var s=script.new();s.setup(manifest.clips);s.attack(true,false)
		var starts:Array[int]=[];var impacts:=0
		for tick in hz*2:
			s.advance(1./hz)
			for event:Dictionary in s.drain_events():
				if event.kind=="accepted":starts.append(event.index)
				if event.kind=="impact":impacts+=1
		check(starts.slice(0,3)==[0,1,2],"Hold traverses three source-duration attacks at "+str(hz))
		check(impacts>=3,"Every accepted attack opens exactly one authored impact-ready gate")
		s.cancel();s.attack(true,false);s.attack(false,false);s.advance(.1);s.request_attack(false);s.advance(.34)
		check(s.phase==&"recovery" and s.index==0,"Early tap expires before clip end")
		s.cancel();s.request_attack(false);s.advance(.30);s.request_attack(false);s.advance(.20)
		check(s.phase==&"attack" and s.index==1 and absf(s.time-(.5-13./30.))<.00001,"Late buffer chains and carries overshoot")
		s.cancel();s.request_attack(false);s.advance(13./30.)
		check(s.phase==&"recovery" and s.clip()=="Recovery1","Unbuffered attack enters its own recovery")
		s.advance(11./30.)
		check(s.phase==&"ready","Full source recovery returns ready")
		s.cancel();s.request_attack(true)
		check(s.clip()=="AirAttack","Airborne request chooses optional airborne alternate")
		s.advance(1.1);check(s.phase==&"ready","Air attack releases without stuck state")
		s.cancel();s.attack(true,false);s.advance(.3);s.release_inputs();s.advance(1.)
		check(s.phase==&"ready" and not s.held and s.buffer_until<0.,"Focus release clears held and buffered commands")
		var a=script.new();a.setup(manifest.clips);a.attack(true,false);a.advance(1.1)
		var b=script.new();b.setup(manifest.clips);b.attack(true,false)
		for tick in 132:b.advance(1./120.)
		check(a.phase==b.phase and a.index==b.index and absf(a.time-b.time)<.00001,"Low-rate overshoot matches 120Hz event clock")
	print("SABRE_STATE ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
