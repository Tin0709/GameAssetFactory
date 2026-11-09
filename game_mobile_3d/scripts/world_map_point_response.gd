extends RefCounted
## Recovered mode selection only; Godot range cutoff remains an approximation.
const FILE="godot_lab/world_map_unified_showcase_v001/deepdark_entrance_v001/player-light.private.json"
const SHA="5f6fe39377b114e178236c93625dc6cf3d4afc4b41d02a207b456889cfaafc54"
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
func available()->bool:return verified
