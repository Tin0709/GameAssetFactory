extends SceneTree

const MODULE := "res://scripts/world_map_far_shadow_receivers.gd"
const MIST := &"gaf_mist_base"
const ENABLE := "#define GAF_FAR_TERRAIN_SHADOWS"
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks+=1
	if not condition:
		failures.append(label)

func shader(probe: bool) -> Shader:
	var value:=Shader.new()
	var guard: String = "\n#ifdef GAF_FAR_TERRAIN_SHADOWS\n#endif" if probe else ""
	value.code = "shader_type spatial;\nuniform vec4 local_value;" + guard + "\nvoid fragment(){ALBEDO=local_value.rgb;}"
	return value

func finish() -> void:
	print("FAR_RECEIVER_LIFECYCLE ",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	check(ResourceLoader.exists(MODULE),"WorldMap has a receiver lifecycle")
	if not failures.is_empty():
		finish()
		return
	var source: Script=load(MODULE)
	if source==null or not source.can_instantiate():
		check(false,"Receiver module must compile")
		finish()
		return

	var controller=source.new()
	var original:=shader(true)
	var mist:=shader(true)
	mist.set_meta(MIST,original)
	var opaque:=ShaderMaterial.new()
	opaque.shader=original
	opaque.set_shader_parameter("local_value",Vector4(1.,2.,3.,4.))
	var fog:=ShaderMaterial.new()
	fog.shader=mist
	var ignored:=ShaderMaterial.new()
	ignored.shader=shader(false)
	var native_ignored:=ignored.shader

	check(controller.bind([opaque,fog,ignored,fog]),"New receiver materials are assigned once")
	var treated:=opaque.shader
	check(treated!=original and treated.code.contains(ENABLE),"Opaque source gains the far-shadow compile switch")
	check(fog.shader.get_meta(MIST)==treated and fog.shader.code.contains(ENABLE),"Mist passes through the same far-shadow base")
	check(ignored.shader==native_ignored,"Materials without a receiver keep their shader")
	check(controller.authored_shader(fog.shader)==original,"Native owners see their source under both effects")
	check(opaque.get_shader_parameter("local_value")==Vector4(1.,2.,3.,4.),"Existing shader parameters survive the swap")
	check(not controller.bind([opaque,fog]),"A stable scene needs neither a compile nor a material change")
	var replacement:=shader(true)
	opaque.shader=replacement
	check(controller.bind([opaque,fog]),"An independent preset can replace a bound material")
	check(controller.authored_shader(opaque.shader)==replacement,"Receiver follows the replacement")
	check(controller.bind([opaque]),"Materials leaving the provider are returned")
	check(fog.shader==mist,"Mist shader identity is restored on removal")
	controller.release()
	check(opaque.shader==replacement,"Cleanup restores the latest preset rather than the initial one")
	check(opaque.get_shader_parameter("local_value")==Vector4(1.,2.,3.,4.),"Parameters survive restoration")
	check(controller.bind([opaque]),"A later scene activation can reuse a cached variant")
	opaque.shader=original
	controller.release()
	check(opaque.shader==original,"Cleanup preserves a native shader chosen independently")
	finish()
