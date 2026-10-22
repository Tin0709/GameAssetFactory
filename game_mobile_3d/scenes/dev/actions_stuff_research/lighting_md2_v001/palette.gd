extends RefCounted
## Original art parameters, not an extraction of MD2 or third-party GLSL.
const HOURS:=[0.,5.,7.,12.,16.5,18.5,20.,22.,24.]
const COLOR_FIELDS:=["key","ambient","sky","horizon","fog","ground"]
const FLOAT_FIELDS:=["energy","ambient_energy","exposure","saturation","fog_amount","fog_end","pitch","yaw"]
var keys:Array[Dictionary]=[]

func _init()->void:
	# time,key,ambient,sky,horizon,fog,ground,keyenergy,fill,exposure,sat,fog,end,pitch,yaw
	var rows:=[
		["b6cdf5","a0bce0","182b48","3e5679","415a79","263747",.30,.45,1.08,.93,.20,52.,-35.,95.],
		["e3c6be","7589a8","536b94","b3a4b2","8b9eae","54646c",.32,.34,1.02,.95,.18,58.,-9.,-115.],
		["ffe0b3","abc7df","5c9fc5","e6c5ac","b8cdd5","65766b",1.18,.42,.98,.98,.14,64.,-19.,-100.],
		["fff0d4","a7c9df","4b94c8","bfcfdb","b9d5dd","5d7669",1.35,.34,.96,.98,.10,70.,-58.,-35.],
		["ffd09a","83a4c8","6c9faf","dec2ac","c6bdaf","696f62",1.12,.39,.98,.97,.18,58.,-24.,38.],
		["ffc4b0","94abcd","414f80","c79aa7","888fa9","4b5567",.40,.44,1.05,.94,.25,52.,-8.,68.],
		["b5c9ff","89a6d0","1e2d50","626f91","3b5072","25374b",.18,.42,1.10,.93,.23,50.,-27.,110.],
		["b6cdf5","a0bce0","182b48","3e5679","415a79","263747",.30,.45,1.08,.93,.20,52.,-40.,105.],
		["b6cdf5","a0bce0","182b48","3e5679","415a79","263747",.30,.45,1.08,.93,.20,52.,-35.,95.]
	]
	for row:Array in rows:
		var key:={}
		for i in COLOR_FIELDS.size():key[COLOR_FIELDS[i]]=Color.html(row[i])
		for i in FLOAT_FIELDS.size():key[FLOAT_FIELDS[i]]=float(row[COLOR_FIELDS.size()+i])
		keys.append(key)

func sample(hour:float,into:Dictionary={})->Dictionary:
	var t:=fposmod(hour,24.) if is_finite(hour) else 12.
	var index:=0
	while index<HOURS.size()-2 and t>HOURS[index+1]:index+=1
	var weight:=smoothstep(HOURS[index],HOURS[index+1],t)
	var a:=keys[index];var b:=keys[index+1]
	for field:String in COLOR_FIELDS:into[field]=Color(a[field]).lerp(b[field],weight)
	for field:String in FLOAT_FIELDS:into[field]=lerpf(a[field],b[field],weight)
	return into
