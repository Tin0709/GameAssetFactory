extends Resource
## A scene-authored starting point for the live lighting controls.

@export var display_name := "Map lighting mix"
@export var strengths: Dictionary[StringName, float] = {}
