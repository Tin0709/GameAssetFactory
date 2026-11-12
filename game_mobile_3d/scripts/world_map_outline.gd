extends CompositorEffect
## Brightens near-side depth edges using the existing HDR color attachment.

const VERTEX := """#version 450
void main() {
	vec2 corner = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
	gl_Position = vec4(corner * 2.0 - 1.0, 0.0, 1.0);
}
"""
const FRAGMENT := """#version 450
#define SAMPLES __OUTLINE_SAMPLES__
#define HAS_TERRAIN __OUTLINE_TERRAIN__
#if SAMPLES > 1
layout(set=0, binding=0) uniform sampler2DMS depth_map;
float read_depth(ivec2 p) {
	float nearest = texelFetch(depth_map, p, 0).r;
	for (int i = 1; i < SAMPLES; i++) nearest = max(nearest, texelFetch(depth_map, p, i).r);
	return nearest;
}
#else
layout(set=0, binding=0) uniform sampler2D depth_map;
float read_depth(ivec2 p) { return texelFetch(depth_map, p, 0).r; }
#endif
layout(push_constant, std430) uniform Outline {
	vec4 inverse_projection_z;
	vec4 settings;
#if HAS_TERRAIN
	mat4 world_from_clip;
	vec4 terrain_origin;
#endif
};
layout(location=0) out vec4 edge_color;

#if HAS_TERRAIN
layout(set=0, binding=1) uniform sampler2D terrain_columns;

vec2 read_column(ivec2 cell) {
	ivec2 extent = textureSize(terrain_columns, 0);
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, extent))) {
		return vec2(0.0);
	}
	return texelFetch(terrain_columns, cell, 0).ga;
}

bool is_wall(ivec2 first, ivec2 second, float height, float tolerance) {
	vec2 a = read_column(first);
	vec2 b = read_column(second);
	return a.y > 0.0 && b.y > 0.0 && abs(a.x - b.x) > tolerance * 2.0
		&& height > min(a.x, b.x) + tolerance && height < max(a.x, b.x) + tolerance;
}

bool is_terrain(float depth, vec2 uv) {
	// RenderSceneData supplies the renderer's Y-flipped, reverse-Z projection.
	vec4 point = world_from_clip * vec4(uv * 2.0 - 1.0, depth, 1.0);
	vec3 world = point.xyz / point.w;
	vec2 grid = world.xz - terrain_origin.xy;
	ivec2 cell = ivec2(floor(grid));
	vec2 top = read_column(cell);
	// MSAA can select a sample offset from the pixel center.
	const float tolerance = 0.027;
	if (top.y > 0.0 && abs(world.y - top.x) <= tolerance) return true;
	vec2 boundary = round(grid);
	if (abs(grid.x - boundary.x) <= tolerance) {
		ivec2 high_x = ivec2(int(boundary.x), cell.y);
		if (is_wall(high_x - ivec2(1, 0), high_x, world.y, tolerance)) return true;
	}
	if (abs(grid.y - boundary.y) <= tolerance) {
		ivec2 high_z = ivec2(cell.x, int(boundary.y));
		if (is_wall(high_z - ivec2(0, 1), high_z, world.y, tolerance)) return true;
	}
	return false;
}
#endif

void main() {
	ivec2 p = ivec2(gl_FragCoord.xy);
	ivec2 size = ivec2(settings.zw);
	int radius = int(settings.y);
	if (any(lessThan(p, ivec2(radius))) || any(greaterThanEqual(p, size - radius))) discard;
	float center = read_depth(p);
	if (center <= 0.000001) discard;

	// Symmetric offsets cancel a planar slope. A depth step behind the
	// current surface leaves a positive residual on the nearer side.
	float average = 0.25 * (read_depth(p + ivec2(radius, radius)) +
		read_depth(p - ivec2(radius, radius)) + read_depth(p + ivec2(radius, -radius)) +
		read_depth(p + ivec2(-radius, radius)));
	float residual = center - average;
	if (residual <= 0.000001) discard;

	vec4 q = inverse_projection_z;
	float denominator = q.z * (1.0 - 2.0 * center) + q.w;
	float meters_per_depth = 2.0 * abs(q.x * q.w - q.z * q.y) /
		max(denominator * denominator, 0.000001);
	float meters = residual * meters_per_depth;
	float edge = smoothstep(0.025 * float(radius), 0.24 * float(radius), meters);
	float gain = 0.25 * edge;
#if HAS_TERRAIN
	if (meters >= 0.004 * float(radius) && is_terrain(center, gl_FragCoord.xy / settings.zw)) {
		// Connected block faces have a crease even without a full depth step.
		float crease = smoothstep(0.004 * float(radius), 0.041 * float(radius), meters);
		gain = max(gain, 0.64 * crease);
	}
#endif
	edge_color = vec4(vec3(settings.x * gain), 0.0);
}
"""

var _guard := Mutex.new()
var _controls := Vector2(0.0, 1.0)
var _terrain_columns: Texture2D
var _terrain_origin := Vector2.ZERO
var _frames := 0
var _failure := ""
var _sampler := RID()
var _shaders: Dictionary = {}
var _pipelines: Dictionary = {}

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	enabled = false

static func supported(viewport: Viewport) -> bool:
	return viewport != null and viewport.msaa_3d <= Viewport.MSAA_8X \
		and RenderingServer.get_current_rendering_method() == "mobile" \
		and RenderingServer.get_rendering_device() != null

func configure(strength: float, thickness: int, terrain_columns: Texture2D = null,
		terrain_origin := Vector2.ZERO) -> void:
	var controls := Vector2(clampf(strength, 0.0, 4.0), clampi(thickness, 1, 4))
	_guard.lock()
	_controls = controls
	_terrain_columns = terrain_columns
	_terrain_origin = terrain_origin
	_guard.unlock()
	if enabled != (controls.x > 0.0):
		enabled = controls.x > 0.0

func snapshot() -> Dictionary:
	_guard.lock()
	var state := {"frames": _frames, "error": _failure}
	_guard.unlock()
	return state

func _fail(message: String) -> void:
	_guard.lock()
	_failure = message
	_guard.unlock()

func _render_callback(kind: int, data: RenderData) -> void:
	if kind != effect_callback_type:
		return
	_guard.lock()
	var controls := _controls
	var terrain_columns := _terrain_columns
	var terrain_origin := _terrain_origin
	var failed := not _failure.is_empty()
	_guard.unlock()
	if controls.x <= 0.0 or failed:
		return
	var rd := RenderingServer.get_rendering_device()
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene := data.get_render_scene_data()
	if rd == null or buffers == null or buffers.get_view_count() != 1 or scene == null:
		return
	var msaa := buffers.get_msaa_3d()
	if msaa > RenderingServer.VIEWPORT_MSAA_8X:
		return
	var depth := buffers.get_depth_layer(0, msaa != RenderingServer.VIEWPORT_MSAA_DISABLED)
	var color := buffers.get_color_layer(0)
	if not depth.is_valid() or not color.is_valid():
		return
	var depth_format := rd.texture_get_format(depth)
	var color_format := rd.texture_get_format(color)
	var sample_formats := [RenderingDevice.TEXTURE_SAMPLES_1, RenderingDevice.TEXTURE_SAMPLES_2,
		RenderingDevice.TEXTURE_SAMPLES_4, RenderingDevice.TEXTURE_SAMPLES_8]
	if depth_format.samples != sample_formats[msaa] or color_format.samples != RenderingDevice.TEXTURE_SAMPLES_1 \
			or depth_format.width != color_format.width or depth_format.height != color_format.height \
			or (depth_format.usage_bits & RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT) == 0:
		return

	var framebuffer := FramebufferCacheRD.get_cache_multipass([color], [], 1)
	if not framebuffer.is_valid():
		return
	var samples := 1 << msaa
	var terrain := RenderingServer.texture_get_rd_texture(terrain_columns.get_rid()) if terrain_columns != null else RID()
	var shader_key := Vector2i(samples, int(terrain.is_valid()))
	var pipeline := _get_pipeline(rd, shader_key, rd.framebuffer_get_format(framebuffer))
	if not pipeline.is_valid():
		return
	var source_depth := RDUniform.new()
	source_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	source_depth.add_id(_sampler)
	source_depth.add_id(depth)
	var inputs: Array[RDUniform] = [source_depth]
	if terrain.is_valid():
		var columns := RDUniform.new()
		columns.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		columns.binding = 1
		columns.add_id(_sampler)
		columns.add_id(terrain)
		inputs.append(columns)
	var uniforms := UniformSetCacheRD.get_cache(_shaders[shader_key], 0, inputs)
	if not uniforms.is_valid():
		return

	var inv := scene.get_cam_projection().inverse()
	var values := PackedFloat32Array([inv.z.z, inv.w.z, inv.z.w, inv.w.w,
		controls.x, controls.y, color_format.width, color_format.height])
	if terrain.is_valid():
		var from_clip := Projection(scene.get_cam_transform()) * inv
		for column: Vector4 in [from_clip.x, from_clip.y, from_clip.z, from_clip.w]:
			values.append_array([column.x, column.y, column.z, column.w])
		values.append_array([terrain_origin.x, terrain_origin.y, 0.0, 0.0])
	var constants := values.to_byte_array()
	var draw := rd.draw_list_begin(framebuffer)
	rd.draw_list_bind_render_pipeline(draw, pipeline)
	rd.draw_list_bind_uniform_set(draw, uniforms, 0)
	rd.draw_list_set_push_constant(draw, constants, constants.size())
	rd.draw_list_draw(draw, false, 1, 3)
	rd.draw_list_end()
	_guard.lock()
	_frames += 1
	_guard.unlock()

func _get_pipeline(rd: RenderingDevice, shader_key: Vector2i, framebuffer_format: int) -> RID:
	var key := Vector3i(shader_key.x, shader_key.y, framebuffer_format)
	if _pipelines.has(key):
		return _pipelines[key]
	if not _shaders.has(shader_key):
		var source := RDShaderSource.new()
		source.source_vertex = VERTEX
		source.source_fragment = FRAGMENT.replace("__OUTLINE_SAMPLES__", str(shader_key.x)) \
			.replace("__OUTLINE_TERRAIN__", str(shader_key.y))
		var spirv := rd.shader_compile_spirv_from_source(source)
		for stage in [RenderingDevice.SHADER_STAGE_VERTEX, RenderingDevice.SHADER_STAGE_FRAGMENT]:
			var error := spirv.get_stage_compile_error(stage)
			if not error.is_empty():
				_fail(error)
				return RID()
		var shader := rd.shader_create_from_spirv(spirv)
		if not shader.is_valid():
			_fail("World Outline shader could not be created")
			return RID()
		_shaders[shader_key] = shader
	if not _sampler.is_valid():
		_sampler = rd.sampler_create(RDSamplerState.new())
	var raster := RDPipelineRasterizationState.new()
	raster.cull_mode = RenderingDevice.POLYGON_CULL_DISABLED
	var blend := RDPipelineColorBlendStateAttachment.new()
	blend.enable_blend = true
	blend.color_blend_op = RenderingDevice.BLEND_OP_ADD
	blend.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_DST_COLOR
	blend.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	blend.write_a = false
	var colors := RDPipelineColorBlendState.new()
	colors.attachments = [blend]
	var pipeline := rd.render_pipeline_create(_shaders[shader_key], framebuffer_format, -1,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, raster, RDPipelineMultisampleState.new(),
		RDPipelineDepthStencilState.new(), colors)
	if not rd.render_pipeline_is_valid(pipeline):
		if pipeline.is_valid():
			rd.free_rid(pipeline)
		_fail("World Outline blend pipeline could not be created")
		return RID()
	_pipelines[key] = pipeline
	return pipeline

func release_on_render_thread() -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		return
	for rid: RID in _pipelines.values():
		rd.free_rid(rid)
	for rid: RID in _shaders.values():
		rd.free_rid(rid)
	if _sampler.is_valid():
		rd.free_rid(_sampler)
	_pipelines.clear()
	_shaders.clear()
	_sampler = RID()
