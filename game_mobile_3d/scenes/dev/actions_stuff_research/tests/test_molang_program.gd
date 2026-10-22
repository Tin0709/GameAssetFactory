extends SceneTree
## Compiler parity for ordered assignments, lazy branches, return scopes,
## query Callables, degree math and strong ownership after compiler returns.
const VM=preload("res://scenes/dev/actions_stuff_research/molang_vm.gd")
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func lit(x:Variant)->Array:return ["literal",x]
func v(x:String)->Array:return ["variable",x]
func b(op:String,a:Array,c:Array)->Array:return ["binary",op,a,c]
func assign(x:String,a:Array)->Array:return ["assign",x,a]
func program(a:Array)->Array:return ["program",a]
func run():
 var cases:Array=[
  program([assign("variable.x",b("+",v("q.n"),lit(2.))),assign("t.y",b("*",v("v.x"),lit(3.)))]),
  program([["conditional",v("q.n"),assign("v.x",lit(3.)),assign("v.x",lit(4.))]]),
  program([b("&&",v("q.n"),assign("v.x",lit(4.)))]),
  program([b("||",v("q.n"),assign("v.x",lit(4.)))]),
  program([b("??",v("q.optional"),assign("v.x",lit(4.)))]),
  program([["return",b("*",v("q.n"),lit(2.))],assign("v.never",lit(99.))]),
  program([b("&&",lit(1.),["return",lit(2.)]),assign("v.never",lit(9.))]),
  b("&&",lit(1.),["return",lit(2.)]),
  program([["call","query.test",[assign("v.x",v("q.n")),lit(2.)]]]),
  program([["call","math.sin",[b("*",v("q.n"),lit(180.))]]]),
  program([["call","math.clamp",[v("q.n"),lit(-.5),lit(.5)]]]),
  program([b("/",lit(5.),v("q.n"))]),
  program([b("%",lit(-5.),v("q.n"))]),
  program([b("==",lit("1"),lit(1.))])]
 var comparisons:=0
 for n in [-2.,0.,.27,1.,3.]:
  for original:Array in cases:
   var code:Array=original.duplicate(true);VM.prepare(code)
   var env:={"q.n":n,"q.optional":null,"q.test":func(a:float,c:float):return a+c}
   var expected_env:=env.duplicate();var actual_env:=env.duplicate()
   var expected:Variant=VM.execute(original,expected_env);var actual:Variant=VM.execute(code,actual_env)
   if expected!=actual or expected_env!=actual_env:failures.append("Value/environment parity "+str(comparisons));push_error(failures[-1])
   comparisons+=1
 print("MOLANG_PROGRAM ",JSON.stringify({"comparisons":comparisons,"failures":failures}));quit(0 if failures.is_empty() else 1)
