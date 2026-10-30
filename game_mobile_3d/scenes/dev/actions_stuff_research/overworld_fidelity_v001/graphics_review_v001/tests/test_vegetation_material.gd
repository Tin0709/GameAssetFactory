extends SceneTree
## Original synthetic inputs only. No private assets or reference palette required.
const SHADER_PATH="res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/foundation_vegetation.gdshader"
var viewport:SubViewport
var frame:=0
var cases:Array[Dictionary]=[]
func _initialize()->void:call_deferred("begin")
func begin()->void:
	var source:=FileAccess.get_file_as_string(SHADER_PATH)
	var declaration:=""
	for line:String in source.split("\n"):
		if line.begins_with("uniform sampler2D review_grass_noise"):declaration=line
	if declaration.is_empty():push_error("Missing material data sampler");quit(2);return
	var image:=Image.create(4,4,false,Image.FORMAT_RGBAF)
	for y in 4:
		for x in 4:image.set_pixel(x,y,Color(float(x)/4.,float(y)/4.,float((x+y)%4)/4.,1.))
	var texture:=ImageTexture.create_from_image(image)
	# Negative, fractional and repeated coordinates distinguish point from linear
	# filtering and clamp, without depending on a proprietary noise image.
	for u:float in [-1.01,-.251,-.01,.001,.249,.251,.499,.501,.749,.751,.999,1.001,1.251]:
		for v:float in [-.02,.13,.51,1.26]:
			var pixel:=Vector2i(posmod(floori(u*4.),4),posmod(floori(v*4.),4))
			cases.append({"uv":Vector2(u,v),"expected":image.get_pixelv(pixel)})
	viewport=SubViewport.new();viewport.size=Vector2i(cases.size()*4,8);viewport.use_hdr_2d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var shader:=Shader.new();shader.code="shader_type canvas_item;render_mode unshaded,blend_disabled;"+declaration+"uniform vec2 sample_uv;void fragment(){COLOR=texture(review_grass_noise,sample_uv);}"
	for i in cases.size():
		var rect:=ColorRect.new();rect.position=Vector2(i*4,0);rect.size=Vector2(4,8)
		var mat:=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("review_grass_noise",texture);mat.set_shader_parameter("sample_uv",cases[i].uv)
		rect.material=mat;viewport.add_child(rect)
func _process(_delta:float)->bool:
	frame+=1
	if frame==20 and viewport!=null:RenderingServer.frame_post_draw.connect(check,CONNECT_ONE_SHOT)
	return false
func check()->void:
	var image:=viewport.get_texture().get_image();var failures:Array=[];var worst:=0.
	for i in cases.size():
		var actual:=image.get_pixel(i*4+2,4);var expected:Color=cases[i].expected
		var error:=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))
		worst=maxf(worst,error)
		if error>.00001:failures.append({"uv":str(cases[i].uv),"actual":str(actual),"expected":str(expected)})
	print("VEGETATION_SAMPLER_GPU ",JSON.stringify({"cases":cases.size(),"failures":failures,"max_error":worst,"format":image.get_format()}))
	quit(0 if failures.is_empty()else 1)
