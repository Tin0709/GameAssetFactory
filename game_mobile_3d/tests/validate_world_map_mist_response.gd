extends SceneTree
var failures=[]
var checks:=0
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func _initialize():
 var host=preload("res://scripts/world_map_showcase.gd").new()
 host._day={"ambient_light_color":Color(.5,.6,.7),"ambient_light_energy":.5,"sun_color":Color(.9,.8,.7),"sun_energy":1.}
 var phases=[]
 for i in 4:
  var row={}
  for key in host.forest.FLOATS:row[key]=1.
  for key in host.forest.VECTORS:row[key]=[1.,1.,1.]
  phases.append(row)
 host.forest.phases=phases
 host.phase_air.anchors=[{"hour":0.,"linear_scatter":[1.,1.,1.],"density_ratio":1.,"height_falloff_m":1.,"start_m":0.},{"hour":12.,"linear_scatter":[1.,1.,1.],"density_ratio":1.,"height_falloff_m":1.,"start_m":0.}]
 host.hour=7.;host.atmosphere_review="combined";host.measured_atmosphere=true
 var a={"scatter_energy":.25};host._apply_mist_source(a,{"linear_scatter":Vector3(1,2,3)},Vector3.ONE)
 var b={"scatter_energy":.25};host._apply_mist_source(b,{"linear_scatter":Vector3(2,4,6)},Vector3.ONE)
 check(host.mist_source_active and absf(b.scatter_energy/a.scatter_energy-2.)<.00001,"source proportionality")
 for invalid in [Vector3.ZERO,Vector3(INF,1,1),Vector3(NAN,1,1)]:
  var output={"scatter_energy":.25};host.mist_source_active=false
  host._apply_mist_source(output,{"linear_scatter":Vector3.ONE},invalid)
  check(output.scatter_energy==.25 and not host.mist_source_active,"invalid denominator "+str(invalid))
 for mode in ["previous","haze","lighting"]:
  host.atmosphere_review=mode
  var output={"scatter_energy":.25};host.mist_source_active=false
  host._apply_mist_source(output,{"linear_scatter":Vector3.ONE},Vector3.ONE)
  check(output.scatter_energy==.25 and not host.mist_source_active,"context "+mode)
 host.atmosphere_review="combined";host.hour=12.
 var noon={"scatter_energy":.25};host.mist_source_active=false;host._apply_mist_source(noon,{"linear_scatter":Vector3.ONE},Vector3.ONE)
 check(noon.scatter_energy==.25 and not host.mist_source_active,"Noon bypass")
 host.hour=7.;host.phase_air.anchors=[]
 var missing={"scatter_energy":.25};host._apply_mist_source(missing,{"linear_scatter":Vector3.ONE},Vector3.ONE)
 check(missing.scatter_energy==.25,"missing proof")
 var forest_profile := load("res://assets/graphics/biomes/forest_reference.tres") as Resource
 var scatter_track := forest_profile.get("mist_front_scatter_by_hour") as Curve
 check(scatter_track != null and is_equal_approx(scatter_track.sample(.375),1.2),"Forest brings in-scattering forward at 09:00")
 if scatter_track != null:
  for time:float in [7.,12.,16.5,19.5,22.]:
   check(scatter_track.sample(time/24.)==0.,"Approved phase keeps the earlier scattering depth: "+str(time))
 print("MIST_SOURCE_UNIT checks=",checks," failures=",JSON.stringify(failures));host.free();quit(0 if failures.is_empty()else 1)
