extends Resource
## Optional weather response layered over a biome's day/night values.

@export_range(0., 1.) var key_energy_scale := .42
@export_range(0., 2.) var ambient_energy_scale := 1.12
@export_range(0., 1.) var local_diffuse_scale := .55
@export var key_color := Color(.78, .87, .94)
@export var fog_color := Color(.57, .66, .73)
@export_range(0., 1.) var additional_fog := .13
@export_range(0., 2., .01) var spatial_extinction_scale := 1.
@export_range(0., 1.) var saturation_scale := .90

@export_group("Phase color")
## Restores some of the resolved time-of-day key hue at the cloudy key's luminance.
@export_range(0., 1., .01) var phase_key_color_retention := 0.
@export_range(0., 1., .01) var ambient_chroma_reduction := 0.
## Uses normalized hours. An empty curve applies the authored amounts at all hours.
@export var phase_color_by_hour: Curve
