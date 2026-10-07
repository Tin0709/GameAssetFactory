import bpy,json
from pathlib import Path
OUT=Path(__file__).resolve().parent/'straight_study_r2s_review'
for job in json.loads((OUT/'video_manifest.json').read_text()):
 s=bpy.data.scenes.new('Encode_'+job['stem']);bpy.context.window.scene=s;ed=s.sequence_editor_create();strips=ed.strips if hasattr(ed,'strips') else ed.sequences
 folder=OUT/job['folder'];strip=strips.new_image(job['stem'],str(folder/'0001.png'),channel=1,frame_start=1)
 for i in range(2,job['frames']+1):strip.elements.append('%04d.png'%i)
 s.render.resolution_x,s.render.resolution_y=job['size'];s.render.resolution_percentage=100;s.render.fps=24;s.render.fps_base=1;s.frame_start=1;s.frame_end=job['frames'];s.render.use_sequencer=True
 s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE'
 s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1;s.render.filepath=str(OUT/(job['stem']+'.mp4'));bpy.ops.render.render(animation=True)
print('R2S_ENCODE_DONE',flush=True)
