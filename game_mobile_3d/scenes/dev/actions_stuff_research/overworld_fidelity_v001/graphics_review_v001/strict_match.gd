extends Node
## One private static Day comparison. No source asset or calibration is embedded.
const Trees=preload("private_trees.gd")
const GradeDomain=preload("grade_domain.gd")
var trees:Node3D
var controller_owner:Node
var lab:Node3D
var data:Dictionary={}
var saved:Dictionary={}
var player_light:OmniLight3D
var vignette_layer:CanvasLayer
var noise_texture:ImageTexture
var field_texture:ImageTexture
var sun_saved:Dictionary={}
var correction:ImageTexture3D
var effect_error:=""
var enabled:=true
var available:=false
var stage:=0
func setup(controller:Node)->void:
	controller_owner=controller;lab=controller_owner.lab
	if OS.get_environment("GAF_STRICT_DAY_DISABLE")=="1"or not OS.has_feature("editor"):return
	var path:=OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research/godot_lab/overworld_strict_day_v001/profile.private.json")
	var profile_override:=OS.get_environment("MD2_STRICT_DAY_PROFILE")
	if not profile_override.is_empty():
		if not lab.private_bundle.permitted(profile_override):effect_error="Private profile must remain inside Research";return
		path=profile_override
	if not FileAccess.file_exists(path):return
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("schema","")!="private_strict_day_v1":return
	data=value;stage=int(data.stage)
	if not GradeDomain.supported(float(data.get("correction_input_domain_linear",1.))):effect_error="Unsupported LUT input domain";return
	if bool(data.get("correction_hdr_2d",false))!=bool(data.get("correction_output_linear",false)):
		effect_error="LUT output encoding must match the HDR2D target";return
	var stage_arg:=OS.get_environment("MD2_STRICT_STAGE")
	if not stage_arg.is_empty():stage=int(stage_arg)
	controller_owner.seek_cycle(.15,true)
	var env:Environment=lab.md2_lighting.environment
	for key:String in ["tonemap_mode","tonemap_exposure","tonemap_white","adjustment_enabled","glow_enabled","fog_enabled","adjustment_color_correction","adjustment_brightness","adjustment_contrast","adjustment_saturation","glow_intensity","glow_hdr_threshold","glow_bloom","glow_blend_mode","glow_strength","fog_depth_begin","fog_depth_end","fog_height_density"]:saved[key]=env.get(key)
	saved.compositor=lab.camera.compositor;saved.aa=lab.get_viewport().screen_space_aa;saved.msaa=lab.get_viewport().msaa_3d;saved.hdr_2d=lab.get_viewport().use_hdr_2d
	var lut_path:String=data.get("correction_path","")
	if not lab.private_bundle.permitted(lut_path)or FileAccess.get_sha256(lut_path)!=data.get("correction_sha256",""):return
	var bytes:=FileAccess.get_file_as_bytes(lut_path)
	var n:int=data.correction_size
	if bool(data.get("correction_texel_centered",false)) and GradeDomain.sampling_contrast(n)<0.:effect_error="Invalid LUT lattice size";return
	if bytes.size()!=n*n*n*16:return
	var slices:Array[Image]=[]
	for z in n:
		var image:=Image.create_from_data(n,n,false,Image.FORMAT_RGBAF,bytes.slice(z*n*n*16,(z+1)*n*n*16));image.convert(Image.FORMAT_RGBAH);slices.append(image)
	var texture:=ImageTexture3D.new()
	if texture.create(Image.FORMAT_RGBAH,n,n,n,false,slices)!=OK:return
	correction=texture
	var noise_path:String=data.grass_noise_path
	if not lab.private_bundle.permitted(noise_path)or FileAccess.get_sha256(noise_path)!=data.grass_noise_sha256:return
	noise_texture=ImageTexture.create_from_image(Image.load_from_file(noise_path))
	for key:String in ["directional_shadow_max_distance","shadow_bias","shadow_normal_bias","shadow_blur","directional_shadow_mode","directional_shadow_split_1"]:sun_saved[key]=lab.md2_lighting.sun.get(key)
	trees=Trees.new();trees.name="PrivateSourceTrees";lab.add_child(trees);var backlight:Array=data.tree_backlight_rgb
	trees.setup(lab,data.get("trees",[]),float(data.get("tree_hue_angle",0.)),Vector3(backlight[0],backlight[1],backlight[2]))
	_build_field()
	trees.set_field(field_texture)
	player_light=OmniLight3D.new();player_light.name="NightPlayerLightPresetAdapter";player_light.omni_range=5.;player_light.light_color=Color.WHITE;player_light.shadow_enabled=false;lab.player.add_child(player_light);player_light.position=Vector3(0,1.5,0)
	_build_vignette()
	available=true;apply()
func apply()->void:
	if not available:return
	var env:Environment=lab.md2_lighting.environment
	if vignette_layer!=null:vignette_layer.visible=enabled and stage>=5
	if player_light!=null:player_light.visible=enabled and stage>=6
	if trees!=null:trees.set_enabled(enabled and stage>=6)
	# Opt-in original adapter: the previous ground-only field remains selectable.
	var use_height:bool=enabled and stage>=3 and bool(data.get("height_aware_fill",false)) and OS.get_environment("GAF_HEIGHT_FILL_DISABLE")!="1"
	var open_values:Array=data.incoming_open_linear;var gain_values:Array=data.get("incoming_adapter_rgb",[1.,1.,1.])
	var open_fill:=Vector3(open_values[0]*gain_values[0],open_values[1]*gain_values[1],open_values[2]*gain_values[2])
	var height_fade:float=float(data.get("fill_height_fade_m",.5))
	if trees!=null:trees.set_height_fill(use_height,open_fill,height_fade)
	for row:Dictionary in controller_owner.pairs:
		row.candidate.set_shader_parameter("review_irradiance_scale",1.)
		row.candidate.set_shader_parameter("gaf_indirect_field",field_texture if enabled and stage>=3 else controller_owner.field.texture)
		row.candidate.set_shader_parameter("gaf_fill_up_ratio",1. if enabled and stage>=3 else .35)
		row.candidate.set_shader_parameter("gaf_height_aware_fill",use_height)
		row.candidate.set_shader_parameter("gaf_open_fill",open_fill)
		row.candidate.set_shader_parameter("gaf_fill_height_fade",height_fade)
		if row.plant:
			row.candidate.set_shader_parameter("review_grass_material",enabled and stage>=6 and row.original.get_meta("source_material","")=="MI_Grass_Plains")
			# Native material scattering is a pre-gust output. Keep its strength
			# separate from the existing approximate Godot lighting-response gain.
			var scatter_strength:float=float(data.get("grass_scatter_strength",1.))
			var scattering:Array=data.grass_backlight_rgb
			row.candidate.set_shader_parameter("review_backlight_rgb",Vector3(scattering[0],scattering[1],scattering[2])/maxf(scatter_strength,.000001))
			row.candidate.set_shader_parameter("review_scatter_strength",scatter_strength)
			row.candidate.set_shader_parameter("review_gust_height",float(data.get("grass_gust_height",0.)))
			row.candidate.set_shader_parameter("review_gust_falloff",float(data.get("grass_gust_falloff",1.)))
			row.candidate.set_shader_parameter("review_grass_noise",noise_texture)
			var tint:Array=data.grass_world_color;row.candidate.set_shader_parameter("review_world_color",Vector3(tint[0],tint[1],tint[2]))
			var origin:Array=data.grass_world_origin_cm;row.candidate.set_shader_parameter("review_world_origin_cm",Vector2(origin[0],origin[1]));row.candidate.set_shader_parameter("review_time",data.grass_captured_time)
			row.candidate.set_shader_parameter("review_tip_height",float(data.get("grass_tip_height",.8)))
			row.candidate.set_shader_parameter("review_tip_falloff",float(data.get("grass_tip_falloff",.52)))
		if not row.plant:
			row.candidate.set_shader_parameter("review_path",enabled and stage>=2 and row.original.get_meta("source_material","")=="MI_MasterTerrain_Opaque_Overworld")
			var rects:Array[Vector4]=[]
			for i in range(1,4):rects.append(_top_rect("MD2 RECON | Dirt block "+str(i)))
			row.candidate.set_shader_parameter("review_source_rects",rects)
			var v:Array=data.path_target_rect;row.candidate.set_shader_parameter("review_target_rect",Vector4(v[0],v[1],v[2],v[3]))
			row.candidate.set_shader_parameter("review_emissive_gain",30. if enabled and stage>=2 and row.original.get_meta("source_material","")=="MI_MasterTerrain_Opaque_Overworld"else 1.)
	for key:String in saved:
		if key not in ["compositor","aa","msaa","hdr_2d"]:env.set(key,saved[key])
	var sun:DirectionalLight3D=lab.md2_lighting.sun
	for key:String in sun_saved:sun.set(key,sun_saved[key])
	if enabled and stage>=3:
		env.fog_depth_begin=40.;env.fog_depth_end=140.;env.fog_height_density=0.
	if enabled and stage>=4:
		sun.directional_shadow_max_distance=data.shadow_distance_m;sun.shadow_bias=data.shadow_bias;sun.shadow_normal_bias=data.shadow_normal_bias;sun.shadow_blur=data.shadow_blur
		sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS;sun.directional_shadow_split_1=.45
	if enabled and stage>=5:
		# Explicit private high-precision review only. The existing target stays
		# the default; FP16 bandwidth needs real mobile-device validation.
		lab.get_viewport().use_hdr_2d=bool(data.get("correction_hdr_2d",false))
		env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.tonemap_exposure=1.;env.adjustment_enabled=true;env.glow_enabled=true
		env.glow_intensity=float(data.glow_intensity);env.glow_hdr_threshold=float(data.glow_threshold);env.glow_bloom=float(data.get("glow_bloom",0.));env.glow_blend_mode=Environment.GLOW_BLEND_MODE_ADDITIVE;env.glow_strength=1.
		env.adjustment_brightness=GradeDomain.ui_brightness(float(data.get("correction_input_domain_linear",1.)))
		env.adjustment_contrast=GradeDomain.sampling_contrast(int(data.correction_size)) if bool(data.get("correction_texel_centered",false))else 1.
		env.adjustment_saturation=1.;env.adjustment_color_correction=correction
		lab.camera.compositor=saved.compositor
		lab.get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA;lab.get_viewport().msaa_3d=Viewport.MSAA_DISABLED
	else:
		lab.get_viewport().use_hdr_2d=saved.hdr_2d
		lab.camera.compositor=saved.compositor;lab.get_viewport().screen_space_aa=saved.aa;lab.get_viewport().msaa_3d=saved.msaa
func _build_vignette()->void:
	vignette_layer=CanvasLayer.new();vignette_layer.name="StrictDayPresentation";vignette_layer.layer=-5;add_child(vignette_layer)
	var rectangle:=ColorRect.new();rectangle.mouse_filter=Control.MOUSE_FILTER_IGNORE;rectangle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);vignette_layer.add_child(rectangle)
	var shader:=Shader.new();shader.code="shader_type canvas_item;render_mode blend_mul;uniform float strength=0.;void fragment(){vec2 p=(UV*2.-1.)*strength;float v=1./pow(1.+dot(p,p),2.);COLOR=vec4(vec3(v),1.);}"
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("strength",float(data.vignette));rectangle.material=material
func _top_rect(asset:String)->Vector4:
	var lo:=Vector2.ONE;var hi:=Vector2.ZERO
	for entry:Dictionary in lab.private_bundle.data.assets:
		if entry.name!=asset:continue
		for surface:Dictionary in entry.surfaces:
			for i in int(surface.normals.size()/3):
				if float(surface.normals[i*3+1])>.99:
					var uv:=Vector2(surface.uv[i*2],surface.uv[i*2+1]);lo=lo.min(uv);hi=hi.max(uv)
	return Vector4(lo.x,lo.y,hi.x,hi.y)
func _build_field()->void:
	var image:=Image.create(196,196,false,Image.FORMAT_RGBAH)
	var a:Array=data.incoming_open_linear;var b:Array=data.incoming_occluded_linear
	var gain:Array=data.get("incoming_adapter_rgb",[1.,1.,1.])
	var open:=Color(a[0]*gain[0],a[1]*gain[1],a[2]*gain[2]);var occluded:=Color(b[0]*gain[0],b[1]*gain[1],b[2]*gain[2])
	var bounds:Array[AABB]=[]
	for child:Node in lab.meadow.get_children():
		if child is StaticBody3D:
			var mesh:Mesh=lab.private_bundle.meshes["MD2 | SM_SF_Boulder_01"]
			bounds.append(child.transform*mesh.get_aabb())
	if trees!=null:bounds.append_array(trees.canopy_bounds)
	# Original bounded visibility approximation from existing static geometry.
	for y in 196:
		for x in 196:
			var point:=Vector2(x+.5,y+.5)*104./196.-Vector2(52,52);var visibility:=1.;var roof:=-1.
			for box:AABB in bounds:
				var nearest:=point.clamp(Vector2(box.position.x,box.position.z),Vector2(box.end.x,box.end.z))
				var distance:=point.distance_to(nearest)
				if distance>1.4:continue
				roof=maxf(roof,box.end.y)
				visibility=minf(visibility,lerpf(.30,1.,smoothstep(0.,1.4,distance)))
			var shade_gain:float=float(data.get("occlusion_exposure_ratio",1.))
			var value:Color=(occluded*shade_gain).lerp(open,visibility);value.a=roof
			image.set_pixel(x,y,value)
	field_texture=ImageTexture.create_from_image(image)
func per_frame()->void:
	if available and enabled and stage>=3:
		lab.md2_lighting.sun.light_energy=float(controller_owner.resolved.get("review_sun_energy",data.sun_energy))
		var scale:float=float(controller_owner.resolved.get("review_irradiance_scale",1.))
		if player_light!=null:
			var night:=clampf((1.-scale)/.7,0.,1.)
			player_light.light_energy=float(data.sun_energy)*7./22.*night
		for row:Dictionary in controller_owner.pairs:row.candidate.set_shader_parameter("review_irradiance_scale",scale)
		if trees!=null:trees.set_phase_scale(scale);trees.set_sky_delta(controller_owner.resolved.sky_fill_linear-controller_owner.field_sky)
func lock_camera()->void:
	if not available or (not enabled and not controller_owner.comparison_camera):return
	var a:Array=data.camera_anchor;var anchor:=Vector3(a[0],a[1],a[2])
	lab.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;lab.camera.keep_aspect=Camera3D.KEEP_WIDTH;lab.camera.fov=45.
	lab.camera.global_position=anchor+Vector3(.5,sqrt(.5),.5)*float(data.camera_distance_m);lab.camera.look_at(anchor,Vector3.UP)
func release()->void:
	enabled=false;apply()
