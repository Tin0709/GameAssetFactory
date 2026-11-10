extends RefCounted
## Original source-only phase transfer on GAF's voxel/reserve model. Not Lumen.
const SOURCE=preload("res://scripts/world_map_sky_response.gd")
const HOURS=SOURCE.HOURS
const FILE="godot_lab/world_map_unified_showcase_v001/source_transport_probe_v001/voxel_phase_field_v001/bake_v002/profile.private.json"
const SHA="d08340b4153806a196ff76b8f661c6219352c17583c31f6adb8a913b7bdc6ac3"
const BASELINE="res://assets/graphics/world_map_actor_light_v001/field.res"
var _meta:Dictionary={}
var _host
var _samplers:Array=[]
var _base:=""
var _baseline_sha:=""
var _failed:=false
var loaded_bytes:=0
func digest(bytes:PackedByteArray)->String:
 var h=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func clear()->void:
 _meta={};_host=null;_samplers.clear();_base="";_baseline_sha="";_failed=false;loaded_bytes=0
func _valid_meta(data:Variant,host,baseline_sha:String)->bool:
 if host==null or not host.ready or not data is Dictionary:return false
 if data.get("schema")!="private-actor-filtered-sky/1"or data.get("operation")!="source-residual-before-mean/1"or data.get("native_clock_recovered")!=false:return false
 if data.get("baseline_sha256")!=baseline_sha or data.get("baseline_sky_sha256")!=digest(host.sky.to_byte_array())or data.get("source_mean_sha256")!=SOURCE.SHA:return false
 var rows=data.get("anchors")
 if not rows is Array or rows.size()!=8:return false
 for i in 8:
  var row=rows[i]
  if not row is Dictionary or row.get("hour")!=HOURS[i]or row.get("file")!="phase_%02d.private.bin"%i:return false
  if not row.get("sha256")is String or row.sha256.length()!=64:return false
  var values=row.get("mean_ratio")
  if not values is Array or values.size()!=3:return false
  for x in values:
   if not(x is float or x is int)or not is_finite(x)or x<=0. or x>4.:return false
 return rows[7].mean_ratio==[1.,1.,1.]
func prepare(host)->bool:
 clear()
 if not OS.has_feature("editor"):return false
 var root=OS.get_environment("MD2_RESEARCH_ROOT")
 if root.is_empty():root="C:/Users/ADMIN/Desktop/MD2 Research"
 var path=root.path_join(FILE)
 if not FileAccess.file_exists(path)or FileAccess.get_sha256(path)!=SHA:return false
 var data=JSON.parse_string(FileAccess.get_file_as_string(path));var baseline=FileAccess.get_sha256(BASELINE)
 if not _valid_meta(data,host,baseline):return false
 _meta=data.duplicate(true);_host=host;_base=path.get_base_dir();_baseline_sha=baseline;return true
func accept(data:Variant,arrays:Array,host,baseline_sha:String)->bool:
 clear()
 if not _valid_meta(data,host,baseline_sha)or arrays.size()!=8:return false
 var fields=[]
 for i in 8:
  var values=arrays[i]
  if not values is PackedFloat32Array or values.size()!=host.sky.size()or digest(values.to_byte_array())!=data.anchors[i].sha256:return false
  for x in values:
   if not is_finite(x)or x<0. or x>4.:return false
  var field=host.get_script().new();field.origin=host.origin;field.step=host.step;field.dimensions=host.dimensions;field.valid=host.valid;field.sun=host.sun;field.sky=PackedFloat32Array(values);field.ready=true;fields.append(field)
 if fields[7].sky!=host.sky:return false
 _meta=data.duplicate(true);_host=host;_baseline_sha=baseline_sha;_samplers=fields;loaded_bytes=host.sky.size()*4*8;return true
func available()->bool:return not _failed and _host!=null and _host.ready and not _meta.is_empty()
func _ensure()->bool:
 if not available():return false
 if _samplers.size()==8:return true
 var arrays=[];var meta=_meta;var host=_host;var sha=_baseline_sha
 for row in meta.anchors:
  var path=_base.path_join(row.file)
  if not FileAccess.file_exists(path)or FileAccess.get_sha256(path)!=row.sha256:_failed=true;return false
  var bytes=FileAccess.get_file_as_bytes(path)
  if bytes.size()!=host.sky.size()*4:_failed=true;return false
  arrays.append(bytes.to_float32_array())
 if not accept(meta,arrays,host,sha):_failed=true;return false
 return true
func sample(position:Vector3,hour:float,current_mean:Vector3)->Dictionary:
 var no={"valid":false,"sky":PackedVector3Array()}
 if not available()or not position.is_finite()or not is_finite(hour)or not current_mean.is_finite()or current_mean.x<=0. or current_mean.y<=0. or current_mean.z<=0.:return no
 var h=fposmod(hour,24.)
 if h>12.:h=24.-h # Original GAF mirror, not recovered native clock.
 var i=0
 while i<6 and h>HOURS[i+1]:i+=1
 var t=smoothstep(HOURS[i],HOURS[i+1],h);var a=_meta.anchors[i].mean_ratio;var b=_meta.anchors[i+1].mean_ratio;var ma=Vector3(a[0],a[1],a[2]);var mb=Vector3(b[0],b[1],b[2])
 if current_mean.distance_to(ma.lerp(mb,t))>.000002:return no
 if is_equal_approx(h,12.):return _host.sample(position)
 if not _ensure():return no
 var first=_samplers[i].sample(position);var second=_samplers[i+1].sample(position)
 if not first.valid or not second.valid:return no
 var sky=PackedVector3Array()
 for axis in 6:sky.append((first.sky[axis]*ma).lerp(second.sky[axis]*mb,t)/current_mean)
 return {"valid":true,"sky":sky}
