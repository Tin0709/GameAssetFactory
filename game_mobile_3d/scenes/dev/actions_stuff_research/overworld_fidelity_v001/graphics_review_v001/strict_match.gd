extends Node
## One private static Day comparison. No source asset or calibration is embedded.
var controller_owner:Node
var lab:Node3D
var data:Dictionary={}
var saved:Dictionary={}
var correction:ImageTexture3D
var effect_error:=""
var enabled:=true
var available:=false
var stage:=0
func setup(controller:Node)->void:
	controller_owner=controller;lab=controller_owner.lab
	if OS.get_environment("GAF_STRICT_DAY_DISABLE")=="1"or not OS.has_feature("editor"):return
	var path:=OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research/godot_lab/overworld_strict_day_v001/profile.private.json")
	if not FileAccess.file_exists(path):return
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("schema","")!="private_strict_day_v1":return
	data=value;stage=int(data.stage)
	var stage_arg:=OS.get_environment("MD2_STRICT_STAGE")
	if not stage_arg.is_empty():stage=int(stage_arg)
	controller_owner.seek_cycle(.15,true)
	var env:Environment=lab.md2_lighting.environment
	for key:String in ["tonemap_mode","tonemap_exposure","tonemap_white","adjustment_enabled","glow_enabled","fog_enabled","adjustment_color_correction","adjustment_brightness","adjustment_contrast","adjustment_saturation"]:saved[key]=env.get(key)
	saved.compositor=lab.camera.compositor;saved.aa=lab.get_viewport().screen_space_aa;saved.msaa=lab.get_viewport().msaa_3d
	var lut_path:String=data.get("correction_path","")
	if not lab.private_bundle.permitted(lut_path)or FileAccess.get_sha256(lut_path)!=data.get("correction_sha256",""):return
	var bytes:=FileAccess.get_file_as_bytes(lut_path)
	var n:int=data.correction_size
	if bytes.size()!=n*n*n*16:return
	var slices:Array[Image]=[]
	for z in n:slices.append(Image.create_from_data(n,n,false,Image.FORMAT_RGBAF,bytes.slice(z*n*n*16,(z+1)*n*n*16)))
	var texture:=ImageTexture3D.new()
	if texture.create(Image.FORMAT_RGBAF,n,n,n,false,slices)!=OK:return
	correction=texture
	available=true;apply()
func apply()->void:
	if not available:return
	var env:Environment=lab.md2_lighting.environment
	if enabled and stage>=5:
		env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.tonemap_exposure=1.;env.adjustment_enabled=true;env.glow_enabled=false
		env.adjustment_brightness=1.;env.adjustment_contrast=1.;env.adjustment_saturation=1.;env.adjustment_color_correction=correction
		lab.camera.compositor=saved.compositor
		lab.get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA;lab.get_viewport().msaa_3d=Viewport.MSAA_DISABLED
	else:
		for key:String in saved:
			if key not in ["compositor","aa","msaa"]:env.set(key,saved[key])
		lab.camera.compositor=saved.compositor;lab.get_viewport().screen_space_aa=saved.aa;lab.get_viewport().msaa_3d=saved.msaa
func lock_camera()->void:
	if not available or not enabled:return
	var a:Array=data.camera_anchor;var anchor:=Vector3(a[0],a[1],a[2])
	lab.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;lab.camera.keep_aspect=Camera3D.KEEP_WIDTH;lab.camera.fov=45.
	lab.camera.global_position=anchor+Vector3(.5,sqrt(.5),.5)*float(data.camera_distance_m);lab.camera.look_at(anchor,Vector3.UP)
func release()->void:
	enabled=false;apply()
