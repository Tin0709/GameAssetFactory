extends "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/local_exposure_v001/local_exposure_effect.gd"
## Latches the strength actually submitted alongside the borrowed raw/statistics.
var _source_frame:=-1
var _source_strength:=0.
func rendered_source()->Dictionary:
 return {"frame":_source_frame,"strength":_source_strength}
func _render_pass(rd:RenderingDevice,framebuffer:RID,pipeline:RID,uniform_set:RID,control:PackedByteArray=PackedByteArray())->void:
 if pipeline==_final_pipeline and control.size()==16:
  _source_strength=control.decode_float(4)if control.decode_float(0)>0. else 0.
  _source_frame=_frames+1
 super(rd,framebuffer,pipeline,uniform_set,control)
func _release_resources()->void:
 _source_frame=-1;_source_strength=0.
 super()
