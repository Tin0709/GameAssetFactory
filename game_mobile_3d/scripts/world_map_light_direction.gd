extends RefCounted
## Original Noon-anchored geometry transfer. Not a recovered native clock or map pose.
const SOURCE=preload("res://scripts/world_map_key_response.gd")
const FILE=SOURCE.FILE
const SHA=SOURCE.SHA
const HOURS=SOURCE.HOURS
var anchors:Array[Vector3]=[]
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
 if not data is Dictionary or data.get("schema")!="private-direct-key-response/1"or data.get("operation")!="componentwise-linear-rgb-ratio"or data.get("native_clock_recovered")!=false:return false
 var rows=data.get("anchors")
 if not rows is Array or rows.size()!=HOURS.size():return false
 var vectors:Array[Vector3]=[]
 for i in HOURS.size():
  var row=rows[i]
  if not row is Dictionary or row.get("hour")!=HOURS[i]:return false
  var a=row.get("direction_ue")
  if not a is Array or a.size()!=3:return false
  for n in a:
   if not(n is float or n is int)or not is_finite(n):return false
  var direction:=Vector3(a[1],a[2],-a[0]) # UE forward/right/up -> Godot -Z/+X/+Y.
  if absf(direction.length()-1.)>.0001 or direction.y<0.:return false
  vectors.append(direction.normalized())
 var reference:=vectors[-1]
 if reference.y<.0001 or Vector2(reference.x,reference.z).length()<.0001:return false
 for direction in vectors:
  if direction.y>reference.y+.000001:return false
 anchors=vectors;verified=true;return true
func available()->bool:return verified and anchors.size()==HOURS.size()
func sample(hour:float,noon:Vector3)->Vector3:
 if not available()or not is_finite(hour)or not noon.is_finite()or absf(noon.length()-1.)>.0001 or noon.y<=0. or noon.y>=.999999:return Vector3.ZERO
 var h:=fposmod(hour,24.)
 if h>12.:h=24.-h # Retained GAF mirror; native capture hours and handoff are unknown.
 if is_equal_approx(h,12.):return noon
 var i:=0
 while i<6 and h>HOURS[i+1]:i+=1
 var weight:=smoothstep(HOURS[i],HOURS[i+1],h)
 var a:=anchors[i];var b:=anchors[i+1];var reference:=anchors[-1]
 # Preserve captured relative NdotL on a horizontal receiver, anchored to Noon.
 var up:=noon.y*lerpf(a.y,b.y,weight)/reference.y
 if not is_finite(up)or up<0. or up>=1.:return Vector3.ZERO
 var yaw:=lerp_angle(atan2(a.x,a.z),atan2(b.x,b.z),weight)+atan2(noon.x,noon.z)-atan2(reference.x,reference.z)
 var horizontal:=sqrt(1.-up*up)
 return Vector3(sin(yaw)*horizontal,up,cos(yaw)*horizontal)
