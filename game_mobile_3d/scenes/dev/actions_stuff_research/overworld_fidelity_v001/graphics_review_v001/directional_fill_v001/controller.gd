extends RefCounted
## Original opt-in calibration manager; no reference arrays are embedded.
var graphics:Node
var lab:Node
var error:=""
var configured:=false
var active:=false
var coefficients:=PackedVector3Array()
var residual:=Vector3.ZERO
var _saved:Array[Dictionary]=[]
func setup(owner:Node,scene:Node)->void:graphics=owner;lab=scene
func configure_external(path:String)->bool:
 if configured:return true
 if not OS.has_feature("editor")or not lab.private_bundle.permitted(path)or not FileAccess.file_exists(path):error="Private directional profile unavailable";return false
 var p:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not p is Dictionary or p.get("schema","")!="single_probe_directional_fill_reference_v1"or not p.get("coefficients_path",null)is String or not p.get("coefficients_sha256",null)is String or not p.get("reflection_residual_RGB",null)is Array or p.reflection_residual_RGB.size()!=3:error="Invalid directional profile";return false
 if not lab.private_bundle.permitted(p.coefficients_path):error="Directional coefficients must remain private";return false
 var bytes:=FileAccess.get_file_as_bytes(p.coefficients_path)
 if bytes.size()!=108 or FileAccess.get_sha256(p.coefficients_path)!=p.coefficients_sha256:error="Changed directional coefficients";return false
 var f:=bytes.to_float32_array()
 for v:float in f:
  if not is_finite(v):error="Nonfinite directional coefficient";return false
 for i in 3:
  var v:Variant=p.reflection_residual_RGB[i]
  if typeof(v)not in[TYPE_FLOAT,TYPE_INT]or not is_finite(float(v))or float(v)<0. or float(v)>1.:error="Invalid directional residual";return false
  residual[i]=float(v)
 # Reject a degenerate up-reference without inventing a fallback energy.
 for c in 3:
  var up:float=4.*(float(f[c])*.8862269520759583+float(f[6+c])*1.0233267545700073+float(f[18+c])*.24770796298980713*2.)
  if up<=.000001:error="Degenerate directional up reference";return false
 for i in 9:coefficients.append(Vector3(f[3*i],f[3*i+1],f[3*i+2]))
 configured=true;error="";return true
func _materials()->Array[ShaderMaterial]:
 var result:Array[ShaderMaterial]=[]
 for row:Dictionary in graphics.pairs:
  if not result.has(row.candidate):result.append(row.candidate)
 if graphics.strict_match!=null and graphics.strict_match.trees!=null:
  for m:ShaderMaterial in graphics.strict_match.trees.materials:
   if not result.has(m):result.append(m)
 return result
func apply(value:bool)->void:
 if value==active:return
 if not value:
  for row:Dictionary in _saved:
   for key:String in row["values"]:row.material.set_shader_parameter(key,row["values"][key])
  _saved.clear();active=false;return
 if not configured:return
 for m:ShaderMaterial in _materials():
  var values:Dictionary={}
  for key:String in["gaf_directional_fill_enabled","gaf_directional_sh","gaf_directional_residual"]:values[key]=m.get_shader_parameter(key)
  _saved.append({"material":m,"values":values});m.set_shader_parameter("gaf_directional_sh",coefficients);m.set_shader_parameter("gaf_directional_residual",residual);m.set_shader_parameter("gaf_directional_fill_enabled",true)
 active=true
func snapshot()->Dictionary:return {"active":active,"configured":configured,"materials":_saved.size(),"error":error,"single_probe_reference":true,"native_spatial_GI":false}
