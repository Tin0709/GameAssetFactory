import bpy,json,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
data=json.loads((HERE/'media_contract.json').read_text());s=bpy.context.scene
s.render.fps=30;s.view_settings.view_transform='Standard';s.view_settings.look='None'
s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG'
s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH';s.render.resolution_percentage=100
report=[]
for c in data['videos']:
 s.sequence_editor_clear();ed=s.sequence_editor_create();folder=HERE/'panels'/c['name']
 strip=ed.strips.new_image('Private source review',str(folder/'001.png'),channel=1,frame_start=1)
 for i in range(1,c['frames']):strip.elements.append(f'{i+1:03d}.png')
 strip.frame_final_duration=c['frames'];s.frame_start=1;s.frame_end=c['frames'];s.render.resolution_x=c['width'];s.render.resolution_y=c['height']
 s.render.filepath=str(HERE/(c['name']+'.mp4'));bpy.ops.render.render(animation=True)
 clip=bpy.data.movieclips.load(s.render.filepath)
 assert clip.frame_duration==c['frames']and clip.fps==30 and list(clip.size)==[c['width'],c['height']]
 report.append(dict(c,path=Path(s.render.filepath).name,sha256=hashlib.sha256(Path(s.render.filepath).read_bytes()).hexdigest(),bytes=Path(s.render.filepath).stat().st_size))
assert not bpy.data.actions
(HERE/'media_validation.json').write_text(json.dumps({'passed':True,'videos':report,'no_blend_saved':True,'no_reference_retime':True},indent=2))
print('NINE_RESEARCH_VIDEOS_VERIFIED',flush=True)
