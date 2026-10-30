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
	print("GRADE_DOMAIN ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty()else 1)
