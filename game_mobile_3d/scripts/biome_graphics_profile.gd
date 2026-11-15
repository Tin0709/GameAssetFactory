extends Resource

const Weather = preload("res://scripts/biome_weather_profile.gd")
const DayNight = preload("res://scripts/biome_day_night.gd")
const GroundHazeProfile = preload("res://scripts/ground_haze_profile.gd")
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
@export_range(0., 4., .05) var shadow_blur := 1.25
@export_range(0., 1., .01) var shadow_opacity := .782
## Daylight caster adjustment for maps with the grass lighting adapter.
@export_range(0., 2., .01) var day_grass_shadow_compactness := 1.
## Local diffuse response around a map-authored opening.
@export_range(0., .65, .01) var local_diffuse_strength := 0.
@export var local_diffuse_by_hour: Curve
## Optional normalized-hour blend towards stronger sunlight in openings of a map's projection.
@export var projected_opening_recovery_by_hour: Curve
## Scales the baked directional diffuse return on shadowed stone walls.
@export_range(0., 1.5, .01) var shadowed_wall_return_scale := 0.
## Restores a limited share of the local sky on shaded walls with low baked return.
@export_range(0., 1.6, .01) var sheltered_stone_return_scale := 0.

@export_group("Atmosphere and fog")
@export var noon_sky_color := Color(.57, .68, .69)
@export var noon_fog_color := Color(.64, .72, .73)
@export var fog_depth_m := Vector2(23., 47.)
@export_range(0., 1.) var noon_fog_density := .16
## Shape of the distance ramp, retained on every quality tier.
@export_range(.1, 4., .05) var fog_depth_curve := 1.7
@export_range(0., 2., .01) var fog_light_energy := .75

@export_subgroup("Spatial mist")
@export var spatial_mist := false
## Depth-fog strength when using the Essential budget instead of the spatial volume.
@export_range(0., 1., .01) var essential_fog_scale := .45
## Extinction in inverse metres. The shared volume uses the map's spawn elevation as reference.
@export_range(0., .06, .001) var mist_extinction := .011
@export_range(0., 1., .01) var mist_height_falloff := .25
@export_range(0., 1., .01) var mist_scatter := .40
@export_range(0., 1., .01) var local_mist_strength := .65
## Multiplies the first map region by normalized hour. A missing or empty curve uses 1.
@export var local_mist_by_hour: Curve
## Uses the first slot during hours when its primary region is idle. A missing curve disables it.
@export var alternate_mist_by_hour: Curve
## Independent multiplier for the second map region. Match the midnight endpoints.
@export var additional_mist_by_hour: Curve
## Optional tree-receiver weight by normalized hour. A missing track keeps the existing tree envelope.
@export var grove_mist_by_hour: Curve
## Optional light scattered into low areas behind the player.
@export var ground_haze: GroundHazeProfile
@export_range(0., 1., .01) var ground_haze_strength := 0.
## Used when the earlier low-air layer is outside its phase or disabled.
@export var twilight_ground_haze: GroundHazeProfile
@export_range(0., 1., .01) var twilight_ground_haze_strength := 0.

@export_group("Color grading")
@export var tonemap := Environment.TONE_MAPPER_FILMIC
@export_range(.1, 4.) var exposure := .96
@export_range(0., 2.) var saturation := .98
@export_range(0., 2.) var contrast := 1.05
@export var color_correction: Texture
## Normalized hours for restoring neutral shadow color in the reference finish.
@export var shadow_grade_recovery_by_hour: Curve
## Shadow recovery for dark greens in the optional reference finish.
@export_range(0., 1., .01) var daylight_green_grade_scale := 0.

@export_group("Bloom")
@export_range(0., 2.) var glow_intensity := .42
@export_range(0., 1.) var glow_bloom := .035
@export_range(0., 4.) var glow_hdr_threshold := .9

@export_subgroup("Adaptive bloom")
@export var adaptive_bloom := false
## Blend weight by normalized biome hour; a missing curve uses full weight.
@export var adaptive_bloom_by_hour: Curve
@export_range(0., .23, .01) var local_exposure := .08
@export_range(0., 4., .01) var adaptive_bloom_gain := .5
@export_range(0., 1., .01) var adaptive_bloom_response := .65
@export_range(0., 1., .01) var adaptive_bloom_prefilter := .72
@export_range(0., 2., .01) var adaptive_bloom_spread := .82

@export_group("Day and night")
@export_range(0., 24.) var start_hour := 12.
@export_range(1., 60.) var cycle_minutes := 20.
@export var auto_cycle := false
## Assign phase color tracks independently of the map and weather response.
@export var day_night: DayNight
## Maps normalized time (0 to 1) to a multiplier. Match the midnight endpoints.
@export var key_energy_by_hour: Curve
## Optional weight of the verified Forest direct-key sequence, in normalized hours.
@export var afternoon_key_by_hour: Curve
## Ambient multiplier before weather, in normalized hours. An empty track uses 1.
@export var ambient_energy_by_hour: Curve
@export var fog_density_by_hour: Curve

@export_group("Local path fixture")
## A missing curve disables the private fixture. Both ends of the curve should match.
@export var path_fixture_by_hour: Curve
@export_range(0., 1., .01) var path_fixture_energy := .70
@export_range(0., 1., .01) var path_fixture_scatter := .50

@export_group("Weather")
@export var overcast: Weather
@export_range(0., 1., .01) var start_overcast := 0.

func ambient_hour_scale(hour: float, strength: float = 1.) -> float:
	var time := fposmod(hour, 24.) / 24.
	var authored := maxf(0., DayNight.sample_curve(ambient_energy_by_hour, time, 1.))
	if is_equal_approx(authored, 1.):
		return 1.
	return lerpf(1., authored, clampf(strength, 0., 1.))

func sample_ground_haze(hour: float, subject_depth_m: float, map_base_y: float,
		day_mix: float = 1., twilight_mix: float = 1.) -> PackedFloat32Array:
	var haze := PackedFloat32Array()
	if ground_haze != null and ground_haze_strength > 0. and day_mix > 0.:
		haze = ground_haze.sample(hour, subject_depth_m, map_base_y, ground_haze_strength * day_mix)
	if haze.is_empty() and twilight_ground_haze != null and twilight_ground_haze_strength > 0. and twilight_mix > 0.:
		haze = twilight_ground_haze.sample(hour, subject_depth_m, map_base_y, twilight_ground_haze_strength * twilight_mix)
	return haze
