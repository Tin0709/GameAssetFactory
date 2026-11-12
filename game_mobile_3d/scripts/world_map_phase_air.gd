extends RefCounted
## Private measured anchors; clock placement/interpolation are original GAF policy.
const FILE="godot_lab/world_map_unified_showcase_v001/phase_atmosphere_integration_v001/phase.private.json"
const SHA="cf6397a816b5c893275fa4c9d72f2c77f33b2a0421c45f73351a47a4c34f2698"
const EVENING_FILE = "graphics_vfx/forest_pix_capture_20261112/forest_weather/evening.private.json"
const EVENING_SHA = "a353d5bd65110d5308061a97519d1f865f265d2f8ea9eb439e5109a73324889b"
var anchors:Array=[]
var evening_anchors: Array = []
func _init():
 if not OS.has_feature("editor"):return
 var root:=OS.get_environment("MD2_RESEARCH_ROOT")
 if root.is_empty():root="C:/Users/ADMIN/Desktop/MD2 Research"
 var path:=root.path_join(FILE)
 if not FileAccess.file_exists(path)or FileAccess.get_sha256(path)!=SHA:return
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or data.get("schema")!="private-forest-phase-gpu/1":return
 var rows=data.get("anchors",[])
 if not rows is Array or rows.size()!=8:return
 var previous:=-1.
 for row in rows:
  if not row is Dictionary:return
  for key in ["hour","density_ratio","height_falloff_m","start_m"]:
   var n=row.get(key)
   if not(n is float or n is int)or not is_finite(n)or n<0 or n>100:return
  if row.hour<=previous:return
  previous=row.hour
  var rgb=row.get("linear_scatter")
  if not rgb is Array or rgb.size()!=3:return
  for n in rgb:
   if not(n is float or n is int)or not is_finite(n)or n<0 or n>8:return
 anchors=rows
 evening_anchors = _load_evening(root.path_join(EVENING_FILE))

func _load_evening(path: String) -> Array:
 if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != EVENING_SHA:
  return []
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or data.get("schema") != "private-forest-evening-fog/1":
  return []
 var rows: Variant = data.get("anchors", [])
 if not rows is Array or rows.size() != 9:
  return []
 var previous := 16.0
 for row in rows:
  if not row is Dictionary:
   return []
  var time: Variant = row.get("hour")
  var density: Variant = row.get("density_ratio")
  var rgb: Variant = row.get("linear_scatter")
  if not _valid_number(time, 21.0) or time <= previous or not _valid_number(density, 2.0):
   return []
  if not rgb is Array or rgb.size() != 3:
   return []
  for channel in rgb:
   if not _valid_number(channel, 8.0):
    return []
  previous = time
 return rows if rows[0].hour == 16.5 and rows[-1].hour == 21.0 else []

static func _valid_number(value: Variant, limit: float) -> bool:
 return (value is float or value is int) and is_finite(value) and value >= 0 and value <= limit

func blend_evening(row: Dictionary, hour: float, strength: float) -> void:
 if evening_anchors.is_empty() or strength <= 0.0:
  return
 # Clock placement is WorldMap art direction. The intermediate colors and
 # optical densities come from the evening GPU samples.
 var weight := strength * smoothstep(16.5, 17.5, hour) * (1.0 - smoothstep(20.25, 21.0, hour))
 if weight <= 0.0:
  return
 var i := 0
 while i < evening_anchors.size() - 2 and hour > float(evening_anchors[i + 1].hour):
  i += 1
 var a: Dictionary = evening_anchors[i]
 var b: Dictionary = evening_anchors[i + 1]
 var t := clampf(inverse_lerp(a.hour, b.hour, hour), 0.0, 1.0)
 var x: Array = a.linear_scatter
 var y: Array = b.linear_scatter
 var color := Vector3(x[0], x[1], x[2]).lerp(Vector3(y[0], y[1], y[2]), t)
 var baseline: Vector3 = row.linear_scatter
 row.linear_scatter = baseline.lerp(color, weight)
 row.density_ratio = lerpf(row.density_ratio, lerpf(a.density_ratio, b.density_ratio, t), weight)

func sample(hour:float)->Dictionary:
 if anchors.is_empty()or not is_finite(hour):return {}
 var h:=fposmod(hour,24.)
 # Evening is a mirrored ART transition, not newly recovered evening evidence.
 if h>12.:h=24.-h
 var i:=0
 while i<anchors.size()-2 and h>float(anchors[i+1].hour):i+=1
 var a:Dictionary=anchors[i];var b:Dictionary=anchors[i+1]
 var t:=smoothstep(float(a.hour),float(b.hour),h)
 var result:Dictionary={}
 for key in ["density_ratio","height_falloff_m","start_m"]:result[key]=lerpf(a[key],b[key],t)
 var x:Array=a.linear_scatter;var y:Array=b.linear_scatter
 result.linear_scatter=Vector3(x[0],x[1],x[2]).lerp(Vector3(y[0],y[1],y[2]),t)
 return result
