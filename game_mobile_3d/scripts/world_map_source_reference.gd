extends "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/local_exposure_v001/local_exposure_effect.gd"
## Latches the strength actually submitted alongside the borrowed raw/statistics.
var _source_frame:=-1
var _source_strength:=0.
var _source_shadow_lift:=1.
var _guide_scale := 1.
var _blur_scale := 1.
var _submitted_guide_scale := 1.
var _guide_buffer := RID()
var _original_guide_weight := 0.

func set_guide_scale(value: float) -> void:
 _mutex.lock()
 _guide_scale = clampf(value, 0., 1.) if is_finite(value) else 1.
 _mutex.unlock()

func set_blur_scale(value: float) -> void:
 _mutex.lock()
 _blur_scale = clampf(value, .5, 1.) if is_finite(value) else 1.
 _mutex.unlock()

func _statistics_blur_scale() -> float:
 _mutex.lock()
 var scale := _blur_scale
 _mutex.unlock()
 return scale

func rendered_source()->Dictionary:
 return {"frame":_source_frame,"strength":_source_strength,"shadow_lift":_source_shadow_lift,
  "guide_scale":_submitted_guide_scale,"blur_scale":_graph.blur_scale}

func _storage_uniform(rd: RenderingDevice, binding: int, bytes: PackedByteArray) -> RDUniform:
 var uniform := super(rd, binding, bytes)
 if binding == 3 and bytes.size() == 64 and bytes == _parameters.get("final"):
  _guide_buffer = uniform.get_ids()[0]
  _original_guide_weight = bytes.decode_float(16)
  _submitted_guide_scale = 1.
 return uniform

func _render_pass(rd:RenderingDevice,framebuffer:RID,pipeline:RID,uniform_set:RID,control:PackedByteArray=PackedByteArray())->void:
 if pipeline==_final_pipeline and control.size()==16:
  _mutex.lock()
  var scale := _guide_scale
  _mutex.unlock()
  if scale != _submitted_guide_scale and _guide_buffer.is_valid():
   var data := PackedFloat32Array([_original_guide_weight * scale]).to_byte_array()
   if rd.buffer_update(_guide_buffer, 16, data.size(), data) == OK:
    _submitted_guide_scale = scale
  _source_strength=control.decode_float(4)if control.decode_float(0)>0. else 0.
  _source_shadow_lift=control.decode_float(8)
  _source_frame=_frames+1
 super(rd,framebuffer,pipeline,uniform_set,control)
func _release_resources()->void:
 _source_frame=-1;_source_strength=0.;_source_shadow_lift=1.
 _guide_buffer = RID()
 _submitted_guide_scale = 1.
 super()
