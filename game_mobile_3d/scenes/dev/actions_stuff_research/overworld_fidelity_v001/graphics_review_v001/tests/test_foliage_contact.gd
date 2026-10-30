extends SceneTree
const HELPER="res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/foliage_contact_math.gdshaderinc"
var fixture:Dictionary
var viewport:SubViewport
var frames:=0
var label:="current"
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
	call_deferred("begin")
func begin()->void:
	fixture=make_cases()
	var helper:=FileAccess.get_file_as_string("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/foliage_wind_math.gdshaderinc")+FileAccess.get_file_as_string(HELPER)
	var shader:=Shader.new();shader.code="""
shader_type canvas_item;render_mode unshaded,blend_disabled;
uniform vec3 probe_relative_position;uniform vec2 probe_encoded;
uniform vec3 probe_main;uniform float probe_time;uniform float probe_frequency;
uniform float probe_threshold;uniform float probe_strong_gain;uniform float probe_angle_scale;
uniform float probe_pin;uniform float probe_ramp;uniform int probe_output_component;
"""+helper+"""
void fragment(){
 vec3 contact=foliage_contact_wpo(probe_relative_position,probe_encoded,probe_time,probe_frequency,probe_threshold,probe_strong_gain,probe_angle_scale,probe_pin,probe_ramp);
 vec3 delta=probe_main+contact;
 uint word=floatBitsToUint(delta[probe_output_component]);
 COLOR=vec4(float(word&255u),float((word>>8u)&255u),float((word>>16u)&255u),float((word>>24u)&255u))/255.;
}
"""

	if shader.get_shader_uniform_list().is_empty():push_error("Wind probe failed shader preflight");quit(2);return
	# Four RGBA8 bytes preserve each float32 result, including sign, rather than
	# measuring the half-float viewport's quantization as shader arithmetic error.
	viewport=SubViewport.new();viewport.size=Vector2i(128*3,ceili(float(fixture.cases.size())/128.));viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	for i in fixture.cases.size():
		var row:Dictionary=fixture.cases[i]
		for component in 3:
			var mat:=ShaderMaterial.new();mat.shader=shader
			mat.set_shader_parameter("probe_relative_position",vec(row.relative));mat.set_shader_parameter("probe_main",vec(row.main));mat.set_shader_parameter("probe_encoded",Vector2(row.encoded[0],row.encoded[1]));mat.set_shader_parameter("probe_output_component",component)
			for key:String in ["time","frequency","threshold","strong_gain","angle_scale","pin","ramp"]:mat.set_shader_parameter("probe_"+key,row[key])
			var rect:=ColorRect.new();rect.position=Vector2((i%128)*3+component,int(i/128));rect.size=Vector2.ONE;rect.material=mat;viewport.add_child(rect)
func _process(_delta:float)->bool:
	frames+=1
	if frames==25 and viewport!=null:RenderingServer.frame_post_draw.connect(check,CONNECT_ONE_SHOT)
	return false
func check()->void:
	var image:=viewport.get_texture().get_image();var bytes:=image.get_data();var errors:Array=[];var rows:Array=[];var worst:=0.
	if image.get_format()!=Image.FORMAT_RGBA8:push_error("Float-bit probe requires raw RGBA8 readback");quit(2);return
	for i in fixture.cases.size():
		var q:Dictionary=fixture.cases[i];var actual:Array=[];var error:=0.
		for c in 3:
			var offset:int=(int(i/128)*image.get_width()+(i%128)*3+c)*4
			var value:=bytes.decode_float(offset);actual.append(value);error=INF if not is_finite(value)else maxf(error,absf(value-float(q.expected[c])))
		worst=maxf(worst,error)
		if not is_finite(error)or error>.00002:errors.append({"case":i,"label":q.label,"error_m":error})
		rows.append({"label":q.label,"actual":actual,"error_m":error})
	var out:={"cases":rows.size(),"max_error_m":worst,"first_case":rows[0],"errors":errors,"rows":rows,"scope":"Original synthetic invariants; no private reference inputs","readback":"float32 bits packed through RGBA8 UNORM, blend disabled"}

	print("CONTACT_SYNTHETIC ",JSON.stringify({"cases":rows.size(),"max_error_m":worst,"errors":errors.size(),"first":rows[0]}));quit(0 if errors.is_empty()else 1)

func make_cases()->Dictionary:
	var rows:Array=[]
	var seed_case:={"relative":[0.,0.,1.],"main":[0.,0.,0.],"encoded":[.5,0.],"time":0.,"frequency":1.,"threshold":1.,"strong_gain":1.,"angle_scale":.25,"pin":.1,"ramp":.01,"expected":[0.,0.,0.]}
	for threshold in [0.,.3,1.]:
		for red in [0.,.5,1.]:
			for clock in [0.,.125,3.7]:
				var row:Dictionary=seed_case.duplicate(true);row.threshold=threshold;row.encoded=[red,0.];row.time=clock;row.label="zero-field/"+str(rows.size());rows.append(row)
	for height in [-.2,0.,.05,.1]:
		var row:Dictionary=seed_case.duplicate(true);row.relative=[.2,.3,height];row.encoded=[.2,.8];row.time=.23;row.label="pin/"+str(height);rows.append(row)
	var axial:Dictionary=seed_case.duplicate(true);axial.threshold=0.;axial.encoded=[.5,1.];axial.expected=[0.,-1.,-1.];axial.label="unit-axis quarter turn";rows.append(axial)
	var diagonal:Dictionary=axial.duplicate(true);diagonal.encoded=[1.,1.];diagonal.strong_gain=1./sqrt(2.);diagonal.expected=[1.,-1.,-1.];diagonal.label="unnormalized-axis quarter turn";rows.append(diagonal)
	var endpoint:Dictionary=seed_case.duplicate(true);endpoint.encoded=[1.,1.];endpoint.time=0.;endpoint.label="zero over zero saturation boundary";rows.append(endpoint)
	return {"cases":rows}
