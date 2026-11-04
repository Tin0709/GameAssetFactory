extends RefCounted
## Original unit conversion: common exposed signal <-> metered pre-exposed input.
static func conversion(grade:float,eye:float,pre:float)->Dictionary:
 if not is_finite(grade)or not is_finite(eye)or not is_finite(pre)or grade<=0. or eye<=0. or pre<=0.:return {"valid":false}
 var scale:=grade/eye*pre
 if not is_finite(scale)or scale<=0.:return {"valid":false}
 return {"valid":true,"physical_scale":grade/eye,"to_native_preexposed":scale,"to_current":1./scale}
