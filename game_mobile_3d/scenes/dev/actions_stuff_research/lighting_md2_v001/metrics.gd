extends RefCounted
## Render timings are NOT script CPU time or end-to-end frame latency.
var viewport:Viewport
var rid:RID
var data:Dictionary={}

func setup(target:Viewport)->void:
	viewport=target;rid=target.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)

func sample()->Dictionary:
	data["fps"]=Engine.get_frames_per_second()
	data["render_cpu_ms"]=RenderingServer.viewport_get_measured_render_time_cpu(rid)
	data["setup_cpu_ms"]=RenderingServer.get_frame_setup_time_cpu()
	data["gpu_ms"]=RenderingServer.viewport_get_measured_render_time_gpu(rid)
	data["process_ms"]=Performance.get_monitor(Performance.TIME_PROCESS)*1000.
	data["physics_ms"]=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.
	data["draws"]=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	data["objects"]=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
	data["primitives"]=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	data["shadow_draws"]=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	data["shadow_primitives"]=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	return data

func release()->void:
	if is_instance_valid(viewport):RenderingServer.viewport_set_measure_render_time(rid,false)
