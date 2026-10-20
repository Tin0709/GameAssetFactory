extends "res://scenes/dev/actions_stuff_research/source_jump_sampler.gd"
func _init(rig: Skeleton3D) -> void:
 super(rig)
 data=JSON.parse_string(FileAccess.get_file_as_string("res://scenes/dev/actions_stuff_research/turn_in_place_v001/turn_program.json"))
