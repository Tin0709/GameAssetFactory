import bpy,json
from pathlib import Path
HERE=Path('/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/actions_stuff_walk_v001');frames=Path('/tmp/codex-player-walk-01a1399a/frames')
s=bpy.context.scene;s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100;s.render.fps=30;s.frame_start=1;s.frame_end=144;s.render.use_sequencer=True;s.render.use_compositing=False
s.view_settings.view_transform='Standard';s.view_settings.look='None'
ed=s.sequence_editor_create();strips=getattr(ed,'strips',getattr(ed,'sequences',None));strip=strips.new_image('Walking preview',str(frames/'walking_0001.png'),channel=1,frame_start=1)
for i in range(1,144):strip.elements.append(f'walking_{i%24+1:04}.png')
strip.frame_final_duration=144
s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.filepath=str(HERE/'walking_1x.mp4')
bpy.ops.render.render(animation=True)
(HERE/'media_verification.json').write_text(json.dumps({'frames':144,'fps':30,'duration_s':4.8,'cycles':6,'source_frames_per_cycle':24,'closing_key_excluded':25,'output':str(HERE/'walking_1x.mp4')},indent=2))
print('VIDEO_READY',str(HERE/'walking_1x.mp4'))
