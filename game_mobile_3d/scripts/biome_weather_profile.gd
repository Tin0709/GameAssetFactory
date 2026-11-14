extends Resource
## Optional weather response layered over a biome's day/night values.

@export_range(0., 1.) var key_energy_scale := .42
@export_range(0., 2.) var ambient_energy_scale := 1.12
@export_range(0., 1.) var local_diffuse_scale := .55
@export var key_color := Color(.78, .87, .94)
@export var fog_color := Color(.57, .66, .73)
@export_range(0., 1.) var additional_fog := .13
@export_range(0., 1.) var saturation_scale := .90
