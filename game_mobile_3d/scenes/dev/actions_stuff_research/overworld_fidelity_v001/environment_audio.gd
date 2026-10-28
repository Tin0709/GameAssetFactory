extends Node3D
## Exact external media, original event/mix adapter. Native Wwise graphs unavailable.
var ambient_enabled:=true:
	set(value):
		ambient_enabled=value
		if not value:
			for bed:Dictionary in beds:
				for voice:AudioStreamPlayer in bed.voices:voice.stop()
				bed.started=false;bed.fading=false;bed.elapsed=0.
			for voice:AudioStreamPlayer3D in nature_voices:voice.stop()
var footsteps_enabled:=true
var rustle_enabled:=true
var actor:CharacterBody3D
var meadow:Node3D
var reader:RefCounted
var config:Dictionary={}
var ambience_gain_db:=0.
var effects_gain_db:=0.
var groups:Dictionary={}
var beds:Array[Dictionary]=[]
var step_voices:Array[AudioStreamPlayer3D]=[]
var rustle_voices:Array[AudioStreamPlayer3D]=[]
var nature_voices:Array[AudioStreamPlayer3D]=[]
var clock:=0.
var event_count:={"grass":0,"dirt":0,"rustle":0,"nature":0,"birds":0,"landing":0}
var last_sources:Dictionary={}
var events:Array[Dictionary]=[]
var loaded_count:=0
var rejected_count:=0
var _random:=RandomNumberGenerator.new()
var _last_choice:Dictionary={}
var _contacts:Array[bool]=[false,false]
var _was_grounded:=true
var _last_step:=-10.
var _next_nature:=4.
var _next_bird:=2.5
var _step_index:=0
var _rustle_index:=0
var _nature_index:=0

func setup(body:CharacterBody3D,field:Node3D,bundle:RefCounted)->void:
	actor=body;meadow=field;reader=bundle;config=reader.data.get("audio_config",{});_random.seed=281027
	for key:String in reader.data.audio:
		var rows:Array=[]
		for row:Dictionary in reader.data.audio[key]:
			var stream:AudioStreamOggVorbis=reader.audio_stream(row)
			if stream==null:rejected_count+=1;continue
			stream.loop=false;rows.append({"stream":stream,"name":row.name,"seconds":row.seconds});loaded_count+=1
		groups[key]=rows
	_make_bed("wind",float(config.get("wind_db",-19.)))
	for i in 4:step_voices.append(_voice("Footstep",float(config.get("footstep_radius_m",8.))));rustle_voices.append(_voice("Vegetation",float(config.get("environment_radius_m",7.))))
	for i in 3:
		var voice:=_voice("MeadowNature",float(config.get("environment_radius_m",20.)));voice.unit_size=float(config.get("nature_unit_size_m_adapter",2.));nature_voices.append(voice)
	var listener:=AudioListener3D.new();listener.name="GroundLevelAudioListener";actor.add_child(listener);listener.position.y=1.55;listener.make_current()
	actor.physics_pose_ready.connect(_on_pose)
	actor.presentation_reset.connect(reset_contacts)
	print("OVERWORLD_AUDIO_READY ",JSON.stringify({"loaded":loaded_count,"rejected":rejected_count,"groups":groups.keys(),"scope":reader.data.audio_scope}))

func _voice(label:String,distance:float)->AudioStreamPlayer3D:
	var voice:=AudioStreamPlayer3D.new();voice.name=label;voice.max_distance=distance;voice.unit_size=2.;voice.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE;voice.max_db=-3.;add_child(voice);return voice

func _make_bed(key:String,db:float)->void:
	if groups.get(key,[]).is_empty():return
	var row:Dictionary=groups[key][0];var voices:Array[AudioStreamPlayer]=[]
	for i in 2:
		var voice:=AudioStreamPlayer.new();voice.name="Ambient_"+key+str(i);voice.stream=row.stream;voice.volume_db=-80.;add_child(voice);voices.append(voice)
	beds.append({"voices":voices,"key":key,"name":row.name,"length":row.seconds,"db":db,"elapsed":0.,"slot":0,"started":false,"fading":false,"fade_elapsed":0.,"fade":minf(2.,row.seconds*.15)})

func _process(delta:float)->void:
	clock+=delta
	if not ambient_enabled:return
	for bed:Dictionary in beds:_advance_bed(bed,delta)
	if clock>=_next_nature:
		_next_nature=clock+_random.randf_range(12.,21.)
		var at:Vector3=actor.global_position+Vector3(_random.randf_range(-10.,10.),.2,_random.randf_range(-10.,10.))
		_play("nature",nature_voices[_nature_index%3],at,float(config.get("insects_db",-23.)),1.);_nature_index+=1
	if clock>=_next_bird:
		_next_bird=clock+_random.randf_range(5.,12.)
		var at:Vector3=actor.global_position+Vector3(_random.randf_range(-8.,8.),_random.randf_range(1.5,3.5),_random.randf_range(-8.,8.))
		_play("birds",nature_voices[_nature_index%3],at,float(config.get("birds_db",-18.)),1.);_nature_index+=1

func _advance_bed(bed:Dictionary,delta:float)->void:
	var voices:Array=bed.voices
	if not bed.started:
		bed.started=true;bed.slot=0;bed.elapsed=0.;bed.fading=false;voices[0].play()
	bed.elapsed+=delta
	# The recording already contains dynamic wind; do not add unverified gain wobble.
	var gain:float=float(bed.db)+ambience_gain_db
	var a:int=bed.slot;var b:int=1-a
	if not bed.fading and float(bed.elapsed)>=float(bed.length)-float(bed.fade):
		bed.fading=true;bed.fade_elapsed=0.;voices[b].play()
	if bed.fading:
		bed.fade_elapsed+=delta
		var phase:=clampf(float(bed.fade_elapsed)/float(bed.fade),0.,1.)*PI*.5
		voices[a].volume_db=gain+linear_to_db(maxf(.0001,cos(phase)));voices[b].volume_db=gain+linear_to_db(maxf(.0001,sin(phase)))
		if float(bed.fade_elapsed)>=float(bed.fade):voices[a].stop();bed.slot=b;bed.elapsed=bed.fade_elapsed;bed.fading=false
	else:voices[a].volume_db=gain+linear_to_db(minf(1.,float(bed.elapsed)/1.2))

func _pick(key:String)->Dictionary:
	var rows:Array=groups.get(key,[])
	if rows.is_empty():return {}
	var index:=_random.randi_range(0,rows.size()-1)
	if rows.size()>1 and index==int(_last_choice.get(key,-1)):index=(index+_random.randi_range(1,rows.size()-1))%rows.size()
	_last_choice[key]=index;return rows[index]

func _play(key:String,voice:AudioStreamPlayer3D,point:Vector3,db:float,pitch:float)->void:
	var row:=_pick(key)
	if row.is_empty():return
	voice.stop();voice.stream=row.stream;voice.global_position=point;voice.volume_db=db+(ambience_gain_db if key in ["nature","birds"]else effects_gain_db);voice.pitch_scale=pitch;voice.play()
	event_count[key]=int(event_count.get(key,0))+1;last_sources[key]=row.name
	events.append({"time":clock,"key":key,"name":row.name,"at":[point.x,point.y,point.z]})
	if events.size()>256:events.pop_front()

func _on_pose()->void:
	if actor.direction_adapter==null:return
	var grounded:bool=actor._grounded
	var moving:=Vector2(actor.velocity.x,actor.velocity.z).length()>.4
	var soles:Array=actor.direction_adapter.observe_soles(actor.global_position.y,grounded)
	var land:bool=grounded and not _was_grounded
	for side in 2:
		var height:float=soles[side].height
		var contact:bool=grounded and height<(.11 if _contacts[side] else .055)
		var rising_contact:bool=contact and not _contacts[side]
		_contacts[side]=contact
		if not actor.review_clip.is_empty() or not grounded or (not moving and not land):continue
		if (rising_contact or land) and clock-_last_step>.12:
			_last_step=clock
			var position:Vector3=soles[side].center
			var key:="dirt" if meadow.is_path(position) else "grass"
			if footsteps_enabled:
				_play(key,step_voices[_step_index%4],position,float(config.get("landing_db",-9.)) if land else float(config.get("footsteps_db",-14.)),1.);_step_index+=1
				if land:event_count.landing+=1
			if rustle_enabled and meadow.interactions_enabled and meadow.foliage_density(position)>.6:
				_play("rustle",rustle_voices[_rustle_index%4],position+Vector3.UP*.3,float(config.get("rustle_db",-22.))-(3. if actor.current_speed<4. else 0.),1.);_rustle_index+=1
	_was_grounded=grounded

func reset_contacts()->void:
	_contacts=[false,false];_was_grounded=true;_last_step=clock
	for voice:AudioStreamPlayer3D in step_voices:voice.stop()
	for voice:AudioStreamPlayer3D in rustle_voices:voice.stop()

func snapshot()->Dictionary:
	return {"loaded":loaded_count,"rejected":rejected_count,"events":event_count,"last_sources":last_sources,"ambient_enabled":ambient_enabled,"footsteps_enabled":footsteps_enabled,"listener_on_player":true,"mix":"Original adapter; native event routing/gains/attenuation unverified"}
