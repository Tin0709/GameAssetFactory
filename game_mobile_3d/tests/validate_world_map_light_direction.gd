extends SceneTree
var checks:=0
var failures=[]
func check(value:bool,label:String)->void:
 checks+=1
 if not value:failures.append(label)
func fixture()->Dictionary:
 var rows=[];var hours=[0.,5.5,6.5,7.,8.,9.,10.,12.];var up=[.2,.15,.25,.35,.5,.6,.7,.8]
 for i in 8:
  var horizontal=sqrt(1.-up[i]*up[i])*(-1. if i>0 else 1.)
  rows.append({"hour":hours[i],"direction_ue":[horizontal,0.,up[i]]})
 return {"schema":"private-direct-key-response/1","operation":"componentwise-linear-rgb-ratio","native_clock_recovered":false,"anchors":rows}
func _initialize():
 var path="res://scripts/world_map_light_direction.gd"
 if not ResourceLoader.exists(path):
  check(false,"Direction transfer missing");print("DIRECTION_UNIT ",failures);quit(1);return
 var curve=load(path).new();var data=fixture();check(curve.accept(data),"Original fixture accepted")
 var noon=Vector3(.4,.6,sqrt(.48));var yaw=atan2(noon.x,noon.z)
 for row in data.anchors:
  var d:Vector3=curve.sample(row.hour,noon)
  check(absf(d.length()-1.)<.000002,"Unit direction "+str(row.hour))
  check(absf(d.y/noon.y-float(row.direction_ue[2])/.8)<.000002,"Ground NdotL ratio "+str(row.hour))
  var expected=yaw+(PI if row.hour==0. else 0.)
  check(absf(wrapf(atan2(d.x,d.z)-expected,-PI,PI))<.000002,"Relative azimuth "+str(row.hour))
 check(curve.sample(12.,noon).is_equal_approx(noon),"Noon anchored")
 check(curve.sample(18.5,noon)==curve.sample(5.5,noon)and curve.sample(-5.5,noon)==curve.sample(18.5,noon),"Original mirror/wrap")
 for time in [NAN,INF]:check(curve.sample(time,noon)==Vector3.ZERO,"Invalid time")
 for invalid in [Vector3.ZERO,Vector3.UP,Vector3(0,-1,0),Vector3(2,.5,0),Vector3(NAN,0,0)]:
  check(curve.sample(7.,invalid)==Vector3.ZERO,"Invalid Noon "+str(invalid))
 for time in [0.,5.5,6.5,7.,8.,9.,10.,12.,24.]:
  check(curve.sample(time-.0001,noon).distance_to(curve.sample(time+.0001,noon))<.001,"Continuous seam "+str(time))
 var saved:Vector3=curve.sample(7.,noon);data.anchors[3].direction_ue[0]=100.
 check(curve.sample(7.,noon)==saved,"Defensive copy")
 for invalid in [Vector3.ZERO,Vector3(INF,0,1),Vector3(0,0,-1),Vector3(2,0,0)]:
  var bad=fixture();bad.anchors[0].direction_ue=[invalid.x,invalid.y,invalid.z]
  check(not curve.accept(bad)and not curve.available(),"Malformed vector clears state")
 var bad=fixture();bad.anchors[2].hour=7.;check(not curve.accept(bad),"Wrong clock rejected")
 bad=fixture();bad.native_clock_recovered=true;check(not curve.accept(bad),"Unproven native clock rejected")
 check(curve.sample(7.,noon)==Vector3.ZERO,"Missing proof neutral")
 print("DIRECTION_UNIT checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty()else 1)
