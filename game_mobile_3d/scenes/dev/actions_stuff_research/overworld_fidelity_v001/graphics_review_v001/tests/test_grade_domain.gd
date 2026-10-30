extends SceneTree
const Domain=preload("../grade_domain.gd")
func _initialize()->void:
	var errors:Array=[];var checks:=0
	for domain:float in [1.,1.25,1.5,2.]:
		checks+=1
		var brightness:float=Domain.ui_brightness(domain)
		var recovered:float=Color(brightness,brightness,brightness).srgb_to_linear().r
		if absf(recovered-1./domain)>.000001:errors.append({"domain":domain,"gain":recovered})
	for invalid:float in [0.,-1.,.999,2.001,INF,NAN]:
		checks+=1
		if Domain.supported(invalid)or Domain.ui_brightness(invalid)!=-1.:errors.append({"invalid_domain":str(invalid)})
	for size:int in [2,16,32,64,128]:
		for c:float in [0.,.5,1.]:
			checks+=1
			var u:=lerpf(.5,c,Domain.sampling_contrast(size))
			var expected:float=(c*(size-1)+.5)/size
			if absf(u-expected)>.000001:errors.append({"size":size,"coordinate":c,"mapped":u})
	for invalid:int in [-1,0,1]:
		checks+=1
		if Domain.sampling_contrast(invalid)!=-1.:errors.append({"invalid_size":invalid})
	print("GRADE_DOMAIN ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty()else 1)
