extends Node3D
## Exact external media, original event/mix adapter. Native Wwise graphs unavailable.
const LANDING_DIRECTORY := "extracted/2026-10-26 12-46-42/Game/Spicewood/Audio/Wwise/Events/Spicewood/Player/Locomotion/Jump"
const LANDING_FAMILIES := {
	"grass": ["grassPath", [
		"b0067dc6c4fc64831e5fd8abf9ae8a2942ac4e5c7733e58d780882021e974fa5",
		"776dd7c002b5b21b98a50db4c97f1716517fdb0b89c28c9d278f0df3e149d7d6",
		"c566493cc289830cd48919d99a0423a494df5bc32619965d3add5a7fa26cdc15",
		"9e2c47a54d249fa735f0469112712c69b36ba6710212b887e53bd591c0b6d2d6",
	]],
	"dirt": ["dirt", [
		"77417d94ee79bb903ddd8faaa5c569a0ef8aebd858a1c3b6b450c96a851b17c2",
		"8907de2b4fc67e86aca9cead2b0ac2369b972df17ff2251e05e060868a9f8551",
		"494d11c18fe43c36381593921dc769261dcb30deefa7feeeed8e8ed57178783f",
		"8e092d6a448354b7677ac934da925fb863995a1902ccfeca03066f425818cffe",
	]],
	"stone": ["stone", [
		"db0ee2fa00ff09a299a8ee91e9186da024313a8c23cd9bebe439cd2401a74eea",
		"9ee42099e7ecead99c65a14bced9c54fa00abf44911290015654c56e777cd87d",
		"34b30cfe0ba487db9aedf9112545e6b64b5af95f3ce09d11476288ba4b5d3ee0",
		"44cef66ab8bfb8edb59cee87e0d6ed7da7c1458d1b121202b73d4141814998d8",
	]],
}
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
var _terrain_contact: Callable
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
var event_count:={"grass":0,"dirt":0,"stone":0,"rustle":0,"nature":0,"birds":0,"landing":0}
var last_sources:Dictionary={}
var events:Array[Dictionary]=[]
var loaded_count:=0
var rejected_count:=0
var _random:=RandomNumberGenerator.new()
var _last_choice:Dictionary={}
var _next_nature:=4.
var _next_bird:=2.5
var _step_index:=0
var _rustle_index:=0
var _nature_index:=0
var _heavy_landing_frame := -1
var landing_contact: Callable
var protect_landing_voice := false
var _step_landing: Array[bool] = []

func setup(body:CharacterBody3D,field:Node3D,bundle:RefCounted, terrain_contact: Callable = Callable())->void:
	actor=body;meadow=field;reader=bundle;config=reader.data.get("audio_config",{});_random.seed=281027
	_terrain_contact = terrain_contact
	for key:String in reader.data.audio:
		var rows:Array=[]
		for row:Dictionary in reader.data.audio[key]:
			var stream:AudioStreamOggVorbis=reader.audio_stream(row)
			if stream==null:rejected_count+=1;continue
			stream.loop=false;rows.append({"stream":stream,"name":row.name,"seconds":row.seconds});loaded_count+=1
		groups[key]=rows
	for surface: String in LANDING_FAMILIES:
		if groups.has(surface):
			_load_landing_family(surface)
	# The flat grass lab supplies its own listener and only needs footsteps.
	if meadow == null:
		ambient_enabled = false
		rustle_enabled = false
	else:
		_make_bed("wind",float(config.get("wind_db",-19.)))
	for i in 4:
		step_voices.append(_voice("Footstep",float(config.get("footstep_radius_m",8.))))
		_step_landing.append(false)
		if meadow != null:
			rustle_voices.append(_voice("Vegetation",float(config.get("environment_radius_m",7.))))
	if meadow != null:
		for i in 3:
			var voice:=_voice("MeadowNature",float(config.get("environment_radius_m",20.)));voice.unit_size=float(config.get("nature_unit_size_m_adapter",2.));nature_voices.append(voice)
		var listener:=AudioListener3D.new();listener.name="GroundLevelAudioListener";actor.add_child(listener);listener.position.y=1.55;listener.make_current()
	actor.surface_contact.connect(_on_surface_contact)
	if actor.has_signal("heavy_jump_landed"):
		actor.heavy_jump_landed.connect(_on_heavy_landing)
	actor.presentation_reset.connect(reset_contacts)
	print("OVERWORLD_AUDIO_READY ",JSON.stringify({"loaded":loaded_count,"rejected":rejected_count,"groups":groups.keys(),"scope":reader.data.audio_scope}))

func _load_landing_family(surface: String) -> void:
	var family: Array = LANDING_FAMILIES[surface]
	var hashes: Array = family[1]
	var directory: String = reader.root.path_join(LANDING_DIRECTORY)
	var rows: Array = []
	for i in hashes.size():
		var name := "sfx_player_land_%s_%02d" % [family[0], i + 1]
		var stream: AudioStreamOggVorbis = reader.audio_stream({"path": directory.path_join(name + ".ogg"), "sha256": hashes[i]})
		if stream == null:
			rejected_count += 1
			continue
		stream.loop = false
		rows.append({"stream": stream, "name": name})
		loaded_count += 1
	groups["land_" + surface] = rows

func _on_heavy_landing(_point: Vector3, _direction: Vector3, _serial: int, _fall_height: float) -> void:
	_heavy_landing_frame = Engine.get_physics_frames()

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
	for voice:AudioStreamPlayer3D in nature_voices:
		if voice.playing:voice.volume_db=float(voice.get_meta("mix_base_db",-80.))+ambience_gain_db
	for voice:AudioStreamPlayer3D in step_voices+rustle_voices:
		if voice.playing:voice.volume_db=float(voice.get_meta("mix_base_db",-80.))+effects_gain_db
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
	voice.stop();voice.stream=row.stream;voice.global_position=point;voice.set_meta("mix_base_db",db);voice.volume_db=db+(ambience_gain_db if key in ["nature","birds"]else effects_gain_db);voice.pitch_scale=pitch;voice.play()
	event_count[key]=int(event_count.get(key,0))+1;last_sources[key]=row.name
	events.append({"time":clock,"key":key,"name":row.name,"at":[point.x,point.y,point.z]})
	if events.size()>256:events.pop_front()

func _on_surface_contact(point: Vector3, landed: bool) -> void:
	if not footsteps_enabled and not rustle_enabled:
		return
	var heavy := landed and _heavy_landing_frame == Engine.get_physics_frames()
	if heavy and not rustle_enabled:
		return
	var key := "grass"
	if _terrain_contact.is_valid():
		var resolver := landing_contact if landed and landing_contact.is_valid() else _terrain_contact
		var contact: Dictionary = resolver.call(point)
		if contact.is_empty():
			return
		point = contact.position
		key = contact.surface
	elif meadow != null:
		key = meadow.surface_at(point)
	if footsteps_enabled and not heavy:
		var db := float(config.get("landing_db", -9.0)) if landed else float(config.get("footsteps_db", -14.0))
		var cue := "land_" + key if landed and not groups.get("land_" + key, []).is_empty() else key
		var slot := _choose_step_slot(landed)
		if slot >= 0:
			_play(cue, step_voices[slot], point, db, 1.0)
			_step_landing[slot] = landed
			_step_index = (slot + 1) % step_voices.size()
			if landed:
				event_count.landing += 1
	if rustle_enabled and meadow != null and meadow.interactions_enabled and key != "stone" and meadow.has_foliage(point):
		var rustle_db := float(config.get("rustle_db", -22.0)) - (3.0 if actor.current_speed < 4.0 else 0.0)
		_play("rustle", rustle_voices[_rustle_index % 4], point + Vector3.UP * 0.3, rustle_db, 1.0)
		_rustle_index += 1

func _choose_step_slot(landed: bool) -> int:
	if not protect_landing_voice:
		return _step_index
	# Playing includes cues waiting to start on the next physics tick.
	var replace_step := -1
	for offset in step_voices.size():
		var slot := (_step_index + offset) % step_voices.size()
		if not step_voices[slot].playing:
			return slot
		if replace_step < 0 and not _step_landing[slot]:
			replace_step = slot
	if replace_step < 0 and landed:
		return _step_index
	return replace_step

func reset_contacts()->void:
	for voice:AudioStreamPlayer3D in step_voices:voice.stop()
	for voice:AudioStreamPlayer3D in rustle_voices:voice.stop()

func snapshot()->Dictionary:
	return {"loaded":loaded_count,"rejected":rejected_count,"events":event_count,"last_sources":last_sources,"ambient_enabled":ambient_enabled,"footsteps_enabled":footsteps_enabled,"listener_on_player":true,"mix":"Original adapter; native event routing/gains/attenuation unverified"}
