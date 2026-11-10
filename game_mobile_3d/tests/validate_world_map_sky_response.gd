extends SceneTree
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize()->void:
 var script=load("res://scripts/world_map_sky_response.gd")
 var curve=script.new()
 var data:Dictionary={"schema":"private-sky-source-response/1","operation":"componentwise-linear-rgb-ratio","native_clock_recovered":false,"anchors":[]}
 for hour:float in script.HOURS:
  var value:float=.1+.9*hour/12.
  data.anchors.append({"hour":hour,"rgb_ratio":[value,value,value]})
 check(curve.accept(data),"independently authored fixture accepted")
 for row:Dictionary in data.anchors:
  check(curve.sample(row.hour).is_equal_approx(Vector3.ONE*float(row.rgb_ratio[0])),"anchor "+str(row.hour))
 check(curve.sample(12.)==Vector3.ONE,"exact Noon")
 check(curve.sample(24.)==curve.sample(0.),"day wrap")
 check(curve.sample(-1.)==curve.sample(23.),"negative hour wrap")
 check(curve.sample(7.)==curve.sample(17.),"explicit original mirror policy")
 check(curve.sample(NAN)==Vector3.ONE and curve.sample(INF)==Vector3.ONE,"nonfinite hours neutral")
 var previous:Vector3=curve.sample(7.)
 data.anchors[3].rgb_ratio=[0.,0.,0.]
 check(curve.sample(7.)==previous,"accepted profile does not alias caller data")
 data.anchors[3].rgb_ratio=[.625,.625,.625]
 for field:String in ["schema","operation","native_clock_recovered","anchors"]:
  var broken:Dictionary=data.duplicate(true);broken.erase(field)
  check(not curve.accept(broken) and not curve.available() and curve.sample(0.)==Vector3.ONE,"missing field neutral "+field)
 for value:Variant in [-1.,5.,NAN,INF,"1",null]:
  var broken:Dictionary=data.duplicate(true);broken.anchors[0].rgb_ratio[0]=value
  check(not curve.accept(broken) and not curve.available(),"invalid source coefficient "+str(value))
 var broken:Dictionary=data.duplicate(true);broken.anchors[-1].rgb_ratio=[.9,1.,1.]
 check(not curve.accept(broken),"reference normalization enforced")
 check(not curve.accept(null),"non-dictionary rejected")
 check(curve.accept(data),"recovery after invalid profile")
 for hour:float in [0.,5.5,6.5,7.,8.,9.,10.,12.]:
  check(curve.sample(hour-.00001).distance_to(curve.sample(hour+.00001))<.0001,"continuous boundary "+str(hour))
 print("WORLD_MAP_SKY_RESPONSE checks=",checks," failures=",failures)
 quit(0 if failures.is_empty()else 1)
