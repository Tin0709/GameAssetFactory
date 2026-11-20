extends Resource

const Weather = preload("res://scripts/biome_weather_profile.gd")
const DayNight = preload("res://scripts/biome_day_night.gd")
const GroundHazeProfile = preload("res://scripts/ground_haze_profile.gd")
const LINEAR_LUMA := Vector3(.2126, .7152, .0722)
## Map-independent art settings. Geometry-derived lighting fields live on each map.

@export var display_name := "Temperate meadow"
## Screen footprint filtering for the authored source-atlas dirt shoulder.
@export_range(0., 1., .01) var source_path_edge_filter := 0.
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
## Default strength of twilight diffuse attenuation on terrain and grass receivers that support it.
@export_range(0., 1., .01) var twilight_ground_shade_strength := 1.
## Daylight caster adjustment for maps with the grass lighting adapter.
@export_range(0., 2., .01) var day_grass_shadow_compactness := 1.
@export_range(0., .5, .01) var day_grass_shadow_footprint_reduction := 0.
## Limit wind displacement in the directional shadow pass while retaining plant contact.
@export_range(0., .75, .01) var day_grass_shadow_wind_reduction := 0.
@export_range(0., 1., .01) var day_grass_sunlight_stability := 0.
## Relative opacity of the daytime canopy silhouette at close camera zoom.
@export_range(0., 1., .01) var daylight_canopy_cue_opacity := 1.
## Orthographic camera sizes that blend the silhouette back to full opacity.
@export var canopy_cue_zoom_fade := Vector2(22., 36.)
## Local diffuse response around a map-authored opening.
@export_range(0., .65, .01) var local_diffuse_strength := 0.
@export var local_diffuse_by_hour: Curve
## Portable character ground return by normalized hour. An empty track disables it.
@export var actor_ground_light_by_hour: Curve
@export_range(0., 2., .01) var actor_ground_light_cloudy_scale := 1.
## Optional normalized-hour blend towards stronger sunlight in openings of a map's projection.
@export var projected_opening_recovery_by_hour: Curve
## Local share of lost sunlight to restore within the map's authored region.
@export var projected_path_recovery_by_hour: Curve
@export_range(0., 1., .01) var projected_path_recovery_overcast_scale := 1.
## Scales the baked directional diffuse return on shadowed stone walls.
@export_range(0., 1.5, .01) var shadowed_wall_return_scale := 0.
## Restores a limited share of the local sky on shaded walls with low baked return.
@export_range(0., 1.6, .01) var sheltered_stone_return_scale := 0.
## Additional diffuse sky on dark stone sides using the map's existing transport.
## Curve X is normalized hour and Y is a gain from 0 to 1.
@export var stone_wall_sky_by_hour: Curve
## Diffuse return on receivers in weak directional light. X is normalized hour.
@export var shadow_diffuse_by_hour: Curve
## Reduction of supplemental fill in deep shadows, on grass and on stone tops respectively.
@export var ground_shadow_fill_reduction := Vector2.ZERO
## Reduction of the path's supplemental shadow fill and gain for moderately lit dirt.
@export var path_sun_response := Vector2.ZERO
## Diffuse gain and warmth in the illuminated core of a dirt path.
@export var path_sun_core := Vector2.ZERO
## Blend of the owned sky irradiance on bark, keyed by normalized hour.
@export var bark_irradiance_by_hour: Curve
@export_range(0.0, 1.0) var spruce_leaf_filter := 0.0
## Fraction of enclosed spruce leaf gaps sampled with 2× MSAA, keyed by normalized hour.
@export var spruce_gap_coverage_by_hour: Curve
@export var bark_irradiance_tint := Vector3.ONE
## Fraction of ambient irradiance returned to diffuse bark above ground contact.
@export var bark_diffuse_return_by_hour: Curve
@export var bark_diffuse_return_tint := Vector3.ONE
## Early daylight reduction for direct sunlight on high leaves and ambient fill in the crown.
@export var dawn_canopy_response := Vector2.ZERO
## X is normalized hour and Y is the blend of the crown response.
@export var dawn_canopy_by_hour: Curve
## Bright-leaf response to the supported player lamp at twilight.
@export_range(0., 1., .01) var twilight_leaf_lamp_shoulder_strength := 0.
@export_range(0., 1., .01) var night_leaf_lamp_shoulder_strength := 0.
## Additional diffuse sky on supported player materials under canopy.
## Curve X is normalized hour and Y is a gain from 0 to 1.
@export var actor_shade_sky_by_hour: Curve
## Optional late-sun highlight shoulder for the existing actor shader. Zero keeps the daylight curve.
@export var actor_sunset_sun_shoulder_by_hour: Curve
## Fraction of the local upper-sky deficit returned to shaded lateral faces.
@export var actor_side_sky_by_hour: Curve
## Ground reflection from the player's lantern during the handoff to night.
## Curve X is normalized hour. Y is the fraction of the daytime gap to fill.
@export var lantern_ground_return_by_hour: Curve

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
## Optional spatial mist light tint, independent of the depth fog color. Preserves source luminance.
## Both tracks use normalized hours. Match the endpoints for a continuous midnight.
@export var mist_scatter_color_by_hour: Gradient
## Multiplier for scattered light. Defaults to 1 and does not change transmission.
@export var mist_scatter_energy_by_hour: Curve
## Added light near the entry to the spatial mist, sampled by normalized hour.
## An empty track leaves the original medium lighting in place.
@export var mist_entry_scatter_by_hour: Curve
## Mix of the rear ambient scattering tint during daylight.
@export_range(0., 1., .01) var mist_rear_chroma := 0.
## Adds ambient sky color to the existing mist in partially occluded air.
@export var mist_sky_scatter_by_hour: Curve
## Independent twilight gain, sharing the same map provider and tint as daytime.
@export var mist_dusk_sky_scatter_by_hour: Curve
@export var mist_sky_scatter_tint := Vector3.ONE
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
## Maximum luminance gain for shaded detail under the same hour curve.
@export_range(0., .52, .01) var daylight_shadow_luminance_scale := 0.
## Fraction of the daylight shadow lift retained as contrast behind the fog entry.
@export_range(0., 1., .01) var daylight_shade_retention := 0.
## Blends the mist source color into normally exposed distant shadows in the depth-aware finish.
@export_range(0., .64, .01) var daylight_air_chroma := 0.
@export_range(0., .4, .01) var green_shadow_exposure_trim := 0.
@export_range(0., .32, .01) var exposure_neighborhood_limit := 0.
@export_range(0., .32, .01) var lantern_exposure := 0.
@export_range(0., .65, .01) var stone_sun_warmth := 0.
## Remove a fraction of the luminance added by the stone warmth tint.
@export_range(0., 1., .01) var stone_warmth_luma_trim := 0.
@export_range(0., 1., .01) var turf_sun_chroma := 0.
## Extra baked directional bounce on stone sides during morning and afternoon.
@export_range(0., 2., .01) var stone_bounce_focus := 0.
## Range in exposure stops for sky fill from blade base to tip during daylight.
@export_range(0., .6, .01) var grass_sky_height := 0.
## Blend toward the turf atlas chroma (X) and reduce base luminance in EV (Y).
@export var grass_ground_tone := Vector2.ZERO
## Shadow recovery for dark greens in the optional reference finish.
@export_range(0., 1., .01) var daylight_green_grade_scale := 0.
## Keep the reference local-exposure blur footprint steadier when zooming out.
@export_range(0., 1., .01) var zoom_exposure_blur_strength := 0.
## Optional exposure blur correction by normalized hour for lantern-lit gameplay.
@export var night_zoom_exposure_blur_by_hour: Curve

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
## Game clock window for the final sunset fade. An empty interval disables it.
@export var dusk_key_fade_hours := Vector2.ZERO
@export_range(0., 1., .01) var dusk_key_fade_strength := 0.
## Ambient multiplier before weather, in normalized hours. An empty track uses 1.
@export var ambient_energy_by_hour: Curve
## Optional weight of the ambient color adjustment, in normalized hours.
@export var ambient_tint_by_hour: Curve
## Linear RGB channel ratios. The adjustment preserves the incoming luminance.
@export var ambient_tint_ratio := Vector3.ONE
@export var day_path_chroma_by_hour: Curve
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

func tint_ambient(hour: float, color: Color, strength: float = 1.) -> Color:
	if ambient_tint_by_hour == null or strength <= 0. or ambient_tint_ratio == Vector3.ONE:
		return color
	var amount := clampf(DayNight.sample_curve(ambient_tint_by_hour, fposmod(hour, 24.) / 24., 0.), 0., 1.)
	if amount <= 0. or not ambient_tint_ratio.is_finite():
		return color
	if ambient_tint_ratio.x < 0. or ambient_tint_ratio.y < 0. or ambient_tint_ratio.z < 0.:
		return color
	var linear := color.srgb_to_linear()
	var source := Vector3(linear.r, linear.g, linear.b)
	var target := source * ambient_tint_ratio
	var target_luma := target.dot(LINEAR_LUMA)
	if not is_finite(target_luma) or target_luma <= 0.:
		return color
	target *= source.dot(LINEAR_LUMA) / target_luma
	var rgb := source.lerp(target, amount * clampf(strength, 0., 1.))
	return Color(rgb.x, rgb.y, rgb.z, color.a).linear_to_srgb()

func sample_mist_entry_scatter(time: float) -> float:
	return clampf(DayNight.sample_curve(mist_entry_scatter_by_hour, time, 0.), 0., 4.)

func sample_mist_sky_scatter(time: float, env: Environment, strength: float = 1.,
		dusk_strength: float = 1.) -> Vector4:
	var day := DayNight.sample_curve(mist_sky_scatter_by_hour, time, 0.) * strength
	var dusk := DayNight.sample_curve(mist_dusk_sky_scatter_by_hour, time, 0.) * dusk_strength
	var gain := clampf(maxf(day, dusk), 0., 4.)
	if gain <= 0. or not mist_sky_scatter_tint.is_finite():
		return Vector4.ZERO
	var ambient_color := env.ambient_light_color.srgb_to_linear()
	var ambient := Vector3(ambient_color.r, ambient_color.g, ambient_color.b) * env.ambient_light_energy * .75
	var tint := ambient * mist_sky_scatter_tint.clamp(Vector3.ZERO, Vector3(4., 4., 4.))
	var luma := Vector3(.2126, .7152, .0722)
	var tint_luma := tint.dot(luma)
	if tint_luma <= .000001:
		return Vector4.ZERO
	tint *= ambient.dot(luma) / tint_luma
	return Vector4(tint.x, tint.y, tint.z, gain)

func sample_ground_haze(hour: float, subject_depth_m: float, map_base_y: float,
		day_mix: float = 1., twilight_mix: float = 1.) -> PackedFloat32Array:
	var haze := PackedFloat32Array()
	if ground_haze != null and ground_haze_strength > 0. and day_mix > 0.:
		haze = ground_haze.sample(hour, subject_depth_m, map_base_y, ground_haze_strength * day_mix)
	if haze.is_empty() and twilight_ground_haze != null and twilight_ground_haze_strength > 0. and twilight_mix > 0.:
		haze = twilight_ground_haze.sample(hour, subject_depth_m, map_base_y, twilight_ground_haze_strength * twilight_mix)
	return haze
