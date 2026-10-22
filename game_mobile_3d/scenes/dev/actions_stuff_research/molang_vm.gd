extends RefCounted
## Executes JSON ASTs emitted by the audited Python molang._compile.
## Degree math, ordered assignments and lazy branches match that source subset.
## Environment keys are flattened v.*, t.*, q.*; q.* calls require Callable.
static func execute(node: Array, env: Dictionary) -> Variant:
	# Literal channels and direct reads have no side effects or nested return.
	# Avoid allocating a return frame for these very common authored channels.
	if node[0]=="native_expression":return _native(node,env)
	if node[0]=="literal":return node[1]
	if node[0]=="variable":return env.get(_name(node[1]),0.0)
	return _execute(node, env, {"returned": false, "value": 0.0})

static func _name(value: String) -> String:
	# Same case-sensitive aliases; no temporary array-of-pairs per AST read.
	if value.begins_with("variable."):return "v."+value.substr(9)
	if value.begins_with("query."):return "q."+value.substr(6)
	if value.begins_with("temp."):return "t."+value.substr(5)
	return value

static func _execute(node: Array, env: Dictionary, frame: Dictionary) -> Variant:
	if frame.returned: return frame.value
	match node[0]:
		"native_expression":return _native(node,env)
		"literal": return node[1]
		"variable": return env.get(_name(node[1]), 0.0)
		"assign":
			var value = _execute(node[2], env, frame)
			if frame.returned: return frame.value
			env[_name(node[1])] = value
			return value
		"return":
			frame.value = _execute(node[1], env, frame)
			frame.returned = true
			return frame.value
		"program":
			var value: Variant = 0.0
			for child in node[1]:
				value = _execute(child, env, frame)
				if frame.returned: return frame.value
			return value if node[1].size() == 1 else 0.0
		"conditional":
			return _execute(node[2] if _execute(node[1], env, frame) else node[3], env, frame)
		"unary":
			var value = _execute(node[2], env, frame)
			if frame.returned: return frame.value
			if node[1] == "!": return float(not value)
			return -value if node[1] == "-" else value
		"binary":
			var op: String = node[1]
			var a = _execute(node[2], env, frame)
			if frame.returned: return frame.value
			if op == "&&": return float(bool(a) and bool(_execute(node[3], env, frame)))
			if op == "||": return float(bool(a) or bool(_execute(node[3], env, frame)))
			if op == "??": return a if a != null else _execute(node[3], env, frame)
			var b = _execute(node[3], env, frame)
			if frame.returned: return frame.value
			match op:
				"+": return a + b
				"-": return a - b
				"*": return a * b
				"/": return float(a) / float(b) if b else 0.0
				"%": return fmod(float(a), float(b)) if b else 0.0
				"==": return float(_equal(a, b))
				"!=": return float(not _equal(a, b))
				"<": return float(a < b)
				">": return float(a > b)
				"<=": return float(a <= b)
				">=": return float(a >= b)
			push_error("Unsupported Molang binary operator: " + op)
		"call":
			var function: String = _name(node[1])
			var args: Array = []
			for arg in node[2]:
				args.append(_execute(arg, env, frame))
				if frame.returned: return frame.value
			if function.begins_with("math."): return _math(function.substr(5), args)
			if function.begins_with("q.") and env.get(function) is Callable:
				return env[function].callv(args)
			push_error("Unsupported Molang call or missing Callable: " + function)
		_: push_error("Unsupported Molang AST node: " + str(node[0]))
	return 0.0

static func _math(function: String, a: Array) -> Variant:
	var x: float = float(a[0]) if not a.is_empty() else 0.0
	match function:
		"sin": return sin(deg_to_rad(x))
		"cos": return cos(deg_to_rad(x))
		"atan": return rad_to_deg(atan(x))
		"atan2": return rad_to_deg(atan2(x, float(a[1])))
		"abs": return absf(x)
		"min": return a.min()
		"max": return a.max()
		"pow":
			var result := pow(x, float(a[1]))
			return result if is_finite(result) else 0.0
		"sqrt": return sqrt(x) if x >= 0.0 else 0.0
		"exp":
			var result := exp(x)
			return result if is_finite(result) else 0.0
		"floor": return floor(x)
		"ceil": return ceil(x)
		"round": return floor(x + 0.5)
		"mod": return fmod(x, float(a[1])) if a[1] else 0.0
		"clamp": return minf(float(a[2]), maxf(float(a[1]), x))
		"lerp": return x + (float(a[1]) - x) * float(a[2])
		"min_angle": return fposmod(x + 180.0, 360.0) - 180.0
		"sign": return float(x > 0.0) - float(x < 0.0)
		"hermite_blend": return x * x * (3.0 - 2.0 * x)
		"ease_out_cubic": return x + (float(a[1])-x)*(1.0-pow(1.0-float(a[2]),3.0))
		"ease_in_out_back":
			# Standard Back easing adapter. Bedrock documents overshoot semantics,
			# but does not publish its engine coefficient; this is declared in the audit.
			var t: float = float(a[2])
			var c := 1.70158*1.525
			var u := 2.0*t if t < .5 else 2.0*t-2.0
			var blend := u*u*((c+1.0)*u-c)*.5 if t < .5 else (u*u*((c+1.0)*u+c)+2.0)*.5
			return x + (float(a[1])-x)*blend
	push_error("Unsupported Molang Math function: " + function)
	return 0.0

static func _equal(a: Variant, b: Variant) -> bool:
	# Python permits unlike scalar types in equality (numeric vs string is false).
	if (a is String) != (b is String): return false
	return a == b

# Compile only side-effect-free arithmetic channel trees. Ordered assignments,
# lazy branches, query Callables and return statements keep the literal VM path.
static func compile_channel(node:Array)->Array:
	if node[0] in ["literal","variable"]:return node
	if node[0]=="program" and node[1].size()==1 and node[1][0][0] in ["literal","variable"]:return node[1][0]
	var variables:Array[String]=[]
	var source:=_channel_source(node,variables)
	if source.is_empty():return node
	var expression:=Expression.new()
	var inputs:=PackedStringArray()
	for i in variables.size():inputs.append("x"+str(i))
	if expression.parse(source,inputs)!=OK:return node
	return ["native_expression",expression,variables]

static func _channel_source(node:Array,variables:Array[String])->String:
	match node[0]:
		"literal":
			return JSON.stringify(node[1],"",true,true) if node[1] is float else ""
		"variable":
			var key:=_name(node[1])
			if not variables.has(key):variables.append(key)
			return "x"+str(variables.find(key))
		"program":
			return _channel_source(node[1][0],variables) if node[1].size()==1 else ""
		"unary":
			if node[1] not in ["-","+"]:return ""
			var value:=_channel_source(node[2],variables)
			return "("+node[1]+value+")" if not value.is_empty() else ""
		"binary":
			if node[1] not in ["+","-","*","/"]:return ""
			# Keep zero-division protection and dynamic divisors in the original VM.
			if node[1]=="/" and (node[3][0]!="literal" or not node[3][1]):return ""
			var a:=_channel_source(node[2],variables)
			var b:=_channel_source(node[3],variables)
			return "("+a+node[1]+b+")" if not a.is_empty() and not b.is_empty() else ""
		"call":
			if node[1] not in ["math.sin","math.cos","math.atan","math.abs"] or node[2].size()!=1:return ""
			var value:=_channel_source(node[2][0],variables)
			if value.is_empty():return ""
			match node[1]:
				"math.sin":return "sin(deg_to_rad("+value+"))"
				"math.cos":return "cos(deg_to_rad("+value+"))"
				"math.atan":return "rad_to_deg(atan("+value+"))"
				"math.abs":return "abs("+value+")"
	return ""

static func _native(node:Array,env:Dictionary)->Variant:
	var inputs:Array=[]
	for key in node[2]:inputs.append(env.get(key,0.0))
	return node[1].execute(inputs,null,true,true)

static func prepare(value:Variant)->Variant:
	# Only JSON AST roots are rewritten, once at construction. Pure subtrees
	# inside ordered/lazy programs can use native arithmetic without reordering.
	if value is Dictionary:
		for key in value:value[key]=prepare(value[key])
	elif value is Array and not value.is_empty():
		if value[0] is String and value[0] in ["literal","variable"]:return value
		if value[0] is String and value[0] in ["program","unary","binary","call","assign","return","conditional"]:
			var compiled:=compile_channel(value)
			if compiled[0]=="native_expression" or compiled[0] in ["literal","variable"]:return compiled
		for i in value.size():value[i]=prepare(value[i])
	return value
