extends RefCounted
## Pinned external point-light proofs. No reference assets are bundled.
const FILE="godot_lab/world_map_unified_showcase_v001/deepdark_entrance_v001/player-light.private.json"
const SHA="5f6fe39377b114e178236c93625dc6cf3d4afc4b41d02a207b456889cfaafc54"
const KERNEL_FILE="godot_lab/world_map_unified_showcase_v001/point_light_kernel_v001/profile.private.json"
const KERNEL_SHA="0fb21e417b285b85e2458b0c691a7b036dc0db9bf3f8fa1e98e9591d3831274f"
const SOFT_FILE="godot_lab/world_map_unified_showcase_v001/player_soft_source_v001/profile.private.json"
const SOFT_SHA="04672ff9dcb2d79ec65475d93cca946fa57e16150cd4a633545ac5d853d7102a"
var soft_verified:=false
var soft_settings:=Vector2.ZERO
var kernel_verified:=false
var verified:=false
var radius_m:=0.
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
func available()->bool:return verified
func kernel_available()->bool:return verified and kernel_verified
