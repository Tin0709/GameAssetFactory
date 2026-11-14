extends Resource
## Map-independent art settings. Geometry-derived lighting fields live on each map.

@export var display_name := "Temperate meadow"
@export_group("Lighting")
@export var noon_sun_rotation := Vector3(-50., -38., 0.)
@export var noon_sun_color := Color(1., .975, .925)
@export_range(0., 4.) var noon_sun_energy := 1.5
@export var noon_ambient_color := Color(.56, .72, .84)
@export_range(0., 2.) var noon_ambient_energy := .32

@export_group("Atmosphere and fog")
@export var noon_sky_color := Color(.57, .68, .69)
@export var noon_fog_color := Color(.64, .72, .73)
@export var fog_depth_m := Vector2(23., 47.)
@export_range(0., 1.) var noon_fog_density := .16

@export_group("Color grading")
@export var tonemap := Environment.TONE_MAPPER_FILMIC
@export_range(.1, 4.) var exposure := .96
@export_range(0., 2.) var saturation := .98
@export_range(0., 2.) var contrast := 1.05
@export var color_correction: Texture

@export_group("Bloom")
@export_range(0., 2.) var glow_intensity := .42
@export_range(0., 1.) var glow_bloom := .035
@export_range(0., 4.) var glow_hdr_threshold := .9

@export_group("Day and night")
@export_range(0., 24.) var start_hour := 12.
@export_range(1., 60.) var cycle_minutes := 20.
@export var auto_cycle := false

@export_group("Overcast")
@export_range(0., 1.) var overcast_key := .42
@export_range(0., 2.) var overcast_ambient := 1.12
@export var overcast_light_color := Color(.78, .87, .94)
@export var overcast_fog_color := Color(.57, .66, .73)
@export_range(0., 1.) var overcast_density := .13
@export_range(0., 1.) var overcast_saturation := .90
