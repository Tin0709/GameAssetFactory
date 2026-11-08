extends RefCounted
## Source color stays private; world shadow visibility is original GAF data.
const FILE="godot_lab/world_map_unified_showcase_v001/environment_light_integration_v002/scatter.private.json"
const SHA="4d6ad7d275e37c692bd1978e8664a724477ac586ae9c3e3ab2076cdc3a46384d"
const GRID="res://assets/graphics/world_map_air_light_v001/visibility.res"
var source_ready:=false
var source_rgb:=Vector3.ZERO
var level:Node3D
var cache:Resource
var texture:ImageTexture3D
var origin:Vector3
var step:Vector3
var dimensions:Vector3i
var _grid_ready:=false
func _init():
 if not OS.has_feature("editor"):return
 var research:=OS.get_environment("MD2_RESEARCH_ROOT")
 if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
 var path:=research.path_join(FILE)
 if not FileAccess.file_exists(path)or FileAccess.get_sha256(path)!=SHA:return
 var d=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not d is Dictionary or d.get("schema","")!="private-forest-gpu-scatter/1":return
 var rgb=d.get("linear_RGB",[])
 if not rgb is Array or rgb.size()!=3:return
 for v in rgb:
  if not(v is float or v is int)or not is_finite(v)or v<=0 or v>8:return
 source_rgb=Vector3(rgb[0],rgb[1],rgb[2]);source_ready=true
func setup(world:Node3D):
 level=world
 if RenderingServer.get_current_rendering_method()!="mobile"or RenderingServer.get_rendering_device()==null or not ResourceLoader.exists(GRID):return
 cache=load(GRID)
 if cache.get_meta("scope","")!="Original GAF static sun visibility, not native light shafts":return
 if cache.get_meta("source_runtime_sha256","")!=FileAccess.get_sha256(level.DATA)or not context_matches():return
 for key in ["origin","step","dimensions"]:
  var a=cache.get_meta(key,[])
  if not a is Array or a.size()!=3:return
  for v in a:
   if not(v is float or v is int)or not is_finite(v):return
 var a:Array=cache.get_meta("origin");origin=Vector3(a[0],a[1],a[2])
 a=cache.get_meta("step");step=Vector3(a[0],a[1],a[2])
 if step.x<=0 or step.y<=0 or step.z<=0:return
 a=cache.get_meta("dimensions")
 for v in a:
  if float(v)!=floorf(float(v))or v<2 or v>256:return
 dimensions=Vector3i(a[0],a[1],a[2]);var count:=dimensions.x*dimensions.y*dimensions.z
 if count>100000:return
 var bytes=cache.get_meta("visibility",null)
 if not bytes is PackedByteArray or bytes.size()!=count:return
 var slices:Array[Image]=[]
 for z in dimensions.z:
  var data:=PackedByteArray();data.resize(dimensions.x*dimensions.y)
  for y in dimensions.y:
   for x in dimensions.x:data[y*dimensions.x+x]=bytes[(x*dimensions.y+y)*dimensions.z+z]
  slices.append(Image.create_from_data(dimensions.x,dimensions.y,false,Image.FORMAT_R8,data))
 texture=ImageTexture3D.new()
 _grid_ready=texture.create(Image.FORMAT_R8,dimensions.x,dimensions.y,dimensions.z,false,slices)==OK
func context_matches()->bool:
 if cache==null or level==null or level.get("terrain_light")==null or not level.terrain_light.installed:return false
 for key in ["ambient_recipe_identity","material_fingerprints","surface_recipe_sha256","sun_direction"]:
  if not cache.has_meta(key)or cache.get_meta(key)!=level.terrain_light.cache.get_meta(key,null):return false
 return true
func shadow_available()->bool:
 if not _grid_ready or not context_matches()or not level.terrain_light.available():return false
 var d:Array=cache.get_meta("sun_direction");var sun:DirectionalLight3D=level.get_node("Sun")
 return sun.is_visible_in_tree() and sun.light_energy>0 and sun.global_basis.z.normalized().dot(Vector3(d[0],d[1],d[2]))>cos(deg_to_rad(.1))
func field()->Dictionary:
 return {"valid":shadow_available(),"texture":texture,"origin":origin,"step":step,"dimensions":Vector3(dimensions)}if _grid_ready else {"valid":false}
func day_weight(hour:float)->float:
 if not is_finite(hour):return 0.
 var h:=fposmod(hour,24.)
 return smoothstep(7.,12.,h) if h<=12. else 1.-smoothstep(12.,16.5,h)
func scatter_color(previous:Vector3,hour:float)->Vector3:
 if not source_ready:return previous
 var luma:=Vector3(.2126,.7152,.0722)
 return previous.lerp(source_rgb*(previous.dot(luma)/source_rgb.dot(luma)),day_weight(hour))
