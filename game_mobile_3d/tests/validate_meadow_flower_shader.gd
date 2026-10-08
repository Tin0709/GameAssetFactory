extends SceneTree
## Rasterize displacement from the actual production vertex function, including native GLB vertices.
const ASSET := "res://assets/environment/meadow_flowers_v1/white_flower_patch_1m.glb"
var checks := 0
var failures: Array[String] = []
var material: ShaderMaterial
var viewport: SubViewport
var probe: MeshInstance3D
var positions: Array[Vector3] = []
var masks: Array[Vector2] = []
var roots: Array[Vector2] = []
var baseline: Array[Vector3] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("FLOWER GPU: " + message)

func _initialize() -> void:
	call_deferred("run")

func readback() -> Array[Vector3]:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var values: Array[Vector3] = []
	for i in positions.size():
		var c := image.get_pixel(i*4+2,2).srgb_to_linear()
		values.append(Vector3(c.r,c.g,c.b)*.4)
	return values

func offsets() -> Array[Vector3]:
	var values := await readback()
	for i in values.size(): values[i]-=baseline[i]
	return values

func sample(strength: float, birth: float, age: float, reversed := false) -> void:
	var starts := PackedVector4Array(); var ends := PackedVector4Array()
	starts.resize(8); ends.resize(8)
	starts.fill(Vector4.ZERO); ends.fill(Vector4(0,0,.8,.14))
	starts[0]=Vector4(.15 if reversed else -.15,0,birth,strength)
	ends[0]=Vector4(-.15 if reversed else .15,0,age,.07 if strength>.05 else .14)
	material.set_shader_parameter("motion_start",starts)
	material.set_shader_parameter("motion_end",ends)

func rigid(values: Array[Vector3], label: String) -> void:
	check(absf((positions[1]+values[1]).distance_to(positions[2]+values[2])-.1)<.003,label+" synthetic white/yellow head retains shape")
	check(absf((positions[5]+values[5]).distance_to(positions[6]+values[6])-.06)<.003,label+" leaf plane retains shape")
	var first: Dictionary = {}
	var native_pairs := 0
	for i in range(7,positions.size()):
		if masks[i].x<.999: continue
		var key := Vector3(roots[i].x,roots[i].y,masks[i].y)
		if not first.has(key): first[key]=i; continue
		var j: int=first[key]
		var distance := positions[i].distance_to(positions[j])
		if distance<.035: continue
		native_pairs+=1
		check(absf((positions[i]+values[i]).distance_to(positions[j]+values[j])-distance)<.004,label+" imported complete head is rigid")
	check(native_pairs>5,label+" exercises native petal/center vertex pairs")

func run() -> void:
	check(DisplayServer.get_name()!="headless","Actual GPU display required")
	check(ResourceLoader.exists(ASSET),"Native authored flower is imported")
	if not failures.is_empty(): quit(1); return
	# Deliberate fixtures: planted root, centre, petal, far flower, outward flower, leaf pair.
	positions=[Vector3.ZERO,Vector3(.05,.35,0),Vector3(-.05,.35,0),Vector3(1.5,.35,0),Vector3(0,.35,.3),Vector3(.03,.175,0),Vector3(-.03,.175,0)]
	masks=[Vector2(0,.65),Vector2(1,.65),Vector2(1,.65),Vector2(1,.65),Vector2(1,.65),Vector2(.5,.65),Vector2(.5,.65)]
	roots=[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2(1.5,0),Vector2(0,.3),Vector2.ZERO,Vector2.ZERO]
	var asset_root: Node3D=load(ASSET).instantiate()
	var nodes: Array[Node]=asset_root.find_children("*","MeshInstance3D",true,false)
	var arrays: Array=nodes[0].mesh.surface_get_arrays(0)
	var native: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var native_masks: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var native_roots: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
	for i in native.size():
		positions.append(native[i]);masks.append(native_masks[i]);roots.append(native_roots[i]-Vector2(.5,.5))
	asset_root.free()
	viewport=SubViewport.new();viewport.size=Vector2i(positions.size()*4,4)
	viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera:=Camera3D.new();camera.position=Vector3(0,0,3);viewport.add_child(camera)
	var source:=FileAccess.get_file_as_string("res://materials/meadow_flowers_v1.gdshader")
	source=source.replace("render_mode cull_disabled, diffuse_lambert, specular_disabled;","render_mode unshaded, cull_disabled, depth_test_disabled;")
	source=source.replace("void vertex() {","varying vec3 measured_offset;\nvoid vertex() {\nvec3 before = VERTEX;")
	var end:=source.find("\n}\n\nvoid fragment()")
	check(end>0,"Probe attaches to actual production vertex function")
	source=source.substr(0,end)+"\nmeasured_offset = (MODEL_MATRIX * vec4(VERTEX - before, 0.0)).xyz;\nPOSITION = vec4(CUSTOM0.rg * 2.0 - 1.0, 0.5, 1.0);\n}\nvoid fragment() { ALBEDO = measured_offset / 0.4 + vec3(0.5); }"
	var shader:=Shader.new();shader.code=source
	material=ShaderMaterial.new();material.shader=shader
	material.set_shader_parameter("wind_strength",0.0)
	probe=MeshInstance3D.new()
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0,SurfaceTool.CUSTOM_RG_FLOAT)
	for i in positions.size():
		for corner in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(masks[i]);tool.set_uv2(roots[i]+Vector2(.5,.5))
			tool.set_custom(0,Color((float(i)+corner.x)/positions.size(),corner.y,0,1))
			tool.add_vertex(positions[i])
	probe.mesh=tool.commit();probe.custom_aabb=AABB(Vector3(-5,-5,-5),Vector3(10,10,10))
	probe.material_override=material;viewport.add_child(probe)
	sample(0,0,.8);baseline=await readback()
	material.set_shader_parameter("wind_strength",1.0);material.set_shader_parameter("wind_phase",PI/2)
	var wind:=await offsets()
	check(wind[0].length()<.0015,"Wind anchors root")
	check(wind[1].x>.01 and wind[1].length()<.025,"Gentle wind moves whole head")
	rigid(wind,"Wind")
	probe.rotation.y=PI/2
	var rotated:=await offsets()
	# The head centre is offset X=.05, so compare zero-X leaf's pair midpoint.
	check(((rotated[5]+rotated[6])*.5).distance_to((wind[5]+wind[6])*.5)<.003,"Rotated instance preserves world wind")
	probe.rotation.y=0
	material.set_shader_parameter("wind_strength",0.0)
	sample(.05,.2,0)
	var walk:=await offsets()
	check(walk[0].length()<.0015,"Walking anchors root")
	check(walk[1].x>.05 and walk[1].x<.075,"Walk bends nearby head gently")
	check(walk[3].length()<.0015,"Distant flower inside same mesh is unaffected")
	check(walk[4].z>.03,"Near-path flower responds outward")
	rigid(walk,"Walk")
	sample(.09,.2,0)
	var sprint:=await offsets()
	check(sprint[1].x>walk[1].x*1.5,"Sprint response exceeds walk")
	check(sprint[1].length()<.125,"Head displacement remains bounded")
	rigid(sprint,"Sprint")
	material.set_shader_parameter("interaction_gain",10.0)
	var capped:=await offsets()
	var center: Vector3=(capped[1]+capped[2])*.5
	check(Vector2(center.x,center.z).length()<=.122,"Extreme passage obeys 12cm head-centre travel limit")
	check(atan2(Vector2(center.x,center.z).length(),.35+center.y)<=PI/6+.01,"Extreme passage remains below 30 degree head tilt")
	rigid(capped,"Capped")
	material.set_shader_parameter("interaction_gain",0.0)
	var disabled:=await offsets()
	check(disabled[1].length()<.0015,"Zero interaction gain independently disables passage")
	material.set_shader_parameter("interaction_gain",1.3)
	sample(.09,.6,.4)
	var recovery:=await offsets()
	check(recovery[1].x>0 and recovery[1].x<sprint[1].x*.8,"Stop fades continuously")
	sample(.09,1,.8)
	var expired:=await offsets()
	check(expired[1].length()<.0015,"Full recovery at 0.8 seconds")
	sample(.05,.2,0,true)
	var reverse:=await offsets()
	check(reverse[1].x<-.05,"Reverse passage bends oppositely")
	var motion=load("res://scripts/grassland_motion.gd").new()
	var point:=Vector3(-.65,0,0)
	motion.advance(0,point,Vector3.ZERO,4.25,6.25)
	var previous: Array[Vector3]=expired
	var peak_step:=0.0
	for i in 40:
		var velocity:=Vector3(4.25 if i<20 else -4.25,0,0)
		point+=velocity/60.0
		motion.advance(1.0/60.0,point,velocity,4.25,6.25)
		motion.publish(material)
		var now:=await offsets()
		peak_step=maxf(peak_step,now[1].distance_to(previous[1]));previous=now
	check(peak_step<.03,"Actual bounded history reverses without head snap")
	for i in native.size():
		if native_masks[i].x<.001: check(sprint[i+7].length()<.0015,"Native GLB root remains planted")
	var report:={"checks":checks,"failures":failures,"native_vertices":native.size(),"walk_head_x_m":walk[1].x,"sprint_head_x_m":sprint[1].x,"peak_reversal_step_m":peak_step,"tolerance_m":.004}
	DirAccess.make_dir_recursive_absolute("res://.validation/meadow_flowers_v1")
	FileAccess.open("res://.validation/meadow_flowers_v1/gpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FLOWER_GPU "+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
