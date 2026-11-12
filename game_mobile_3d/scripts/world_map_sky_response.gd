extends RefCounted
## Original low-frequency source transfer. Not native Lumen irradiance or clock recovery.
const FILE="godot_lab/world_map_unified_showcase_v001/night_fill_audit_v001/sky_profile.private.json"
const SHA="a6b1e9c5111bcab8317d402ad8b0e1cc7987c1cf326e39f2da137f31bec8091b"
const HOURS:=[0.,5.5,6.5,7.,8.,9.,10.,12.]
const TWILIGHT_FILE := "graphics_vfx/forest_pix_capture_20261112/forest_twilight_color/twilight_sky.private.json"
const TWILIGHT_SHA := "fbd91f0deb586b7f9d58b40e073504325e4fe5c97c568639b373cc686bd92c26"
const LUMA := Vector3(.2126, .7152, .0722)
var anchors:Array=[]
var verified:=false
var twilight_rgb_to_green := Vector3.ZERO
func _init()->void:
 if not OS.has_feature("editor"):return
 var root:=OS.get_environment("MD2_RESEARCH_ROOT")
 if root.is_empty():root="C:/Users/ADMIN/Desktop/MD2 Research"
 var path:=root.path_join(FILE)
 if not FileAccess.file_exists(path)or FileAccess.get_sha256(path)!=SHA:return
 accept(JSON.parse_string(FileAccess.get_file_as_string(path)))
 var twilight_path := root.path_join(TWILIGHT_FILE)
 if FileAccess.file_exists(twilight_path) and FileAccess.get_sha256(twilight_path) == TWILIGHT_SHA:
  var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(twilight_path))
  var rgb: Array = data.rgb_to_green
  twilight_rgb_to_green = Vector3(rgb[0], rgb[1], rgb[2])
func accept(data:Variant)->bool:
 anchors.clear();verified=false
 if not data is Dictionary or data.get("schema")!="private-sky-source-response/1"or data.get("operation")!="componentwise-linear-rgb-ratio"or data.get("native_clock_recovered")!=false:return false
 var rows=data.get("anchors")
 if not rows is Array or rows.size()!=HOURS.size():return false
 for i in HOURS.size():
  var row=rows[i]
  if not row is Dictionary or row.get("hour")!=HOURS[i]or not row.get("rgb_ratio")is Array or row.rgb_ratio.size()!=3:return false
  for value in row.rgb_ratio:
   if not(value is float or value is int)or not is_finite(value)or value<0. or value>4.:return false
 if rows[-1].rgb_ratio!=[1.,1.,1.]:return false
 anchors=rows.duplicate(true);verified=true;return true
func available()->bool:return verified and anchors.size()==HOURS.size()

func twilight_available() -> bool:
 return available() and twilight_rgb_to_green != Vector3.ZERO

func twilight_color(rgb: Vector3, hour: float, strength: float) -> Vector3:
 if not twilight_available() or not is_finite(hour) or strength <= 0.0:
  return rgb
 # WorldMap review times for the short-lived shift seen between PIX 07, 08 and 09.
 var weight := strength * smoothstep(19.0, 19.5, hour) * (1.0 - smoothstep(19.5, 20.0, hour))
 if weight <= 0.0:
  return rgb
 var tint := twilight_rgb_to_green * (rgb.dot(LUMA) / twilight_rgb_to_green.dot(LUMA))
 return rgb.lerp(tint, weight)

func sample(hour:float)->Vector3:
 if not available()or not is_finite(hour):return Vector3.ONE
 var h:=fposmod(hour,24.)
 if h>12.:h=24.-h # Retained GAF mirrored evening; actual capture hours are unknown.
 var i:=0
 while i<6 and h>HOURS[i+1]:i+=1
 var a:Array=anchors[i].rgb_ratio;var b:Array=anchors[i+1].rgb_ratio
 return Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),smoothstep(HOURS[i],HOURS[i+1],h))
