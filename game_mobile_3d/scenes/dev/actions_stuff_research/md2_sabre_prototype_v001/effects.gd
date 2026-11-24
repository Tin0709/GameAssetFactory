extends Node3D
## A bounded ribbon follows the actual exported blade markers. These authored
## gates describe fast motion only; whiffs do not spawn fake damage or hitstop.
const EffectSource := preload("res://scripts/mechanic_lab_effect_source.gd")
const RIBBON_SHADER := preload("res://materials/mechanic_lab_sabre_ribbon.gdshader")
const SLASH_TEXTURE := "extracted/2026-10-25 19-26-25/Game/Spicewood/FX/Combat/Materials/T_Slash_Grayscale.png"
const SLASH_TEXTURE_SHA256 := "bd5d52c41304562f1f4108aa5fc564f09d0e23766fd489a2d45ae8c30a7e11a5"
const MAX_SAMPLES:=28
const PARTICLE_CAPACITY:=48
const MAX_PARTICLE_HISTORY:=16
const RIBBON_U := [0.0, 1.0, 1.0, 0.0, 1.0, 0.0]
const RIBBON_SAMPLE := [0, 0, 1, 0, 1, 1]
const RIBBON_LIFETIME := 0.14
const THRUST_GLINT_HALF_HEIGHT := 0.20
const RIBBON_TINT := Color(1.0, 0.73, 0.23)
const RIBBON_EDGE_TINT := Color(1.0, 0.97, 0.82)
var samples:Array[Dictionary]=[]
var particles:Array[Dictionary]=[]
var clock:=0.
var serial:=-1
var bursts:=0
var ribbon:MeshInstance3D
var sparks:MultiMeshInstance3D
var enabled:=true
var blade_trail_enabled := true
var trail_end_fraction: Callable
var interpolate_ground_trail_edges := false
var intensity:=.75
var _mesh:=ImmediateMesh.new()
var _rng:=RandomNumberGenerator.new()
var _was_active:=false
var _ribbon_section := 0
var _ribbon_lifetime := RIBBON_LIFETIME
var _ribbon_opacity_scale := 1.0
var _ribbon_tint := RIBBON_TINT
var _ribbon_edge_tint := RIBBON_EDGE_TINT
var _thrust_glint_started := INF
var _previous_base := Vector3.ZERO
var _previous_tip:=Vector3.ZERO

func _ready()->void:
	_rng.seed=2761026
	ribbon=MeshInstance3D.new();ribbon.name="BoundedBladeRibbon";ribbon.mesh=_mesh;add_child(ribbon)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.no_depth_test=false;ribbon.material_override=material;ribbon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spark_mesh:=QuadMesh.new();spark_mesh.size=Vector2(.035,.07)
	var spark_material:=StandardMaterial3D.new();spark_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo=true;spark_material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;spark_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mesh.material=spark_material
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=spark_mesh;mm.instance_count=PARTICLE_CAPACITY
	sparks=MultiMeshInstance3D.new();sparks.name="BoundedArcSparks";sparks.multimesh=mm;sparks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(sparks)
	for i in PARTICLE_CAPACITY:particles.append({"life":0.,"position":Vector3.ZERO,"velocity":Vector3.ZERO,"duration":.3,"born":-INF,"history":[]})
	reset()

func use_private_slash_material() -> void:
	var material := ShaderMaterial.new()
	material.shader = RIBBON_SHADER
	var slash := EffectSource.load_image(SLASH_TEXTURE, SLASH_TEXTURE_SHA256, Vector2i(128, 128))
	if slash != null:
		material.set_shader_parameter(&"source_slash", ImageTexture.create_from_image(slash))
		material.set_shader_parameter(&"use_source_slash", true)
	ribbon.material_override = material

func sample(delta:float,active:bool,base:Vector3,tip:Vector3,attack_serial:int,edge_age:float=-1.0,style:Dictionary={})->void:
	clock+=delta
	if not enabled or not blade_trail_enabled:active=false
	if active:
		if serial != attack_serial:
			samples.clear()
			serial = attack_serial
			_was_active = false
			_ribbon_section = 0
		if not _was_active:
			_ribbon_section += 1
			_ribbon_lifetime = style.get("lifetime", RIBBON_LIFETIME)
			_ribbon_opacity_scale = style.get("opacity_scale", 1.0)
			_ribbon_tint = style.get("tint", RIBBON_TINT)
			_ribbon_edge_tint = _ribbon_tint.lerp(Color.WHITE, 0.74) if style.has("tint") else RIBBON_EDGE_TINT
			_thrust_glint_started = clock - clampf(edge_age, 0.0, delta) if style.get("thrust_glint", false) else INF
			_sample_trail_edge(delta, edge_age, base, tip)
		var point := _trail_sample(base, tip, clock)
		if not _was_active and _ribbon_section == 1 and point.tip_u == 1.0:
			_burst(tip,tip-_previous_tip)
		samples.append(point)
	elif _was_active and serial == attack_serial and enabled and blade_trail_enabled:
		_sample_trail_edge(delta, edge_age, base, tip)
	while samples.size() > MAX_SAMPLES:
		samples.pop_front()
	var display_lag:=1./maxf(1.,Engine.physics_ticks_per_second)
	while not samples.is_empty() and clock-float(samples[0].time)>float(samples[0].lifetime)+display_lag:samples.pop_front()
	for particle:Dictionary in particles:
		if float(particle.life)>0.:
			particle.life=maxf(0.,float(particle.life)-delta);particle.velocity+=Vector3(0,-1.8,0)*delta;particle.position+=particle.velocity*delta
		if particle.life>0. or clock-float(particle.born)<=float(particle.duration)+display_lag:
			var history:Array=particle.history
			history.append({"time":clock,"position":particle.position,"life":particle.life})
			while history.size()>2 and clock-float(history[1].time)>display_lag+1./120.:history.pop_front()
			while history.size()>MAX_PARTICLE_HISTORY:history.pop_front()
	_was_active=active;_previous_base=base;_previous_tip=tip

func _sample_trail_edge(delta: float, edge_age: float, base: Vector3, tip: Vector3) -> void:
	# Near a tick boundary the regular pose on that edge may be inactive.
	# Deduplicate actual samples instead of discarding all near-edge cues.
	const TIME_EPSILON := 0.000000001
	if edge_age < 0.0 or edge_age > delta + TIME_EPSILON or clock <= delta:
		return
	var elapsed := minf(edge_age, delta)
	var edge_time := clock - elapsed
	if (not _was_active and elapsed <= TIME_EPSILON) \
			or (not samples.is_empty() and edge_time <= float(samples[-1].time) + TIME_EPSILON):
		return
	var weight := 1.0 - elapsed / delta
	samples.append(_trail_sample(_previous_base.lerp(base, weight), _previous_tip.lerp(tip, weight), edge_time))

func _trail_sample(base: Vector3, tip: Vector3, time: float) -> Dictionary:
	var tip_u := float(trail_end_fraction.call(base, tip)) if trail_end_fraction.is_valid() else 1.0
	var end := tip if tip_u == 1.0 else base.lerp(tip, tip_u)
	return {"base": base, "tip": end, "tip_u": tip_u, "time": time, "section": _ribbon_section,
		"lifetime": _ribbon_lifetime, "opacity_scale": _ribbon_opacity_scale,
		"tint": _ribbon_tint, "edge_tint": _ribbon_edge_tint,
		"thrust_glint_started": _thrust_glint_started}

func _burst(point:Vector3,direction:Vector3,publish_sample:=false,sample_time:=-1.0)->void:
	bursts+=1;var added:=0
	var born := clock if sample_time < 0.0 else minf(sample_time, clock)
	var age := clock - born
	for particle:Dictionary in particles:
		if particle.life>0. or clock<float(particle.born)+float(particle.duration)+1./maxf(1.,Engine.physics_ticks_per_second):continue
		var duration:=_rng.randf_range(.13,.3)
		particle.position=point;particle.velocity=direction.normalized()*_rng.randf_range(.2,.8)+Vector3(_rng.randf_range(-.7,.7),_rng.randf_range(.1,.7),_rng.randf_range(-.7,.7))
		particle.duration=duration;particle.life=duration;particle.born=born;particle.history.clear();added+=1
		if publish_sample:
			particle.history.append({"time":born,"position":point,"life":duration})
		if age > 0.0:
			particle.life = maxf(0.0, duration - age)
			particle.velocity += Vector3.DOWN * 1.8 * age
			particle.position += particle.velocity * age
			if publish_sample:
				particle.history.append({"time":clock,"position":particle.position,"life":particle.life})
		if added>=8:break
func contact(point: Vector3, direction: Vector3, publish_sample := false, sample_time := -1.0) -> void:
	if enabled:
		_burst(point, direction, publish_sample, sample_time)
func samples_at(display_time:float,blade_base:Variant=null,blade_tip:Variant=null)->Array:
	var result:Array=[]
	for point:Dictionary in samples:
		if display_time-float(point.time)>float(point.lifetime):continue
		if float(point.time)<=display_time:result.append(point)
		else:
			if not result.is_empty() and display_time>float(result[-1].time):
				var a:Dictionary=result[-1]
				if a.section != point.section or a.tip_u <= 0.0 or point.tip_u <= 0.0:
					break
				var weight:=clampf((display_time-float(a.time))/maxf(.000001,float(point.time)-float(a.time)),0.,1.)
				# The presented bone pose is unclipped. Use it only when
				# both simulated blade spans were fully visible.
				var full_span: bool = a.tip_u == 1.0 and point.tip_u == 1.0
				result.append({
					"base": blade_base if full_span and blade_base != null else Vector3(a.base).lerp(point.base, weight),
					"tip": blade_tip if full_span and blade_tip != null else Vector3(a.tip).lerp(point.tip, weight),
					"tip_u": lerpf(a.tip_u, point.tip_u, weight), "time": display_time,
					"section": point.section,
					"lifetime": point.lifetime, "opacity_scale": point.opacity_scale,
					"tint": point.tint, "edge_tint": point.edge_tint,
					"thrust_glint_started": point.thrust_glint_started,
				})
			break
	return result
func particle_at(index:int,display_time:float)->Dictionary:
	var particle:Dictionary=particles[index];var history:Array=particle.history
	if history.is_empty() or display_time<float(history[0].time):return {"position":particle.position,"life":0.}
	var previous:Dictionary=history[0]
	for state:Dictionary in history:
		if float(state.time)<=display_time:previous=state
		else:
			var weight:=clampf((display_time-float(previous.time))/maxf(.000001,float(state.time)-float(previous.time)),0.,1.)
			return {"position":Vector3(previous.position).lerp(state.position,weight),"life":lerpf(previous.life,state.life,weight)}
	return {"position":previous.position,"life":previous.life}
func present(display_time:float=-1.,blade_base:Variant=null,blade_tip:Variant=null)->void:
	var time:=clock if display_time<0. else minf(display_time,clock)
	var shown: Array = samples if display_time < 0.0 else samples_at(time, blade_base, blade_tip)
	_mesh.clear_surfaces()
	var has_surface := false
	for i in range(1, shown.size()):
		var a: Dictionary = shown[i - 1]
		var b: Dictionary = shown[i]
		if a.section != b.section or a.tip_u <= 0.0 or b.tip_u <= 0.0:
			continue
		if not has_surface:
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			has_surface = true
		var age_a := clampf((time - float(a.time)) / float(a.lifetime), 0.0, 1.0)
		var age_b := clampf((time - float(b.time)) / float(b.lifetime), 0.0, 1.0)
		var ages := Vector2(age_a, age_b)
		var opacity := (1.0 - age_a) * intensity * 0.58 * float(a.opacity_scale)
		_add_ribbon_strip(a, b, 0.0, ages, Color(a.tint, opacity))
		if a.tip_u > 0.86 or b.tip_u > 0.86:
			_add_ribbon_strip(a, b, 0.86, ages, Color(a.edge_tint, opacity * 0.8))
	if has_surface:
		var latest: Dictionary = shown[-1]
		if is_finite(float(latest.thrust_glint_started)):
			var glint_age := time - float(latest.thrust_glint_started)
			var envelope := smoothstep(0.0, 0.022, glint_age) * (1.0 - smoothstep(0.042, 0.113, glint_age))
			var exposed := smoothstep(0.60, 0.92, float(latest.tip_u))
			var opacity := intensity * envelope * exposed
			if opacity > 0.01:
				_add_thrust_glint(latest, opacity)
		_mesh.surface_end()
	for i in particles.size():
		var particle:Dictionary=particles[i]
		var shown_particle:Dictionary=particle if display_time<0. else particle_at(i,time)
		var fade:=float(shown_particle.life)/float(particle.duration)
		var scale:=Vector3.ONE*(maxf(.001,fade) if enabled else .001)
		var position:Vector3=shown_particle.position
		sparks.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(scale),position))
		sparks.multimesh.set_instance_color(i,Color(1.,.87,.4,fade*intensity if enabled else 0.))

func _add_ribbon_strip(a: Dictionary, b: Dictionary, inner_u: float, ages: Vector2, tint: Color) -> void:
	var inner := Vector2(minf(inner_u, a.tip_u), minf(inner_u, b.tip_u))
	var outer := Vector2(a.tip_u, b.tip_u)
	var start_a := Vector3(a.base).lerp(a.tip, inner.x / outer.x)
	var start_b := Vector3(b.base).lerp(b.tip, inner.y / outer.y)
	var points := [start_a, a.tip, b.tip, start_a, b.tip, start_b]
	for corner in points.size():
		var sample_index: int = RIBBON_SAMPLE[corner]
		_mesh.surface_set_uv(Vector2(lerpf(inner[sample_index], outer[sample_index], RIBBON_U[corner]), ages[sample_index]))
		_mesh.surface_set_color(tint)
		_mesh.surface_add_vertex(points[corner])

func _add_thrust_glint(point: Dictionary, opacity: float) -> void:
	# The thrust can sweep nearly zero area. Span its outer blade length
	# vertically so the accent adds no horizontal reach past the clipped tip.
	var end: Vector3 = point.tip
	var start := Vector3(point.base).lerp(end, 0.42)
	for corner in RIBBON_SAMPLE.size():
		var along: float = float(RIBBON_SAMPLE[corner])
		var across: float = RIBBON_U[corner]
		# Negative V lets the glint share this mesh's one slash material.
		_mesh.surface_set_uv(Vector2(along, across - 1.5))
		_mesh.surface_set_color(Color(1.0, 1.0, 1.0, opacity))
		var height := (across * 2.0 - 1.0) * THRUST_GLINT_HALF_HEIGHT
		_mesh.surface_add_vertex(start.lerp(end, along) + Vector3.UP * height)

func reset()->void:
	samples.clear();_was_active=false;_ribbon_section=0;serial=-1;clock=0.;_mesh.clear_surfaces()
	for particle:Dictionary in particles:particle.life=0.;particle.born=-INF;particle.history.clear()
	if sparks!=null:present()
