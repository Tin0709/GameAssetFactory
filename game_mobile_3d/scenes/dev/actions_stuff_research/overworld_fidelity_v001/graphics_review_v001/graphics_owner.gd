extends Node
## Single opt-in owner for the existing private meadow. Original code only.
const StrictMatch=preload("strict_match.gd")
var strict_match:Node
const PhaseTrack=preload("phase_track.gd")
const Profile=preload("profile.gd")
const Resolver=preload("override_resolver.gd")
const Field=preload("indirect_field.gd")
const Solid=preload("foundation_solid.gdshader")
const Vegetation=preload("foundation_vegetation.gdshader")
const MOTION:=["wind_time","wind_intensity","wind_direction","frequency","interaction_field","interaction_previous","interaction_alpha","interaction_strength","field_extent","ground_atlas","ground_uv","lighting_grade"]
var lab:Node3D
var profile=Profile.new()
var field=Field.new()
var resolved:Dictionary={}
var target_state:Dictionary={}
var state_velocity:Dictionary={}
var phase:StringName=&"day"
var local_overrides:Array=[]
var candidate:=false
var comparison_camera:=false
var released:=false
var available:=false
var error:=""
var surfaces:Array[Dictionary]=[]
var pairs:Array[Dictionary]=[]
var baseline:Dictionary={}
var ui:CanvasLayer
var state_label:Label
var cycle_auto:=true
var cycle_position:=.15
var cycle_seconds:=300.
var cycle_slider:HSlider
var cycle_check:CheckButton
var field_sky:=Vector3.ZERO
var environment_baseline:Dictionary={}
var sky_baseline:Dictionary={}
func setup(scene:Node3D)->void:
	lab=scene;process_priority=100
	if OS.get_environment("GAF_DAY_DISABLE")=="1":return
	var path:=OS.get_environment("MD2_DAY_PROFILE")
	if path.is_empty():path=OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research/godot_lab/overworld_day_foundation_v001/day_profile.private.json")
	# Private reference calibration never loads in an exported build.
	if not OS.has_feature("editor")or not path.is_absolute_path()or path.begins_with(ProjectSettings.globalize_path("res://"))or not FileAccess.file_exists(path):error="Private Day calibration unavailable";return
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema","")!="original_graphics_foundation_v1":error="Invalid Day profile";return
	profile.profile_id=data.profile_id;profile.fields=data.fields.duplicate(true)
	for key:String in profile.fields:
		var value:Variant=profile.fields[key]
		if value is Array and value.size()==3:profile.fields[key]=Vector3(value[0],value[1],value[2])
	for name:String in data.get("phases",{}):
		var values:Dictionary=data.phases[name].duplicate(true)
		for key:String in values:
			if values[key]is Array and values[key].size()==3:values[key]=Vector3(values[key][0],values[key][1],values[key][2])
		profile.phases[StringName(name)]=values
	cycle_seconds=maxf(30.,float(data.get("cycle",{}).get("preview_seconds",300.)))
	if not profile.validate().is_empty():error="Invalid profile values";return
	resolved=Resolver.resolve(profile.phase_fields(phase),local_overrides)
	target_state=resolved.duplicate(true)
	baseline={"sun_color":lab.md2_lighting.sun.light_color,"sun_energy":lab.md2_lighting.sun.light_energy,"sun_rotation":lab.md2_lighting.sun.rotation,
		"process":lab.md2_lighting.is_processing(),"ui_visible":lab.md2_lighting.ui.visible,"camera_projection":lab.camera.projection,"camera_aspect":lab.camera.keep_aspect,
		"camera_fov":lab.camera.fov,"camera_near":lab.camera.near,"azimuth":lab.azimuth,"elevation":lab.elevation,"camera_size":lab.camera_size}
	var env:Environment=lab.md2_lighting.environment
	for key:String in ["ambient_light_energy","ambient_light_color","fog_light_color"]:environment_baseline[key]=env.get(key)
	for key:String in ["sky_top_color","sky_horizon_color","ground_bottom_color","ground_horizon_color"]:sky_baseline[key]=lab.md2_lighting.sky_material.get(key)
	field_sky=resolved.sky_fill_linear
	field.build(lab.private_bundle,resolved)
	var made:Dictionary={}
	for mesh:ArrayMesh in lab.private_bundle.meshes.values():
		for i in mesh.get_surface_count():
			var old:ShaderMaterial=mesh.surface_get_material(i)
			if not made.has(old.get_instance_id()):
				var mat:ShaderMaterial=old.duplicate(false)
				var plant:bool=old.shader.resource_path.ends_with("vegetation.gdshader")
				mat.shader=Vegetation if plant else Solid
				mat.set_shader_parameter("gaf_indirect_field",field.texture)
				mat.set_shader_parameter("gaf_field_origin",Field.ORIGIN);mat.set_shader_parameter("gaf_field_extent",Field.EXTENT)
				mat.set_shader_parameter("gaf_fill_up_ratio",float(resolved.get("fill_up_ratio",.35)))
				var specular:=0.
				var family:String=old.get_meta("source_material","")
				if family=="MI_MasterTerrain_Opaque_Overworld":specular=.5
				elif family=="MI_PlainsA1_MeadowPlants":specular=.4
				mat.set_shader_parameter("gaf_specular",specular)
				made[old.get_instance_id()]=mat;pairs.append({"original":old,"candidate":mat,"plant":plant})
			surfaces.append({"mesh":mesh,"surface":i,"original":old,"candidate":made[old.get_instance_id()]})
	available=true
	lab.md2_lighting.set_process(false);lab.md2_lighting.ui.hide()
	_build_ui();set_candidate(true)
	strict_match=StrictMatch.new();add_child(strict_match);strict_match.setup(self)
	if strict_match.available:
		cycle_check.show();cycle_slider.show();ui.find_child("CyclePhaseButtons",true,false).show()
		state_label.text="MD2 SOURCE MEADOW · LOCKED CAMERA"
		lab.get_window().title="GameAssetFactory — MD2 Source Meadow / Day & Night"
func _process(_delta:float)->void:
	if not available or released:return
	if cycle_auto:
		cycle_position=fposmod(cycle_position+_delta/cycle_seconds,1.)
		_update_phase_caption()
		target_state=Resolver.resolve(PhaseTrack.sample(profile,cycle_position),local_overrides)
		_refresh_label()
		if cycle_slider!=null:cycle_slider.set_value_no_signal(cycle_position)
	var next:Dictionary=Resolver.advance(resolved,target_state,state_velocity,_delta,.5)
	resolved=next.state;state_velocity=next.velocity
	if candidate:
		_apply_sun()
		for row:Dictionary in pairs:
			if row.plant:
				for key:String in MOTION:row.candidate.set_shader_parameter(key,row.original.get_shader_parameter(key))
func set_candidate(value:bool)->void:
	if released or not available:return
	candidate=value
	for row:Dictionary in surfaces:row.mesh.surface_set_material(row.surface,row.candidate if candidate else row.original)
	var sun:DirectionalLight3D=lab.md2_lighting.sun
	if candidate:
		_apply_sun()
	else:
		sun.light_color=baseline.sun_color;sun.light_energy=baseline.sun_energy;sun.rotation=baseline.sun_rotation
		_restore_atmosphere()
	if strict_match!=null and strict_match.available:strict_match.enabled=candidate;strict_match.apply()
	apply_camera();_refresh_label()
func _apply_sun()->void:
	var sun:DirectionalLight3D=lab.md2_lighting.sun
	var c:Vector3=resolved.sun_color_srgb;sun.light_color=Color(c.x,c.y,c.z);sun.light_energy=resolved.sun_energy
	sun.rotation_degrees=Vector3(resolved.sun_pitch_deg,resolved.sun_yaw_deg,0.)
	var sky_delta:Vector3=resolved.sky_fill_linear-field_sky
	for row:Dictionary in pairs:row.candidate.set_shader_parameter("gaf_sky_delta",sky_delta)
	var gain:float=resolved.get("environment_gain",1.)
	for key:String in sky_baseline:
		var c0:Color=sky_baseline[key];lab.md2_lighting.sky_material.set(key,(c0.srgb_to_linear()*gain).linear_to_srgb())
	lab.md2_lighting.environment.ambient_light_energy=environment_baseline.ambient_light_energy*float(resolved.get("ambient_gain",1.))
	var fog:Color=environment_baseline.fog_light_color
	lab.md2_lighting.environment.fog_light_color=(fog.srgb_to_linear()*gain).linear_to_srgb()
	if strict_match!=null:strict_match.per_frame()
func _restore_atmosphere()->void:
	for key:String in environment_baseline:lab.md2_lighting.environment.set(key,environment_baseline[key])
	for key:String in sky_baseline:lab.md2_lighting.sky_material.set(key,sky_baseline[key])
func set_cycle_enabled(value:bool)->void:
	cycle_auto=value
	if cycle_check!=null:cycle_check.set_pressed_no_signal(value)
func seek_cycle(position:float,snap:bool=false)->void:
	cycle_position=fposmod(position,1.);set_cycle_enabled(false);_update_phase_caption()
	target_state=Resolver.resolve(PhaseTrack.sample(profile,cycle_position),local_overrides)
	if snap:resolved=target_state.duplicate(true);state_velocity.clear()
	if candidate:_apply_sun()
	_refresh_label()
func _update_phase_caption()->void:
	for i in 4:
		if cycle_position>=PhaseTrack.STARTS[i]:phase=PhaseTrack.NAMES[i]
func set_phase(value:StringName)->bool:
	if not available or released or (value!=&"day" and not profile.phases.has(value)):return false
	set_cycle_enabled(false)
	var phase_index:=PhaseTrack.NAMES.find(value)
	if phase_index>=0:cycle_position=PhaseTrack.STARTS[phase_index]
	phase=value;target_state=Resolver.resolve(profile.phase_fields(phase),local_overrides);_refresh_label();return true
func set_local_overrides(entries:Array)->bool:
	# M1 supports local key-light intent only; other visual systems are deferred.
	for row:Variant in entries:
		if not row is Dictionary or not row.get("fields",null)is Dictionary:return false
		if not is_finite(float(row.get("weight",0.))):return false
		for key:Variant in row.fields:
			if key=="sun_energy":
				if not (row.fields[key]is float or row.fields[key]is int)or not is_finite(float(row.fields[key]))or row.fields[key]<0.:return false
			elif key=="sun_color_srgb":
				if not row.fields[key]is Vector3 or not row.fields[key].is_finite():return false
			else:return false
	local_overrides=entries.duplicate(true);target_state=Resolver.resolve(PhaseTrack.sample(profile,cycle_position),local_overrides);return true
func set_comparison_camera(value:bool)->void:
	comparison_camera=value;apply_camera();_refresh_label()
func apply_camera()->void:
	if not available or released:return
	var c:Camera3D=lab.camera
	if (candidate or comparison_camera)and not lab.grass_overview:
		var yaw:float=lab.azimuth-baseline.azimuth+deg_to_rad(resolved.camera_azimuth_deg)
		var elevation:float=lab.elevation-baseline.elevation+deg_to_rad(resolved.camera_elevation_deg)
		var arm:float=resolved.camera_distance_m*lab.camera_size/baseline.camera_size
		c.projection=Camera3D.PROJECTION_PERSPECTIVE;c.keep_aspect=Camera3D.KEEP_WIDTH;c.fov=resolved.horizontal_fov_deg;c.near=resolved.camera_near_m
		c.global_position=lab.camera_anchor+Vector3(sin(yaw)*cos(elevation),sin(elevation),cos(yaw)*cos(elevation))*arm
		c.look_at(lab.camera_anchor,Vector3.UP)
	else:
		c.projection=baseline.camera_projection;c.keep_aspect=baseline.camera_aspect;c.fov=baseline.camera_fov;c.near=baseline.camera_near
	if strict_match!=null:strict_match.lock_camera()
func material_identity()->Dictionary:
	var result:={}
	for row:Dictionary in surfaces:result[str(row.mesh.get_instance_id())+"/"+str(row.surface)]=row.mesh.surface_get_material(row.surface).get_instance_id()
	return result
func snapshot()->Dictionary:
	return {"available":available,"candidate":candidate,"matched_camera":candidate or comparison_camera,"profile":profile.profile_id,"phase":phase,"local_overrides":local_overrides.size(),
		"device_tiers":profile.device_tiers.keys(),"phone_benchmarked":false,"indirect_kind":"Original196x196 spatial diffuse-color gather; not native Lumen","cycle_auto":cycle_auto,"cycle_position":cycle_position,"cycle_preview_seconds":cycle_seconds,"cycle_native_timing":false,"surface_count":surfaces.size(),"error":error}
func input(event:InputEvent)->bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F9:
			if strict_match!=null and strict_match.available:
				strict_match.stage=0 if strict_match.stage>0 else int(strict_match.data.stage);set_candidate(true)
			else:set_comparison_camera(true);set_candidate(not candidate)
			return true
		if event.physical_keycode==KEY_F10:set_candidate(false);set_comparison_camera(false);lab._update_camera();return true
	return false
func _build_ui()->void:
	ui=CanvasLayer.new();ui.name="DayFoundationReview";add_child(ui)
	var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);panel.position=Vector2(-380,-265);panel.custom_minimum_size=Vector2(365,250);ui.add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.045,.045,.9);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=10;style.content_margin_bottom=10;style.set_corner_radius_all(6);panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new();panel.add_child(box)
	var title:=Label.new();title.text="OVERWORLD DAY · FOUNDATION REVIEW";title.add_theme_font_size_override("font_size",13);box.add_child(title)
	state_label=Label.new();state_label.add_theme_font_size_override("font_size",11);box.add_child(state_label)
	var phase_row:=HBoxContainer.new();phase_row.name="CyclePhaseButtons";box.add_child(phase_row)
	for name:StringName in PhaseTrack.NAMES:
		var b:=Button.new();b.text=String(name).capitalize();b.focus_mode=Control.FOCUS_NONE;phase_row.add_child(b)
		b.pressed.connect(func():set_phase(name))
	cycle_check=CheckButton.new();cycle_check.text="Auto day/night · 5 min preview";cycle_check.button_pressed=cycle_auto;cycle_check.focus_mode=Control.FOCUS_NONE;cycle_check.toggled.connect(set_cycle_enabled);box.add_child(cycle_check)
	cycle_slider=HSlider.new();cycle_slider.min_value=0.;cycle_slider.max_value=.99999;cycle_slider.step=.0001;cycle_slider.value=cycle_position;cycle_slider.value_changed.connect(func(v:float):seek_cycle(v));box.add_child(cycle_slider)
	var row:=HBoxContainer.new();box.add_child(row)
	for text:String in ["Day foundation","Baseline · same camera","Original"]:
		var button:=Button.new();button.text=text;button.focus_mode=Control.FOCUS_NONE;button.add_theme_font_size_override("font_size",11);row.add_child(button)
		if text=="Day foundation":button.pressed.connect(func():
			if strict_match!=null and strict_match.available:strict_match.stage=int(strict_match.data.stage)
			set_comparison_camera(true);set_candidate(true))
		elif text=="Original":button.pressed.connect(func():set_candidate(false);set_comparison_camera(false);lab._update_camera())
		else:button.pressed.connect(func():
			set_comparison_camera(true)
			if strict_match!=null and strict_match.available:strict_match.stage=0;set_candidate(true)
			else:set_candidate(false))
	var hint:=Label.new();hint.text="F9 A/B · F10 original · H hide controls";hint.add_theme_font_size_override("font_size",11);box.add_child(hint)
func _refresh_label()->void:
	if state_label!=null and strict_match!=null and strict_match.available and candidate:
		state_label.text=("UPDATED MD2 · "+String(phase).to_upper()if strict_match.stage>0 else"PREVIOUS GODOT M1")+" · locked camera\nF9 previous / updated · source LUT + calibrated fill"
		return
	if state_label!=null:state_label.text=("FOUNDATION"if candidate else"BASELINE")+(" · perspective45°"if candidate or comparison_camera else" · original camera")+"\n100 × 100 m · cycle %.0f%% · Pending review"%[cycle_position*100.]
func release()->void:
	if released:return
	if available:
		if strict_match!=null:strict_match.release()
		set_candidate(false);comparison_camera=false;apply_camera()
		lab.md2_lighting.set_process(baseline.process);lab.md2_lighting.ui.visible=baseline.ui_visible
		if ui!=null:ui.hide()
	released=true;set_process(false)
func _exit_tree()->void:release()
