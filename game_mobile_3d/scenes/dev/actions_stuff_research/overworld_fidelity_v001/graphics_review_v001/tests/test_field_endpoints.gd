extends SceneTree
const Transfer=preload("../field_endpoints.gd")
func _initialize()->void:
 var checks:=0
 for reach:float in[.7,1.4,2.8]:
  assert(Transfer.source_weight(0.,reach)==0.);assert(Transfer.source_weight(reach,reach)==1.);assert(Transfer.source_weight(reach*.5,reach)==.5);checks+=3
  var previous:=-1.
  for i in 1001:
   var x:float=reach*float(i)/1000.;var value:float=Transfer.source_weight(x,reach);assert(value>=0. and value<=1. and value>=previous);previous=value
   var legacy:float=lerpf(.30,1.,value);assert(absf((legacy-.30)/.70-value)<1e-12);checks+=2
  assert(Transfer.source_weight(-reach,reach)==0. and Transfer.source_weight(2.*reach,reach)==1.);checks+=1
 print("FIELD_ENDPOINT_TRANSFER_PASS ",checks);quit()
