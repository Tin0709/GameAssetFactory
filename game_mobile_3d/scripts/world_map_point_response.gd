extends RefCounted
## Pinned external point-light proofs. No reference assets are bundled.
const FILE="godot_lab/world_map_unified_showcase_v001/deepdark_entrance_v001/player-light.private.json"
const SHA="5f6fe39377b114e178236c93625dc6cf3d4afc4b41d02a207b456889cfaafc54"
const KERNEL_FILE="godot_lab/world_map_unified_showcase_v001/point_light_kernel_v001/profile.private.json"
const KERNEL_SHA="0fb21e417b285b85e2458b0c691a7b036dc0db9bf3f8fa1e98e9591d3831274f"
const DAWN_FILE="godot_lab/world_map_unified_showcase_v001/lantern_phase_transfer_v001/profile.private.json"
const DAWN_SHA="31179c46805cfd96c6fbc7e0eea67ea96310d1c9e6f7ba2413f1a5fc87542141"
const SOFT_FILE="godot_lab/world_map_unified_showcase_v001/player_soft_source_v001/profile.private.json"
const SOFT_SHA="04672ff9dcb2d79ec65475d93cca946fa57e16150cd4a633545ac5d853d7102a"
const EVENING_FILE := "graphics_vfx/forest_pix_capture_20261112/forest_twilight_actor/evening_lantern.private.json"
const EVENING_SHA := "4ec5547bcbf57e8aeeb8fe6718dac8171d9e4c08de6f9e024a4d9d87b13c216f"
const EVENING_START := 18.5
const EVENING_END := 21.0
const EVENING_HOURS := [19.0, 19.5, 20.0, 20.5, 21.0]
var _evening_energy: PackedFloat64Array
var soft_verified:=false
var soft_settings:=Vector2.ZERO
var kernel_verified:=false
var verified:=false
var radius_m:=0.
var dawn_profile:Dictionary={}
func _init()->void:
 if not OS.has_feature("editor"):return
 var root:=OS.get_environment("MD2_RESEARCH_ROOT")
 if root.is_empty():root="C:/Users/ADMIN/Desktop/MD2 Research"
 var path:=root.path_join(FILE)
 if not FileAccess.file_exists(path)or FileAccess.get_sha256(path)!=SHA:return
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or not data.get("values")is Dictionary:return
 var v:Dictionary=data.values
 if not v.get("bUseInverseSquaredFalloff")is bool or v.bUseInverseSquaredFalloff:return
 if v.get("LightFalloffExponent")!=2. or v.get("IntensityUnits")!=0:return
 var radius=v.get("AttenuationRadius")
 if not(radius is float or radius is int)or not is_finite(radius)or radius<=0. or radius>10000.:return
 radius_m=float(radius)*.01;verified=true
 var kernel_path:=root.path_join(KERNEL_FILE)
 if not FileAccess.file_exists(kernel_path)or FileAccess.get_sha256(kernel_path)!=KERNEL_SHA:return
 var k=JSON.parse_string(FileAccess.get_file_as_string(kernel_path))
 if not k is Dictionary or k.get("schema")!="private-player-radial-kernel/1"or k.get("operation")!="positive_one_minus_squared_radius_power"or k.get("exponent")!=2.:return
 var r=k.get("radius_m")
 if not(r is float or r is int)or not is_finite(r)or not is_equal_approx(float(r),radius_m):return
 kernel_verified=true
 _load_dawn(root)
 _load_evening(root.path_join(EVENING_FILE))
 var soft_path:=root.path_join(SOFT_FILE)
 if not FileAccess.file_exists(soft_path)or FileAccess.get_sha256(soft_path)!=SOFT_SHA:return
 var soft=JSON.parse_string(FileAccess.get_file_as_string(soft_path))
 if not soft is Dictionary or soft.get("schema")!="private-player-soft-source/1"or soft.get("operation")!="angular-source-ggx-broadening"or soft.get("hard_radius_m")!=0. or soft.get("source_length_m")!=0.:return
 var size=soft.get("soft_radius_m");var minimum=soft.get("min_roughness")
 if not(size is float or size is int)or not is_finite(size)or size<=0. or size>100.:return
 if not(minimum is float or minimum is int)or not is_finite(minimum)or minimum<0. or minimum>1.:return
 soft_settings=Vector2(float(size),float(minimum));soft_verified=true
func available()->bool:return verified
func kernel_available()->bool:return verified and kernel_verified
func soft_available()->bool:return kernel_available()and soft_verified

func _load_evening(path: String) -> void:
 if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != EVENING_SHA:
  return
 var data = JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or data.get("schema") != "private-forest-evening-lantern/1":
  return
 var anchors = data.get("anchors")
 if not anchors is Array or anchors.size() != EVENING_HOURS.size():
  return
 var energy := PackedFloat64Array()
 var previous := 0.0
 for i in anchors.size():
  var row = anchors[i]
  if not row is Dictionary or row.get("hour") != EVENING_HOURS[i]:
   return
  var value = row.get("relative_energy")
  if not (value is float or value is int) or not is_finite(value) or value <= previous or value > 1.0:
   return
  energy.append(value)
  previous = value
 if previous == 1.0:
  _evening_energy = energy

func evening_available() -> bool:
 return kernel_available() and _evening_energy.size() == EVENING_HOURS.size()

func afternoon_lantern_energy(hour: float, authored: float, strength: float, half_past_nineteen: float) -> float:
 if not evening_available() or strength <= 0.0 or hour <= 12.0 or hour >= EVENING_HOURS[1]:
  return authored
 # Forest Day-to-Sunset captures contain no matching point light through
 # the slot assigned to 18:30. The 19:00 slot is the first measured light.
 var first := minf(_evening_energy[0], half_past_nineteen)
 var target := 0.0
 if hour > EVENING_HOURS[0]:
  target = lerpf(first, half_past_nineteen, inverse_lerp(EVENING_HOURS[0], EVENING_HOURS[1], hour))
 elif hour > EVENING_START:
  target = lerpf(0.0, first, inverse_lerp(EVENING_START, EVENING_HOURS[0], hour))
 return lerpf(authored, target, strength)

func evening_lantern_energy(hour: float, authored: float, strength: float, bounds: Vector2) -> float:
 if not evening_available() or authored <= 0.0 or strength <= 0.0 or not is_finite(hour) or hour <= EVENING_START or hour >= EVENING_END:
  return authored
 # Keep the approved endpoints and require a monotone path. The earlier captured
 # value falls below the approved 18:30 energy and would cause a visible dip.
 if not bounds.is_finite() or bounds.x < 0.0 or bounds.x > _evening_energy[1] or bounds.y < _evening_energy[3]:
  return authored
 var before_hour := EVENING_START
 var before_energy := bounds.x
 for i in range(1, 4):
  var after_hour: float = EVENING_HOURS[i]
  var after_energy := _evening_energy[i]
  if hour <= after_hour:
   var progress := inverse_lerp(before_hour, after_hour, hour)
   return lerpf(authored, lerpf(before_energy, after_energy, progress), strength)
  before_hour = after_hour
  before_energy = after_energy
 var progress := inverse_lerp(before_hour, EVENING_END, hour)
 return lerpf(authored, lerpf(before_energy, bounds.y, progress), strength)

func _load_dawn(root:String)->void:
 var path:=root.path_join(DAWN_FILE)
 if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=DAWN_SHA:return
 var profile=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not profile is Dictionary or profile.get("schema")!="private-player-dawn-fade/1":return
 for field in ["full_density","zero_density","mid_density","mid_relative_energy","latest_source_hour"]:
  var value=profile.get(field)
  if not (value is float or value is int) or not is_finite(value) or value<0.:return
 if not (profile.full_density<profile.mid_density and profile.mid_density<profile.zero_density):return
 if profile.mid_relative_energy>=1. or profile.latest_source_hour<=0. or profile.latest_source_hour>7.:return
 var predicted:=inverse_lerp(float(profile.zero_density),float(profile.full_density),float(profile.mid_density))
 if absf(predicted-float(profile.mid_relative_energy))>1e-6:return
 dawn_profile=profile

func dawn_available()->bool:
 return kernel_available() and not dawn_profile.is_empty()

func dawn_gain(hour:float, density:float, authored:float)->float:
 if not dawn_available() or not is_finite(hour) or not is_finite(density):return authored
 if hour<0. or hour>float(dawn_profile.latest_source_hour):return authored
 return clampf(inverse_lerp(float(dawn_profile.zero_density),float(dawn_profile.full_density),density),0.,1.)
