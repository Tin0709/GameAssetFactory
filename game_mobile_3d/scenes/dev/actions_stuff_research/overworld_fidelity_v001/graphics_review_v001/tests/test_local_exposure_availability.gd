extends SceneTree
const Policy=preload("../local_exposure_v001/availability.gd")
var failures:Array=[]
func check(value:bool,message:String)->void:
	if not value:failures.append(message)
func _initialize()->void:
	var good:={"editor":true,"renderer":"mobile","metadata_available":true,"reference_requested":true}
	check(Policy.evaluate(good).allowed,"Explicit editor Mobile reference is available")
	for change:Dictionary in [{"editor":false},{"renderer":"gl_compatibility"},{"renderer":"forward_plus"},{"metadata_available":false},{"reference_requested":false}]:
		var context:Dictionary=good.duplicate();context.merge(change,true)
		var result:Dictionary=Policy.evaluate(context)
		check(not result.allowed,"Unsupported/private or Auto must preserve baseline: "+str(change))
		check(not result.reason.is_empty(),"Fallback must explain why: "+str(change))
	check(not Policy.evaluate(good).phone_benchmarked,"Desktop support must not claim handset performance")
	print("LOCAL_EXPOSURE_AVAILABILITY ",JSON.stringify({"checks":12,"failures":failures}))
	quit(0 if failures.is_empty()else 1)
