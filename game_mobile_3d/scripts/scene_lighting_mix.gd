extends Resource
## A scene-authored starting point for the live lighting controls.

@export var display_name := "Map lighting mix"
@export_multiline var description := ""
@export_multiline var review_tip := ""
@export var strengths: Dictionary[StringName, float] = {}
