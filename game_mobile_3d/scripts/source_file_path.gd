extends RefCounted
## Resolves external research paths without depending on a lab script.

static func resolve_private_file(research_root:String,relative:String)->String:
	if not research_root.is_absolute_path() or relative.is_absolute_path():return ""
	var normalized:=research_root.replace("\\","/").simplify_path().trim_suffix("/")+"/"
	var project:=ProjectSettings.globalize_path("res://").replace("\\","/").simplify_path().trim_suffix("/")+"/"
	if normalized.to_lower().begins_with(project.to_lower()):return ""
	var target:=normalized.path_join(relative).simplify_path()
	return target if target.to_lower().begins_with(normalized.to_lower()) else ""
