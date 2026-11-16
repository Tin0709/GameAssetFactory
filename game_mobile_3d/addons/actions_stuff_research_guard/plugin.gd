@tool
extends EditorPlugin

# Always enabled for normal exports; all source study resources are private.
# This script contains no source-derived research data.
class ResearchExportGuard extends EditorExportPlugin:
	const RESEARCH_SCENE := "res://scenes/dev/ActionsStuffWalkRunTest.tscn"
	const RESEARCH_ROOT := "res://scenes/dev/actions_stuff_research/"
	const GUARD_ROOT := "res://addons/actions_stuff_research_guard/"
	const MIST_KERNEL := "res://materials/world_map_mist_field.glsl"

	func _get_name() -> String:
		return "ActionsStuffResearchReleaseExclusion"

	func _supports_platform(_platform: EditorExportPlatform) -> bool:
		return true

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		# The runtime specializes this source before compiling on the active GPU backend.
		add_file(MIST_KERNEL, FileAccess.get_file_as_bytes(MIST_KERNEL), false)

	func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
		var normalized := path.replace("\\", "/").simplify_path()
		if normalized == RESEARCH_SCENE \
				or normalized.begins_with(RESEARCH_SCENE + ".") \
				or normalized.begins_with(RESEARCH_ROOT) \
				or normalized.begins_with(GUARD_ROOT):
			skip()


var _export_guard: ResearchExportGuard


func _enter_tree() -> void:
	_export_guard = ResearchExportGuard.new()
	add_export_plugin(_export_guard)


func _exit_tree() -> void:
	if _export_guard != null:
		remove_export_plugin(_export_guard)
		_export_guard = null
