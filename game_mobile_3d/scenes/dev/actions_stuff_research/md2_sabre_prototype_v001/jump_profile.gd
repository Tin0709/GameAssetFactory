extends RefCounted
## Optional private measured settings; no reference data embedded in production.
static func read(path:String,target_path:String)->Dictionary:
	if not path.is_absolute_path() or not FileAccess.file_exists(path):return {}
	var root:=ProjectSettings.globalize_path("res://").replace("\\","/").simplify_path().to_lower().trim_suffix("/")+"/"
	if path.replace("\\","/").simplify_path().to_lower().begins_with(root):return {}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>64000:return {}
	file.close()
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("schema")!="private-measured-jump/1" or value.get("research_only")!=true or value.get("production_eligible")!=false:return {}
	if value.get("target_sha256")!=FileAccess.get_sha256(target_path) or value.get("root_advance_applied")!=false:return {}
	for key in ["launch_speed_m_s","vertical_acceleration_m_s2","normal_air_speed_m_s","compact_landing_seconds"]:
		var number:Variant=value.get(key)
		if not(number is float or number is int) or not is_finite(float(number)) or float(number)<=0. or float(number)>500.:return {}
	if float(value.compact_landing_seconds)>.5:return {}
	return value.duplicate(true)
