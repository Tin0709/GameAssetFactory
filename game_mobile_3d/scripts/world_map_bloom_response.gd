extends RefCounted
## Captured relative convolution gain. Time placement remains original GAF policy.
const FILE="godot_lab/world_map_unified_showcase_v001/multiscale_bloom_v001/response.private.json"
const SHA="f2003aa4e4c1ddae39877b99bda7b2de8f13bb8999c86ec14a6757e92eec19aa"
var anchors:Array=[]
func _init()->void:
 if not OS.has_feature("editor"):return
 var root:=OS.get_environment("MD2_RESEARCH_ROOT")
 if root.is_empty():root="C:/Users/ADMIN/Desktop/MD2 Research"
 var path:=root.path_join(FILE)
 if not FileAccess.file_exists(path)or FileAccess.get_sha256(path)!=SHA:return
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or data.get("schema")!="private-forest-bloom-response/1":return
 var rows=data.get("anchors");var hours:=[0.,5.5,6.5,7.,8.,9.,10.,12.]
 if not rows is Array or rows.size()!=8:return
 for i in 8:
  if not rows[i]is Dictionary:return
  for key in ["hour","ratio"]:
   var n=rows[i].get(key)
   if not(n is float or n is int)or not is_finite(n):return
  if float(rows[i].hour)!=hours[i]or rows[i].ratio<=0. or rows[i].ratio>4.:return
 if float(rows[7].ratio)!=1.:return
 anchors=rows
func available()->bool:return anchors.size()==8
func sample(hour:float)->float:
 if not available()or not is_finite(hour):return 1.
 var h:=fposmod(hour,24.)
 if h>12.:h=24.-h # Original mirrored evening, not recovered MD2 clock.
 var i:=0
 while i<6 and h>float(anchors[i+1].hour):i+=1
 return lerpf(float(anchors[i].ratio),float(anchors[i+1].ratio),smoothstep(float(anchors[i].hour),float(anchors[i+1].hour),h))
