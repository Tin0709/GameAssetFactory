extends Node3D
## Reuses the private meadow audio engine against the authored map's surfaces.
const BUNDLE=preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/private_bundle.gd")
const AUDIO=preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/environment_audio.gd")
var level:Node3D
var audio:Node3D
var interactions_enabled:bool:
	get:return level.look.stage!=0
var _plants:Dictionary={}
var error:=""

func setup(world:Node3D,research:String)->void:
	level=world
	var path:=research.path_join("godot_lab/overworld_fidelity_v001/bundle.private.json")
	var reader:=BUNDLE.new()
	if not reader.permitted(path) or not FileAccess.file_exists(path):error="Private ambience manifest unavailable";return
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema","")!="private_overworld_v1" or not parsed.get("private_only",false):error="Invalid ambience manifest";return
	reader.root=research.replace("\\","/").simplify_path().to_lower()
	reader.data={"audio":parsed.get("audio",{}),"audio_config":parsed.get("audio_config",{}),"audio_scope":parsed.get("audio_scope","")}
	for cell:Vector3i in level.geometry.cells:
		var entry:Dictionary=level.runtime.palette[level.geometry.cells[cell]]
		if entry.category=="plant":
			var at:Vector3=level.source_to_world(cell)
			_plants[Vector2i(floori(at.x),floori(at.z))]=true
	audio=AUDIO.new();audio.name="PrivateOverworldAudio";add_child(audio)
	audio.setup(level.player,self,reader)
	if audio.rejected_count>0:error="Some private ambience samples unavailable: %d"%audio.rejected_count

func surface_at(point:Vector3)->String:
	var offset:Array=level.runtime.offset
	var column:=Vector2i(floori(point.x-float(offset[0])),floori(point.z-float(offset[2])))
	var height:float=level.columns.get(column,NAN)
	if not is_finite(height):return "grass"
	for y:int in [floori(height-.01),floori(height-.51)]:
		var key:=Vector3i(column.x,y,column.y)
		if level.geometry.cells.has(key):
			var kind:String=level.runtime.palette[level.geometry.cells[key]].kind
			if "stone" in kind or "rock" in kind:return "stone"
			if "dirt" in kind:return "dirt"
	return "grass"

func has_foliage(point:Vector3)->bool:
	if level.grove!=null and not level.grove.visible:return false
	return _plants.has(Vector2i(floori(point.x),floori(point.z)))
