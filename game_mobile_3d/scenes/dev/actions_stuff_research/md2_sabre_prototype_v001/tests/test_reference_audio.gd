extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var script=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
	check(script!=null,"External original-audio adapter exists")
	if script==null:quit(1);return
	var a=script.new();root.add_child(a)
	a.setup("C:/a_missing_research_workspace")
	check(a.available_count==0,"Missing private audio leaves silent fallback")
	check(a.voices.size()==4,"Audio uses a bounded four-voice pool")
	a.trigger_attack(0,"Attack1",1)
	check(a.event_count==0,"No nonexistent source audio is played")
	var research:String=OS.get_environment("MD2_RESEARCH_ROOT")
	if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
	check(script.resolve_private_file(research,"../outside.ogg").is_empty(),"Relative traversal cannot escape Research")
	check(script.resolve_private_file(research,"C:/outside.ogg").is_empty(),"Absolute media entries are rejected")
	check(script.resolve_private_file(ProjectSettings.globalize_path("res://"),"anything.ogg").is_empty(),"Proprietary media cannot be loaded from the project")
	a.setup(research)
	check(a.get("pending")!=null,"Reference audio schedules source peaks against motion timing")
	if a.get("pending")==null:a.free();quit(1);return
	a.set_physics_process(false)
	check(a.available_count==15,"All fifteen original Sabre variants decode in memory")
	check(a.rejected_count==0,"All requested source hashes and durations validate")
	var external_resources:=true
	for group:Array in a.groups.values():
		for entry:Dictionary in group:
			if not entry.stream.resource_path.is_empty():external_resources=false
	check(external_resources,"Original audio streams have no saved project resource path")
	a.trigger_attack(0,"Attack1",2)
	check(a.event_count==1 and a.last_sources.size()==1,"First attack plays one original Sabre sample")
	check(a.pending.size()==1 and a.played_count==0,"Accepted swing waits for its measured source-envelope offset")
	var first:Dictionary=a.groups.Attack1[0]
	a.advance(float(first.delay)*.5)
	check(a.played_count==0,"A queued sample cannot play before its aligned time")
	a.advance(float(first.delay)*.6+.000001)
	check(a.played_count==1,"Aligned swing starts once after its queued delay")
	a.trigger_attack(0,"Attack1",2)
	check(a.event_count==1,"An accepted serial cannot play twice")
	a.trigger_attack(2,"Attack3",3)
	check(a.event_count==2 and a.last_sources.size()==2,"Finisher layers separate source swing and whoosh")
	check(a.pending.size()==2,"Finisher layers have independent source-envelope offsets")
	a.advance(.34)
	check(a.played_count==3 and a.pending.is_empty(),"Both finisher layers are dispatched within its fast-motion phase")
	var alignment_ok:=true
	for group:Array in a.groups.values():
		for entry:Dictionary in group:
			if absf(float(entry.delay)+float(entry.peak)-float(entry.target))>.00001:alignment_ok=false
	check(alignment_ok,"All fifteen source envelope peaks align to their documented motion landmark")
	for i in range(4,104):a.trigger_attack(i%3,"Attack%d"%(i%3+1),i)
	check(a.voices.size()==4 and a.get_child_count()==4,"Repeated combos allocate no additional voices")
	check(a.pending.size()<=8,"Pending source events have a finite queue budget")
	var count:int=a.event_count;a.enabled=false;a.trigger_attack(0,"Attack1",105)
	check(a.event_count==count,"Muted reference audio does not trigger")
	var muted:=true
	for player:AudioStreamPlayer in a.voices:
		if player.playing:muted=false
	check(muted,"Muting immediately stops existing source voices")
	check(a.pending.is_empty(),"Muting clears delayed events as well as live voices")
	a.enabled=true;a.reset()
	check(a.last_serial==-1 and a.last_sources.is_empty(),"Reset clears audio event state")
	var stopped:=true
	for player:AudioStreamPlayer in a.voices:
		if player.playing or player.stream!=null:stopped=false
	check(stopped,"Reset stops and releases all source voices")
	a.is_event_valid=func(_serial:int)->bool:return false
	a.trigger_attack(0,"Attack1",106);var played:int=a.played_count;a.advance(1.)
	check(a.played_count==played and a.pending.is_empty(),"Interrupted attacks cannot emit delayed swing sounds")
	a.is_event_valid=Callable();a.reset()
	if a.get("clip_play_rates")!=null:
		a.clip_play_rates={"Attack1":1.2,"Attack2":1.2,"Attack3":1.}
		a.trigger_attack(0,"Attack1",107)
		var scheduled:Dictionary=a.pending[0];var entry:Dictionary=scheduled.entry
		check(absf(float(scheduled.at)+float(entry.peak)-float(entry.target)/1.2)<.000001,"Configured faster source pose keeps audio envelope peak aligned")
		check(a.voices[0].pitch_scale==1.,"Faster source pose does not pitch-shift original Sabre samples")
	else:check(false,"Audio exposes independent per-clip motion-rate alignment")
	var accepts_time:=false
	for method:Dictionary in a.get_method_list():
		if method.name=="trigger_attack":accepts_time=method.args.size()==4
	check(accepts_time,"Audio accepts exact sub-tick source event timestamp")
	if accepts_time:
		a.reset();a.clock=.3333333333;a.trigger_attack(1,"Attack2",108,.3611111111)
		var timed:Dictionary=a.pending[0]
		check(absf(float(timed.at)-(.3611111111+maxf(0.,float(timed.entry.target)/1.2-float(timed.entry.peak))))<.000001,"Chained sound uses accepted event time rather than physics tick start")
		a.timeline_provider=func()->float:return 20.3333333333
		a.enabled=false;a.enabled=true;a.trigger_attack(0,"Attack1",109,20.3);var before_unmute:int=a.played_count;a.advance(1./30.)
		check(a.played_count==before_unmute+1 and a.pending.is_empty(),"Mute/reset cannot desynchronize source audio from an actor already20seconds into gameplay")
		a.timeline_provider=Callable();a.reset();a.clip_play_rates["AirAttack"]=1.6;a.trigger_attack(0,"AirAttack",110)
		var aerial:Dictionary=a.pending[0]
		check(absf(float(aerial.at)+float(aerial.entry.peak)-float(aerial.entry.target)/1.6)<.000001,"Aerial envelope uses the same faster physics-cadence adapter as blade motion")
		a.reset();a.clip_aliases["NativeFinisher"]="Attack3";var count_before:int=a.event_count
		a.trigger_attack(2,"NativeFinisher",111)
		check(a.event_count==count_before+1 and a.pending.size()==2,"Actual montage finisher retains bounded prototype swing/whoosh mix through explicit alias")
	var report:={"checks":checks,"failures":failures,"available_sources":a.available_count,"voice_capacity":a.voices.size(),"native_mixer_recovered":false}
	var dir:="res://.validation/md2_sabre_prototype_v001"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	FileAccess.open(dir.path_join("reference-audio.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	a.free()
	# Let the audio mixing thread release the intentionally stressed playback pool.
	await create_timer(.15).timeout
	print("SABRE_REFERENCE_AUDIO ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
