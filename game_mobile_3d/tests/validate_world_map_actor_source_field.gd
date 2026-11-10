extends SceneTree
var checks:=0
var failures=[]
func check(v,label):
 checks+=1
 if not v:failures.append(label)
func fixture():
 var r=Resource.new();r.set_meta("origin",[0.,0.,0.]);r.set_meta("step",[1.,1.,1.]);r.set_meta("dimensions",[2,2,2]);var values=PackedFloat32Array();values.resize(144);values.fill(.25);r.set_meta("sky",values);var zero=PackedFloat32Array();zero.resize(144);r.set_meta("sun",zero);var valid=PackedByteArray();valid.resize(8);valid.fill(1);r.set_meta("valid",valid);var host=load("res://scripts/world_map_actor_irradiance.gd").new();assert(host.initialize(r));return host
func _initialize():
 if not ResourceLoader.exists("res://scripts/world_map_actor_source_field.gd"):push_error("Actor source field is not implemented");quit(1);return
 var Script=load("res://scripts/world_map_actor_source_field.gd");var obj=Script.new();var host=fixture();var arrays=[];var data={"schema":"private-actor-filtered-sky/1","operation":"source-residual-before-mean/1","native_clock_recovered":false,"baseline_sha256":"fixture","baseline_sky_sha256":obj.digest(host.sky.to_byte_array()),"source_mean_sha256":obj.SOURCE.SHA,"anchors":[]}
 var scales=[.5,.25,.3,.31,.32,.29,.27,.25];var means=[2.,4.,1.5,1.25,1.2,1.1,1.05,1.]
 for i in 8:
  var value=PackedFloat32Array();value.resize(144);value.fill(scales[i]);arrays.append(value);data.anchors.append({"hour":obj.HOURS[i],"mean_ratio":[means[i],means[i],means[i]],"file":"phase_%02d.private.bin"%i,"sha256":obj.digest(value.to_byte_array())})
 check(obj.accept(data,arrays,host,"fixture"),"Original fixture accepted")
 for i in 8:
  var q=obj.sample(Vector3(.3,.4,.7),obj.HOURS[i],Vector3.ONE*means[i]);check(q.valid and q.sky[0].is_equal_approx(Vector3.ONE*scales[i]),"Anchor "+str(i))
 var q=obj.sample(Vector3(.4,.2,.8),2.75,Vector3.ONE*3.);check(q.valid and q.sky[0].distance_to(Vector3.ONE/3.)<.000001,"Interpolate source before mean division")
 check(obj.sample(Vector3(.4,.2,.8),12.,Vector3.ONE).sky==host.sample(Vector3(.4,.2,.8)).sky,"Noon exact")
 check(obj.sample(Vector3(.4,.2,.8),21.25,Vector3.ONE*3.).sky==q.sky,"Existing mirror policy")
 for args in [[Vector3(-.1,.2,.8),2.75,Vector3.ONE*3.],[Vector3(.4,.2,.8),NAN,Vector3.ONE],[Vector3(.4,.2,.8),2.75,Vector3.ZERO],[Vector3(.4,.2,.8),2.75,Vector3.ONE],[Vector3(INF,0,0),2.75,Vector3.ONE*3.]]:check(not obj.sample(args[0],args[1],args[2]).valid,"Invalid receiver/clock/mean neutral")
 arrays[0][0]=3.;data.anchors[0].mean_ratio[0]=3.;check(obj.sample(Vector3.ZERO,0.,Vector3.ONE*2.).sky[0]==Vector3.ONE*.5,"Owned fixture snapshot")
 var bads=[];var bad=data.duplicate(true);bad.schema="bad";bads.append(bad);bad=data.duplicate(true);bad.native_clock_recovered=true;bads.append(bad);bad=data.duplicate(true);bad.anchors[7].mean_ratio=[2,2,2];bads.append(bad)
 for bad_data in bads:check(not obj.accept(bad_data,arrays,host,"fixture")and not obj.available(),"Rejected metadata clears state")
 print("ACTOR_SOURCE_FIELD checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty()else 1)
