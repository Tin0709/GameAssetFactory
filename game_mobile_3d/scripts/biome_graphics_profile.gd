extends Resource

const Weather = preload("res://scripts/biome_weather_profile.gd")
## Map-independent art settings. Geometry-derived lighting fields live on each map.

@export var display_name := "Temperate meadow"
## The existing reference route requires matching private Forest data.
@export var use_forest_reference := false
@export_group("Private reference data")
@export var atmosphere_reference_path := ""
@export var atmosphere_reference_sha256 := ""
@export var finish_reference_path := ""
@export var finish_reference_sha256 := ""
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

@export_subgroup("Spatial mist")
@export var spatial_mist := false
## Extinction in inverse metres. The shared volume uses the map's spawn elevation as reference.
@export_range(0., .06, .001) var mist_extinction := .011
@export_range(0., 1., .01) var mist_height_falloff := .25
@export_range(0., 1., .01) var mist_scatter := .40
@export_range(0., 1., .01) var local_mist_strength := .65

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
## Maps normalized time (0 to 1) to a multiplier. Match the midnight endpoints.
@export var key_energy_by_hour: Curve
@export var fog_density_by_hour: Curve

@export_group("Weather")
@export var overcast: Weather
