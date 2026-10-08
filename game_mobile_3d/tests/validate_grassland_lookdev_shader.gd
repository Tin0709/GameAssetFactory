extends SceneTree
## Compare actual GPU vertex displacement in current/new shaders, including widened influence.
var failures: Array[String] = []
var checks := 0
var viewport: SubViewport
var probe: MeshInstance3D
var material: ShaderMaterial
var baseline: Array[Vector3]

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func readback() -> Array[Vector3]:
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	var result: Array[Vector3] = []
	for i in range(8):
		var color := pixels.get_pixel(i * 16 + 8, 8).srgb_to_linear()
		result.append(Vector3(color.r, color.g, color.b) * 0.5)
	return result

func offsets(wind: float, strength: float, age := 0.2, last_age := 0.0) -> Array[Vector3]:
	material.set_shader_parameter("wind_strength", wind)
	material.set_shader_parameter("wind_phase", PI / 2.0)
	var starts := PackedVector4Array()
	var ends := PackedVector4Array()
	starts.resize(8)
	ends.resize(8)
	starts.fill(Vector4.ZERO)
	ends.fill(Vector4(0, 0, 0.8, 0.07))
	starts[0] = Vector4(-0.15, 0, age, strength)
	ends[0] = Vector4(0.15, 0, last_age, 0.07)
	material.set_shader_parameter("motion_start", starts)
	material.set_shader_parameter("motion_end", ends)
	var result := await readback()
	for i in range(8): result[i] -= baseline[i]
	return result

func measure(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	var regex := RegEx.new()
	regex.compile("render_mode[^;]+;")
	source = regex.sub(source, "render_mode unshaded, cull_disabled, depth_test_disabled;")
	source = source.replace("void vertex() {", "varying vec3 measured;\nvoid vertex() {\nvec3 before = VERTEX;")
	var end := source.find("\n}\n\nvoid fragment()")
	source = source.substr(0, end) + "\nmeasured = (MODEL_MATRIX * vec4(VERTEX - before, 0.0)).xyz;\nPOSITION = vec4(UV * 2.0 - 1.0, 0.5, 1.0);\n}\nvoid fragment() { ALBEDO = measured / 0.5 + vec3(0.5); }"
	var shader := Shader.new()
	shader.code = source
	material = ShaderMaterial.new()
	material.shader = shader
	probe.material_override = material
	material.set_shader_parameter("wind_strength", 0.0)
	baseline = await readback()
	return {"wind": await offsets(1, 0), "walk": await offsets(0, 0.05), "sprint": await offsets(0, 0.09),
		"combined": await offsets(1, 0.20), "recovery": await offsets(0, 0.09, 0.6, 0.4), "expired": await offsets(0, 0.09, 1.0, 0.8)}

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendered Mobile display required")
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(128, 16)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 3)
	viewport.add_child(camera)
	probe = MeshInstance3D.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var roots := [Vector2.ZERO, Vector2.ZERO, Vector2(0, 0.78), Vector2(1.5, 0), Vector2(-0.1726, 0), Vector2(-0.1724, 0), Vector2.ZERO, Vector2.ZERO]
	var heights := [0.0, 0.6, 0.6, 0.6, 0.6, 0.6, 0.39, 0.132]
	for i in range(8):
		var t: float = heights[i] / 0.6
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(Vector2((i + corner.x) / 8.0, corner.y))
			tool.set_uv2(roots[i] + Vector2(0.5, 0.5))
			tool.set_color(Color(t * t, t, 0.6 / 0.7, 1))
			tool.add_vertex(Vector3(roots[i].x, heights[i], roots[i].y))
	probe.mesh = tool.commit()
	probe.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	viewport.add_child(probe)
	var current := await measure("res://materials/grassland_grass.gdshader")
	var styled := await measure("res://materials/lookdev_grass.gdshader")
	check(styled.wind[0].length() < 0.002 and styled.combined[0].length() < 0.002, "New wind and interaction keep roots planted")
	check(styled.wind[1].x > current.wind[1].x * 2.4, "New wind is visibly stronger")
	check(styled.walk[1].x > current.walk[1].x * 1.6, "New player splay is stronger")
	check(current.sprint[2].length() < 0.002 and styled.sprint[2].length() > 0.002, "New influence reaches blades beyond original radius")
	check(styled.combined[1].x < 0.211 and styled.combined[1].x > 0.18, "Combined bend is capped near 20cm")
	check(styled.sprint[3].length() < 0.002, "Distant grass remains unaffected")
	check(styled.sprint[4].distance_to(styled.sprint[5]) < 0.005, "Cancellation stays continuous")
	check(styled.recovery[1].x > 0.03 and styled.recovery[1].x < styled.sprint[1].x * 0.8, "Player splay fades softly")
	check(styled.expired[1].length() < 0.002, "Original 0.8 second recovery retained")
	check(styled.wind[7].length() < styled.wind[6].length() and styled.wind[6].length() < styled.wind[1].length(), "Lower rings bend less than tips")
	var tip: Vector3 = styled.combined[1]
	check(absf(Vector2(tip.x, tip.y + 0.6).length() - 0.6) < 0.005, "Bend shortens arc without stretching blade")
	var report := {"checks": checks, "failures": failures, "current_wind_m": current.wind[1].x, "new_wind_m": styled.wind[1].x,
		"current_walk_m": current.walk[1].x, "new_walk_m": styled.walk[1].x, "new_combined_m": styled.combined[1].x}
	FileAccess.open("res://.validation/lookdev_gpu.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
