extends SceneTree
var failures:Array[String]=[]
var checks:=0
var events:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a);a.set_physics_process(false)
	check(a.has_signal("source_locomotion_event"),"Actor exposes original phase-timed locomotion event hook")
	if a.has_signal("source_locomotion_event"):
		a.source_locomotion_event.connect(func(notify:String,clip:String,source_seconds:float,simulation_seconds:float):events.append({"name":notify,"clip":clip,"source":source_seconds,"at":simulation_seconds}))
		a._grounded=true;a._move_requested=true;a._run_requested=true;a.current_speed=7.;a._play("Run",0.)
		var duration:float=a.clips.Run.duration
		a._animate(duration/a._playback_speed if a._playback_speed>1. else duration/1.25)
		var expected:Array=a.runtime_locomotion_profile.locomotion_events[a.clips.Run.source_name].events
		check(events.size()==expected.size(),"One physical cycle emits each native run notify exactly once")
		for i in mini(events.size(),expected.size()):
			check(events[i].name==expected[i].name and absf(events[i].source-expected[i].time)<.00001,"Native event name/source time retained "+str(i))
			check(absf(events[i].at-expected[i].time/1.25)<.00001,"Notify uses actual source cadence without shifting its source key "+str(i))
		var count:=events.size();a._animate(duration/1.25)
		check(events.size()==count*2,"Loop seam does not drop or duplicate native notifications")
		a.review("Run");a._animate(duration*2.)
		check(events.size()==count*2,"Raw review does not trigger gameplay event hooks")
		a.reset_actor();check(a.movement_measurements().get("source_locomotion_event_count",-1)==0,"Reset clears event diagnostics")
		var source:String=a.clips.Run.source_name
		var native_record:Dictionary=a.runtime_locomotion_profile.locomotion_events[source].duplicate(true)
		for invalid:Variant in [{},[],null,NAN,INF,"bad",-1.]:
			a.runtime_locomotion_profile.locomotion_events[source]=native_record.duplicate(true)
			a.runtime_locomotion_profile.locomotion_events[source].duration=invalid
			a._dispatch_locomotion_events("Run",0.,duration,duration)
			check(a.source_locomotion_event_count==0,"Malformed optional notify duration ignored: "+str(invalid))
	print("SABRE_LOCOMOTION_EVENTS ",JSON.stringify({"checks":checks,"failures":failures}));a.free();quit(0 if failures.is_empty() else 1)
