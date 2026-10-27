extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a);a.set_physics_process(false)
	var folder:String=a.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/runtime_locomotion/combat/refinement")
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("ground-input-replay.json")));var results:Array=[]
	for policy:String in ["legacy_buffer","live_hold"]:
		var s=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/combo_state.gd").new();s.setup(a.clips);s.configure_native(a.runtime_locomotion_profile.combat);s.native_input_policy=policy
		var events:Array=[];var previous:=0.
		for sample:Dictionary in data.samples:
			s.advance(float(sample.t)-previous);previous=sample.t
			for e:Dictionary in s.drain_events():
				if e.kind=="accepted":events.append({"index":e.index,"at":e.at})
			s.attack(sample.lmb);s.advance(0.)
			for e:Dictionary in s.drain_events():
				if e.kind=="accepted":events.append({"index":e.index,"at":e.at})
		var errors:Array=[];var indices:=true
		for i in mini(events.size(),data.native_accepts.size()):
			indices=indices and events[i].index==data.native_accepts[i].index
			errors.append(absf(float(events[i].at)-float(data.native_accepts[i].at_source_estimated)))
		var mean_error:=0.;var worst:=0.
		for error:float in errors:mean_error+=error/errors.size();worst=maxf(worst,error)
		results.append({"policy":policy,"accepted":events.size(),"native_accepted":data.native_accepts.size(),"indices_match":indices,"mean_absolute_error_s":mean_error,"maximum_error_s":worst,"events":events})
		if policy=="live_hold":
			check(events.size()==data.native_accepts.size() and indices,"Actual recorded input produces the native ordered15attacks")
			check(worst<.035,"Accepted source-clock differences fit frame/read/input ordering bound")
	check(results[1].mean_absolute_error_s<results[0].mean_absolute_error_s*.25,"Live input gating materially improves over the220ms queued-tap adapter")
	var report:={"checks":checks,"failures":failures,"results":results,"scope":data.scope};FileAccess.open(folder.path_join("input-replay-comparison.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_NATIVE_INPUT_REPLAY ",JSON.stringify(report));a.free();quit(0 if failures.is_empty() else 1)
