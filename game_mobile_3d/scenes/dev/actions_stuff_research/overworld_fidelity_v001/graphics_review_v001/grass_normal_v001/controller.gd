extends RefCounted
## Private reference parameter; original normal response, no native buffers embedded.
var graphics:Node
var lab:Node
var error:=""
var configured:=false
var active:=false
var weight:=0.
var _materials:Array[ShaderMaterial]=[]
var _saved:Array[Dictionary]=[]
func setup(owner:Node,scene:Node)->void:graphics=owner;lab=scene
func _fail(message:String)->bool:error=message;return false
func configure_external(path:String)->bool:
 if configured:return true
 if not OS.has_feature("editor")or not lab.private_bundle.permitted(path)or not FileAccess.file_exists(path):return _fail("Private grass normal profile unavailable")
 var p:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not p is Dictionary or p.get("schema","")!="private_grass_normal_parameter_v1":return _fail("Invalid grass normal profile")
 if not p.get("parameter_path",null)is String or not p.get("parameter_sha256",null)is String or typeof(p.get("byte_offset",null))not in[TYPE_INT,TYPE_FLOAT]:return _fail("Invalid grass normal parameter reference")
 var offset:float=float(p.byte_offset)
 if not is_finite(offset)or offset<0. or offset!=floor(offset)or offset>2147483643.:return _fail("Invalid grass normal parameter offset")
 if not lab.private_bundle.permitted(p.parameter_path)or not FileAccess.file_exists(p.parameter_path)or FileAccess.get_sha256(p.parameter_path)!=p.parameter_sha256:return _fail("Missing/changed grass normal parameter")
 var bytes:=FileAccess.get_file_as_bytes(p.parameter_path)
 if int(offset)+4>bytes.size():return _fail("Grass normal parameter outside payload")
 var value:float=bytes.decode_float(int(offset))
 if not is_finite(value)or value<0. or value>1.:return _fail("Invalid grass normal weight")
 var targets:Array[ShaderMaterial]=[]
 for row:Dictionary in graphics.pairs:
  var material:ShaderMaterial=row.candidate
  if material.shader!=null and material.shader.resource_path.ends_with("foundation_vegetation.gdshader")and material.get_shader_parameter("tinted_grass")==true and material.get_shader_parameter("review_grass_material")==true and not targets.has(material):targets.append(material)
 if targets.is_empty():return _fail("No compatible captured-grass material")
 _materials=targets;weight=value;configured=true;error="";return true
func apply(value:bool)->void:
 if value==active:return
 if not value:
  for row:Dictionary in _saved:
   for key:String in row["values"]:row.material.set_shader_parameter(key,row["values"][key])
  _saved.clear();active=false;return
 if not configured:return
 for material:ShaderMaterial in _materials:
  var values:Dictionary={}
  for key:String in["gaf_grass_normal_enabled","gaf_grass_normal_up_weight"]:values[key]=material.get_shader_parameter(key)
  _saved.append({"material":material,"values":values});material.set_shader_parameter("gaf_grass_normal_up_weight",weight);material.set_shader_parameter("gaf_grass_normal_enabled",true)
 active=true
func release()->void:
 apply(false);_materials.clear();configured=false
func snapshot()->Dictionary:return {"active":active,"configured":configured,"materials":_materials.size(),"error":error,"weight":weight,"world_space":true,"new_texture_bytes":0}
