extends Node
## Original private samples, decoded transiently. Trigger, mix and layering are
## explicit prototype choices; this is not a recovered Wwise event graph.
const VOICE_CAPACITY:=4
const MAX_PENDING:=8
var voices:Array[AudioStreamPlayer]=[]
var groups:Dictionary={}
var clip_play_rates:Dictionary={}
var clip_aliases:Dictionary={} # Explicit prototype sample mapping for new source clips.
var pending:Array[Dictionary]=[]
var is_event_valid:Callable
var timeline_provider:Callable
var available_count:=0
var rejected_count:=0
var event_count:=0
var played_count:=0
var clock:=0.
var last_serial:=-1
var last_sources:Array[String]=[]
var enabled:=true:
	set(value):
		enabled=value
		if not enabled:reset()
var _voice:=0
var _choices:Dictionary={}

static func resolve_private_file(research_root:String,relative:String)->String:
	if not research_root.is_absolute_path() or relative.is_absolute_path():return ""
	var normalized:=research_root.replace("\\","/").simplify_path().trim_suffix("/")+"/"
	var project:=ProjectSettings.globalize_path("res://").replace("\\","/").simplify_path().trim_suffix("/")+"/"
	if normalized.to_lower().begins_with(project.to_lower()):return ""
	var target:=normalized.path_join(relative).simplify_path()
	return target if target.to_lower().begins_with(normalized.to_lower()) else ""

func setup(research_root:String)->void:
	reset();groups.clear();available_count=0;rejected_count=0;_choices.clear()
	event_count=0;played_count=0;process_physics_priority=10
	if voices.is_empty():
		for i in VOICE_CAPACITY:
			var player:=AudioStreamPlayer.new();player.name="PrivateSabreVoice%d"%i
			player.volume_db=-14.;player.pitch_scale=1.;add_child(player);voices.append(player)
	var path:=resolve_private_file(research_root,"reports/prototype_sabre/private_media_manifest.json")
	if path.is_empty() or not FileAccess.file_exists(path):return
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema","")!="sabre-private-media/1":return
	for key:String in data.get("groups",{}):
		var entries:Array=[]
		for entry:Dictionary in data.groups[key]:
			var source:=resolve_private_file(research_root,String(entry.get("source","")))
			if source.is_empty() or not source.ends_with(".ogg") or not FileAccess.file_exists(source):rejected_count+=1;continue
			if FileAccess.get_sha256(source)!=String(entry.get("sha256","")):rejected_count+=1;continue
			var stream:=AudioStreamOggVorbis.load_from_file(source)
			if stream==null or absf(stream.get_length()-float(entry.get("duration",0.)))>.002:rejected_count+=1;continue
			stream.loop=false;entries.append({"stream":stream,"source":entry.source,"delay":float(entry.get("trigger_delay_seconds",0.)),"peak":float(entry.get("sample_envelope_peak_seconds",0.)),"target":float(entry.get("motion_landmark_seconds",0.))});available_count+=1
		groups[key]=entries

func trigger_attack(_index:int,clip:String,serial:int,event_time:float=-1.)->void:
	if not enabled or serial<=last_serial:return
	clip=String(clip_aliases.get(clip,clip))
	if not groups.has(clip) or groups[clip].is_empty():return
	last_serial=serial;last_sources.clear();event_count+=1
	var rate:=maxf(.001,float(clip_play_rates.get(clip,1.)))
	var at:=event_time if event_time>=0. else clock
	_schedule_group(clip,serial,rate,at)
	if clip=="Attack3":_schedule_group("Attack3Whoosh",serial,rate,at)

func _schedule_group(key:String,serial:int,rate:float,accepted_at:float)->void:
	var entries:Array=groups.get(key,[])
	if entries.is_empty():return
	var index:int=int(_choices.get(key,0))%entries.size();_choices[key]=index+1
	var entry:Dictionary=entries[index]
	if pending.size()>=MAX_PENDING:pending.pop_front()
	# Move the envelope peak, not the source sample pitch. Targets are source
	# motion landmarks, not recovered native Wwise notifies.
	var delay:=maxf(0.,float(entry.target)/rate-float(entry.peak))
	pending.append({"at":accepted_at+delay,"entry":entry,"serial":serial});last_sources.append(entry.source)

func _physics_process(delta:float)->void:advance(delta)

func advance(delta:float)->void:
	# Source mode shares the actor timeline, including after mute/reset/review.
	clock=maxf(0.,float(timeline_provider.call())) if timeline_provider.is_valid() else clock+maxf(0.,delta)
	var future:Array[Dictionary]=[]
	for event:Dictionary in pending:
		if not enabled or (is_event_valid.is_valid() and not is_event_valid.call(int(event.serial))):continue
		if float(event.at)>clock+.0000001:future.append(event);continue
		var player:AudioStreamPlayer=voices[_voice];_voice=(_voice+1)%voices.size()
		player.stop();player.stream=event.entry.stream;player.play();played_count+=1
	pending=future

func reset()->void:
	for player:AudioStreamPlayer in voices:player.stop();player.stream=null
	last_serial=-1;last_sources.clear();pending.clear();_voice=0;clock=0.;_choices.clear()

func _exit_tree()->void:reset()
