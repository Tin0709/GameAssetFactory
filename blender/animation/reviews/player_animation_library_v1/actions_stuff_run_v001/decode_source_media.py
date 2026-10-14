"""Decode final H264 samples through Blender's sequencer; do not save a blend."""
import bpy
from pathlib import Path
HERE=Path(__file__).resolve().parent
s=bpy.context.scene;s.render.resolution_percentage=100;s.render.fps=30
s.view_settings.view_transform='Standard';s.view_settings.look='None'
s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
for name,frames,width,height in [
 ('reference_source_approved_front_1x',[11,14,28,68],1536,578),
 ('source_full_take_1x',[1,180],512,578)]:
 s.sequence_editor_clear();ed=s.sequence_editor_create()
 strip=ed.strips.new_movie('Final media decode',str(HERE/(name+'.mp4')),channel=1,frame_start=1)
 s.render.resolution_x=width;s.render.resolution_y=height
 for f in frames:
  s.frame_set(f);s.render.filepath=str(HERE/f'decoded_{name}_{f:03d}.png')
  bpy.ops.render.render(write_still=True)
assert not bpy.data.actions
print('SIX_FINAL_VIDEO_SAMPLES_DECODED',flush=True)
