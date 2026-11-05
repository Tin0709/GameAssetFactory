extends Node
## Original, reversible integration in the existing lab. Reference data external.
const Effect=preload("../presentation_v001/presentation_effect.gd")
const Directional=preload("../directional_fill_v001/controller.gd")
const Leaf=preload("../leaf_material_v001/controller.gd")
const GrassNormal=preload("../grass_normal_v001/controller.gd")
const Cloud=preload("../cloud_v001/controller.gd")
const Policy=preload("availability.gd")
const GradeDomain=preload("../grade_domain.gd")
var owner_graphics:Node
var lab:Node3D
var mode:=0 # Original / common HDR baseline / local exposure / neutral graph
var error:=""
var quality:=0 # Auto is baseline; Reference is explicit, desktop-verified only.
var effect:CompositorEffect
var _compositor:Compositor
var _saved:Dictionary={}
var _changing:=false
var _released:=false
var _elapsed:=0.
var _hdr:ImageTexture3D
var _covered_field:ImageTexture
var _want_covered:=false
var _covered_toggle:CheckBox
var _covered_builds:=0
var _covered_build_us:=0
var _field:ImageTexture
var _panel:PanelContainer
var _directional=Directional.new()
var _leaf=Leaf.new()
var _grass_normal=GrassNormal.new()
var _normal_toggle:CheckBox
var _want_normal:=false
var _cloud=Cloud.new()
var _cloud_toggle:CheckBox
var _want_cloud:=false
var _day_sun_toggle:CheckBox
var _day_sun:Dictionary={}
var _active_grade_gain:=0.0
var _canopy_toggle:CheckBox
var _canopy_weights:Image
var _want_canopy:=false
var _canopy_fields:Array[ImageTexture]=[null,null]
var _leaf_toggle:CheckBox
var _want_leaf:=false
var _leaf_wind_toggle: CheckBox
var _want_leaf_wind := false
var _directional_toggle:CheckBox
var _want_directional:=false
var _bloom_toggle:CheckBox
var _want_bloom:=false
var _want_presentation:=false
var _presentation_environment:Dictionary={}
var _presentation_vignette:=false
var _presentation_toggle:CheckBox
var _status:Label
var _quality:OptionButton
var _buttons:Array[Button]=[]
func setup(graphics:Node)->void:
	owner_graphics=graphics;lab=graphics.lab;_directional.setup(graphics,lab);_leaf.setup(graphics,lab);_grass_normal.setup(graphics,lab);_build_ui();_refresh()
func _paths()->Dictionary:
	var root:=OS.get_environment("USERPROFILE")+"/Desktop/MD2 Research/godot_lab/"
	var parameters:=OS.get_environment("GAF_LOCAL_EXPOSURE_PROFILE")
	var hdr:=OS.get_environment("GAF_LOCAL_EXPOSURE_HDR_PROFILE")
	return {"parameters":root+"local_exposure_contract_v001/live_parameters_units_v002/parameters.private.json"if parameters.is_empty()else parameters,"hdr":root+"hdr_grade_v001/profile.high_precision.private.json"if hdr.is_empty()else hdr}
func _available(paths:Dictionary)->bool:
	for path:String in paths.values():
		if not lab.private_bundle.permitted(path)or not FileAccess.file_exists(path):return false
	return owner_graphics.strict_match!=null and owner_graphics.strict_match.available
func _load_hdr(profile:Dictionary)->bool:
	if not bool(profile.get("correction_hdr_2d",false))or not bool(profile.get("correction_output_linear",false))or not bool(profile.get("correction_texel_centered",false))or float(profile.get("correction_input_domain_linear",0.))!=2.:error="Reference requires the verified HDR2D/domain2 grading contract";return false
	var path:String=profile.get("correction_path","");var n:int=profile.get("correction_size",0)
	if n!=64 or not lab.private_bundle.permitted(path)or FileAccess.get_sha256(path)!=profile.get("correction_sha256",""):error="Private HDR grading data unavailable or changed";return false
	var bytes:=FileAccess.get_file_as_bytes(path)
	if bytes.size()!=n*n*n*16:error="Invalid HDR grading payload";return false
	var slices:Array[Image]=[]
	for z in n:
		var im:=Image.create_from_data(n,n,false,Image.FORMAT_RGBAF,bytes.slice(z*n*n*16,(z+1)*n*n*16));im.convert(Image.FORMAT_RGBAH);slices.append(im)
	_hdr=ImageTexture3D.new()
	if _hdr.create(Image.FORMAT_RGBAH,n,n,n,false,slices)!=OK:error="HDR grading texture unsupported";return false
	return true
func _bind_field(texture:ImageTexture)->void:
	var strict=owner_graphics.strict_match;strict.field_texture=texture;strict.trees.set_field(texture)
	for row:Dictionary in owner_graphics.pairs:row.candidate.set_shader_parameter("gaf_indirect_field",texture)
func _begin()->bool:
	var paths:=_paths();var support:Dictionary=Policy.evaluate({"editor":OS.has_feature("editor"),"renderer":RenderingServer.get_current_rendering_method(),"metadata_available":_available(paths),"reference_requested":quality==1})
	if not support.allowed:error=support.reason;return false
	var profile:Variant=JSON.parse_string(FileAccess.get_file_as_string(paths.hdr));var meta:Variant=JSON.parse_string(FileAccess.get_file_as_string(paths.parameters))
	if not profile is Dictionary or not meta is Dictionary or not meta.get("paths",null)is Dictionary:error="Invalid external exposure configuration";return false
	for value:Variant in meta.paths.values():
		var rows:Array=value if value is Array else[value]
		for row:Variant in rows:
			if not row is Dictionary or not lab.private_bundle.permitted(str(row.get("path",""))):error="Captured buffers must remain private and outside the project";return false
	var unit:Dictionary=meta.get("unit_contract",{});var gain:float=float(unit.get("existing_grade_exposed_gain",unit.get("grade_gain",0.)))
	if gain<=0. or gain!=float(profile.get("exposure_adapter",-1.)):error="Metering/grade units do not match";return false
	if not _load_hdr(profile):return false
	effect=Effect.new()
	if not effect.configure_external(paths.parameters):error=effect.snapshot().error;effect=null;return false
	effect.enabled=false
	var strict=owner_graphics.strict_match
	_saved={"cycle":owner_graphics.cycle_position,"auto":owner_graphics.cycle_auto,"candidate":owner_graphics.candidate,"stage":strict.stage,"comparison_camera":owner_graphics.comparison_camera}
	_changing=true;owner_graphics.seek_cycle(.15,true);strict.stage=int(strict.data.stage);owner_graphics.set_candidate(true);owner_graphics.set_comparison_camera(true);lab._update_camera();_changing=false
	_saved.field=strict.field_texture;_saved.ratio=float(strict.data.get("occlusion_exposure_ratio",1.));_saved.compositor=lab.camera.compositor;_saved.hdr=lab.get_viewport().use_hdr_2d;_saved.environment={}
	var env:Environment=lab.md2_lighting.environment
	for key:String in ["tonemap_mode","tonemap_exposure","adjustment_enabled","adjustment_brightness","adjustment_contrast","adjustment_saturation","adjustment_color_correction"]:_saved.environment[key]=env.get(key)
	var field_started:=Time.get_ticks_usec();strict.data.occlusion_exposure_ratio=1.;strict._build_field(false,true);_field=strict.field_texture;_covered_field=strict.source_companion_for(_field);_covered_build_us=Time.get_ticks_usec()-field_started;_covered_builds+=1;strict.data.occlusion_exposure_ratio=_saved.ratio;_bind_field(_saved.field)
	lab.get_viewport().use_hdr_2d=true;env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.tonemap_exposure=1.;env.adjustment_enabled=true;env.adjustment_brightness=GradeDomain.ui_brightness(2.);env.adjustment_contrast=GradeDomain.sampling_contrast(64);env.adjustment_saturation=1.;env.adjustment_color_correction=_hdr
	_compositor=Compositor.new();var active:Array[CompositorEffect]=[]
	if _saved.compositor!=null:
		for e:CompositorEffect in _saved.compositor.compositor_effects:active.append(e)
	active.append(effect);_compositor.compositor_effects=active;lab.camera.compositor=_compositor
	_active_grade_gain=gain
	return true
func select_mode(value:int)->bool:
	if _released or value not in [0,1,2,3]:return false
	error=""
	if value==0:deactivate(true);return true
	quality=1;_quality.select(1)
	if _saved.is_empty()and not _begin():_refresh();return false
	mode=value;_directional.apply(value==2 and _want_directional);_leaf.apply(value==2 and _want_leaf);_grass_normal.apply(value==2 and _want_normal);effect.set_neutral(value==3);effect.enabled=value in [2,3];_apply_presentation(value==2 and _want_presentation)
	_leaf.apply_wind(value == 2 and _want_leaf_wind and owner_graphics.strict_match.stage >= 6)
	if not _day_sun.is_empty() or owner_graphics.day_composition_requested:
		owner_graphics._apply_sun()
	else:
		sync_cloud()
	owner_graphics.strict_match.data.occlusion_exposure_ratio=1. if value==2 else float(_saved.ratio)
	_bind_field(_comparison_field() if value==2 else _saved.field);lab.camera.compositor=_compositor;_refresh();return true
func set_bloom_enabled(value:bool)->bool:
	if not value:
		_want_bloom=false
		if effect!=null:effect.set_bloom_enabled(false)
		_refresh();return true
	if mode!=2 and not select_mode(2):return false
	if not effect.bloom_configured():
		var path:=OS.get_environment("GAF_BLOOM_PROFILE")
		if path.is_empty():path=OS.get_environment("USERPROFILE")+"/Desktop/MD2 Research/godot_lab/local_exposure_contract_v001/bloom_chain_v001/live_profile_v001/profile.private.json"
		if not lab.private_bundle.permitted(path)or not FileAccess.file_exists(path):error="Private bloom profile unavailable";_refresh();return false
		var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or not data.get("setup",null)is Dictionary or not data.get("steps",null)is Array:error="Invalid private bloom profile";_refresh();return false
		var rows:Array=[data.setup];rows.append_array(data.steps)
		for row:Variant in rows:
			if not row is Dictionary or not lab.private_bundle.permitted(str(row.get("path",""))):error="Bloom parameters must stay private";_refresh();return false
		if not effect.configure_bloom_external(path):error="Bloom parameter/unit validation failed";_refresh();return false
	_want_bloom=true;effect.set_bloom_enabled(true);error="";_refresh();return true
func set_directional_enabled(value:bool)->bool:
	if not value:_want_directional=false;_directional.apply(false);_refresh();return true
	if mode!=2 and not select_mode(2):return false
	var path:=OS.get_environment("GAF_DIRECTIONAL_FILL_PROFILE")
	if path.is_empty():path=OS.get_environment("USERPROFILE")+"/Desktop/MD2 Research/godot_lab/day_light_components_v001/directional_profile_v001/profile.private.json"
	if not _directional.configure_external(path):error=_directional.error;_refresh();return false
	_want_directional=true;_directional.apply(true);error="";_refresh();return true
func _apply_presentation(active:bool)->void:
	if effect!=null:effect.set_presentation_enabled(active)
	var env:Environment=lab.md2_lighting.environment
	var layer:CanvasLayer=owner_graphics.strict_match.vignette_layer
	if active:
		if _presentation_environment.is_empty():
			for key:String in["tonemap_mode","tonemap_exposure","adjustment_enabled","glow_enabled"]:_presentation_environment[key]=env.get(key)
			_presentation_vignette=layer!=null and layer.visible
		env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.tonemap_exposure=1.;env.adjustment_enabled=false;env.glow_enabled=false
		if layer!=null:layer.visible=false
	elif not _presentation_environment.is_empty():
		for key:String in _presentation_environment:env.set(key,_presentation_environment[key])
		if layer!=null:layer.visible=_presentation_vignette
		_presentation_environment.clear()
func set_presentation_enabled(value:bool)->bool:
	if not value:_want_presentation=false;_apply_presentation(false);_refresh();return true
	if mode!=2 and not select_mode(2):return false
	if not effect.presentation_configured():
		var path:=OS.get_environment("GAF_PRESENTATION_PROFILE")
		if path.is_empty():path=OS.get_environment("USERPROFILE")+"/Desktop/MD2 Research/godot_lab/presentation_closure_v001/live_profile_v001/profile.private.json"
		if not lab.private_bundle.permitted(path)or not FileAccess.file_exists(path):error="Private presentation profile unavailable";_refresh();return false
		var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:error="Invalid presentation profile";_refresh();return false
		for key:String in["lut","parameters"]:
			if not data.get(key,null)is Dictionary or not lab.private_bundle.permitted(str(data[key].get("path",""))):error="Presentation reference data must stay private";_refresh();return false
		if not effect.configure_presentation_external(path):error="Presentation parameter/unit validation failed";_refresh();return false
	_want_presentation=true;_apply_presentation(true);error="";_refresh();return true
func set_covered_fill_enabled(value:bool)->bool:
	if not value:
		_want_covered=false
		if mode==2:_bind_field(_comparison_field())
		_refresh();return true
	if mode!=2 and not select_mode(2):return false
	if _covered_field==null:
		var strict=owner_graphics.strict_match;var previous:ImageTexture=strict.field_texture;var ratio:float=float(strict.data.get("occlusion_exposure_ratio",1.));var started:=Time.get_ticks_usec()
		strict.data.occlusion_exposure_ratio=1.;strict._build_field(true);_covered_field=strict.field_texture;strict.data.occlusion_exposure_ratio=ratio;_bind_field(previous)
		_covered_build_us=Time.get_ticks_usec()-started;_covered_builds+=1
		if _covered_field==null:error="Covered-field allocation failed";_refresh();return false
	_want_covered=true;_bind_field(_comparison_field());error="";_refresh();return true
func set_leaf_material_enabled(value:bool)->bool:
	if not value:_want_leaf_wind=false;_want_leaf=false;_leaf.apply(false);_refresh();return true
	if mode!=2 and not select_mode(2):return false
	var path:=OS.get_environment("GAF_LEAF_MATERIAL_PROFILE")
	if path.is_empty():path=OS.get_environment("USERPROFILE")+"/Desktop/MD2 Research/godot_lab/leaf_vertex_material_v001/profile.private.json"
	if not _leaf.configure_external(path):error=_leaf.error;_refresh();return false
	_want_leaf=true;_leaf.apply(true);error="";_refresh();return true
func set_leaf_wind_enabled(value: bool) -> bool:
	if value:
		if mode != 2 or not _want_leaf or owner_graphics.strict_match.stage < 6:
			error = "Oak wind needs Day reference and the matched leaf material"
			_refresh()
			return false
		if not _leaf.configure_wind(OS.get_environment("GAF_OAK_WIND_PROFILE")):
			error = _leaf.error
			_refresh()
			return false
	_want_leaf_wind = value
	_leaf.apply_wind(value)
	error = ""
	_refresh()
	return true

func set_normal_override_enabled(value:bool)->bool:
	if not value:_want_normal=false;_grass_normal.apply(false);_refresh();return true
	if mode!=2 and not select_mode(2):return false
	var path:=OS.get_environment("GAF_GRASS_NORMAL_PROFILE")
	if path.is_empty():path=OS.get_environment("USERPROFILE")+"/Desktop/MD2 Research/godot_lab/grass_normal_response_v001/profile.private.json"
	if not _grass_normal.configure_external(path):error=_grass_normal.error;_refresh();return false
	_want_normal=true;_grass_normal.apply(true);error="";_refresh();return true
func set_cloud_enabled(value:bool)->bool:
	if value:
		if not Cloud.supported() or (mode!=2 and not select_mode(2)):
			_refresh()
			return false
	_want_cloud=value
	sync_cloud()
	if value and not _cloud.active:_want_cloud=false
	_refresh()
	return _want_cloud==value

func sync_cloud()->void:
	if not _released:
		_cloud.apply(owner_graphics,(mode==2 and _want_cloud) or owner_graphics.day_composition_active())

func _day_sun_path()->String:
	var path:=OS.get_environment("GAF_DAY_SUN_PROFILE")
	if not OS.has_feature("editor") or RenderingServer.get_current_rendering_method()!="mobile" or path.is_empty():
		return ""
	return path if lab.private_bundle.permitted(path) and FileAccess.file_exists(path) else ""

func _read_day_sun(path:String)->Dictionary:
	if path.is_empty():
		return {}
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema","")!="original_day_sun_transfer_v1":
		return {}
	var energy:Variant=data.get("energy")
	var gain:Variant=data.get("grade_gain")
	var rgb:Variant=data.get("color_srgb")
	if typeof(energy) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(energy)) or energy<=0.0 or energy>4.0:
		return {}
	if typeof(gain) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(gain)) or gain<=0.0:
		return {}
	if not rgb is Array or rgb.size()!=3:
		return {}
	for channel:Variant in rgb:
		if typeof(channel) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(channel)) or channel<0.0 or channel>1.0:
			return {}
	return {"energy":float(energy),"grade_gain":float(gain),"color":Color(rgb[0],rgb[1],rgb[2])}

func set_day_sun_enabled(value:bool)->bool:
	if _released:
		return false
	if value:
		if mode!=2 or owner_graphics.strict_match.stage<3:
			return false
		var measured:=_read_day_sun(_day_sun_path())
		if measured.is_empty():
			error="Validated Day sun profile unavailable"
			_refresh()
			return false
		if measured.grade_gain!=_active_grade_gain:
			error="Day sun and exposure use different units"
			_refresh()
			return false
		_day_sun=measured
	else:
		_day_sun.clear()
	if owner_graphics.candidate:
		owner_graphics._apply_sun()
	error=""
	_refresh()
	return true

func apply_day_sun(sun:DirectionalLight3D)->void:
	if mode==2 and not _day_sun.is_empty():
		sun.light_energy=_day_sun.energy
		sun.light_color=_day_sun.color

func _canopy_profile_path()->String:
	var path:=OS.get_environment("GAF_CANOPY_FIELD_PROFILE")
	if not OS.has_feature("editor") or RenderingServer.get_current_rendering_method()!="mobile" or path.is_empty():
		return ""
	return path if lab.private_bundle.permitted(path) and FileAccess.file_exists(path) else ""

func _load_canopy_weights()->Image:
	var path:=_canopy_profile_path()
	if path.is_empty():return null
	var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary or manifest.get("schema","")!="original_canopy_visibility_v1":
		return null
	var strict=owner_graphics.strict_match
	if manifest.get("size")!=196 or manifest.get("span_m")!=104.0 or manifest.get("origin_m")!=[-52.0,-52.0]:
		return null
	if manifest.get("strict_profile_sha256")!=strict.profile_sha256 or not manifest.get("rows") is Array:
		return null
	if strict.trees.loaded!=manifest.rows.size() or not strict.trees.errors.is_empty():
		return null
	var payload:Variant=manifest.get("map_path")
	if not payload is String or not lab.private_bundle.permitted(payload) or not FileAccess.file_exists(payload):
		return null
	var bytes:=FileAccess.get_file_as_bytes(payload)
	if bytes.size()!=196*196*4:return null
	var digest:=HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	if digest.finish().hex_encode()!=manifest.get("map_sha256"):return null
	for i in range(0,bytes.size(),4):
		var visibility:=bytes.decode_half(i)
		var roof:=bytes.decode_half(i+2)
		if not is_finite(visibility) or not is_finite(roof) or visibility<0.0 or visibility>1.0 or roof< -1.0 or roof>32.0:
			return null
		if roof<0.0 and visibility!=1.0:return null
	return Image.create_from_data(196,196,false,Image.FORMAT_RGH,bytes)

func _comparison_field()->ImageTexture:
	if _want_canopy:
		var key:=int(_want_covered)
		if _canopy_fields[key]==null:
			_canopy_fields[key]=owner_graphics.strict_match._build_field(_want_covered,false,_canopy_weights)
		return _canopy_fields[key]
	return _covered_field if _want_covered else _field

func set_canopy_enabled(value:bool)->bool:
	if _released or mode!=2 or owner_graphics.strict_match.stage<6:return false
	if value and _canopy_weights==null:
		_canopy_weights=_load_canopy_weights()
		if _canopy_weights==null:
			error="Private canopy field missing or incompatible"
			_refresh()
			return false
	_want_canopy=value
	_bind_field(_comparison_field())
	error=""
	_refresh()
	return true

func before_environment_change()->void:
	if not _changing and not _saved.is_empty():deactivate(false)
func deactivate(restore_owner:bool)->void:
	_want_canopy=false
	_canopy_weights=null
	_canopy_fields=[null,null]
	var had_day_sun:=not _day_sun.is_empty()
	_day_sun.clear()
	_active_grade_gain=0.0
	if had_day_sun and owner_graphics.candidate:
		owner_graphics._apply_sun()
	_want_cloud=false
	_cloud.apply(owner_graphics,false)
	_want_presentation=false;_apply_presentation(false)
	_want_normal=false;_grass_normal.release()
	_want_leaf_wind = false
	_want_leaf=false;_leaf.release()
	if owner_graphics!=null and owner_graphics.strict_match!=null:owner_graphics.strict_match.clear_source_companion()
	_want_covered=false
	_want_directional=false;_directional.apply(false)
	if _saved.is_empty():
		_covered_field=null;_want_bloom=false;mode=0;_refresh()
		if restore_owner and owner_graphics.day_composition_active():owner_graphics._apply_sun()
		return
	_changing=true
	if effect!=null:effect.enabled=false
	lab.camera.compositor=_saved.compositor
	if effect!=null:RenderingServer.call_on_render_thread(effect.release_on_render_thread)
	var strict=owner_graphics.strict_match;strict.data.occlusion_exposure_ratio=_saved.ratio;_bind_field(_saved.field)
	var env:Environment=lab.md2_lighting.environment
	for key:String in _saved.environment:env.set(key,_saved.environment[key])
	lab.get_viewport().use_hdr_2d=_saved.hdr
	if restore_owner:
		strict.stage=int(_saved.stage);owner_graphics.seek_cycle(float(_saved.cycle),true);owner_graphics.set_candidate(bool(_saved.candidate));owner_graphics.set_comparison_camera(bool(_saved.comparison_camera));owner_graphics.set_cycle_enabled(bool(_saved.auto));lab._update_camera()
	_want_bloom=false;_saved.clear();_covered_field=null;_field=null;_hdr=null;effect=null;_compositor=null;mode=0;_changing=false;_refresh()
	if restore_owner and owner_graphics.day_composition_active():owner_graphics._apply_sun()
func input(event:InputEvent)->bool:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F7:
		select_mode(1 if mode==2 else 2);return true
	return false
func _process(delta:float)->void:
	if _released:return
	_cloud.advance(delta)
	_leaf.update_wind(lab.meadow.clock, lab.meadow.wind_enabled)
	_elapsed+=delta
	if _elapsed<.25:return
	_elapsed=0.
	if effect!=null:
		var s:Dictionary=effect.snapshot()
		if not s.error.is_empty():error=s.error;deactivate(true)
	_refresh()
func snapshot()->Dictionary:
	return {"mode":mode,"quality":quality,"error":error,"effect":{}if effect==null else effect.snapshot(),"captured_day_parameters":true,"cloud_projection":{"requested":_want_cloud,"active":_cloud.active},"canopy":{"requested":_want_canopy,"active":mode==2 and _want_canopy},"day_sun":{"requested":not _day_sun.is_empty(),"active":mode==2 and not _day_sun.is_empty()},"work_size":[1024,576],"phone_benchmarked":false,"bloom_requested":_want_bloom,"presentation":{"requested":_want_presentation,"active":mode==2 and _want_presentation,"environment_saved":not _presentation_environment.is_empty()},"directional_fill":_directional.snapshot(),"leaf_material":_leaf.snapshot(),"grass_normal":_grass_normal.snapshot(),"covered_field":{"requested":_want_covered,"active":mode==2 and _want_covered,"cached":_covered_field!=null,"builds":_covered_builds,"last_build_us":_covered_build_us,"preparation":"Reference entry, shared geometry pass"},"restorable_session":not _saved.is_empty()}
func _build_ui()->void:
	_panel=PanelContainer.new();_panel.name="LocalExposureReview";_panel.position=Vector2(-380,10);_panel.custom_minimum_size=Vector2(365,255);_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT);owner_graphics.ui.add_child(_panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.045,.045,.94);style.content_margin_left=10;style.content_margin_right=10;style.content_margin_top=8;style.content_margin_bottom=8;style.set_corner_radius_all(6);_panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",2);_panel.add_child(box);var title:=Label.new();title.text="LOCAL EXPOSURE - DAY REFERENCE";title.add_theme_font_size_override("font_size",12);box.add_child(title)
	_quality=OptionButton.new();_quality.add_theme_font_size_override("font_size",12);_quality.add_item("Auto / low device: original");_quality.add_item("Reference: experimental");_quality.focus_mode=Control.FOCUS_NONE;_quality.item_selected.connect(func(index:int):quality=index;if index==0:deactivate(true));box.add_child(_quality)
	var row:=HBoxContainer.new();box.add_child(row)
	for index in 4:
		var b:=Button.new();b.text=["Original","HDR baseline","LE on","Neutral"][index];b.toggle_mode=true;b.focus_mode=Control.FOCUS_NONE;b.add_theme_font_size_override("font_size",11);b.pressed.connect(func():select_mode(index));row.add_child(b);_buttons.append(b)
	_bloom_toggle=CheckBox.new();_bloom_toggle.text="Source bloom - experimental Day";_bloom_toggle.add_theme_font_size_override("font_size",11);_bloom_toggle.focus_mode=Control.FOCUS_NONE;_bloom_toggle.toggled.connect(set_bloom_enabled);box.add_child(_bloom_toggle)
	_directional_toggle=CheckBox.new();_directional_toggle.text="Directional fill - single-probe reference";_directional_toggle.add_theme_font_size_override("font_size",11);_directional_toggle.focus_mode=Control.FOCUS_NONE;_directional_toggle.toggled.connect(set_directional_enabled);_directional_toggle.tooltip_text="Normal-dependent SH calibration; spatial field and foliage back GI remain approximate.";box.add_child(_directional_toggle)
	_covered_toggle=CheckBox.new();_covered_toggle.text="Covered fill - preserve source endpoints";_covered_toggle.add_theme_font_size_override("font_size",11);_covered_toggle.focus_mode=Control.FOCUS_NONE;_covered_toggle.toggled.connect(set_covered_fill_enabled);_covered_toggle.tooltip_text="Two source-lit endpoints, unchanged original AABB/reach/height geometry; not native AO.";box.add_child(_covered_toggle)
	_leaf_toggle=CheckBox.new();_leaf_toggle.text="Leaf channels - captured Oak Var2";_leaf_toggle.add_theme_font_size_override("font_size",11);_leaf_toggle.focus_mode=Control.FOCUS_NONE;_leaf_toggle.toggled.connect(set_leaf_material_enabled);_leaf_toggle.tooltip_text="Restores verified vertex-weighted material inputs for one matching mesh; native two-sided lighting remains approximate.";box.add_child(_leaf_toggle)
	_leaf_wind_toggle = CheckBox.new()
	_leaf_wind_toggle.text = "Oak wind - captured Var2"
	_leaf_wind_toggle.tooltip_text = "Uses the measured Oak deformation with the lab camera and wind clock."
	_leaf_wind_toggle.add_theme_font_size_override("font_size", 11)
	_leaf_wind_toggle.focus_mode = Control.FOCUS_NONE
	_leaf_wind_toggle.visible = not OS.get_environment("GAF_OAK_WIND_PROFILE").is_empty()
	_leaf_wind_toggle.toggled.connect(set_leaf_wind_enabled)
	box.add_child(_leaf_wind_toggle)
	_normal_toggle=CheckBox.new();_normal_toggle.text="World-up normals - captured grass";_normal_toggle.add_theme_font_size_override("font_size",11);_normal_toggle.focus_mode=Control.FOCUS_NONE;_normal_toggle.toggled.connect(set_normal_override_enabled);_normal_toggle.tooltip_text="Captured Day grass normal response only; tree and terrain normals remain unchanged.";box.add_child(_normal_toggle)
	_presentation_toggle=CheckBox.new();_presentation_toggle.text="Direct log-LUT + pre-grade vignette";_presentation_toggle.add_theme_font_size_override("font_size",11);_presentation_toggle.focus_mode=Control.FOCUS_NONE;_presentation_toggle.toggled.connect(set_presentation_enabled);_presentation_toggle.tooltip_text="Direct private typed LUT, aspect-normalized vignette before grading. Preserves old scene exposure calibration; native noise and final image are not bit-exact.";box.add_child(_presentation_toggle)
	_cloud_toggle=CheckBox.new()
	_cloud_toggle.text="Moving cloud shadows - Day"
	_cloud_toggle.tooltip_text="Original cloud pattern on the meadow and foliage. Uses the Day scene's direct light only."
	_cloud_toggle.add_theme_font_size_override("font_size",11)
	_cloud_toggle.focus_mode=Control.FOCUS_NONE
	_cloud_toggle.visible=Cloud.supported()
	_cloud_toggle.toggled.connect(set_cloud_enabled)
	box.add_child(_cloud_toggle)
	_day_sun_toggle=CheckBox.new()
	_day_sun_toggle.text="Calibrated Day sun"
	_day_sun_toggle.tooltip_text="Unattenuated direct light with matched exposure units. Cloud attenuation is a separate switch."
	_day_sun_toggle.add_theme_font_size_override("font_size",11)
	_day_sun_toggle.focus_mode=Control.FOCUS_NONE
	_day_sun_toggle.visible=not _day_sun_path().is_empty()
	_day_sun_toggle.toggled.connect(set_day_sun_enabled)
	box.add_child(_day_sun_toggle)
	_canopy_toggle=CheckBox.new()
	_canopy_toggle.text="Canopy sky contact - Day"
	_canopy_toggle.tooltip_text="Voxel canopy sky visibility in the existing Day field. Direct lighting and boulder treatment stay independent."
	_canopy_toggle.add_theme_font_size_override("font_size",11)
	_canopy_toggle.focus_mode=Control.FOCUS_NONE
	_canopy_toggle.visible=not _canopy_profile_path().is_empty()
	_canopy_toggle.toggled.connect(set_canopy_enabled)
	box.add_child(_canopy_toggle)
	_status=Label.new();_status.add_theme_font_size_override("font_size",10);box.add_child(_status)
func _refresh()->void:
	if _status==null:return
	_bloom_toggle.set_pressed_no_signal(_want_bloom)
	_directional_toggle.set_pressed_no_signal(_want_directional)
	_covered_toggle.set_pressed_no_signal(_want_covered)
	_leaf_toggle.set_pressed_no_signal(_want_leaf)
	_leaf_wind_toggle.set_pressed_no_signal(_want_leaf_wind)
	_leaf_wind_toggle.disabled = mode != 2 or not _want_leaf or owner_graphics.strict_match.stage < 6
	_normal_toggle.set_pressed_no_signal(_want_normal)
	_presentation_toggle.set_pressed_no_signal(_want_presentation)
	_cloud_toggle.set_pressed_no_signal(_want_cloud)
	_day_sun_toggle.set_pressed_no_signal(not _day_sun.is_empty())
	_day_sun_toggle.disabled=mode!=2 or owner_graphics.strict_match.stage<3
	_canopy_toggle.set_pressed_no_signal(_want_canopy)
	_canopy_toggle.disabled=mode!=2 or owner_graphics.strict_match.stage<6
	for i in _buttons.size():_buttons[i].button_pressed=i==mode
	_status.text=error if not error.is_empty()else["Off - F7 enters Day A/B - H hides controls","HDR baseline - F7 enables LE","LE on - F7 compares HDR baseline","Full graph, neutral contrast - baseline image"][mode]
	if _want_bloom and mode==2 and error.is_empty():_status.text="LE + source bloom - toggle checkbox for A/B"
	_status.tooltip_text="Reference uses fixed1024x576work, preserved1.35grade calibration and source-backedDaycontrast. Original restores prior graphics/cycle. Auto retains baseline; phone performance unverified."
func release()->void:
	if _released:return
	deactivate(false);_released=true;set_process(false)
func _exit_tree()->void:release()
