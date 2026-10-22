extends RefCounted
## Dev-only compiler of the audited JSON AST subset into Godot bytecode.
## No source evaluation/rewrite or clock changes. Lazy branches and ordered
## side effects become explicit statements; each root keeps its return scope.
const KERNEL_PATH="res://scenes/dev/actions_stuff_research/molang_vm.gd"
const TAGS=["program","unary","binary","call","assign","return","conditional"]
static var _cache:Dictionary={}

static func prepare(value:Variant)->Variant:
 var roots:Array=[]
 _gather(value,roots)
 if roots.is_empty():return value
 var state:={"lines":PackedStringArray(),"next":0}
 state.lines.append("extends RefCounted\nconst VM=preload("+JSON.stringify(KERNEL_PATH)+")")
 for i in roots.size():
  state.lines.append("func e"+str(i)+"(env:Dictionary)->Variant:")
  var result:=_emit(roots[i],state,1)
  _line(state,1,"return "+result)
 var code:String="\n".join(state.lines)
 var program:RefCounted
 if _cache.has(code):program=_cache[code].get_ref()
 if program==null:
  var script:=GDScript.new();script.source_code=code
  if script.reload()!=OK:
   push_error("Molang source bytecode compilation failed; retaining literal VM")
   return value
  program=script.new()
  _cache[code]=weakref(program)
 for i in roots.size():
  var node:Array=roots[i]
  node.clear();node.append("compiled_program");node.append(Callable(program,"e"+str(i)))
 return value

static func _gather(value:Variant,roots:Array)->void:
 if value is Dictionary:
  for item in value.values():_gather(item,roots)
 elif value is Array and not value.is_empty():
  if value[0] is String:
   if value[0] in ["literal","variable","compiled_program"]:return
   if value[0] in TAGS:roots.append(value);return
  for item in value:_gather(item,roots)

static func _name(value:String)->String:
 if value.begins_with("variable."):return "v."+value.substr(9)
 if value.begins_with("query."):return "q."+value.substr(6)
 if value.begins_with("temp."):return "t."+value.substr(5)
 return value
static func _line(s:Dictionary,indent:int,code:String)->void:s.lines.append(" ".repeat(indent)+code)
static func _store(s:Dictionary,indent:int,expression:String)->String:
 var name:="v"+str(s.next);s.next+=1
 _line(s,indent,"var "+name+":Variant="+expression)
 return name
static func _emit(n:Array,s:Dictionary,indent:int)->String:
 match n[0]:
  "literal":return _store(s,indent,JSON.stringify(n[1],"",true,true))
  "variable":return _store(s,indent,"env.get("+JSON.stringify(_name(n[1]))+",0.0)")
  "assign":
   var a:=_emit(n[2],s,indent)
   _line(s,indent,"env["+JSON.stringify(_name(n[1]))+"]="+a)
   return a
  "return":
   var a:=_emit(n[1],s,indent)
   _line(s,indent,"return "+a)
   return a
  "program":
   var a:="0.0"
   for child in n[1]:a=_emit(child,s,indent)
   return a if n[1].size()==1 else "0.0"
  "conditional":
   var condition:=_emit(n[1],s,indent)
   var result:=_store(s,indent,"null")
   _line(s,indent,"if "+condition+":")
   var a:=_emit(n[2],s,indent+1);_line(s,indent+1,result+"="+a)
   _line(s,indent,"else:")
   var b:=_emit(n[3],s,indent+1);_line(s,indent+1,result+"="+b)
   return result
  "unary":
   var a:=_emit(n[2],s,indent)
   return _store(s,indent,"float(not "+a+")" if n[1]=="!" else ("-"+a if n[1]=="-" else a))
  "binary":
   var op:String=n[1];var a:=_emit(n[2],s,indent)
   if op in ["&&","||","??"]:
    var result:=_store(s,indent,"null")
    var condition:=a if op=="&&" else ("not "+a if op=="||" else a+"==null")
    _line(s,indent,"if "+condition+":")
    var b:=_emit(n[3],s,indent+1)
    _line(s,indent+1,result+"="+(b if op=="??" else "float(bool("+b+"))"))
    _line(s,indent,"else:")
    _line(s,indent+1,result+"="+(a if op=="??" else ("0.0" if op=="&&" else "1.0")))
    return result
   var b:=_emit(n[3],s,indent)
   match op:
    "+","-","*":return _store(s,indent,a+op+b)
    "/":return _store(s,indent,"float("+a+")/float("+b+") if "+b+" else 0.0")
    "%":return _store(s,indent,"fmod(float("+a+"),float("+b+")) if "+b+" else 0.0")
    "==","!=":return _store(s,indent,"float("+("not " if op=="!=" else "")+"VM._equal("+a+","+b+"))")
    "<",">","<=",">=":return _store(s,indent,"float("+a+op+b+")")
  "call":
   var function:=_name(n[1]);var args:=PackedStringArray()
   for child in n[2]:args.append(_emit(child,s,indent))
   var arguments:String="["+",".join(args)+"]"
   if function.begins_with("math."):return _store(s,indent,"VM._math("+JSON.stringify(function.substr(5))+","+arguments+")")
   var callback:=_store(s,indent,"env.get("+JSON.stringify(function)+")")
   return _store(s,indent,callback+".callv("+arguments+") if "+callback+" is Callable else 0.0")
 _line(s,indent,"push_error(\"Unsupported compiled Molang node\")")
 return "0.0"
