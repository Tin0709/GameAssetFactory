extends RefCounted
## Original map-owned incident field; no runtime rays or proprietary radiance.
var origin:Vector3
var step:Vector3
var dimensions:Vector3i
var sky:PackedFloat32Array
var sun:PackedFloat32Array
var valid:PackedByteArray
var ready:=false
func initialize(resource:Resource)->bool:
 ready=false
 for key in ["origin","step","dimensions"]:
  var a:Variant=resource.get_meta(key,[])
  if not a is Array or a.size()!=3:return false
  for v in a:
   if not(v is float or v is int)or not is_finite(float(v)):return false
 var a:Array=resource.get_meta("origin");origin=Vector3(a[0],a[1],a[2])
 a=resource.get_meta("step");step=Vector3(a[0],a[1],a[2])
 a=resource.get_meta("dimensions")
 for v in a:
  if float(v)!=floorf(float(v))or float(v)<2. or float(v)>256.:return false
 dimensions=Vector3i(int(a[0]),int(a[1]),int(a[2]))
 if step.x<=0 or step.y<=0 or step.z<=0:return false
 var count:=dimensions.x*dimensions.y*dimensions.z
 if count>100000:return false
 if not resource.get_meta("sky",null)is PackedFloat32Array or not resource.get_meta("sun",null)is PackedFloat32Array or not resource.get_meta("valid",null)is PackedByteArray:return false
 sky=resource.get_meta("sky");sun=resource.get_meta("sun");valid=resource.get_meta("valid")
 if sky.size()!=count*18 or sun.size()!=count*18 or valid.size()!=count:return false
 for values in [sky,sun]:
  for v in values:
   if not is_finite(v)or v<0 or v>4:return false
 for v in valid:
  if v>1:return false
 ready=true;return true
func sample(position:Vector3)->Dictionary:
 var result={"valid":false,"sky":PackedVector3Array(),"sun":PackedVector3Array()}
 if not ready or not position.is_finite():return result
 var p:Vector3=(position-origin)/step
 if p.x<0 or p.y<0 or p.z<0 or p.x>dimensions.x-1 or p.y>dimensions.y-1 or p.z>dimensions.z-1:return result
 var lo:=Vector3i(mini(floori(p.x),dimensions.x-2),mini(floori(p.y),dimensions.y-2),mini(floori(p.z),dimensions.z-2))
 var f:=p-Vector3(lo);var total:=0.
 var s:=PackedVector3Array();var b:=PackedVector3Array();s.resize(6);b.resize(6)
 for dx in 2:
  for dy in 2:
   for dz in 2:
    var index:=((lo.x+dx)*dimensions.y+lo.y+dy)*dimensions.z+lo.z+dz
    if valid[index]==0:continue
    var w:float=(f.x if dx else 1.-f.x)*(f.y if dy else 1.-f.y)*(f.z if dz else 1.-f.z)
    total+=w
    for axis in 6:
     var k:=index*18+axis*3
     s[axis]+=Vector3(sky[k],sky[k+1],sky[k+2])*w;b[axis]+=Vector3(sun[k],sun[k+1],sun[k+2])*w
 if total<.0001:return result
 for i in 6:s[i]/=total;b[i]/=total
 return {"valid":true,"sky":s,"sun":b}
