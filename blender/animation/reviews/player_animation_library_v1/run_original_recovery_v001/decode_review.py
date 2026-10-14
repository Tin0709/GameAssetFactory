import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
s=bpy.context.scene;s.render.resolution_x=1280;s.render.resolution_y=690;s.render.resolution_percentage=100
s.render.fps=30;s.view_settings.view_transform='Standard';s.view_settings.look='None'
s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
ed=s.sequence_editor_create();strip=ed.strips.new_movie('Review decode',str(OUT/'approved_vs_candidate_side_1x.mp4'),channel=1,frame_start=1)
assert strip.frame_final_duration==102
for f in [10,11,17,18]:
 s.frame_set(f);s.render.filepath=str(OUT/f'decoded_{f:03d}.png');bpy.ops.render.render(write_still=True)
assert not bpy.data.actions
print('DECODED_REVIEW_FRAMES',flush=True)
