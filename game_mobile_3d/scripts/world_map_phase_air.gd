extends RefCounted
## Private measured anchors; clock placement/interpolation are original GAF policy.
const FILE="godot_lab/world_map_unified_showcase_v001/phase_atmosphere_integration_v001/phase.private.json"
const SHA="cf6397a816b5c893275fa4c9d72f2c77f33b2a0421c45f73351a47a4c34f2698"
var anchors:Array=[]
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
