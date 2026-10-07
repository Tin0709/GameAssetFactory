extends SceneTree
## GPU readback executes the actual production vertex shader, not a CPU reimplementation.
var checks := 0
var failures: Array[String] = []
var material: ShaderMaterial
var viewport: SubViewport
var probe: MeshInstance3D
var baseline: Array[Vector3] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("GRASSLAND GPU: " + message)

func _initialize() -> void:
	call_deferred("run")

func readback() -> Array[Vector3]:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var values: Array[Vector3] = []
	for i in range(8):
		var c := image.get_pixel(i * 16 + 8, 8).srgb_to_linear()
		values.append(Vector3(c.r, c.g, c.b) * 0.25)
	return values

func offsets() -> Array[Vector3]:
	var values := await readback()
	for i in range(values.size()): values[i] -= baseline[i]
	return values

func sample(strength: float, birth_age: float, last_age: float, attack: float, sideways := false) -> void:
	var starts := PackedVector4Array()
	var ends := PackedVector4Array()
	starts.resize(8); ends.resize(8)
	starts.fill(Vector4.ZERO); ends.fill(Vector4(0, 0, 0.8, 0.14))
	starts[0] = Vector4(-0.15 if not sideways else 0.0, 0.0 if not sideways else -0.15, birth_age, strength)
	ends[0] = Vector4(0.15 if not sideways else 0.0, 0.0 if not sideways else 0.15, last_age, attack)
	material.set_shader_parameter("motion_start", starts)
	material.set_shader_parameter("motion_end", ends)

func run() -> void:
	check(DisplayServer.get_name() != "headless", "GPU checks require a rendered display")
	if not failures.is_empty(): quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(128, 16)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 3)
	viewport.add_child(camera)
	# Adapt only output/rasterization: vertex computation is copied verbatim at runtime.
	var source := FileAccess.get_file_as_string("res://materials/grassland_grass.gdshader")
	source = source.replace("render_mode cull_disabled, diffuse_lambert, specular_disabled, vertex_lighting;", "render_mode unshaded, cull_disabled, depth_test_disabled;")
	source = source.replace("void vertex() {", "varying vec3 measured_offset;\nvoid vertex() {\nvec3 before = VERTEX;")
	var end := source.find("\n}\n\nvoid fragment()")
	check(end > 0, "Production shader probe attached to real vertex function")
	source = source.substr(0, end) + "\nmeasured_offset = (MODEL_MATRIX * vec4(VERTEX - before, 0.0)).xyz;\nPOSITION = vec4(UV * 2.0 - 1.0, 0.5, 1.0);\n}\nvoid fragment() { ALBEDO = measured_offset / 0.25 + vec3(0.5); }"
	var shader := Shader.new()
	shader.code = source
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("wind_strength", 0.0)
	probe = MeshInstance3D.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights := [0.0, 0.6, 0.6, 0.6, 0.6, 0.39, 0.132, 0.6]
	var roots := [Vector2.ZERO, Vector2.ZERO, Vector2(-0.1726, 0), Vector2(1.5, 0), Vector2(0, 0.3), Vector2.ZERO, Vector2.ZERO, Vector2(-0.1724, 0)]
	for i in range(8):
		var t: float = float(heights[i]) / 0.6
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(Vector2((i + corner.x) / 8.0, corner.y))
			tool.set_uv2(Vector2(roots[i].x + 0.5, 0.5 + roots[i].y))
			tool.set_color(Color(t * t, t, 0.6 / 0.7, 1))
			tool.add_vertex(Vector3(roots[i].x, heights[i], roots[i].y))
	probe.mesh = tool.commit()
	probe.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	probe.material_override = material
	viewport.add_child(probe)
	sample(0, 0, 0.8, 0.14)
	baseline = await readback()
	material.set_shader_parameter("wind_strength", 1.0)
	material.set_shader_parameter("wind_phase", PI / 2)
	var wind := await offsets()
	check(wind[0].length() < 0.001, "Wind roots remain anchored")
	check(wind[1].x > 0.014 and wind[1].length() < 0.025, "Approved subtle 1.8cm wind reaches tip")
	check(wind[5].length() < wind[1].length() and wind[6].length() < wind[5].length(), "Middle and lower rings bend less than tips")
	probe.rotation.y = PI / 2
	var rotated := await offsets()
	check(rotated[1].distance_to(wind[1]) < 0.002, "Rotated patch preserves world wind direction")
	probe.rotation.y = 0
	material.set_shader_parameter("wind_phase", PI / 2 + TAU)
	var seam := await offsets()
	check(seam[1].distance_to(wind[1]) < 0.001, "Global wind loop has continuous seam")
	material.set_shader_parameter("wind_strength", 0.0)
	sample(0.05, 0.2, 0, 0.14)
	var walk := await offsets()
	check(walk[0].length() < 0.001, "Player disturbance leaves roots planted")
	check(walk[1].x > 0.044 and walk[1].x < 0.056, "Walking gives a small 5cm forward bend")
	check(walk[3].length() < 0.001, "Distant blade remains unaffected")
	check(walk[4].z > 0.012, "Nearby blade bends outward from the path")
	check(walk[2].distance_to(walk[7]) < 0.004, "Outward/movement cancellation crosses smoothly without a direction snap")
	sample(0.09, 0.2, 0, 0.07)
	var sprint := await offsets()
	check(sprint[1].x > walk[1].x * 1.6 and sprint[1].x < 0.10, "Sprint bends more strongly without exaggeration")
	check(sprint[1].y < -0.003, "Blade shortens its arc rather than stretching")
	material.set_shader_parameter("wind_strength", 1.0)
	var combined := await offsets()
	check(absf(combined[1].x - sprint[1].x - wind[1].x) < 0.002, "Shared wind and local player disturbance add on the GPU")
	check(combined[0].length() < 0.001, "Combined effects still leave roots planted")
	material.set_shader_parameter("wind_strength", 0.0)
	sample(0.09, 0.04, 0, 0.07)
	var fast_attack := await offsets()
	sample(0.05, 0.04, 0, 0.14)
	var slow_attack := await offsets()
	check(fast_attack[1].x > slow_attack[1].x * 2, "Sprint attacks faster than walking")
	sample(0.05, 0.2, 0, 0.14, true)
	var sideways := await offsets()
	check(sideways[1].z > 0.044 and absf(sideways[1].x) < 0.002, "Sideways passage uses player movement direction")
	sample(0.09, 0.6, 0.4, 0.07)
	var recovery := await offsets()
	check(recovery[1].x > 0.025 and recovery[1].x < sprint[1].x * 0.8, "Stopped disturbance fades softly through recovery")
	sample(0.09, 1.0, 0.8, 0.07)
	var expired := await offsets()
	check(expired[1].length() < 0.001, "Trail returns completely after 0.8 seconds")
	material.set_shader_parameter("wind_strength", 1.0)
	var recovered_wind := await offsets()
	check(recovered_wind[1].distance_to(wind[1]) < 0.001, "Wind continues after disturbance expires")
	var report := {"checks": checks, "failures": failures, "wind_tip_m": wind[1].length(), "walk_tip_x_m": walk[1].x, "sprint_tip_x_m": sprint[1].x,
		"root_motion_m": sprint[0].length(), "far_motion_m": walk[3].length(), "readback_tolerance_m": 0.002}
	print(JSON.stringify(report))
	FileAccess.open("res://.validation/grassland_gpu.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	quit(0 if failures.is_empty() else 1)
