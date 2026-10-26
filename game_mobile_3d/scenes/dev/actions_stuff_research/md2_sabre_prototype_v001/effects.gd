extends Node3D
## A bounded ribbon follows the actual exported blade markers. These authored
## gates describe fast motion only; whiffs do not spawn fake damage or hitstop.
const MAX_SAMPLES:=28
const PARTICLE_CAPACITY:=48
var samples:Array[Dictionary]=[]
var particles:Array[Dictionary]=[]
var clock:=0.
var serial:=-1
var bursts:=0
var ribbon:MeshInstance3D
var sparks:MultiMeshInstance3D
var enabled:=true
var intensity:=.75
var _mesh:=ImmediateMesh.new()
var _rng:=RandomNumberGenerator.new()
var _was_active:=false
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
	for i in PARTICLE_CAPACITY:particles.append({"life":0.,"position":Vector3.ZERO,"velocity":Vector3.ZERO,"duration":.3})
	reset()
func sample(delta:float,active:bool,base:Vector3,tip:Vector3,attack_serial:int)->void:
	clock+=delta
	if not enabled:active=false
	if active:
		if serial!=attack_serial:samples.clear();serial=attack_serial;_was_active=false
		if not _was_active:_burst(tip,tip-_previous_tip)
		samples.append({"base":base,"tip":tip,"time":clock})
		if samples.size()>MAX_SAMPLES:samples.pop_front()
	while not samples.is_empty() and clock-float(samples[0].time)>.14:samples.pop_front()
	for particle:Dictionary in particles:
		if float(particle.life)>0.:
			particle.life=maxf(0.,float(particle.life)-delta);particle.velocity+=Vector3(0,-1.8,0)*delta;particle.position+=particle.velocity*delta
	_was_active=active;_previous_tip=tip
func _burst(point:Vector3,direction:Vector3)->void:
	bursts+=1;var added:=0
	for particle:Dictionary in particles:
		if particle.life>0.:continue
		var duration:=_rng.randf_range(.13,.3)
		particle.position=point;particle.velocity=direction.normalized()*_rng.randf_range(.2,.8)+Vector3(_rng.randf_range(-.7,.7),_rng.randf_range(.1,.7),_rng.randf_range(-.7,.7))
		particle.duration=duration;particle.life=duration;added+=1
		if added>=8:break
func present()->void:
	_mesh.clear_surfaces()
	if samples.size()>1:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(1,samples.size()):
			var a:Dictionary=samples[i-1];var b:Dictionary=samples[i]
			var opacity:=clampf(1.-(clock-float(a.time))/.14,0.,1.)*intensity*.58
			for point:Vector3 in [a.base,a.tip,b.tip,a.base,b.tip,b.base]:
				_mesh.surface_set_color(Color(1.,.73,.23,opacity));_mesh.surface_add_vertex(point)
			var a_inner:Vector3=Vector3(a.base).lerp(a.tip,.86);var b_inner:Vector3=Vector3(b.base).lerp(b.tip,.86)
			for point:Vector3 in [a_inner,a.tip,b.tip,a_inner,b.tip,b_inner]:
				_mesh.surface_set_color(Color(1.,.97,.82,opacity*.8));_mesh.surface_add_vertex(point)
		_mesh.surface_end()
	for i in particles.size():
		var particle:Dictionary=particles[i]
		var fade:=float(particle.life)/float(particle.duration)
		var scale:=Vector3.ONE*(maxf(.001,fade) if enabled else .001)
		sparks.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(scale),particle.position))
		sparks.multimesh.set_instance_color(i,Color(1.,.87,.4,fade*intensity if enabled else 0.))
func reset()->void:
	samples.clear();_was_active=false;serial=-1;clock=0.;_mesh.clear_surfaces()
	for particle:Dictionary in particles:particle.life=0.
	if sparks!=null:present()
