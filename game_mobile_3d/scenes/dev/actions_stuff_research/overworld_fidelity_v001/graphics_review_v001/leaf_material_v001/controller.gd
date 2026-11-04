extends RefCounted
## Optional private vertex-weight material adapter. Never rebuilds a source mesh.
var graphics:Node
var lab:Node
var error:=""
var active:=false
var configured:=false
var _texture:ImageTexture
var _materials:Array[ShaderMaterial]=[]
var _saved:Array[Dictionary]=[]
var _strength:=0.
func setup(owner:Node,scene:Node)->void:graphics=owner;lab=scene
func _fail(message:String)->bool:error=message;return false
func _sha(bytes:PackedByteArray)->String:
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func configure_external(path:String)->bool:
 if configured:return true
 if not OS.has_feature("editor")or not lab.private_bundle.permitted(path)or not FileAccess.file_exists(path):return _fail("Private leaf profile unavailable")
 var p:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not p is Dictionary or p.get("schema","")!="private_leaf_vertex_material_v1":return _fail("Invalid leaf profile")
 for key:String in["asset_path","asset_sha256","colors_path","colors_sha256"]:
  if not p.get(key,null)is String:return _fail("Invalid leaf identity")
 if not p.get("imported_hashes",null)is Dictionary:return _fail("Missing imported mesh identity")
 for key:String in["positions","uv","indices"]:
  if not p.imported_hashes.get(key,null)is String:return _fail("Invalid imported mesh identity")
 if typeof(p.get("vertices",null))not in[TYPE_INT,TYPE_FLOAT]or typeof(p.get("indices",null))not in[TYPE_INT,TYPE_FLOAT]or typeof(p.get("scatter_strength",null))not in[TYPE_INT,TYPE_FLOAT]:return _fail("Invalid leaf dimensions")
 var count:int=int(p.vertices);var strength:float=float(p.scatter_strength)
 if count<1 or count>RenderingServer.get_rendering_device().limit_get(RenderingDevice.LIMIT_MAX_TEXTURE_SIZE_2D)or not is_finite(strength)or strength<0. or strength>1.:return _fail("Unsupported leaf dimensions/strength")
 for key:String in["asset_path","colors_path"]:
  if not lab.private_bundle.permitted(p[key])or not FileAccess.file_exists(p[key]):return _fail("Leaf reference data must remain private")
 if FileAccess.get_sha256(p.asset_path)!=p.asset_sha256 or FileAccess.get_sha256(p.colors_path)!=p.colors_sha256:return _fail("Changed leaf source data")
 var bytes:=FileAccess.get_file_as_bytes(p.colors_path)
 if bytes.size()!=count*4:return _fail("Invalid leaf color payload")
 var found:Array[ShaderMaterial]=[]
 for tree:Node in graphics.strict_match.trees.get_children():
  if tree.get_meta("private_source_sha256","")!=p.asset_sha256:continue
  for child:Node in tree.find_children("*","MeshInstance3D",true,false):
   var instance:MeshInstance3D=child
   for surface in instance.mesh.get_surface_count():
    var arrays:Array=instance.mesh.surface_get_arrays(surface);var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    if positions.size()!=count or indices.size()!=int(p.indices):return _fail("Leaf mesh counts differ")
    if _sha(positions.to_byte_array())!=p.imported_hashes.positions or _sha(uv.to_byte_array())!=p.imported_hashes.uv or _sha(indices.to_byte_array())!=p.imported_hashes.indices:return _fail("Leaf imported vertex order differs")
    var material:Material=instance.get_active_material(surface)
    if not material is ShaderMaterial:return _fail("Leaf reference material unavailable")
    if not found.has(material):found.append(material)
 if found.is_empty():return _fail("Matching private leaf mesh unavailable")
 _texture=ImageTexture.create_from_image(Image.create_from_data(count,1,false,Image.FORMAT_RGBA8,bytes));_materials=found;_strength=strength;configured=true;error="";return true
func apply(value:bool)->void:
 if value==active:return
 if not value:
  for row:Dictionary in _saved:
   for key:String in row["values"]:row.material.set_shader_parameter(key,row["values"][key])
  _saved.clear();active=false;return
 if not configured:return
 for material:ShaderMaterial in _materials:
  var values:Dictionary={}
  for key:String in["gaf_leaf_material_enabled","gaf_leaf_vertex_colors","gaf_leaf_scatter_strength"]:values[key]=material.get_shader_parameter(key)
  _saved.append({"material":material,"values":values});material.set_shader_parameter("gaf_leaf_vertex_colors",_texture);material.set_shader_parameter("gaf_leaf_scatter_strength",_strength);material.set_shader_parameter("gaf_leaf_material_enabled",true)
 active=true
func release()->void:
 apply(false);_materials.clear();_texture=null;configured=false
func snapshot()->Dictionary:return {"active":active,"configured":configured,"materials":_materials.size(),"error":error,"native_lighting":false,"mesh_rebuilt":false,"texture_payload_bytes":0 if _texture==null else _texture.get_width()*4}
