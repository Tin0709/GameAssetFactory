extends SceneTree
const Actor=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd")
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	# Synthetic original fixture only; no private source changes or copies.
	var path:=ProjectSettings.globalize_path("user://synthetic-runtime-profile-validation.json")
	var good:={"schema":"md2-private-locomotion-runtime/1","units":{"centimetres_per_godot_unit":100.},"ground":{"speed_cm_s":100.,"acceleration_cm_s2":100.,"braking_deceleration_cm_s2":100.,"yaw_deg_s":360.}}
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(good))
	check(not Actor.read_runtime_locomotion_profile(path).is_empty(),"Well-formed external selected-value profile accepted")
	for variant:String in ["partial","units","string","negative","schema"]:
		var data:=good.duplicate(true)
		match variant:
			"partial":data.ground.erase("yaw_deg_s")
			"units":data.units.centimetres_per_godot_unit=1.
			"string":data.ground.acceleration_cm_s2="fast"
			"negative":data.ground.speed_cm_s=-1.
			"schema":data.schema="different"
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data))
		check(Actor.read_runtime_locomotion_profile(path).is_empty(),"Malformed profile rejected atomically: "+variant)
	FileAccess.open(path,FileAccess.WRITE).store_string("not JSON")
	check(Actor.read_runtime_locomotion_profile(path).is_empty(),"Malformed JSON rejected")
	DirAccess.remove_absolute(path)
	check(Actor.read_runtime_locomotion_profile(path).is_empty(),"Missing external profile harmless")
	check(Actor.read_runtime_locomotion_profile(ProjectSettings.globalize_path("res://project.godot")).is_empty(),"Project-local input refused")
	var a=Actor.new();a.prefer_private_skin=false;root.add_child(a);a.set_physics_process(false)
	check(not a.using_original_source and a.runtime_locomotion_profile.is_empty(),"Authored fallback does not apply private configuration")
	check(absf(a.acceleration-48.)<.001 and absf(a.deceleration-42.)<.001 and absf(a.ground_turn_rate-12.)<.001,"Authored response parameters preserved")
	check(absf(a.gravity-18.)<.001,"Authored vertical behavior preserved")
	print("SABRE_RUNTIME_PROFILE_VALIDATION ",JSON.stringify({"checks":checks,"failures":failures}));a.free();quit(0 if failures.is_empty() else 1)
