extends RefCounted
## Original low-frequency source transfer. Not native Lumen irradiance or clock recovery.
const FILE="godot_lab/world_map_unified_showcase_v001/night_fill_audit_v001/sky_profile.private.json"
const SHA="a6b1e9c5111bcab8317d402ad8b0e1cc7987c1cf326e39f2da137f31bec8091b"
const HOURS:=[0.,5.5,6.5,7.,8.,9.,10.,12.]
var anchors:Array=[]
var verified:=false
func _init()->void:
 if not OS.has_feature("editor"):return
 var root:=OS.get_environment("MD2_RESEARCH_ROOT")
 if root.is_empty():root="C:/Users/ADMIN/Desktop/MD2 Research"
 var path:=root.path_join(FILE)
 if not FileAccess.file_exists(path)or FileAccess.get_sha256(path)!=SHA:return
 accept(JSON.parse_string(FileAccess.get_file_as_string(path)))
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
func sample(hour:float)->Vector3:
 if not available()or not is_finite(hour):return Vector3.ONE
 var h:=fposmod(hour,24.)
 if h>12.:h=24.-h # Retained GAF mirrored evening; actual capture hours are unknown.
 var i:=0
 while i<6 and h>HOURS[i+1]:i+=1
 var a:Array=anchors[i].rgb_ratio;var b:Array=anchors[i+1].rgb_ratio
 return Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),smoothstep(HOURS[i],HOURS[i+1],h))
