extends Resource
## Original graphics profile contract. Does not contain reference assets or presets.
var profile_id:StringName=&""
var fields:Dictionary={}
var phases:Dictionary={}
var device_tiers:Dictionary={30:{"target_fps":30},60:{"target_fps":60},120:{"target_fps":120}}
func validate()->PackedStringArray:
	var errors:=PackedStringArray()
	if profile_id.is_empty():errors.append("Profile ID required")
	_check_values(fields,errors)
	for values:Dictionary in phases.values():_check_values(values,errors)
	return errors
func _check_values(values:Dictionary,errors:PackedStringArray)->void:
	for key:Variant in values:
		var v:Variant=values[key]
		if v is float and not is_finite(v):errors.append("Nonfinite field: "+str(key))
		elif v is Vector3 and not v.is_finite():errors.append("Nonfinite vector: "+str(key))
		elif v is Vector2 and not v.is_finite():errors.append("Nonfinite pair: "+str(key))
		if str(key)=="exposure_bounds" and v is Vector2 and v.x>v.y:errors.append("Inverted exposure bounds")
func phase_fields(phase:StringName)->Dictionary:
	var result:=fields.duplicate(true)
	result.merge(phases.get(phase,{}),true)
	return result
