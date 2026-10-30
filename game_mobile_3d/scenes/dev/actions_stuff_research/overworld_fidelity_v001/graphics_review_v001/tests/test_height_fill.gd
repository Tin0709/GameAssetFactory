extends SceneTree
## Synthetic geometry invariants for the original flat-map irradiance adapter.
const SOURCE="res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/foundation_solid.gdshader"
var viewport:SubViewport
var cases:Array[Dictionary]=[]
var frame:=0
func _initialize()->void:call_deferred("begin")
func begin()->void:
	var source:=FileAccess.get_file_as_string(SOURCE)
	var expression:String=source.split("gaf_diffuse_fill=")[1].split(";")[0]
	expression=expression.replace("textureLod(gaf_indirect_field,(p.xz-gaf_field_origin)/gaf_field_extent,0.0)","probe_field").replace("p.y","probe_height")
	var helpers:=""
	for line:String in source.split("\n"):
		if line.begins_with("#include"):helpers+=FileAccess.get_file_as_string(SOURCE.get_base_dir().path_join(line.split('"')[1]))+"\n"
	var shader:=Shader.new();shader.code="""
shader_type canvas_item;render_mode unshaded,blend_disabled;
uniform vec4 probe_field;
uniform float probe_height;
uniform bool gaf_height_aware_fill;
uniform float gaf_fill_height_fade;
uniform vec3 gaf_open_fill;
"""+helpers+"void fragment(){COLOR=vec4("+expression+",1.);}"
	var ground:=Color(.125,.25,.375,1.);var open:=Color(.5,.625,.75,1.)
	for enabled:bool in [false,true]:
		for h:float in [-1.,0.,1.,1.5,1.75,2.,3.]:
			var expected:=ground
			if enabled and h==1.75:expected=ground.lerp(open,.5)
			if enabled and h>=2.:expected=open
			cases.append({"enabled":enabled,"height":h,"expected":expected,"roof":2.})
	# No overhead geometry must never darken an exposed surface.
	cases.append({"enabled":true,"height":0.,"expected":open,"roof":-1.})
	viewport=SubViewport.new();viewport.size=Vector2i(cases.size()*4,8);viewport.use_hdr_2d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	for i in cases.size():
		var row:Dictionary=cases[i];var material:=ShaderMaterial.new();material.shader=shader
		material.set_shader_parameter("probe_field",Vector4(ground.r,ground.g,ground.b,row.roof));material.set_shader_parameter("probe_height",row.height)
		material.set_shader_parameter("gaf_height_aware_fill",row.enabled);material.set_shader_parameter("gaf_open_fill",Vector3(open.r,open.g,open.b));material.set_shader_parameter("gaf_fill_height_fade",.5)
		var rect:=ColorRect.new();rect.position=Vector2(i*4,0);rect.size=Vector2(4,8);rect.material=material;viewport.add_child(rect)
func _process(_delta:float)->bool:
	frame+=1
	if frame==20 and viewport!=null:RenderingServer.frame_post_draw.connect(check,CONNECT_ONE_SHOT)
	return false
func check()->void:
	var image:=viewport.get_texture().get_image();var errors:Array=[]
	for i in cases.size():
		var actual:=image.get_pixel(i*4+2,4);var expected:Color=cases[i].expected
		var error:=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))
		if error>.00001:errors.append({"case":i,"height":cases[i].height,"enabled":cases[i].enabled,"error":error})
	var result:={"cases":cases.size(),"errors":errors,"scope":"Original height-aware adapter invariants, not native Lumen validation"}
	print("HEIGHT_FILL_GPU ",JSON.stringify(result))
	var out:=OS.get_environment("GAF_GRAPHICS_TEST_OUTPUT")
	if not out.is_empty():var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(result));f.close()
	quit(0 if errors.is_empty()else 1)
